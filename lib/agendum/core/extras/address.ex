# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Extras.Address do
  @moduledoc """
  Where a post's page is on the site (R74): the Site's address pattern,
  such as `posts/{zettel}.html` (the default) or
  `{year}/{month}/{day}-{slug}.html`, filled in once, when a post is first
  published, and kept (`Agendum.Core.Extras.PostRecord`), so an address
  that is out there never changes (meeting 2026-11-02-1255, § 6). Pure.

  The placeholders: `{zettel}` the post's Zettel id, `{slug}` its title
  in lowercase a–z, 0–9 and `-` (`slug/1`), `{year}`, `{month}`, `{day}`
  its date. A pattern must end in `.html`, name `{zettel}` or `{slug}` (so
  each post can have its own address), and stay inside the site's folder.
  """

  @default "posts/{zettel}.html"
  @placeholders ~w(zettel slug year month day)

  @doc "The address pattern a new blog has."
  @spec default() :: String.t()
  def default, do: @default

  @doc """
  Whether `pattern` can give each post an address of its own, inside the
  site: it names `{zettel}` or `{slug}`, and filled in it is a `safe?/1`
  path.
  """
  @spec valid?(term) :: boolean
  def valid?(pattern) when is_binary(pattern) do
    names = Regex.scan(~r/\{([^}]*)\}/, pattern, capture: :all_but_first) |> List.flatten()

    Enum.all?(names, &(&1 in @placeholders)) and
      Enum.any?(names, &(&1 in ["zettel", "slug"])) and
      safe?(String.replace(pattern, ~r/\{[a-z]+\}/, "x"))
  end

  def valid?(_pattern), do: false

  @doc """
  Whether `path` is a page's address Agendum may write: relative, inside
  the site's folder (no `..`, `.` or empty part), ending in `.html`, and
  only a–z, A–Z, 0–9, `.`, `_`, `~`, `-` and `/`, so it needs no escaping
  in a web address. A file's stored addresses are checked with it too
  (SECURITY.md, door 2: a crafted file must not write outside the folder).
  """
  @spec safe?(term) :: boolean
  def safe?(path) when is_binary(path) do
    parts = String.split(path, "/")

    String.ends_with?(path, ".html") and Regex.match?(~r{^[A-Za-z0-9._~/-]+$}, path) and
      Enum.all?(parts, &(&1 not in ["", ".", ".."]))
  end

  def safe?(_path), do: false

  @doc """
  A post's address from `pattern`, its `title`, Zettel id `zettel` and
  `date`. `taken` holds the addresses already made, and the last
  argument the site's own files and folders (`Agendum.Core.Extras.Site.own/0`): an
  address that is taken gets `-2`, `-3` … before `.html`, and one inside
  a reserved folder (`fonts/…`) has that folder renamed (`fonts-2/…`).
  """
  @spec path(
          String.t(),
          String.t(),
          String.t(),
          Date.t(),
          MapSet.t(String.t()),
          {[String.t()], [String.t()]}
        ) :: String.t()
  def path(pattern, title, zettel, date, taken, {files, folders}) do
    slug = if slug(title) == "", do: zettel, else: slug(title)
    pad = &String.pad_leading(Integer.to_string(&1), 2, "0")

    filled =
      pattern
      |> String.replace("{zettel}", zettel)
      |> String.replace("{slug}", slug)
      |> String.replace("{year}", Integer.to_string(date.year))
      |> String.replace("{month}", pad.(date.month))
      |> String.replace("{day}", pad.(date.day))

    filled |> out_of(folders) |> free(MapSet.union(taken, MapSet.new(files)), 1)
  end

  # a first folder the site uses itself is renamed: `fonts/a.html` is
  # `fonts-2/a.html` (no `-N` at the end could leave that folder)
  defp out_of(path, folders) do
    case String.split(path, "/", parts: 2) do
      [first, rest] -> if first in folders, do: "#{first}-2/#{rest}", else: path
      [_file] -> path
    end
  end

  # the first of `a.html`, `a-2.html`, `a-3.html` … that is free; it ends,
  # as each try is a new address and `taken` is finite
  defp free(path, taken, n) do
    candidate = if n == 1, do: path, else: String.replace_suffix(path, ".html", "-#{n}.html")
    if MapSet.member?(taken, candidate), do: free(path, taken, n + 1), else: candidate
  end

  @doc """
  A title as an address: accents and Swedish letters folded (`ö` → `o`),
  lowercase, anything but a–z and 0–9 a `-`, at most 60 characters; empty
  when nothing is left.
  """
  @spec slug(String.t()) :: String.t()
  def slug(title) do
    # Domain: NFD splits "ö" into "o" and a combining diaeresis (a mark,
    # \p{Mn}), which is then dropped
    title
    |> :unicode.characters_to_nfd_binary()
    |> String.replace(~r/\p{Mn}/u, "")
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
    |> String.slice(0, 60)
    |> String.trim_trailing("-")
  end
end
