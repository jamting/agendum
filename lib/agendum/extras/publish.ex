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

  @typedoc """
  What a folder holds of the site: contents by path, the last publish's
  paths, and the templates Agendum would write as they are missing.
  """
  @type scan :: %{
          existing: %{optional(String.t()) => String.t()},
          published: [String.t()],
          templates_missing: [String.t()]
        }

  # a template, and all the assets together, may be at most this big
  @template_limit 1_000_000
  @assets_limit 50_000_000

  @doc """
  What the site is made from in `folder` (R74): its templates
  (`templates/*.html` by name, `*.xml` by whole name) and its assets (every file under
  `assets/`, by path, hidden files and links left out). A folder without
  them has none; assets over #{div(@assets_limit, 1_000_000)} MB together are refused.
  """
  @spec inputs(String.t()) :: {:ok, Site.inputs()} | {:error, String.t()}
  def inputs(folder) do
    with {:ok, templates} <- templates(folder, own_style?(folder)),
         {:ok, assets} <- assets(folder) do
      {:ok, %{templates: templates, assets: assets}}
    end
  end

  # each `templates/*.html` (by its name, `post`) and `*.xml` (by its whole
  # name, `rss.xml`), and those of a list's own folder, one level down
  # (`templates/gym/index.html` is `gym/index`; R74e); one that is a link,
  # too big or unreadable stops publishing, saying so, rather than
  # Agendum's being used unseen
  defp templates(folder, own_style?) do
    dir = Path.join(folder, "templates")

    lists =
      for name <- list(dir),
          not String.starts_with?(name, "."),
          match?({:ok, %{type: :directory}}, File.lstat(Path.join(dir, name))),
          file <- list(Path.join(dir, name)),
          do: name <> "/" <> file

    (list(dir) ++ lists)
    |> Enum.filter(&(Path.extname(&1) in [".html", ".xml"]))
    |> Enum.sort()
    |> Enum.reduce_while({:ok, %{}}, fn name, {:ok, acc} ->
      case template(Path.join(dir, name)) do
        # still word for word an older Agendum's: Agendum's own is used
        {:ok, text} ->
          if not own_style? and Site.legacy_template?("templates/" <> name, text),
            do: {:cont, {:ok, acc}},
            else: {:cont, {:ok, Map.put(acc, template_name(name), text)}}

        # a folder named like a template is not one: passed over
        {:error, "is not a file"} ->
          {:cont, {:ok, acc}}

        {:error, why} ->
          {:halt, {:error, "templates/#{name} #{why}"}}
      end
    end)
  end

  defp template_name(file),
    do: if(Path.extname(file) == ".html", do: Path.rootname(file), else: file)

  defp template(path) do
    case File.lstat(path) do
      {:ok, %{type: :regular, size: size}} when size <= @template_limit ->
        case File.read(path) do
          {:ok, text} -> {:ok, text}
          {:error, reason} -> {:error, "cannot be read (#{:file.format_error(reason)})"}
        end

      {:ok, %{type: :regular}} ->
        {:error, "is larger than #{div(@template_limit, 1_000_000)} MB"}

      {:ok, %{type: :symlink}} ->
        {:error, "is a link; put the template itself there"}

      {:ok, _other} ->
        {:error, "is not a file"}

      {:error, reason} ->
        {:error, "cannot be read (#{:file.format_error(reason)})"}
    end
  end

  defp assets(folder) do
    paths = files_under(folder, "assets")
    total = paths |> Enum.map(&size(Path.join(folder, &1))) |> Enum.sum()

    if total > @assets_limit do
      {:error, "assets/ holds more than #{div(@assets_limit, 1_000_000)} MB"}
    else
      {:ok,
       for(path <- paths, {:ok, bin} <- [File.read(Path.join(folder, path))], do: {path, bin})}
    end
  end

  # the regular files under `rel` (a path inside `folder`), not hidden, no
  # links followed, sorted so two reads give the same site
  defp files_under(folder, rel) do
    rel
    |> then(&list(Path.join(folder, &1)))
    |> Enum.reject(&String.starts_with?(&1, "."))
    |> Enum.sort()
    |> Enum.flat_map(fn name ->
      path = Path.join(rel, name)

      case File.lstat(Path.join(folder, path)) do
        {:ok, %{type: :directory}} -> files_under(folder, path)
        {:ok, %{type: :regular}} -> [path]
        _ -> []
      end
    end)
  end

  defp list(dir) do
    case File.ls(dir) do
      {:ok, names} -> names
      {:error, _} -> []
    end
  end

  defp size(path) do
    case File.stat(path) do
      {:ok, %{size: size}} -> size
      {:error, _} -> 0
    end
  end

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
    contents = Map.new(files)

    # an asset was just read from this very file (`inputs/1`): it is
    # there as it is, without reading it again
    existing =
      for path <- paths,
          {:ok, content} <- [existing(folder, path, contents)],
          into: %{},
          do: {path, content}

    own = own_style?(folder)
    missing = for {path, _} <- Site.default_templates(), replaced?(folder, path, own), do: path

    {:ok, %{existing: existing, published: published, templates_missing: missing}}
  end

  # a template Agendum writes: missing, or still word for word an older
  # Agendum's own (read only where there was one, as `templates/2` reads:
  # not through a link, nor a big file), unless the folder's stylesheet is
  # the person's own, which the old one was made for
  defp replaced?(folder, path, own_style?) do
    full = Path.join(folder, path)

    case File.lstat(full) do
      {:error, :enoent} -> true
      {:ok, _} -> not own_style? and Site.had_legacy?(path) and legacy_copy?(path, full)
      {:error, _} -> false
    end
  end

  # Domain: whether the folder's `style.css` is the person's own (not one
  # Agendum wrote); read as a template is, so a link or a huge file is not
  # read, and counts as theirs
  defp own_style?(folder) do
    path = Path.join(folder, Site.stylesheet())

    case File.lstat(path) do
      {:error, :enoent} ->
        false

      _ ->
        case template(path) do
          {:ok, text} -> Site.own_stylesheet?(text)
          {:error, _} -> true
        end
    end
  end

  defp legacy_copy?(path, full) do
    case template(full) do
      {:ok, text} -> Site.legacy_template?(path, text)
      {:error, _} -> false
    end
  end

  defp existing(folder, "assets/" <> _ = path, contents) when is_map_key(contents, path) do
    if File.exists?(Path.join(folder, path)), do: {:ok, contents[path]}, else: :error
  end

  defp existing(folder, path, _contents), do: File.read(Path.join(folder, path))

  @doc """
  Writes Agendum's templates into `folder`'s `templates/` where one is
  missing (R74): one that is there is the person's and stays. They make
  the pages and are never uploaded.
  """
  @spec write_templates(String.t(), [Site.file()]) :: :ok | {:error, String.t()}
  def write_templates(folder, templates) do
    own = own_style?(folder)
    missing = Enum.filter(templates, &replaced?(folder, elem(&1, 0), own))

    with :ok <- each(folders(Enum.map(missing, &elem(&1, 0))), &mkdir(Path.join(folder, &1))) do
      each(missing, fn {path, text} -> put(folder, path, text) end)
    end
  end

  @doc """
  Writes the site into `folder`: the files added and changed (the
  stylesheet only when there is none or it is still Agendum's old one), and removes those taken away.
  """
  @spec write(String.t(), [Site.file()], Site.changes()) :: :ok | {:error, String.t()}
  def write(folder, files, changes) do
    contents = Map.new(files)

    # the folders a page's address names (R74: `2026/11/…`) are made first
    with :ok <- each(folders(Map.keys(contents)), &mkdir(Path.join(folder, &1))),
         :ok <- each(changes.added ++ changes.changed, &put(folder, &1, contents[&1])),
         :ok <- each(changes.removed, &remove(folder, &1)) do
      manifest = Enum.map_join(files, "\n", &elem(&1, 0))
      put(folder, @manifest, manifest <> "\n")
    end
  end

  @doc """
  The folders `paths` lie in, each with the folders above it, parents
  first: `["2026/11/a.html"]` gives `["2026", "2026/11"]`.
  """
  @spec folders([String.t()]) :: [String.t()]
  def folders(paths) do
    paths
    |> Enum.flat_map(fn path ->
      parts = path |> Path.dirname() |> Path.split() |> Enum.reject(&(&1 == "."))
      for n <- 1..length(parts)//1, do: Path.join(Enum.take(parts, n))
    end)
    |> Enum.uniq()
    |> Enum.sort_by(&{length(Path.split(&1)), &1})
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

  @doc """
  Where the site of the file at `path` is written: a relative folder is
  beside the file (or, for a file not saved yet, where Agendum was
  started), `~` the home folder.
  """
  @spec folder(String.t() | nil, String.t()) :: String.t()
  def folder(path, folder) do
    if path != nil and Path.type(folder) == :relative and not String.starts_with?(folder, "~"),
      do: Path.join(Path.dirname(path), folder),
      else: folder
  end

  @doc """
  Writes the site into `dir` (Agendum's templates where one is missing:
  the person's then), without uploading it.
  """
  @spec write_site(String.t(), [Site.file()], Site.changes()) :: :ok | {:error, String.t()}
  def write_site(dir, files, changes) do
    with :ok <- write(dir, files, changes),
         do: write_templates(dir, Agendum.Core.site_default_templates())
  end

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
    # rsync looks into a folder only when it is included itself: every
    # folder a page lies in, then the pages
    dirs = Enum.map(folders(paths), &(&1 <> "/"))
    includes = Enum.map(Enum.uniq(dirs ++ paths), &"--include=/#{&1}")
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
    {sent, removed} = sftp_plan(folder, files, changes)

    # every folder a page lies in, parents first; one already there is fine
    for dir <- folders(sent),
        do: _ = :ssh_sftp.make_dir(channel, String.to_charlist(remote.(dir)), @timeout)

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
