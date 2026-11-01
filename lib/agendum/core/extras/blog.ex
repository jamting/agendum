# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Extras.Blog do
  @moduledoc """
  The file's micro-blog (R74): which items are its posts and how the site
  is published. Kept in the file (`Database.blog`), so the blog goes with
  its posts. A password is never kept: Agendum reads it from `~/.netrc`
  or asks for it.

    * `posts`: the category whose items are the posts; `drafts`: the
      category that keeps a post out until it is ready (nil: none)
    * `title`, `description`, `author`, `language` (`"en"`, `"sv"` …):
      what the pages and feeds say about the blog
    * `base_url`: where the site is on the web (`https://example.com/`),
      for the feeds' links, which must be whole addresses
    * `me`: addresses of the person's other profiles, for `rel="me"`
      links (a fediverse account, micro.blog), separated by spaces
    * `folder`: where the site is written, a mounted one (sshfs) too; a
      relative folder is beside the file
    * `upload`: `:none`, `:rsync` (over ssh, to `target`, such as
      `me@host:www/blog`) or `:sftp` (to the host `target`, `host` or
      `host:port`, as `user`, into `remote_dir`). Not FTP: OTP deprecates
      its `ftp` application and removes it in OTP 30.
  """

  alias Agendum.Core.Database

  @type upload :: :none | :rsync | :sftp

  @type t :: %__MODULE__{
          posts: Database.id() | nil,
          drafts: Database.id() | nil,
          title: String.t(),
          description: String.t(),
          author: String.t(),
          language: String.t(),
          base_url: String.t(),
          me: String.t(),
          folder: String.t(),
          upload: upload,
          target: String.t(),
          user: String.t(),
          remote_dir: String.t()
        }

  defstruct posts: nil,
            drafts: nil,
            title: "",
            description: "",
            author: "",
            language: "en",
            base_url: "",
            me: "",
            folder: "",
            upload: :none,
            target: "",
            user: "",
            remote_dir: ""

  @doc """
  Whether an rsync target (`me@host:www/blog`, or a folder) is safe to hand
  to rsync: neither it nor its user or host starts with `-`. rsync passes
  the host on to ssh, where `-oProxyCommand=…` would run a command, and a
  shared file carries its blog settings (docs/SECURITY.md, door 4).
  """
  @spec rsync_target_safe?(String.t()) :: boolean
  def rsync_target_safe?(target) do
    # `user@host:path`: what comes before the first ":" is the user and the
    # host (a local folder has no ":", and is checked whole)
    [remote | _] = String.split(target, ":", parts: 2)
    not Enum.any?([target | String.split(remote, "@")], &String.starts_with?(&1, "-"))
  end

  @doc "The ways of uploading, in the order the Publish box offers them."
  @spec uploads() :: [upload]
  def uploads, do: [:none, :rsync, :sftp]

  @doc """
  The posts, newest first: the items in the posts category (or under it),
  not in the drafts category. A post's date is its When date, else its
  Entry date; posts of one day come newest made first.
  """
  @spec posts(Database.t()) :: [Agendum.Core.Item.t()]
  def posts(%Database{blog: %__MODULE__{posts: nil}}), do: []

  def posts(%Database{blog: blog} = db) do
    db
    |> Database.items()
    |> Enum.filter(&Database.member?(db, &1.id, blog.posts))
    |> Enum.reject(&(blog.drafts && Database.member?(db, &1.id, blog.drafts)))
    # Domain: a `Date` is a struct (a map), and maps compare by their
    # keys, not as dates; `Date.to_erl/1` gives `{year, month, day}`, which
    # compares as dates do. With the id after it, posts of one day come
    # newest made first; `&>=/2` sorts descending.
    |> Enum.sort_by(&{sortable(date(&1)), &1.id}, &>=/2)
  end

  @doc "A post's date: When, else Entry (nil only for an item with neither)."
  @spec date(Agendum.Core.Item.t()) :: Date.t() | nil
  def date(item), do: item.when || item.entry

  defp sortable(nil), do: {0, 0, 0}
  defp sortable(date), do: Date.to_erl(date)
end
