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
  alias Agendum.Core.Extras.{Address, Blog, Markdown, Template, ZettelLinks}
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

  # the templates a site's pages are drawn from (`Agendum.Core.Extras.Template`),
  # written into its `templates/` folder when missing, then the person's
  @template_names ~w(layout index post menu)
  for name <- @template_names,
      do: @external_resource(Path.join([@assets, "templates", name <> ".html"]))

  @default_templates Map.new(@template_names, fn name ->
                       {name, File.read!(Path.join([@assets, "templates", name <> ".html"]))}
                     end)

  @doc "The stylesheet's path: written only when the folder has none."
  @spec stylesheet() :: String.t()
  def stylesheet, do: @stylesheet

  @typedoc """
  What the site's folder holds that the site is made from: its templates,
  by name (`templates/post.html` is `"post"`), and its assets, by their path
  in `assets/`, as the shell read them (`Agendum.Extras.Publish.inputs/1`).
  """
  @type inputs :: %{templates: %{optional(String.t()) => String.t()}, assets: [file]}

  @doc """
  The templates Agendum writes into a site's `templates/` folder when one
  is missing, by their path there: then they are the person's to change.
  """
  @spec default_templates() :: [file]
  def default_templates,
    do: for({name, text} <- @default_templates, do: {"templates/#{name}.html", text})

  @doc """
  Every file of the site on `today`: the posts due then (a When still to
  come waits; a post without a Zettel id is left out, as Publish gives
  each one first, R73), its pages drawn from the folder's
  templates (Agendum's own where one is missing) and its assets copied as
  they are; or why not: a template's mistake, with where it is, or an
  asset's name that cannot be on the web.
  """
  @typedoc """
  Why the site could not be made: a template's mistake (its name, the
  line or nil, and what, `Agendum.Core.Extras.Template`), or an asset's
  name that cannot be on the web.
  """
  @type error ::
          {:template, String.t(), pos_integer | nil, Template.mistake() | Template.render_error()}
          | {:asset_name, String.t()}

  @spec build(Database.t(), Date.t(), inputs) :: {:ok, [file]} | {:error, error}
  def build(db, today, inputs) do
    with {:ok, templates} <- parse(Map.merge(@default_templates, inputs.templates)),
         :ok <- assets_named_well(inputs.assets) do
      # an included template's last newline is not part of it, so a
      # partial can be a file ending in a newline and still sit in a line
      partials = Map.new(templates, fn {n, tree} -> {n, drop_last_newline(tree)} end)
      pages(db, today, %{whole: templates, partials: partials}, inputs.assets)
    end
  end

  @doc "Every file of the site on `today`, with Agendum's own templates and no assets."
  @spec build(Database.t(), Date.t()) :: [file]
  def build(db, today) do
    {:ok, files} = build(db, today, %{templates: %{}, assets: []})
    files
  end

  # each template parsed, or the first mistake and where
  defp parse(texts) do
    Enum.reduce_while(texts, {:ok, %{}}, fn {name, text}, {:ok, parsed} ->
      case Template.parse(text) do
        {:ok, tree} ->
          {:cont, {:ok, Map.put(parsed, name, tree)}}

        {:error, {line, mistake}} ->
          {:halt, {:error, {:template, name, line, mistake}}}
      end
    end)
  end

  # an asset's path goes into web addresses as it is: plain characters only
  defp assets_named_well(assets) do
    case Enum.find(assets, fn {path, _} -> not Address.plain?(path) end) do
      nil -> :ok
      {path, _} -> {:error, {:asset_name, path}}
    end
  end

  defp pages(%Database{} = db, today, templates, assets) do
    # the addresses and modified days publishing would record now: shown in
    # the preview, kept only once the person publishes (`record/2`)
    db = Blog.record_posts(db, today, own())
    blog = db.blog
    used = Zettels.zettels(db)
    posts = db |> Blog.posts(today) |> Enum.filter(& &1.zettel)
    published = MapSet.new(posts, & &1.id)
    site = %{db: db, blog: blog, used: used, published: published, posts: posts}
    draw = &draw(site, templates, &1, &2)

    with {:ok, index} <- draw.("index", index(site)),
         {:ok, pages} <- post_pages(site, draw) do
      {:ok,
       [
         {"index.html", index},
         {"rss.xml", rss(site)},
         {"feed.json", json_feed(site)},
         {@stylesheet, default_stylesheet()}
       ] ++ pages ++ @font_files ++ assets}
    end
  end

  defp post_pages(site, draw) do
    Enum.reduce_while(site.posts, {:ok, []}, fn item, {:ok, pages} ->
      case draw.("post", post_page(site, item)) do
        {:ok, page} -> {:cont, {:ok, [{post_path(site.db, item), page} | pages]}}
        error -> {:halt, error}
      end
    end)
    |> then(fn
      {:ok, pages} -> {:ok, Enum.reverse(pages)}
      error -> error
    end)
  end

  # a page: its own template (`index`, `post`) filled in, then put in the
  # layout as `content`; the templates are each other's partials, so
  # `{{> menu}}` (or any template in the folder) can be included
  defp draw(site, templates, name, context) do
    context = Map.merge(site_context(site), context)

    with {:ok, body} <- render(templates, name, context) do
      render(templates, "layout", Map.put(context, "content", body))
    end
  end

  defp render(templates, name, context) do
    case Template.render(templates.whole[name], context, templates.partials, name) do
      {:ok, text} -> {:ok, text}
      {:error, error} -> {:error, {:template, name, nil, error}}
    end
  end

  defp drop_last_newline(tree) do
    case List.last(tree) do
      {:text, text} -> List.replace_at(tree, -1, {:text, String.replace_suffix(text, "\n", "")})
      _ -> tree
    end
  end

  @doc """
  The site's own files and folders, which a post's page never takes
  (`Agendum.Core.Extras.Address.path/6`).
  """
  @spec own() :: {[String.t()], [String.t()]}
  def own do
    files = ["index.html", "rss.xml", "feed.json", @stylesheet]
    fonts = @font_files |> Enum.map(&(&1 |> elem(0) |> Path.dirname())) |> Enum.uniq()
    # the person's templates and assets are never a post's page
    {files, fonts ++ ["templates", "assets"]}
  end

  @doc """
  Publishing on `today`, the part in the file: each post's record kept
  (`Agendum.Core.Extras.Blog.record_posts/3`), as the site was built.
  """
  @spec record(Database.t(), Date.t()) :: Database.t()
  def record(db, today), do: Blog.record_posts(db, today, own())

  @doc """
  Where a post's page is: the address publishing made for it the first
  time (`Agendum.Core.Extras.PostRecord`), else `posts/bonalaku.html`. A
  stored address that is not a safe one (a crafted file) is not used.
  """
  @spec post_path(Database.t(), Agendum.Core.Item.t()) :: String.t()
  def post_path(db, item) do
    case Blog.record(db, item.id) do
      %{path: path} -> if Address.safe?(path), do: path, else: default_path(item)
      nil -> default_path(item)
    end
  end

  defp default_path(item), do: "posts/#{Zettels.zettel(item)}.html"

  # from a page at `path` back to the site's root: "../" for each folder
  defp root(path), do: String.duplicate("../", length(String.split(path, "/")) - 1)

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
      # a path written last time and not now goes, whether or not the
      # folder still has it: an asset the person deleted is removed from
      # the server too
      removed: for(path <- published, not MapSet.member?(paths, path), do: path)
    }
  end

  # --- pages -------------------------------------------------------------------
  #
  # Domain: what the templates see, as maps with string keys (the names a
  # template uses): `site` on every page, `root` (from the page back to the
  # site's root), `page` (its title, whether it is the index), and `posts`
  # (the index) or `post` (a post's page). Each post holds its parts ready
  # to show: dates as the file shows them and as ISO, its title as HTML,
  # its body as HTML (put in with `{{{…}}}`), its address from the page.

  defp site_context(site) do
    blog = site.blog

    %{
      "site" => %{
        "title" => blog.title,
        "description" => blog.description,
        "author" => blog.author,
        "language" => blog.language,
        "home" => home(site),
        "base_url" => blog.base_url,
        "me" => String.split(blog.me)
      }
    }
  end

  defp index(site) do
    posts =
      site.posts
      |> Enum.with_index()
      |> Enum.map(fn {item, i} ->
        post_context(site, item, "", :index) |> Map.put("first", i == 0)
      end)

    %{"root" => "", "page" => %{"title" => site.blog.title, "index" => true}, "posts" => posts}
  end

  defp post_page(site, item) do
    root = root(post_path(site.db, item))

    %{
      "root" => root,
      "page" => %{"title" => "#{title_text(site, item)} · #{site.blog.title}", "index" => false},
      "post" => post_context(site, item, root, :page)
    }
  end

  # One post, for the index (its address from there) or its own page
  # (`root` leads back to the site's root, for links to other posts).
  defp post_context(site, item, root, where) do
    date = Blog.date(item)
    modified = if where == :page, do: modified(site, item)

    %{
      "zettel" => Zettels.zettel(item),
      "url" => post_path(site.db, item),
      "title" => title_text(site, item),
      "title_html" => title_html(site, item, root),
      "date" => shown(site, date),
      "date_iso" => date && Date.to_iso8601(date),
      "updated" => shown(site, modified),
      "updated_iso" => modified && Date.to_iso8601(modified),
      "permalink" => permalink(site, item),
      "content" => Markdown.to_html(item.note, site.used, link_fun(site, root))
    }
  end

  defp shown(_site, nil), do: nil
  defp shown(site, date), do: DateFormat.date(date, site.db.date_format)

  # the day a publish found the post changed (R74), or nil
  defp modified(site, item) do
    case Blog.record(site.db, item.id) do
      %{modified: %Date{} = date} -> date
      _ -> nil
    end
  end

  # on its own page the post says where it is, for the u-url microformat;
  # without a Base address, by its file name, as the page is in its folder
  defp permalink(%{blog: %{base_url: ""}} = site, item),
    do: Path.basename(post_path(site.db, item))

  defp permalink(site, item), do: absolute(site, post_path(site.db, item))

  # A Zettel link in a post: to the target's page when it is published,
  # else the target's text; a broken link stays as it was written.
  defp link_fun(site, root) do
    fn
      nil, word ->
        Markdown.escape("[[#{word}]]")

      target, _word ->
        item = site.db.items[target]
        text = Markdown.escape(plain_title(site, item))

        if MapSet.member?(site.published, target),
          do: ~s(<a href="#{attr(root <> post_path(site.db, item))}">#{text}</a>),
          else: text
    end
  end

  # A title is the post's (a note's first-line `# Heading`, else the
  # item's text, `Blog.title/1`); links in it become links too, without
  # becoming a title of their own
  defp title_html(site, item, root),
    do: inline_title(site, Blog.title(item), link_fun(site, root))

  defp title_text(site, item), do: plain_title(site, item)

  defp plain_title(site, item) do
    title = Blog.title(item)

    title
    |> ZettelLinks.scan(site.used)
    |> Enum.reverse()
    |> Enum.reduce(title, fn link, text ->
      replacement =
        case link.target do
          nil -> link.word
          id when id == item.id -> link.word
          id -> Blog.title(site.db.items[id])
        end

      String.slice(text, 0, link.at) <>
        replacement <> String.slice(text, (link.at + link.length)..-1//1)
    end)
  end

  defp inline_title(site, text, link), do: Markdown.inline(text, site.used, link)

  # --- feeds ---------------------------------------------------------------------

  defp rss(site) do
    blog = site.blog

    items =
      Enum.map_join(site.posts, "", fn item ->
        url = absolute(site, post_path(site.db, item))

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
        url = absolute(site, post_path(site.db, item))
        date = Blog.date(item)
        modified = modified(site, item)

        Enum.reject(
          [
            {"id", url},
            {"url", url},
            {"title", title_text(site, item)},
            {"content_html", content_html(site, item)},
            {"date_published", date && Date.to_iso8601(date) <> "T00:00:00Z"},
            {"date_modified", modified && Date.to_iso8601(modified) <> "T00:00:00Z"}
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

      # the link is from the site's root: the base address goes before it
      String.replace(html, ~s(<a href="), ~s(<a href="#{attr(absolute(site, ""))}), global: false)
    end
  end

  # --- addresses -------------------------------------------------------------------

  defp home(%{blog: %{base_url: ""}}), do: ""
  defp home(site), do: base(site)

  defp absolute(site, path), do: base(site) <> path

  defp base(%{blog: %{base_url: url}}) do
    if url == "" or String.ends_with?(url, "/"), do: url, else: url <> "/"
  end

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
