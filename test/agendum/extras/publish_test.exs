# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Extras.PublishTest do
  @moduledoc """
  The micro-blog's shell (R74): reading and writing the site's folder,
  and uploading it by rsync (to a local folder) and by SFTP (to an SFTP
  server run here, by OTP's own ssh).
  """
  # not async: SFTP turns logging off while it runs (`Agendum.Extras.Publish`),
  # which would hide the logs other tests capture
  use ExUnit.Case, async: false

  alias Agendum.Core.Extras.{Blog, Site}
  alias Agendum.Extras.Publish

  @moduletag :tmp_dir

  @files [
    {"index.html", "<p>new</p>"},
    {"style.css", "ours"},
    {"posts/bonalaku.html", "Party"}
  ]

  defp publish(folder, files) do
    {:ok, scan} = Publish.scan(folder, files)
    changes = Site.changes(files, scan.existing, scan.published)
    :ok = Publish.write(folder, files, changes)
    changes
  end

  test "a first publish writes every file and remembers them", %{tmp_dir: dir} do
    changes = publish(dir, @files)
    assert changes.added == ~w(index.html style.css posts/bonalaku.html)
    assert File.read!(Path.join(dir, "posts/bonalaku.html")) == "Party"
    assert File.read!(Path.join(dir, ".agendum-site")) =~ "posts/bonalaku.html"
  end

  test "again: only what changed; a post taken away is removed; the rest is left", %{tmp_dir: dir} do
    publish(dir, @files)
    File.write!(Path.join(dir, "style.css"), "theirs")
    File.write!(Path.join(dir, "notes.txt"), "the person's own")

    files = [{"index.html", "<p>newer</p>"}, {"style.css", "ours"}]
    changes = publish(dir, files)

    assert changes == %{added: [], changed: ["index.html"], removed: ["posts/bonalaku.html"]}
    refute File.exists?(Path.join(dir, "posts/bonalaku.html"))
    assert File.read!(Path.join(dir, "style.css")) == "theirs"
    assert File.read!(Path.join(dir, "notes.txt")) == "the person's own"
  end

  test "rsync sends Agendum's files and removes the ones taken away, nothing else",
       %{tmp_dir: dir} do
    if System.find_executable("rsync") do
      site = Path.join(dir, "site")
      server = Path.join(dir, "server")
      File.mkdir_p!(Path.join(server, "posts"))
      File.write!(Path.join(server, "other.txt"), "keep")
      File.write!(Path.join(server, "posts/old.html"), "gone")

      changes = publish(site, @files)
      changes = %{changes | removed: ["posts/old.html"]}
      blog = %Blog{upload: :rsync, target: server}
      assert :ok = Publish.upload(blog, site, @files, changes, nil)

      assert File.read!(Path.join(server, "posts/bonalaku.html")) == "Party"
      assert File.read!(Path.join(server, "other.txt")) == "keep"
      refute File.exists?(Path.join(server, "posts/old.html"))
      refute File.exists?(Path.join(server, ".agendum-site"))
    end
  end

  test "rsync's arguments include only Agendum's paths" do
    ssh =
      "ssh -o BatchMode=yes -o ConnectTimeout=20 -o ServerAliveInterval=15 -o ServerAliveCountMax=3"

    assert Publish.rsync_args("me@host:www", "site", ["index.html"]) ==
             ["-rtzc", "--delete", "-e", ssh] ++
               ~w(--include=/posts/ --include=/fonts/ --include=/index.html --exclude=* -- site/ me@host:www)
  end

  # Found writing the threat model (docs/SECURITY.md, door 4; 2026-11-01): a
  # shared file carries its blog settings, and rsync read a target or a
  # folder starting with "-" as an option (`-e` runs a command); rsync also
  # hands the host to ssh, where `-oProxyCommand=` runs one
  test "rsync takes no target or folder as an option, nor a host or user starting with -",
       %{tmp_dir: dir} do
    marker = Path.join(dir, "ran")

    # after "--" the folder and the target are only paths
    assert ["--", "-esh/", "-x"] = Enum.take(Publish.rsync_args("-x", "-esh", []), -3)

    for target <- [
          "-e touch #{marker}",
          "-oProxyCommand=touch #{marker}:www",
          "me@-oProxyCommand=touch #{marker}:www",
          "-oProxyCommand=touch #{marker}@host:www"
        ] do
      blog = %Blog{upload: :rsync, target: target}
      changes = %{added: [], changed: [], removed: []}
      assert {:error, message} = Publish.upload(blog, dir, [], changes, nil)
      assert message =~ "must not start with -"
    end

    refute File.exists?(marker)
    # an ordinary target is no problem
    assert Agendum.Core.Extras.Blog.rsync_target_safe?("me@host:www/blog-2026")
    assert Agendum.Core.Extras.Blog.rsync_target_safe?("/Users/owl/site")
  end

  describe "SFTP" do
    # An SFTP server on a free port, with a host key made for the test and
    # one user, owl, whose password is "honey"
    setup %{tmp_dir: dir} do
      keys = Path.join(dir, "keys")
      root = Path.join(dir, "root")
      File.mkdir_p!(keys)
      File.mkdir_p!(Path.join(root, "www"))

      {_, 0} =
        System.cmd(
          "ssh-keygen",
          ~w(-q -t ed25519 -N) ++ ["", "-f", Path.join(keys, "ssh_host_ed25519_key")]
        )

      {:ok, _} = Application.ensure_all_started(:ssh)
      # the server's log of each connection would fill the test output
      :logger.set_application_level(:ssh, :none)

      {:ok, daemon} =
        :ssh.daemon(0,
          system_dir: String.to_charlist(keys),
          user_passwords: [{~c"owl", ~c"honey"}],
          # a refused login is what one test is about: not printed
          failfun: fn _user, _peer, _reason -> :ok end,
          subsystems: [:ssh_sftpd.subsystem_spec(root: String.to_charlist(root))]
        )

      {:ok, info} = :ssh.daemon_info(daemon)
      on_exit(fn -> :ssh.stop_daemon(daemon) end)

      blog = %Blog{
        upload: :sftp,
        target: "localhost:#{info[:port]}",
        user: "owl",
        remote_dir: "/www"
      }

      # the test's server key is new: accept it, and keep the person's ~/.ssh out
      opts = [
        silently_accept_hosts: true,
        user_dir: String.to_charlist(keys),
        save_accepted_host: false
      ]

      %{blog: blog, root: root, opts: opts}
    end

    test "sends the site and removes what was taken away", ctx do
      site = Path.join(ctx.tmp_dir, "site")
      changes = publish(site, @files)
      File.write!(Path.join(ctx.root, "www/old.html"), "gone")

      assert :ok =
               Publish.upload(
                 ctx.blog,
                 site,
                 @files,
                 %{changes | removed: ["old.html"]},
                 "honey",
                 ctx.opts
               )

      assert File.read!(Path.join(ctx.root, "www/posts/bonalaku.html")) == "Party"
      assert File.read!(Path.join(ctx.root, "www/style.css")) == "ours"
      refute File.exists?(Path.join(ctx.root, "www/old.html"))
    end

    test "without a password the server's refusal asks for one", ctx do
      site = Path.join(ctx.tmp_dir, "site")
      changes = publish(site, @files)
      assert {:error, :password} = Publish.upload(ctx.blog, site, @files, changes, nil, ctx.opts)

      assert {:error, "SFTP: the user name or password was refused"} =
               Publish.upload(ctx.blog, site, @files, changes, "vinegar", ctx.opts)
    end
  end

  test "host and port of a target" do
    assert Publish.host_port("owl.example") == {"owl.example", 22}
    assert Publish.host_port("owl.example:2222") == {"owl.example", 2222}
  end

  test "a .netrc gives the password of a machine and login, or the default" do
    netrc = """
    machine owl.example login owl password honey
    machine other.example
      login pooh
      password hunny
    default login owl password fallback
    """

    assert Publish.netrc_lookup(netrc, "owl.example", "owl") == "honey"
    assert Publish.netrc_lookup(netrc, "other.example", "pooh") == "hunny"
    assert Publish.netrc_lookup(netrc, "nowhere.example", "owl") == "fallback"
    assert Publish.netrc_lookup(netrc, "nowhere.example", "rabbit") == nil
  end
end
