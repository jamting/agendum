# SPDX-License-Identifier: AGPL-3.0-only
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
    do: "Two categories have that name: give the posts, drafts or pages a name of their own"

  def text(:ingested),
    do: "The posts, drafts and pages are your own categories, not a feed's or a calendar's"

  def text(:zettels_full), do: "Every Zettel id is in use; the posts cannot all have one"

  def text(:bad_categories),
    do: "The posts, drafts and pages categories must differ, and be categories"

  def text(:bad_address),
    do: "The address needs {zettel} or {slug}, must end in .html and stay in the site's folder"

  def text(:nothing_published), do: "Nothing was published"
  def text(:publishing), do: "Publishing …"

  def text(:publishing_goes_on),
    do: "Publishing goes on; the message line says when it is done"

  def text(:up_to_date), do: "The folder already holds this site: nothing to publish"
  def text(:password_later), do: "Not published: the server asks for a password. Publish again"
  def text(:site_kept), do: "Kept the site settings"
  def text(:feed_kept), do: "Kept the feed's settings"
  def text(:bad_slug), do: "A feed's folder: a-z, 0-9 and -, one no other feed or the site has"
  def text(:save_first), do: "Save the file first: its upload settings are kept by its name"

  def text(:upload_session_only),
    do: "The blog's upload settings last this session only: no preferences file"

  def text(:upload_moved),
    do: "The blog's folder and upload moved to your preferences (Extras ▸ Publish ▸ Upload)"

  @doc "A text with one thing to fill in: a folder, or why it failed."
  @spec text(atom, String.t()) :: String.t()
  def text(:reading, folder), do: "Reading #{folder} …"
  def text(:cannot_read_folder, reason), do: "Could not read the site's folder: #{reason}"
  def text(:not_published, reason), do: "Not published: #{reason}"
  def text(:upload_kept, file), do: "Kept the upload settings for #{file}"

  def text(:no_feeds, posts),
    do: "No feeds yet · a category under #{posts} is one (add it in the category manager, F9)"

  def text(:feed_made, slug),
    do: "Its folder, made from its name at the first publish: /#{slug}/"

  def text(:feed_where, slug),
    do: "Its page and feeds: /#{slug}/index.html, rss.xml, feed.json"

  def text(:templates_written, names),
    do: "Writes templates/ for you to change: #{names} (never uploaded)"

  def text(:upload_whose, file), do: "Yours, for #{file} on this computer; not kept in the file."

  @doc "Why the site could not be made (`Agendum.Core.site/3`), in words."
  @spec site_error(term) :: String.t()
  def site_error({:asset_name, path}),
    do: "#{path}: an asset's name may hold only a-z, A-Z, 0-9 and . _ ~ - /"

  def site_error({:template, name, line, why}) do
    where = if line, do: "templates/#{name}.html line #{line}", else: "templates/#{name}.html"
    "#{where}: #{template_mistake(why)}"
  end

  defp template_mistake(:tag_not_closed), do: "a tag is not closed"
  defp template_mistake({:not_closed, n}), do: "{{##{n}}} is not closed"
  defp template_mistake({:closes_nothing, n}), do: "{{/#{n}}} closes nothing"
  defp template_mistake({:closes, n, other}), do: "{{/#{n}}} closes {{##{other}}}"
  defp template_mistake({:no_partial, n}), do: "{{> #{n}}}: there is no templates/#{n}.html"
  defp template_mistake({:includes_itself, n}), do: "{{> #{n}}} includes itself"

  defp template_mistake(:too_big),
    do: "the templates include each other too many times over"

  @doc """
  The site published, uploaded or not, with what changed ("2 added, 1
  changed, 0 removed"); the SFTP password's prompt, for a user at a host.
  """
  @spec text(atom, term, String.t()) :: String.t()
  def text(:published, uploaded?, summary),
    do: "Published#{if uploaded?, do: " and uploaded", else: ""}: #{summary}"

  def text(:password, user, host), do: "Password of #{user}@#{host} (not kept):"

  def text(:waiting, 1, day), do: "1 post waits for its day (#{day})"
  def text(:waiting, n, day), do: "#{n} posts wait for their day (the first #{day})"

  @doc "The site published without a Base address: the feeds' links are not whole."
  @spec text(atom, boolean, String.t(), :needs_base_url) :: String.t()
  def text(:published, uploaded?, summary, :needs_base_url),
    do: text(:published, uploaded?, summary) <> ". The feeds need a Base address"
end
