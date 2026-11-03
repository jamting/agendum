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

  alias Agendum.Core.{Database, DateFormat, ViewModel}
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

  # a list's own files, in its folder (R74e), kept free of posts' pages
  # whether or not its switches have them now; an item page already at one
  # of the first three moves the list's folder, while one already at
  # `archive.html` (made before the archive was) moves the archive to the
  # next free name instead (code review 2026-11-03)
  @list_files ~w(index.html rss.xml feed.json)
  @archive "archive.html"

  # the templates a site's pages and RSS feeds are drawn from
  # (`Agendum.Core.Extras.Template`), written into its `templates/` folder
  # when missing, then the person's; an `.html` one is named without its
  # extension (`post`), any other by its whole name (`rss.xml`)
  @template_names ~w(layout index post page menu archive rss.xml)
  for name <- @template_names ++ ~w(menu-0.81 index-0.81 index-0.87 index-0.89 post-0.87),
      do: @external_resource(Path.join(@assets, "templates/" <> Template.file(name)))

  @default_templates Map.new(@template_names, fn name ->
                       {name, File.read!(Path.join(@assets, "templates/" <> Template.file(name)))}
                     end)

  # templates an older Agendum wrote: one still word for word as it was is
  # Agendum's, not the person's, so a newer one replaces it (as `style.css`)
  @legacy_templates %{
    "templates/menu.html" => [File.read!(Path.join(@assets, "templates/menu-0.81.html"))],
    "templates/index.html" =>
      for(
        v <- ~w(0.81 0.87 0.89),
        do: File.read!(Path.join(@assets, "templates/index-#{v}.html"))
      ),
    "templates/post.html" => [File.read!(Path.join(@assets, "templates/post-0.87.html"))]
  }

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
  Whether `text` at `path` (`templates/menu.html`) is still word for word a
  template an older Agendum wrote: then it is replaced, as missing.
  """
  @spec legacy_template?(String.t(), String.t()) :: boolean
  def legacy_template?(path, text), do: text in Map.get(@legacy_templates, path, [])

  @doc "Whether an older Agendum ever wrote another version of the template at `path`."
  @spec had_legacy?(String.t()) :: boolean
  def had_legacy?(path), do: Map.has_key?(@legacy_templates, path)

  @doc """
  The templates Agendum writes into a site's `templates/` folder when one
  is missing, by their path there: then they are the person's to change.
  """
  @spec default_templates() :: [file]
  def default_templates,
    do: for({name, text} <- @default_templates, do: {"templates/" <> Template.file(name), text})

  @doc """
  Every file of the site on `today`: the posts due then (a When still to
  come waits; a post without a Zettel id is left out, as Publish gives
  each one first, R73), its pages drawn from the folder's
  templates (Agendum's own where one is missing) and its assets copied as
  they are; or why not: a template's mistake, with where it is, an
  asset's name that cannot be on the web, an image in a post or a page
  naming an asset the folder does not have (R74c), or a feed that does
  not read back (R74e).
  """
  @typedoc """
  Why the site could not be made: a template's mistake (its name, the
  line or nil, and what, `Agendum.Core.Extras.Template`), an asset's
  name that cannot be on the web, an asset an image names that is not
  there (its path, and the title of the post or page it is in), or a feed
  that does not read back as the feed it should be (its path; R74e).
  """
  @type error ::
          {:template, String.t(), pos_integer | nil, Template.mistake() | Template.render_error()}
          | {:asset_name, String.t()}
          | {:missing_asset, String.t(), String.t()}
          | {:bad_feed, String.t()}

  @spec build(Database.t(), Date.t(), inputs) :: {:ok, [file]} | {:error, error}
  def build(db, today, inputs), do: build(db, today, inputs, true)

  @doc """
  Every file of the site on `today`, with Agendum's own templates and no
  assets (an image's asset is not asked for).
  """
  @spec build(Database.t(), Date.t()) :: [file]
  def build(db, today) do
    {:ok, files} = build(db, today, %{templates: %{}, assets: []}, false)
    files
  end

  defp build(db, today, inputs, check_images?) do
    with {:ok, templates} <- parse(Map.merge(@default_templates, inputs.templates)),
         :ok <- assets_named_well(inputs.assets) do
      # an included template's last newline is not part of it, so a
      # partial can be a file ending in a newline and still sit in a line
      partials = Map.new(templates, fn {n, tree} -> {n, drop_last_newline(tree)} end)
      templates = %{whole: templates, partials: partials}
      pages(db, today, templates, inputs.assets, check_images?)
    end
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

  # Each image in a post or a page that names an asset (`assets/owl.jpg`)
  # needs that file in the folder's `assets/`; the first that is missing
  # stops publishing, with the post's title (R74c). A path that leads out of
  # `assets/` (`assets/../x`) is never one of its files, so it is missing too.
  defp images_there(_site, _assets, false), do: :ok

  defp images_there(site, assets, true) do
    have = MapSet.new(assets, &elem(&1, 0))

    # a list's items show their titles, and their notes only when it says so
    shown =
      for(item <- site.posts ++ site.pages, do: {item, true}) ++
        for list <- site.lists, item <- list.items, do: {item, list.notes}

    missing =
      Enum.find_value(shown, fn {item, notes?} ->
        notes = if notes?, do: Markdown.assets(item.note), else: []

        (Markdown.inline_assets(Blog.title(item)) ++ notes)
        |> Enum.find(&(not MapSet.member?(have, &1)))
        |> case do
          nil -> nil
          path -> {path, title_text(site, item)}
        end
      end)

    case missing do
      nil -> :ok
      {path, title} -> {:error, {:missing_asset, path, title}}
    end
  end

  # an asset's path goes into web addresses as it is: plain characters only
  defp assets_named_well(assets) do
    case Enum.find(assets, fn {path, _} -> not Address.plain?(path) end) do
      nil -> :ok
      {path, _} -> {:error, {:asset_name, path}}
    end
  end

  defp pages(%Database{} = db, today, templates, assets, check_images?) do
    # the addresses and modified days publishing would record now: shown in
    # the preview, kept only once the person publishes (`record/2`)
    {db, lists} = db |> unshown_notes(today) |> plan(today)
    blog = db.blog
    used = Zettels.zettels(db)
    posts = db |> Blog.posts(today) |> Enum.filter(& &1.zettel)
    pages = db |> Blog.pages(today) |> Enum.filter(& &1.zettel)
    # a list with feeds or item pages links its items, which needs a Zettel
    # id (Publish gives each one); an index-only list shows them all
    lists =
      for list <- lists do
        if list.feeds or list.item_pages,
          do: %{list | items: Enum.filter(list.items, & &1.zettel)},
          else: list
      end

    item_pages = Blog.item_pages(db, lists)
    taken = MapSet.new(Map.values(db.blog.published), & &1.path)
    published = MapSet.new(posts ++ pages ++ Enum.map(item_pages, &elem(&1, 0)), & &1.id)

    site = %{
      db: db,
      blog: blog,
      used: used,
      published: published,
      posts: posts,
      pages: pages,
      lists: lists,
      item_pages: item_pages,
      taken: taken
    }

    # the menu's pages and the lists, made once: each page drawn marks its
    # own as current
    site =
      site
      |> Map.put(:menu, for(item <- pages, do: menu_entry(site, item)))
      |> Map.put(:list_links, list_links(Enum.filter(lists, & &1.index)))

    draw = &draw(site, templates, &1, &2)
    rss = &rss(site, templates, &1)
    main = main_feed(site)

    with :ok <- images_there(site, assets, check_images?),
         {:ok, index} <- draw.("index", index(site)),
         {:ok, archive} <- main_archive(site, draw),
         {:ok, main_rss} <- rss.(main),
         {:ok, list_files} <- list_files(site, templates, draw, rss),
         {:ok, post_files} <-
           each_page(site.posts, "post", &own_page(site, &1, "post"), site, draw),
         {:ok, page_files} <-
           each_page(site.pages, "page", &own_page(site, &1, "item"), site, draw),
         {:ok, item_files} <- item_page_files(site, templates, draw) do
      pages = post_files ++ page_files ++ item_files ++ list_files

      files =
        [
          {"index.html", index},
          {"rss.xml", main_rss},
          {"feed.json", json_feed(site, main)},
          {@stylesheet, default_stylesheet()}
        ] ++ archive ++ pages

      metas = for list <- site.lists, list.feeds, do: own_feed(site, list)

      with :ok <- feeds_read_back(files, [main | metas]),
           do: {:ok, files ++ @font_files ++ assets}
    end
  end

  # Every feed written is read back by Agendum's own feed reader
  # (`Agendum.Core.Extras.FeedParser`), as a reader would: an RSS template
  # that gives no feed, or one with another number of entries than posts,
  # stops publishing, since a broken feed fails silently in readers (the
  # owner, after meeting 2026-11-02-2244, § 6). The JSON Feed, made in
  # code, is checked to be JSON with its items, too.
  defp feeds_read_back(files, metas) do
    files = Map.new(files)

    Enum.find_value(metas, :ok, fn meta ->
      count = length(meta.posts)
      rss = meta.folder <> "rss.xml"
      json = meta.folder <> "feed.json"

      cond do
        not rss_reads?(files[rss], count) -> {:error, {:bad_feed, rss}}
        not json_reads?(files[json], count) -> {:error, {:bad_feed, json}}
        true -> nil
      end
    end)
  end

  defp rss_reads?(text, count) do
    case Agendum.Core.Extras.FeedParser.parse(text) do
      {:ok, %{entries: entries}} -> length(entries) == count
      {:error, _} -> false
    end
  end

  defp json_reads?(text, count) do
    case JSON.decode(text) do
      {:ok, %{"items" => items}} when is_list(items) -> length(items) == count
      _ -> false
    end
  end

  # Each list's own files in its folder (R74e), as its switches say: its
  # index page, from its own `templates/<folder>/index.html` or the shared
  # one, and its RSS (`<folder>/rss.xml` or the shared `rss.xml`) and JSON
  # Feed.
  defp list_files(site, templates, draw, rss) do
    site.lists
    |> Enum.reduce_while({:ok, []}, fn list, {:ok, files} ->
      meta = %{
        own_feed(site, list)
        | template: own_template(templates, list, "rss.xml", "rss.xml")
      }

      archive? = list.index and archive?(list.items, list.newest)
      archive_template = own_template(templates, list, "archive", "archive")

      with {:ok, index} <-
             maybe(list.index, fn ->
               draw.(own_template(templates, list, "index", "index"), list_index(site, list))
             end),
           {:ok, archive} <-
             maybe(archive?, fn -> draw.(archive_template, list_archive(site, list)) end),
           {:ok, list_rss} <- maybe(list.feeds, fn -> rss.(meta) end) do
        own =
          Enum.filter(
            [
              list.index && {list.slug <> "/index.html", index},
              archive? && {archive_path(site, list.slug <> "/"), archive},
              list.feeds && {list.slug <> "/rss.xml", list_rss},
              list.feeds && {list.slug <> "/feed.json", json_feed(site, meta)}
            ],
            & &1
          )

        {:cont, {:ok, [own | files]}}
      else
        error -> {:halt, error}
      end
    end)
    |> then(fn
      {:ok, files} -> {:ok, files |> Enum.reverse() |> List.flatten()}
      error -> error
    end)
  end

  # a file drawn only when its switch is on
  defp maybe(true, draw), do: draw.()
  defp maybe(false, _draw), do: {:ok, nil}

  # A list's own template when its folder in `templates/` has one
  # (`templates/gym/index.html`), else the shared one (the owner,
  # 2026-11-03); Agendum never writes a list's own.
  defp own_template(templates, list, own, shared) do
    name = list.slug <> "/" <> own
    if Map.has_key?(templates.whole, name), do: name, else: shared
  end

  # each item's page from its list (R74e), from the list's own `item.html`
  # or the shared `post.html`, its values as `item` and as `post`
  defp item_page_files(site, templates, draw) do
    Enum.reduce_while(site.item_pages, {:ok, []}, fn {item, list}, {:ok, pages} ->
      template = own_template(templates, list, "item", "post")

      case draw.(template, item_page(site, item, list)) do
        {:ok, page} -> {:cont, {:ok, [{post_path(site.db, item), page} | pages]}}
        error -> {:halt, error}
      end
    end)
    |> then(fn
      {:ok, pages} -> {:ok, Enum.reverse(pages)}
      error -> error
    end)
  end

  # each post's (or page's) page from its template, or the first mistake
  defp each_page(items, template, context, site, draw) do
    Enum.reduce_while(items, {:ok, []}, fn item, {:ok, pages} ->
      case draw.(template, context.(item)) do
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
    context =
      site
      |> site_context()
      |> Map.merge(menu(site, context))
      |> Map.put("lists", site.list_links)
      |> Map.put("has_lists", site.list_links != [])
      |> Map.merge(context)

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
    files = ["index.html", "rss.xml", "feed.json", @archive, @stylesheet]
    fonts = @font_files |> Enum.map(&(&1 |> elem(0) |> Path.dirname())) |> Enum.uniq()
    # the person's templates and assets are never a post's page
    {files, fonts ++ ["templates", "assets"]}
  end

  @doc """
  Publishing on `today`, the part in the file: each post's record kept
  (`Agendum.Core.Extras.Blog.record_posts/3`), as the site was built.
  """
  @spec record(Database.t(), Date.t()) :: Database.t()
  def record(db, today) do
    # the records made as the site was built, from the notes it may show;
    # the file keeps its notes (only the blog's records come back)
    {shown, lists} = db |> unshown_notes(today) |> plan(today)
    Blog.record_lists(%{db | blog: shown.blog}, lists)
  end

  # Domain: an item published only through lists that keep their notes at
  # home has its note left out of the whole site, as if empty: no title
  # from a note's `# Heading` (on its pages, in feeds, in a `{slug}`
  # address, as a link's text), and no "Updated" from a changed note (code
  # review 2026-11-03). A post, a page, or an item of a list that publishes
  # notes shows its note as before.
  defp unshown_notes(db, today) do
    lists = Blog.lists(db, today, [])
    shown = MapSet.new(Blog.posts(db) ++ Blog.pages(db), & &1.id)
    shown = for list <- lists, list.notes, item <- list.items, into: shown, do: item.id

    hidden =
      for list <- lists,
          not list.notes,
          item <- list.items,
          not MapSet.member?(shown, item.id),
          uniq: true,
          do: item.id

    %{
      db
      | items: Enum.reduce(hidden, db.items, &Map.update!(&2, &1, fn i -> %{i | note: ""} end))
    }
  end

  @doc """
  The blog's lists on `today` as the site makes them (R74e): their
  folders kept from the site's own, and from a post already at a list's
  index or feeds (`Agendum.Core.Extras.Blog.lists/3`).
  """
  @spec lists(Database.t(), Date.t()) :: [Blog.blog_list()]
  def lists(db, today) do
    {_files, folders} = own()

    clashing =
      for %{path: path} <- Map.values(db.blog.published),
          Path.basename(path) in @list_files,
          Path.dirname(path) != ".",
          do: Path.dirname(path)

    Blog.lists(db, today, folders ++ clashing)
  end

  # The lists first; then the records of the posts, pages and list items'
  # pages, none of them on a list's index or feeds (the rest of a list's
  # folder is free: a list named Posts leaves `posts/<zettel id>.html`
  # alone).
  defp plan(db, today) do
    lists = lists(db, today)
    {files, folders} = own()
    list_files = for list <- lists, file <- [@archive | @list_files], do: "#{list.slug}/#{file}"
    db = Blog.record_posts(db, today, {files ++ list_files, folders}, lists)
    {db, lists}
  end

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

  # the pages for the menu, on every page: each with its address from the
  # site's root and whether it is the page being drawn
  defp menu(site, context) do
    pages = for entry <- site.menu, do: Map.put(entry, "current", entry["url"] == context["path"])
    %{"pages" => pages, "has_pages" => pages != []}
  end

  defp menu_entry(site, item),
    do: %{"title" => title_text(site, item), "url" => post_path(site.db, item)}

  # the main index: every post, the blog's description, and a line naming
  # the lists with feeds (the owner's choices, 2026-11-02 and 2026-11-03)
  defp index(site) do
    feeds = list_links(Enum.filter(site.lists, &(&1.index and &1.feeds)))

    %{
      "root" => "",
      "path" => "index.html",
      "page" => %{"title" => site.blog.title, "index" => true},
      "summary" => site.blog.description,
      "feeds" => feeds,
      "has_feeds" => feeds != [],
      "posts" => listed(site, newest(site.posts, site.blog.newest), ""),
      "has_archive" => archive?(site.posts, site.blog.newest),
      "archive_url" => archive_path(site, "")
    }
  end

  # lists named on a page: each title and index, from the site's root
  defp list_links(lists) do
    lists
    |> Enum.with_index()
    |> Enum.map(fn {list, i} ->
      %{"title" => list.title, "url" => list.slug <> "/index.html", "first" => i == 0}
    end)
  end

  # A list's own index (R74e): its items, its description, its title as
  # heading; `feed` and `posts` are the names an index template written
  # for feeds knows, `list` and `items` the same values by their new names
  defp list_index(site, list) do
    about = %{"title" => list.title, "slug" => list.slug, "has_rss" => list.feeds}

    items =
      list.items
      |> newest(list.newest)
      |> Enum.with_index()
      |> Enum.map(fn {item, i} ->
        site |> list_item(item, list, "../", :index) |> Map.put("first", i == 0)
      end)

    %{
      "root" => "../",
      "path" => list.slug <> "/index.html",
      "page" => %{"title" => "#{list.title} · #{site.blog.title}", "index" => false},
      "summary" => list.description,
      "feed" => about,
      "list" => about,
      "posts" => items,
      "items" => items,
      "has_archive" => archive?(list.items, list.newest),
      # from the list's own folder
      "archive_url" => site |> archive_path(list.slug <> "/") |> Path.basename()
    }
  end

  # --- the newest N, and the archive (R74, R74e; PUBLISHER_2 step 4) -----------

  # Where an archive goes, from the site's root: `archive.html` in its
  # folder, else `archive-2.html` … when a page published before archives
  # were has that address, as a published page never moves (R74b)
  defp archive_path(site, folder, n \\ 1) do
    name = if n == 1, do: @archive, else: "archive-#{n}.html"
    path = folder <> name
    if MapSet.member?(site.taken, path), do: archive_path(site, folder, n + 1), else: path
  end

  # the newest `n` of items already newest first; 0 is all
  defp newest(items, 0), do: items
  defp newest(items, n), do: Enum.take(items, n)

  # Domain: an archive only once an index no longer shows every item (the
  # owner, 2026-11-03), so a small site stays as it is
  defp archive?(items, n), do: n > 0 and length(items) > n

  defp main_archive(site, draw) do
    if archive?(site.posts, site.blog.newest) do
      context = archive(site, site.posts, "", nil, &post_path(site.db, &1))
      path = archive_path(site, "")

      with {:ok, page} <- draw.("archive", Map.put(context, "path", path)),
           do: {:ok, [{path, page}]}
    else
      {:ok, []}
    end
  end

  # a list's archive, in its folder: an item links to its own page (a
  # post's, or one from a list), else to nothing, as it may no longer be
  # on the list's index (the owner, 2026-11-03)
  defp list_archive(site, list) do
    about = %{"title" => list.title, "slug" => list.slug, "has_rss" => list.feeds}

    path = fn item ->
      if MapSet.member?(site.published, item.id), do: post_path(site.db, item)
    end

    site
    |> archive(list.items, "../", about, path)
    |> Map.put("path", archive_path(site, list.slug <> "/"))
  end

  # The archive's values: every item by month, newest first, each month's
  # title in the blog's language (its date language pack's month names,
  # English when Agendum has none for it), `path` giving an item's page
  # from the site's root, or nil.
  defp archive(site, items, root, about, path) do
    names = Agendum.Core.DateLanguage.for_code(site.blog.language).month_names()

    months =
      items
      |> Enum.chunk_by(&month(Blog.date(&1)))
      |> Enum.with_index()
      |> Enum.map(fn {[first | _] = items, i} ->
        {title, iso} = month_title(Blog.date(first), names)

        %{
          "title" => title,
          "month_iso" => iso,
          "first" => i == 0,
          "posts" => items |> Enum.with_index() |> Enum.map(&archived(site, &1, root, path))
        }
      end)

    title = if about, do: "#{about["title"]} · ", else: ""

    %{
      "root" => root,
      "page" => %{"title" => "#{title}Archive · #{site.blog.title}", "index" => false},
      "feed" => about,
      "list" => about,
      "months" => months
    }
  end

  defp month(nil), do: nil
  defp month(date), do: {date.year, date.month}

  defp month_title(nil, _names), do: {"", ""}

  defp month_title(date, names) do
    iso = "#{date.year}-#{String.pad_leading("#{date.month}", 2, "0")}"
    {"#{Enum.at(names, date.month - 1)} #{date.year}", iso}
  end

  defp archived(site, {item, i}, root, path) do
    date = Blog.date(item)
    to = path.(item)

    %{
      "title" => title_text(site, item),
      "title_html" => site |> title_html(item, root) |> place_assets(root),
      "url" => to && root <> to,
      "date" => shown(site, date),
      "date_iso" => date && Date.to_iso8601(date),
      "zettel" => Zettels.zettel(item),
      "first" => i == 0
    }
  end

  # an item's own page from its list (R74e)
  defp item_page(site, item, list) do
    path = post_path(site.db, item)
    root = root(path)
    values = list_item(site, item, list, root, :page)

    %{
      "root" => root,
      "path" => path,
      "page" => %{"title" => "#{title_text(site, item)} · #{site.blog.title}", "index" => false},
      "post" => values,
      "item" => values
    }
  end

  # One of a list's items, from a page at `root`: a post's values, with its
  # address (its post page, its page from a list, else its place on the
  # list's index), the list's fields, and its note only when the list
  # publishes notes (the owner, 2026-11-03).
  defp list_item(site, item, list, root, where) do
    path = item_path(site, item, list)
    {fields, columns} = fields(site, item, list)

    values =
      site
      |> post_context(item, root, where)
      |> Map.merge(%{
        "url" => path && root <> path,
        "permalink" => path && permalink_of(site, path),
        "fields" => fields,
        "columns" => columns,
        "has_columns" => columns != []
      })

    if list.notes,
      do: values,
      else: Map.merge(values, %{"content" => "", "notes_hidden" => true})
  end

  # where an item of `list` is, from the site's root: its own page (a post's
  # or one from a list), else its place on the list's index (by its Zettel
  # id); nil when it has neither, as an index-only list's items
  defp item_path(site, item, list) do
    cond do
      MapSet.member?(site.published, item.id) -> post_path(site.db, item)
      list.index and item.zettel -> list.slug <> "/index.html#" <> Zettels.zettel(item)
      true -> nil
    end
  end

  # The list's fields of an item (R74e; the owner, 2026-11-03): each named
  # by its category's name in lowercase, spaces as `_` (`Due date` is
  # `due_date`), the second of two alike `_2`; its value as the item's
  # column shows it (`Agendum.Core.ViewModel.cell/3`: the names of the
  # categories it is in, a date, a number, a text), "" when it has none.
  defp fields(site, item, list) do
    {columns, _keys} =
      list.fields
      |> Enum.with_index()
      |> Enum.map_reduce(MapSet.new(), fn {id, i}, keys ->
        name = site.db.categories[id].name
        key = free_key(field_key(name, id), keys, 1)
        value = ViewModel.cell(site.db, item, id)
        column = %{"name" => name, "key" => key, "value" => value, "first" => i == 0}
        {column, MapSet.put(keys, key)}
      end)

    {Map.new(columns, &{&1["key"], &1["value"]}), columns}
  end

  defp field_key(name, id) do
    case Address.slug(name) do
      "" -> "field_#{id}"
      slug -> String.replace(slug, "-", "_")
    end
  end

  defp free_key(key, keys, n) do
    candidate = if n == 1, do: key, else: "#{key}_#{n}"
    if MapSet.member?(keys, candidate), do: free_key(key, keys, n + 1), else: candidate
  end

  defp listed(site, posts, root) do
    posts
    |> Enum.with_index()
    |> Enum.map(fn {item, i} ->
      post_context(site, item, root, :index) |> Map.put("first", i == 0)
    end)
  end

  # a post's own page (its values under `post`) or a page's, such as About
  # (under `item`, drawn from `page.html`)
  defp own_page(site, item, key) do
    path = post_path(site.db, item)
    root = root(path)

    %{
      "root" => root,
      "path" => path,
      "page" => %{"title" => "#{title_text(site, item)} · #{site.blog.title}", "index" => false},
      key => post_context(site, item, root, :page)
    }
  end

  # One post, for the index (its address from there) or its own page
  # (`root` leads back to the site's root, for links to other posts).
  defp post_context(site, item, root, where) do
    date = Blog.date(item)
    modified = if where == :page, do: modified(site, item)

    %{
      "zettel" => Zettels.zettel(item),
      # from the page it is shown on: an index in a feed's folder too, so
      # a template written before feeds (`href="{{url}}"`) still works
      "url" => root <> post_path(site.db, item),
      "title" => title_text(site, item),
      "title_html" => site |> title_html(item, root) |> place_assets(root),
      "date" => shown(site, date),
      "date_iso" => date && Date.to_iso8601(date),
      "date_rss" => date && rss_date(date),
      "updated" => shown(site, modified),
      "updated_iso" => modified && Date.to_iso8601(modified),
      "permalink" => permalink(site, item),
      "content" =>
        item.note |> Markdown.to_html(site.used, link_fun(site, root)) |> place_assets(root)
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
  defp permalink(site, item), do: permalink_of(site, post_path(site.db, item))

  defp permalink_of(%{blog: %{base_url: ""}}, path), do: Path.basename(path)
  defp permalink_of(site, path), do: absolute(site, path)

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

  # What a feed says about itself: the site's main one, or a list's at
  # `slug/` (R74e); `url` gives an item's address from the site's root,
  # `notes` whether its body is in the feed, `template` its RSS template.
  defp main_feed(site) do
    %{
      title: site.blog.title,
      description: site.blog.description,
      home: home(site),
      folder: "",
      posts: newest(site.posts, site.blog.newest),
      url: &post_path(site.db, &1),
      notes: true,
      template: "rss.xml"
    }
  end

  defp own_feed(site, list) do
    home = if home(site) == "", do: "", else: absolute(site, list.slug <> "/")

    %{
      title: "#{site.blog.title} · #{list.title}",
      description: if(list.description == "", do: site.blog.description, else: list.description),
      home: home,
      folder: list.slug <> "/",
      posts: newest(list.items, list.newest),
      # an item without a page of its own or a place on an index is still
      # in the feed, at the list's folder by its own Zettel id, so each
      # entry has an id of its own (code review 2026-11-03)
      url: &(item_path(site, &1, list) || "#{list.slug}/##{Zettels.zettel(&1)}"),
      notes: list.notes,
      template: "rss.xml"
    }
  end

  # An RSS feed, drawn from the `rss.xml` template (R74e; the owner, after
  # meeting 2026-11-02-2244, § 6): Agendum's own gives what it wrote
  # before, word for word. Not put in the layout: the feed is the whole
  # file. Its values are whole addresses, its posts' bodies HTML, which
  # `{{content_html}}` escapes into the XML as RSS has it.
  defp rss(site, templates, meta) do
    items =
      Enum.map(meta.posts, fn item ->
        date = Blog.date(item)

        %{
          "title" => title_text(site, item),
          "url" => absolute(site, meta.url.(item)),
          "date_rss" => date && rss_date(date),
          "date_iso" => date && Date.to_iso8601(date),
          "zettel" => Zettels.zettel(item),
          "content_html" => if(meta.notes, do: content_html(site, item), else: "")
        }
      end)

    context =
      site
      |> site_context()
      |> Map.merge(%{
        "feed" => %{
          "title" => meta.title,
          "description" => meta.description,
          "home" => meta.home,
          "self" => absolute(site, meta.folder <> "rss.xml")
        },
        "items" => items
      })

    render(templates, meta.template, context)
  end

  # RSS dates are RFC 822 ("Sat, 17 Oct 2026 00:00:00 +0000"); a post has
  # a day, not a moment, so it is midnight
  defp rss_date(date) do
    day = Enum.at(~w(Mon Tue Wed Thu Fri Sat Sun), Date.day_of_week(date) - 1)
    month = Enum.at(~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec), date.month - 1)
    dd = String.pad_leading("#{date.day}", 2, "0")
    "#{day}, #{dd} #{month} #{date.year} 00:00:00 +0000"
  end

  defp json_feed(site, meta) do
    blog = site.blog

    items =
      Enum.map(meta.posts, fn item ->
        url = absolute(site, meta.url.(item))
        date = Blog.date(item)
        modified = modified(site, item)

        Enum.reject(
          [
            {"id", url},
            {"url", url},
            {"title", title_text(site, item)},
            {"content_html", if(meta.notes, do: content_html(site, item), else: "")},
            {"date_published", date && Date.to_iso8601(date) <> "T00:00:00Z"},
            {"date_modified", modified && Date.to_iso8601(modified) <> "T00:00:00Z"}
          ],
          &(elem(&1, 1) == nil)
        )
      end)

    authors = if blog.author == "", do: [], else: [[{"name", blog.author}, {"url", home(site)}]]

    json([
      {"version", "https://jsonfeed.org/version/1.1"},
      {"title", meta.title},
      {"home_page_url", meta.home},
      {"feed_url", absolute(site, meta.folder <> "feed.json")},
      {"description", meta.description},
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

  # in the feeds, an image's asset is a whole address too (from the site's
  # root without a Base address, as the links are)
  defp content_html(site, item) do
    item.note
    |> Markdown.to_html(site.used, absolute_link_fun(site))
    |> place_assets(attr(absolute(site, "")))
  end

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

  # An image's asset is written from the site's root (`assets/owl.jpg`);
  # on a page in a folder it needs `root` before it (`../assets/owl.jpg`).
  # Only Markdown's own images can start so: every `<` of a note's text is
  # escaped, so the note itself cannot write `<img src="assets/`.
  defp place_assets(html, ""), do: html

  defp place_assets(html, root),
    do: String.replace(html, ~s(<img src="assets/), ~s(<img src="#{root}assets/))

  defp home(%{blog: %{base_url: ""}}), do: ""
  defp home(site), do: base(site)

  defp absolute(site, path), do: base(site) <> path

  defp base(%{blog: %{base_url: url}}) do
    if url == "" or String.ends_with?(url, "/"), do: url, else: url <> "/"
  end

  defp attr(text), do: Markdown.attribute(text)

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
