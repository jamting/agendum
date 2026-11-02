# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Extras.Upload do
  @moduledoc """
  Where the micro-blog's site is written and how it is uploaded (R74):
  Extras ▸ Publish ▸ Upload. Kept in the person's preferences, by the
  file's path, not in the file (meeting 2026-11-02-1255, § 10): the folder
  and the server belong to this computer, and a file shared or opened
  elsewhere should not carry them. A password is never kept: Agendum reads
  it from `~/.netrc` or asks for it.

    * `folder`: where the site is written, a mounted one (sshfs) too; a
      relative folder is beside the file
    * `method`: `:none`, `:rsync` (over ssh, to `target`, such as
      `me@host:www/blog`) or `:sftp` (to the host `target`, `host` or
      `host:port`, as `user`, into `remote_dir`). Not FTP: OTP deprecates
      its `ftp` application and removes it in OTP 30 (ADR 0041).

  Files saved before format 47 kept these in `Agendum.Core.Extras.Blog`;
  loading one lifts them out (`from_old_blog/1`) for the preferences.
  """

  @type method :: :none | :rsync | :sftp
  @type t :: %__MODULE__{
          folder: String.t(),
          method: method,
          target: String.t(),
          user: String.t(),
          remote_dir: String.t()
        }
  defstruct folder: "site", method: :none, target: "", user: "", remote_dir: ""

  @doc "The ways of uploading, in the order the Upload box offers them."
  @spec methods() :: [method]
  def methods, do: [:none, :rsync, :sftp]

  @doc """
  Whether an rsync target (`me@host:www/blog`, or a folder) is safe to hand
  to rsync: neither it nor its user or host starts with `-`. rsync passes
  the host on to ssh, where `-oProxyCommand=…` would run a command
  (docs/SECURITY.md, door 4).
  """
  @spec rsync_target_safe?(String.t()) :: boolean
  def rsync_target_safe?(target) do
    # `user@host:path`: what comes before the first ":" is the user and the
    # host (a local folder has no ":", and is checked whole)
    [remote | _] = String.split(target, ":", parts: 2)
    not Enum.any?([target | String.split(remote, "@")], &String.starts_with?(&1, "-"))
  end

  @doc """
  The upload settings an older file's blog held (format 46 and before), or
  nil when it held none worth keeping (the folder empty or `site`, no
  upload). `blog` is the old struct as a plain map; a value of the wrong
  kind counts as none.
  """
  @spec from_old_blog(map) :: t | nil
  def from_old_blog(blog) do
    upload = %__MODULE__{
      folder: text(blog[:folder], "site"),
      method: if(blog[:upload] in methods(), do: blog[:upload], else: :none),
      target: text(blog[:target], ""),
      user: text(blog[:user], ""),
      remote_dir: text(blog[:remote_dir], "")
    }

    if upload == %__MODULE__{}, do: nil, else: upload
  end

  # `""` was the old default for the folder, meaning `site`
  defp text(value, _default) when is_binary(value) and value != "", do: value
  defp text(_value, default), do: default
end
