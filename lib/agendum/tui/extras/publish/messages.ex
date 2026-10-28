defmodule Agendum.TUI.Extras.Publish.Messages do
  @moduledoc """
  What publishing the blog (R74) says: one text per error the core gives
  and per step, kept beside the extra (UI guidelines rule 7.5; see
  `Agendum.TUI.Extras.Feeds.Messages`). Pure.
  """

  @doc "A text without anything to fill in; for an error, its atom."
  @spec text(atom) :: String.t()
  def text(:no_posts_category), do: "Name the category whose items are the posts"

  def text(:ambiguous),
    do: "Two categories have that name: give the posts or drafts a name of their own"

  def text(:ingested),
    do: "The posts and drafts are your own categories, not a feed's or a calendar's"

  def text(:zettels_full), do: "Every Zettel id is in use; the posts cannot all have one"
  def text(:bad_categories), do: "The posts and drafts categories must differ, and be categories"
  def text(:nothing_published), do: "Nothing was published"
  def text(:publishing), do: "Publishing …"

  def text(:publishing_goes_on),
    do: "Publishing goes on; the message line says when it is done"

  def text(:up_to_date), do: "The folder already holds this site: nothing to publish"
  def text(:password_later), do: "Not published: the server asks for a password. Publish again"

  @doc "A text with one thing to fill in: a folder, or why it failed."
  @spec text(atom, String.t()) :: String.t()
  def text(:reading, folder), do: "Reading #{folder} …"
  def text(:cannot_read_folder, reason), do: "Could not read the site's folder: #{reason}"
  def text(:not_published, reason), do: "Not published: #{reason}"

  @doc """
  The site published, uploaded or not, with what changed ("2 added, 1
  changed, 0 removed"); the SFTP password's prompt, for a user at a host.
  """
  @spec text(atom, term, String.t()) :: String.t()
  def text(:published, uploaded?, summary),
    do: "Published#{if uploaded?, do: " and uploaded", else: ""}: #{summary}"

  def text(:password, user, host), do: "Password of #{user}@#{host} (not kept):"
end
