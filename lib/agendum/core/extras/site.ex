# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Extras.Site do
  @moduledoc """
  The micro-blog as a static site (R74): `build/1` makes every file from
  the file's posts (`Agendum.Core.Extras.Blog`), as `{path, content}` pairs, and
  `changes/2` compares them with what a folder holds. Pure: the shell
  writes and uploads them (`Agendum.Extras.Publish`).

  The site, plain HTML without JavaScript, readable without its
  stylesheet:

    * `index.html`: the posts, newest first, each in full
    * `posts/<zettel id>.html`: a page per post, its address its Zettel
      id, which never changes (R73)
    * `rss.xml` (RSS 2.0) and `feed.json` (JSON Feed 1.1)
    * `style.css`: The Proportional Web by Oskar Wickström (MIT), dark
      when the reader's system is; written when the folder has none, or
      still Agendum's old one, so the person's own stays
    * `fonts/`: its fonts, Alegreya, Alegreya SC and Courier Prime, with
      their licence (`OFL.txt`), so no reader's browser asks Google for them

  For the fediverse without a server, the pages carry microformats
  (`h-feed`, `h-entry`, `h-card`) and `rel="me"` links, which micro.blog
  or a bridge such as Bridgy Fed can follow.
  """

  alias Agendum.Core.{Database, DateFormat}
  alias Agendum.Core.Extras.{Blog, Markdown, ZettelLinks}
  alias Agendum.Core.Facade.Extras.Zettels

  @typedoc "A file of the site: its path in the site's folder, and its content."
  @type file :: {String.t(), String.t()}

  @stylesheet "style.css"

  # Domain: the stylesheet and the fonts are read when this module is
  # compiled, so the escript carries them (ADR 0021: no runtime files), as
  # the help topics are (ADR 0047); `@external_resource` recompiles it when
  # one of them changes. The core stays pure: `File.read!/1` runs in the
  # compiler, never when the program does.
  @assets Path.join(__DIR__, "site_assets")
  @fonts ~w(alegreya-latin-wght-normal.woff2 alegreya-latin-wght-italic.woff2
            alegreya-sc-latin-400-normal.woff2 alegreya-sc-latin-500-normal.woff2
            courier-prime-latin-400-normal.woff2 OFL.txt)
  for file <- ["style.css", "legacy-style.css" | @fonts],
      do: @external_resource(Path.join(@assets, file))

  @default_stylesheet File.read!(Path.join(@assets, "style.css"))
  # the stylesheet Agendum wrote before 0.69: replaced while still exactly it
  @legacy_stylesheet File.read!(Path.join(@assets, "legacy-style.css"))
  @font_files for file <- @fonts, do: {"fonts/" <> file, File.read!(Path.join(@assets, file))}

  @doc "The stylesheet's path: written only when the folder has none."
  @spec stylesheet() :: String.t()
  def stylesheet, do: @stylesheet

  @doc """
  Every file of the site. A post without a Zettel id is left out: Publish
  gives each post one first (R73).
  """
  @spec build(Database.t()) :: [file]
  def build(%Database{blog: blog} = db) do
    used = Zettels.zettels(db)
    posts = db |> Blog.posts() |> Enum.filter(& &1.zettel)
    published = MapSet.new(posts, & &1.id)
    site = %{db: db, blog: blog, used: used, published: published, posts: posts}

    [
      {"index.html", index(site)},
      {"rss.xml", rss(site)},
      {"feed.json", json_feed(site)},
      {@stylesheet, default_stylesheet()}
    ] ++ Enum.map(posts, &{post_path(&1), post_page(site, &1)}) ++ @font_files
  end

  @doc "Where a post's page is: `posts/bonalaku.html`."
  @spec post_path(Agendum.Core.Item.t()) :: String.t()
  def post_path(item), do: "posts/#{Zettels.zettel(item)}.html"

  @typedoc "What publishing would do to a folder: the paths in each list."
  @type changes :: %{added: [String.t()], changed: [String.t()], removed: [String.t()]}

  @doc """
  What writing `files` would change in a folder that holds `existing`
  (path to content, for the paths Agendum wrote or would write) and was
  last published with the paths in `published`: files that are new, that
  differ, and that Agendum wrote before but would not now (a post taken
  away). The stylesheet is changed only while it is still the one
  Agendum wrote before (`legacy_stylesheet/0`), so the person's own stays.
  """
  @spec changes([file], %{optional(String.t()) => String.t()}, [String.t()]) :: changes
  def changes(files, existing, published) do
    paths = MapSet.new(files, &elem(&1, 0))

    %{
      added: for({path, _} <- files, not Map.has_key?(existing, path), do: path),
      changed:
        for(
          {path, content} <- files,
          path != @stylesheet or existing[path] == @legacy_stylesheet,
          Map.has_key?(existing, path),
          existing[path] != content,
          do: path
        ),
      removed:
        for(
          path <- published,
          not MapSet.member?(paths, path),
          Map.has_key?(existing, path),
          do: path
        )
    }
  end

  # --- pages -------------------------------------------------------------------

  defp index(site) do
    articles = Enum.map_join(site.posts, "\n", &article(site, &1, "posts/", :index))
    empty = if site.posts == [], do: "<p>No posts yet.</p>", else: ""

    page(site, "", site.blog.title, """
    <main class="h-feed">
    #{description(site)}#{articles}#{empty}
    </main>
    """)
  end

  defp post_page(site, item) do
    page(site, "../", "#{title_text(site, item)} · #{site.blog.title}", """
    <main>
    #{article(site, item, "", :page)}
    <p class="back"><a href="../index.html">← #{esc(site.blog.title)}</a></p>
    </main>
    """)
  end

  defp description(%{blog: %{description: ""}}), do: ""
  defp description(site), do: ~s(<p class="p-summary">#{esc(site.blog.description)}</p>\n)

  # One post as an h-entry: its title (a link to its page on the index),
  # its date, its author and its note as HTML.
  defp article(site, item, prefix, where) do
    word = Zettels.zettel(item)
    title = title_html(site, item, prefix)

    heading =
      case where do
        :index ->
          ~s(<h2 class="p-name"><a class="u-url" href="#{prefix}#{word}.html">#{title}</a></h2>)

        :page ->
          ~s(<h1 class="p-name">#{title}</h1>)
      end

    """
    <article class="h-entry" id="#{word}">
    #{heading}
    <p class="meta">#{time_tag(site, item)}#{author_tag(site)}#{permalink(site, item, where)}</p>
    <div class="e-content">
    #{Markdown.to_html(item.note, site.used, link_fun(site, prefix))}
    </div>
    </article>
    """
  end

  defp time_tag(site, item) do
    case Blog.date(item) do
      nil ->
        ""

      date ->
        shown = DateFormat.date(date, site.db.date_format)
        ~s(<time class="dt-published" datetime="#{Date.to_iso8601(date)}">#{esc(shown)}</time>)
    end
  end

  defp author_tag(%{blog: %{author: ""}}), do: ""

  # without a Base address there is no home page to link the author to,
  # and an empty href="" would be a link to the page itself
  defp author_tag(%{blog: %{base_url: ""}} = site),
    do: ~s( · <span class="p-author h-card">#{esc(site.blog.author)}</span>)

  defp author_tag(site),
    do: ~s( · <a class="p-author h-card" href="#{attr(home(site))}">#{esc(site.blog.author)}</a>)

  # on its own page the post says where it is, for the u-url microformat;
  # without a Base address, by its file name, as the page is in posts/
  defp permalink(_site, _item, :index), do: ""

  defp permalink(%{blog: %{base_url: ""}}, item, :page),
    do: ~s( · <a class="u-url" href="#{attr(Path.basename(post_path(item)))}">permalink</a>)

  defp permalink(site, item, :page),
    do: ~s( · <a class="u-url" href="#{attr(absolute(site, post_path(item)))}">permalink</a>)

  # A Zettel link in a post: to the target's page when it is published,
  # else the target's text; a broken link stays as it was written.
  defp link_fun(site, prefix) do
    fn
      nil, word ->
        Markdown.escape("[[#{word}]]")

      target, _word ->
        item = site.db.items[target]
        text = Markdown.escape(plain_title(site, item))

        if MapSet.member?(site.published, target),
          do: ~s(<a href="#{prefix}#{Zettels.zettel(item)}.html">#{text}</a>),
          else: text
    end
  end

  # A title is the item's text; links in it become links too, without
  # becoming a title of their own
  defp title_html(site, item, prefix),
    do: inline_title(site, item.text, link_fun(site, prefix))

  defp title_text(site, item), do: plain_title(site, item)

  defp plain_title(site, item) do
    item.text
    |> ZettelLinks.scan(site.used)
    |> Enum.reverse()
    |> Enum.reduce(item.text, fn link, text ->
      replacement =
        case link.target do
          nil -> link.word
          id when id == item.id -> link.word
          id -> site.db.items[id].text
        end

      String.slice(text, 0, link.at) <>
        replacement <> String.slice(text, (link.at + link.length)..-1//1)
    end)
  end

  defp inline_title(site, text, link), do: Markdown.inline(text, site.used, link)

  defp page(site, root, title, body) do
    blog = site.blog

    """
    <!DOCTYPE html>
    <html lang="#{attr(blog.language)}">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="generator" content="Wol's Agendum">
    <title>#{esc(title)}</title>
    <link rel="stylesheet" href="#{root}#{@stylesheet}">
    <link rel="alternate" type="application/rss+xml" title="#{attr(blog.title)}" href="#{root}rss.xml">
    <link rel="alternate" type="application/feed+json" title="#{attr(blog.title)}" href="#{root}feed.json">
    #{me_links(blog)}</head>
    <body>
    #{site_header(blog, root)}
    #{body}<footer>
    <p>#{footer_card(site)}<a href="#{root}rss.xml">RSS</a> · <a href="#{root}feed.json">JSON Feed</a> · made with Wol's Agendum</p>
    </footer>
    </body>
    </html>
    """
  end

  # on the index the blog's title is the page's heading; on a post's page
  # the post's title is, and the blog's is a link home
  defp site_header(blog, ""),
    do: ~s(<header><h1 class="site"><a href="index.html">#{esc(blog.title)}</a></h1></header>)

  defp site_header(blog, root),
    do:
      ~s(<header><p class="site"><a href="#{root}index.html">#{esc(blog.title)}</a></p></header>)

  defp me_links(blog) do
    blog.me
    |> String.split()
    |> Enum.map_join(&~s(<link rel="me" href="#{attr(&1)}">\n))
  end

  defp footer_card(%{blog: %{author: ""}}), do: ""

  defp footer_card(%{blog: %{base_url: ""}} = site),
    do: ~s(<span class="h-card"><span class="p-name">#{esc(site.blog.author)}</span></span> · )

  defp footer_card(site) do
    ~s(<span class="h-card"><a class="p-name u-url" rel="me" href="#{attr(home(site))}">) <>
      "#{esc(site.blog.author)}</a></span> · "
  end

  # --- feeds ---------------------------------------------------------------------

  defp rss(site) do
    blog = site.blog

    items =
      Enum.map_join(site.posts, "", fn item ->
        url = absolute(site, post_path(item))

        """
        <item>
        <title>#{xml(title_text(site, item))}</title>
        <link>#{xml(url)}</link>
        <guid isPermaLink="true">#{xml(url)}</guid>
        #{pub_date(item)}<description>#{xml(content_html(site, item))}</description>
        </item>
        """
      end)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
    <channel>
    <title>#{xml(blog.title)}</title>
    <link>#{xml(home(site))}</link>
    <description>#{xml(blog.description)}</description>
    <language>#{xml(blog.language)}</language>
    <generator>Wol's Agendum</generator>
    <atom:link href="#{xml(absolute(site, "rss.xml"))}" rel="self" type="application/rss+xml"/>
    #{items}</channel>
    </rss>
    """
  end

  # RSS dates are RFC 822 ("Sat, 17 Oct 2026 00:00:00 +0000"); a post has
  # a day, not a moment, so it is midnight
  defp pub_date(item) do
    case Blog.date(item) do
      nil ->
        ""

      date ->
        day = Enum.at(~w(Mon Tue Wed Thu Fri Sat Sun), Date.day_of_week(date) - 1)

        month =
          Enum.at(~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec), date.month - 1)

        dd = String.pad_leading("#{date.day}", 2, "0")
        "<pubDate>#{day}, #{dd} #{month} #{date.year} 00:00:00 +0000</pubDate>\n"
    end
  end

  defp json_feed(site) do
    blog = site.blog

    items =
      Enum.map(site.posts, fn item ->
        url = absolute(site, post_path(item))
        date = Blog.date(item)

        Enum.reject(
          [
            {"id", url},
            {"url", url},
            {"title", title_text(site, item)},
            {"content_html", content_html(site, item)},
            {"date_published", date && Date.to_iso8601(date) <> "T00:00:00Z"}
          ],
          &(elem(&1, 1) == nil)
        )
      end)

    authors = if blog.author == "", do: [], else: [[{"name", blog.author}, {"url", home(site)}]]

    json([
      {"version", "https://jsonfeed.org/version/1.1"},
      {"title", blog.title},
      {"home_page_url", home(site)},
      {"feed_url", absolute(site, "feed.json")},
      {"description", blog.description},
      {"language", blog.language},
      {"authors", authors},
      {"items", items}
    ]) <> "\n"
  end

  # JSON with its keys in the order given (a map would sort them), so the
  # feed reads as the spec lists it and two builds are the same
  defp json(pairs) when is_list(pairs) and pairs != [] and is_tuple(hd(pairs)),
    do:
      "{" <> Enum.map_join(pairs, ",", fn {k, v} -> JSON.encode!(k) <> ":" <> json(v) end) <> "}"

  defp json(list) when is_list(list), do: "[" <> Enum.map_join(list, ",", &json/1) <> "]"
  defp json(value), do: JSON.encode!(value)

  defp content_html(site, item),
    do: Markdown.to_html(item.note, site.used, absolute_link_fun(site))

  # in the feeds, links to other posts are whole addresses
  defp absolute_link_fun(site) do
    relative = link_fun(site, "")

    fn target, word ->
      html = relative.(target, word)

      String.replace(html, ~s(<a href="), ~s(<a href="#{attr(absolute(site, "posts/"))}),
        global: false
      )
    end
  end

  # --- addresses -------------------------------------------------------------------

  defp home(%{blog: %{base_url: ""}}), do: ""
  defp home(site), do: base(site)

  defp absolute(site, path), do: base(site) <> path

  defp base(%{blog: %{base_url: url}}) do
    if url == "" or String.ends_with?(url, "/"), do: url, else: url <> "/"
  end

  defp esc(text), do: Markdown.escape(text)
  defp attr(text), do: Markdown.attribute(text)

  defp xml(text) do
    text
    |> Markdown.escape()
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end

  # --- the stylesheet ------------------------------------------------------------------

  @doc """
  The stylesheet Agendum writes when the folder has none: The Proportional
  Web (`site_assets/style.css`).
  """
  @spec default_stylesheet() :: String.t()
  def default_stylesheet, do: @default_stylesheet

  @doc """
  The monospace stylesheet Agendum wrote before 0.69, word for word: a
  folder that still has it gets the new one.
  """
  @spec legacy_stylesheet() :: String.t()
  def legacy_stylesheet, do: @legacy_stylesheet
end
