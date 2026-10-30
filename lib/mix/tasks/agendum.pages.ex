# SPDX-License-Identifier: AGPL-3.0-only
defmodule Mix.Tasks.Agendum.Pages do
  @shortdoc "Assembles the GitHub Pages site in _build/pages"
  @moduledoc """
  Puts the public site together (meeting 2026-10-30-2020, §§ 5, 8, 10), as
  GitHub Pages serves it at `jamting.github.io/agendum/`:

      _build/pages/
        index.html, filing.webp   the front page and its recording (pages/)
        devlog/                   the devlog, published there by the blog extra
        guide/  manual/  fonts/   the user guide and the manual (docs/)
        docs/                     the API and design docs (`mix docs`)
        llms.txt                  the documents for a model, from docs/INDEX.md

      mix docs && mix agendum.pages     # then open _build/pages/index.html

  It fails, naming the link, when a page of the site's own links to a path
  starting with `/` (the site lives under `/agendum/`, so such a link leads
  out of it) or to a file the site does not have; the API docs are
  ex_doc's and not checked. The Pages workflow (`.github/workflows/pages.yml`)
  runs it.
  """
  use Mix.Task

  @out "_build/pages"
  @ex_doc "_build/docs"

  # what is copied from where: the guide's and the manual's pages with their
  # stylesheets, script and pictures, not the sources they are made from
  @copies [
    {"pages", ""},
    {@ex_doc, "docs"},
    {"docs/fonts", "fonts"},
    {"docs/guide/index.html", "guide/index.html"},
    {"docs/guide/guide.css", "guide/guide.css"},
    {"docs/guide/place.js", "guide/place.js"},
    {"docs/guide/screens", "guide/screens"},
    {"docs/manual/index.html", "manual/index.html"},
    {"docs/manual/manual.css", "manual/manual.css"},
    {"docs/manual/screens", "manual/screens"}
  ]

  # the pages whose links are checked: ours, not ex_doc's
  @checked ["index.html", "guide/index.html", "manual/index.html"]

  @impl Mix.Task
  def run(_args) do
    unless File.exists?(Path.join(@ex_doc, "index.html")),
      do: Mix.raise("No API docs in #{@ex_doc}: run `mix docs` first")

    File.rm_rf!(@out)

    for {from, to} <- @copies do
      target = Path.join(@out, to)
      File.mkdir_p!(Path.dirname(target))
      File.cp_r!(from, target)
    end

    # llms.txt is written below, from this list
    available = @out |> files() |> MapSet.put("llms.txt")
    version = Mix.Project.config()[:version]

    File.write!(
      Path.join(@out, "llms.txt"),
      llms_txt(File.read!("docs/INDEX.md"), version, available)
    )

    problems =
      for page <- @checked,
          problem <- link_problems(page, File.read!(Path.join(@out, page)), available),
          do: problem

    if problems != [], do: Mix.raise("Broken links on the site:\n" <> Enum.join(problems, "\n"))

    Mix.shell().info("Wrote the site to #{@out} (#{MapSet.size(available) + 1} files)")
  end

  # every file under `dir`, as a path relative to it
  defp files(dir) do
    Path.wildcard(Path.join(dir, "**/*"), match_dot: false)
    |> Enum.filter(&File.regular?/1)
    |> MapSet.new(&Path.relative_to(&1, dir))
  end

  @doc """
  The site's `llms.txt` (llmstxt.org): the tables of `docs/INDEX.md`, each
  row a link to the Markdown copy `mix docs` writes beside its page, up to
  the section "Where a change is written down" (which is about editing the
  repository). Rows whose document is not on the site (the reference texts,
  the folders) are left out. `available` holds the site's files. Pure.
  """
  @spec llms_txt(String.t(), String.t(), MapSet.t(String.t())) :: String.t()
  def llms_txt(index, version, available) do
    sections =
      index
      |> String.split("\n## ")
      # the first piece is the title and the introduction
      |> Enum.drop(1)
      |> Enum.take_while(&(not String.starts_with?(&1, "Where a change is written down")))
      |> Enum.map(&section(&1, available))
      |> Enum.reject(&(&1 == nil))

    """
    # Wol's Agendum

    > Lotus Agenda (1988) rebuilt in Elixir, with a terminal UI that looks like the original: a personal information manager where you type a thought and it files itself under categories. A pure functional core with an imperative shell. Version #{version}; AGPL-3.0-only, the documents CC BY 4.0.

    The user guide and the manual are HTML; the other documents are Markdown copies of the repository's `docs/` (https://github.com/jamting/agendum).

    #{Enum.join(sections, "\n")}
    ## Optional

    - [Every page and module](docs/llms.txt): the API documentation's full table of contents
    """
  end

  # one "## Heading" and its rows as a list of links; nil when none is left
  defp section(text, available) do
    [heading | lines] = String.split(text, "\n")

    links =
      for "| " <> row <- lines,
          [first, description | _] = row |> String.split(" | ") |> Enum.map(&String.trim/1),
          path = site_path(first),
          path != nil and MapSet.member?(available, path),
          do:
            "- [#{name(first)}](#{path}): #{description |> String.trim_trailing("|") |> String.trim()}\n"

    if links != [], do: "## #{heading}\n\n#{Enum.join(links)}"
  end

  # Domain: INDEX.md names a document as a link, [`ARCHITECTURE.md`](ARCHITECTURE.md),
  # or as a path in backquotes when it is not Markdown; ex_doc writes each
  # Markdown document as docs/<lower-case name>.md, the folders flattened.
  defp site_path("[`" <> _ = cell) do
    case Regex.run(~r/\]\(([^)#]+\.md)\)/, cell) do
      [_, target] -> "docs/" <> String.downcase(Path.basename(target))
      nil -> nil
    end
  end

  defp site_path("`docs/guide/index.html`"), do: "guide/index.html"
  defp site_path("`docs/manual/index.html`"), do: "manual/index.html"
  defp site_path(_cell), do: nil

  defp name(cell) do
    case Regex.run(~r/`([^`]+)`/, cell) do
      [_, "docs/guide/index.html"] -> "The user guide"
      [_, "docs/manual/index.html"] -> "The manual"
      [_, file] -> Path.basename(file)
      nil -> cell
    end
  end

  @doc """
  What is wrong with the links on `page` (its path in the site) in `html`:
  each `href` or `src` that starts with `/` (it would leave `/agendum/`) or
  leads to a file not in `available`, as a line naming the page and the
  link. Links to other sites, mail and fragments in the same page are fine;
  a link to a folder means its `index.html`. Pure.
  """
  @spec link_problems(String.t(), String.t(), MapSet.t(String.t())) :: [String.t()]
  def link_problems(page, html, available) do
    for [_, link] <- Regex.scan(~r/(?:href|src)="([^"]*)"/, html),
        problem = link_problem(page, link, available),
        do: "  #{page}: #{link} (#{problem})"
  end

  defp link_problem(page, link, available) do
    target = link |> String.split(["#", "?"]) |> hd()

    cond do
      String.starts_with?(link, "/") -> "starts with /"
      Regex.match?(~r/^[a-z]+:/, link) or target == "" -> nil
      MapSet.member?(available, resolve(page, target)) -> nil
      true -> "no such file"
    end
  end

  # a relative link from `page`, as a path in the site
  # (the site's root itself comes back from relative_to/2 as ".")
  defp resolve(page, target) do
    path =
      case page |> Path.dirname() |> Path.join(target) |> Path.expand("/") do
        "/" -> ""
        absolute -> Path.relative_to(absolute, "/")
      end

    if String.ends_with?(target, "/") or target in [".", ".."],
      do: Path.join(path, "index.html"),
      else: path
  end
end
