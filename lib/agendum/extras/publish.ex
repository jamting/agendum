# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Extras.Publish do
  @moduledoc """
  The micro-blog's shell (imperative, R74): reads what a folder holds of
  the site, writes the site the core made (`Agendum.Core.Extras.Site`), and
  uploads it, by `rsync` over ssh or by SFTP (OTP's own `ssh`, no other
  dependency; not FTP, which OTP deprecates and removes in OTP 30). Errors come back as a short sentence
  for the person.

  The folder keeps a list of the files Agendum wrote, `.agendum-site`, so
  that a post taken away is removed again, and nothing else in the folder
  (or on the server) is ever touched. Passwords are never kept: SFTP uses
  the person's ssh keys, else a password from `~/.netrc` or asked for.
  """

  alias Agendum.Core.Extras.{Site, Upload}

  @manifest ".agendum-site"
  # what a failed SFTP upload left to remove on the server
  @unsent ".agendum-unsent"
  # an SFTP call's longest wait, in milliseconds
  @timeout 60_000

  @typedoc "What a folder holds of the site: contents by path, and the last publish's paths."
  @type scan :: %{existing: %{optional(String.t()) => String.t()}, published: [String.t()]}

  @doc """
  What `folder` holds of the site: the content of each file Agendum would
  write or wrote last time, and the paths it wrote last time.
  """
  @spec scan(String.t(), [Site.file()]) :: {:ok, scan} | {:error, String.t()}
  def scan(folder, files) do
    published =
      case File.read(Path.join(folder, @manifest)) do
        {:ok, text} -> String.split(text, "\n", trim: true)
        {:error, _} -> []
      end

    paths = Enum.uniq(Enum.map(files, &elem(&1, 0)) ++ published)

    existing =
      for path <- paths,
          {:ok, content} <- [File.read(Path.join(folder, path))],
          into: %{},
          do: {path, content}

    {:ok, %{existing: existing, published: published}}
  end

  @doc """
  Writes the site into `folder`: the files added and changed (the
  stylesheet only when there is none or it is still Agendum's old one), and removes those taken away.
  """
  @spec write(String.t(), [Site.file()], Site.changes()) :: :ok | {:error, String.t()}
  def write(folder, files, changes) do
    contents = Map.new(files)

    with :ok <- mkdir(Path.join(folder, "posts")),
         :ok <- mkdir(Path.join(folder, "fonts")),
         :ok <- each(changes.added ++ changes.changed, &put(folder, &1, contents[&1])),
         :ok <- each(changes.removed, &remove(folder, &1)) do
      manifest = Enum.map_join(files, "\n", &elem(&1, 0))
      put(folder, @manifest, manifest <> "\n")
    end
  end

  defp mkdir(dir) do
    case File.mkdir_p(dir) do
      :ok -> :ok
      {:error, reason} -> {:error, "could not make #{dir} (#{:file.format_error(reason)})"}
    end
  end

  defp put(folder, path, content) do
    case File.write(Path.join(folder, path), content) do
      :ok -> :ok
      {:error, reason} -> {:error, "could not write #{path} (#{:file.format_error(reason)})"}
    end
  end

  defp remove(folder, path) do
    case File.rm(Path.join(folder, path)) do
      result when result in [:ok, {:error, :enoent}] -> :ok
      {:error, reason} -> {:error, "could not remove #{path} (#{:file.format_error(reason)})"}
    end
  end

  # each step in turn, stopping at the first error
  defp each(list, fun),
    do: Enum.reduce_while(list, :ok, fn x, :ok -> continue(fun.(x)) end)

  defp continue(:ok), do: {:cont, :ok}
  defp continue(error), do: {:halt, error}

  # --- uploading ------------------------------------------------------------------

  @doc """
  Uploads what the folder holds of the site, as the person's upload
  settings say (`:rsync` or `:sftp`); the files taken away are removed on the server too.
  `password` is the SFTP password, nil to use the person's ssh keys (and
  `~/.netrc`). `{:error, :password}` asks for one: the server refused the
  keys. `opts` are more ssh options (the tests give their own keys).
  """
  @spec upload(Upload.t(), String.t(), [Site.file()], Site.changes(), String.t() | nil, keyword) ::
          :ok | {:error, String.t() | :password}
  def upload(upload, folder, files, changes, password, opts \\ [])

  def upload(%Upload{method: :none}, _folder, _files, _changes, _password, _opts), do: :ok

  def upload(%Upload{method: :rsync} = upload, folder, files, changes, _password, _opts),
    do: rsync(upload.target, folder, Enum.map(files, &elem(&1, 0)) ++ changes.removed)

  def upload(%Upload{method: :sftp} = upload, folder, files, changes, password, opts),
    do: sftp(upload, folder, files, changes, password, opts)

  @doc """
  The arguments for rsync: only Agendum's own paths are sent, and of
  those, the ones no longer in the folder are deleted on the server
  (`--delete` touches only what the filters include; everything else is
  excluded, so left alone). `-c` compares contents, not only size and
  time: a page rewritten within the same second with the same length is
  still sent.
  """
  @spec rsync_args(String.t(), String.t(), [String.t()]) :: [String.t()]
  def rsync_args(target, folder, paths) do
    includes = Enum.map(Enum.uniq(["posts/", "fonts/" | paths]), &"--include=/#{&1}")
    # the folder ends in "/": its contents are sent, not the folder itself
    source = String.trim_trailing(folder, "/") <> "/"
    # ssh never asks (a password or a new host key would wait on the screen)
    # and gives up on a dead connection (code review 2026-10-26)
    ssh =
      "ssh -o BatchMode=yes -o ConnectTimeout=20 -o ServerAliveInterval=15 -o ServerAliveCountMax=3"

    # "--" ends the options: a folder or target starting with "-" is then
    # only a path, never an option (`-e` would run a command)
    ["-rtzc", "--delete", "-e", ssh] ++ includes ++ ["--exclude=*", "--", source, target]
  end

  defp rsync("", _folder, _paths), do: {:error, "say where to upload to (Upload to)"}

  defp rsync(target, folder, paths) do
    if Upload.rsync_target_safe?(target),
      do: run_rsync(target, folder, paths),
      else: {:error, "Upload to must not start with - (nor its host or user)"}
  end

  defp run_rsync(target, folder, paths) do
    case System.find_executable("rsync") do
      nil ->
        {:error, "rsync is not installed"}

      rsync ->
        case System.cmd(rsync, rsync_args(target, folder, paths), stderr_to_stdout: true) do
          {_out, 0} -> :ok
          {out, status} -> {:error, "rsync failed (#{status}): #{last_line(out)}"}
        end
    end
  rescue
    error -> {:error, "rsync could not run (#{Exception.message(error)})"}
  end

  defp last_line(out), do: out |> String.split("\n", trim: true) |> List.last("") |> String.trim()

  # SFTP (OTP's ssh): the files added and changed are sent, the
  # stylesheet as the folder has it, and the removed ones deleted. The
  # server's key must be in ~/.ssh/known_hosts, as for ssh itself.
  defp sftp(%Upload{target: ""}, _folder, _files, _changes, _password, _opts),
    do: {:error, "say which server to upload to (Upload to)"}

  defp sftp(upload, folder, files, changes, password, opts) do
    {:ok, _} = Application.ensure_all_started(:ssh)
    {host, port} = host_port(upload.target)
    password = password || netrc_password(host, upload.user)

    base = [
      user: String.to_charlist(upload.user),
      user_interaction: false,
      silently_accept_hosts: false,
      quiet_mode: true,
      connect_timeout: 20_000,
      # the channel's setup, too, never waits for ever
      timeout: 30_000
    ]

    # the keys first; a password only when there is one (never typed at
    # the terminal: Agendum asks for it in its own prompt)
    with_password =
      if password,
        do: [password: String.to_charlist(password), auth_methods: ~c"publickey,password"],
        else: [auth_methods: ~c"publickey"]

    # the tests' options replace the person's (`Keyword.merge/2`)
    ssh_opts = base |> Keyword.merge(with_password) |> Keyword.merge(opts)

    quietly(fn -> connect(host, port, ssh_opts, upload, folder, files, changes, password) end)
  rescue
    error -> {:error, "SFTP failed (#{Exception.message(error)})"}
  end

  # ssh reports each connection and refusal through `error_logger`, which
  # the screen would show over the program: logging is off while it runs,
  # and back as it was after (`try … after` restores it, also on a crash)
  defp quietly(fun) do
    %{level: level} = :logger.get_primary_config()
    :logger.update_primary_config(%{level: :none})

    try do
      fun.()
    after
      :logger.update_primary_config(%{level: level})
    end
  end

  defp connect(host, port, ssh_opts, upload, folder, files, changes, password) do
    case :ssh_sftp.start_channel(String.to_charlist(host), port, ssh_opts) do
      {:ok, channel, connection} ->
        try do
          send_all(channel, upload.remote_dir, folder, files, changes)
        after
          :ssh.close(connection)
        end

      {:error, reason} ->
        sftp_error(reason, password)
    end
  end

  defp send_all(channel, dir, folder, files, changes) do
    remote = fn path -> if dir == "", do: path, else: Path.join(dir, path) end
    _ = :ssh_sftp.make_dir(channel, String.to_charlist(remote.("posts")), @timeout)
    _ = :ssh_sftp.make_dir(channel, String.to_charlist(remote.("fonts")), @timeout)
    {sent, removed} = sftp_plan(folder, files, changes)

    # Domain: the removals wait in the folder until an upload has made
    # them; a failed one leaves them for the next (code review 2026-10-26)
    :ok = keep_unsent(folder, removed)

    result =
      with :ok <- each(sent, &sftp_put(channel, folder, &1, remote.(&1))) do
        each(removed, &sftp_delete(channel, remote.(&1)))
      end

    if result == :ok, do: keep_unsent(folder, [])
    result
  end

  @doc """
  What an SFTP upload sends and removes: every file of the site, as the
  folder has it, not only the changes since the folder was last written
  (an upload that failed, or a site first published with Upload None,
  would leave the server behind for good; code review 2026-10-26); and the
  files taken away now, with those a failed upload did not remove.
  """
  @spec sftp_plan(String.t(), [Site.file()], Site.changes()) :: {[String.t()], [String.t()]}
  def sftp_plan(folder, files, changes) do
    sent = Enum.uniq(Enum.map(files, &elem(&1, 0)) ++ [Site.stylesheet()])
    {sent, Enum.uniq(unsent(folder) ++ changes.removed)}
  end

  @doc "Keeps the removals an upload has still to make, in the folder (none: the file goes)."
  @spec keep_unsent(String.t(), [String.t()]) :: :ok
  def keep_unsent(folder, []) do
    _ = File.rm(Path.join(folder, @unsent))
    :ok
  end

  def keep_unsent(folder, paths) do
    _ = File.write(Path.join(folder, @unsent), Enum.join(paths, "\n") <> "\n")
    :ok
  end

  defp unsent(folder) do
    case File.read(Path.join(folder, @unsent)) do
      {:ok, text} -> String.split(text, "\n", trim: true)
      {:error, _} -> []
    end
  end

  defp sftp_put(channel, folder, path, remote) do
    case File.read(Path.join(folder, path)) do
      {:ok, content} ->
        case :ssh_sftp.write_file(channel, String.to_charlist(remote), content, @timeout) do
          :ok -> :ok
          {:error, reason} -> {:error, "SFTP could not write #{remote} (#{inspect(reason)})"}
        end

      {:error, _} ->
        :ok
    end
  end

  defp sftp_delete(channel, remote) do
    case :ssh_sftp.delete(channel, String.to_charlist(remote), @timeout) do
      result when result in [:ok, {:error, :no_such_file}] -> :ok
      {:error, reason} -> {:error, "SFTP could not remove #{remote} (#{inspect(reason)})"}
    end
  end

  # the keys refused and no password tried yet: ask for one
  defp sftp_error(reason, nil) do
    text = to_string(reason)

    if String.contains?(text, "authentication"),
      do: {:error, :password},
      else: {:error, "SFTP: #{sftp_reason(text)}"}
  end

  defp sftp_error(reason, _password), do: {:error, "SFTP: #{sftp_reason(to_string(reason))}"}

  defp sftp_reason(text) do
    cond do
      String.contains?(text, "authentication") ->
        "the user name or password was refused"

      String.contains?(text, "econnrefused") ->
        "the server refused the connection"

      String.contains?(text, "nxdomain") ->
        "no such server"

      String.contains?(text, "known_hosts") or String.contains?(text, "host key") ->
        "the server's key is not known: connect once with ssh to accept it"

      true ->
        text
    end
  end

  @doc "A target's host and port: `host` (port 22) or `host:port`."
  @spec host_port(String.t()) :: {String.t(), pos_integer}
  def host_port(target) do
    case String.split(target, ":") do
      [host, port] ->
        case Integer.parse(port) do
          {n, ""} -> {host, n}
          _ -> {target, 22}
        end

      _ ->
        {target, 22}
    end
  end

  # --- passwords ---------------------------------------------------------------------

  @doc """
  The password `~/.netrc` gives for `user` on `host`, or nil: the file's
  `machine host login user password secret` entries (and `default`).
  """
  @spec netrc_password(String.t(), String.t()) :: String.t() | nil
  def netrc_password(host, user) do
    case File.read(Path.join(System.user_home!(), ".netrc")) do
      {:ok, text} -> netrc_lookup(text, host, user)
      {:error, _} -> nil
    end
  end

  @doc "The password in a `.netrc` text for `user` on `host`, or nil."
  @spec netrc_lookup(String.t(), String.t(), String.t()) :: String.t() | nil
  def netrc_lookup(text, host, user) do
    entries =
      text
      |> String.split()
      |> Enum.chunk_while(
        nil,
        fn
          word, acc when word in ["machine", "default"] ->
            if acc, do: {:cont, acc, %{kind: word}}, else: {:cont, %{kind: word}}

          word, nil ->
            {:cont, %{kind: word}}

          word, %{pending: key} = acc ->
            {:cont, acc |> Map.delete(:pending) |> Map.put(key, word)}

          word, acc when word in ["login", "password", "account"] ->
            {:cont, Map.put(acc, :pending, word)}

          word, %{kind: "machine"} = acc when not is_map_key(acc, "host") ->
            {:cont, Map.put(acc, "host", word)}

          _word, acc ->
            {:cont, acc}
        end,
        fn
          nil -> {:cont, nil}
          acc -> {:cont, acc, nil}
        end
      )

    entry =
      Enum.find(entries, &(&1[:kind] == "machine" and &1["host"] == host and login?(&1, user))) ||
        Enum.find(entries, &(&1[:kind] == "default" and login?(&1, user)))

    entry && entry["password"]
  end

  defp login?(entry, user), do: entry["login"] in [nil, user]
end
