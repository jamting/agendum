# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.PagesTaskTest do
  @moduledoc "The site's llms.txt and link check (`mix agendum.pages`)."
  use ExUnit.Case, async: true

  alias Mix.Tasks.Agendum.Pages

  @index """
  # Index of the documents

  Introduction.

  ## Start here

  | Document | Read it to know |
  | --- | --- |
  | [`../README.md`](../README.md) | What Agendum is |
  | [`ROADMAP.md`](ROADMAP.md) | What is open |

  ## What Agendum does

  | Document | Read it to know |
  | --- | --- |
  | [`SPEC.md`](SPEC.md) | Every behaviour |
  | `docs/guide/index.html` | The short user guide |
  | `docs/reference/README.md` | The manuals as text |

  ## Plans

  | Document | Read it to know |
  | --- | --- |
  | [`plans/GITHUB.md`](plans/GITHUB.md) | Putting it on GitHub |

  ## Where a change is written down

  | [`SPEC.md`](SPEC.md) | not for a reader |
  """

  @available MapSet.new(
               ~w(docs/readme.md docs/spec.md docs/github.md guide/index.html index.html)
             )

  test "llms.txt lists INDEX.md's documents that are on the site, as links to their Markdown" do
    text = Pages.llms_txt(@index, "0.72.4", @available)

    assert text =~ "# Wol's Agendum\n"
    assert text =~ "Version 0.72.4"
    assert text =~ "## Start here\n\n- [README.md](docs/readme.md): What Agendum is\n"
    assert text =~ "- [SPEC.md](docs/spec.md): Every behaviour\n"
    assert text =~ "- [The user guide](guide/index.html): The short user guide\n"
    # the plans' folder is flattened, as ex_doc does
    assert text =~ "- [GITHUB.md](docs/github.md): Putting it on GitHub\n"
    # not on the site: left out, and so is the editing section
    refute text =~ "ROADMAP"
    refute text =~ "reference"
    refute text =~ "not for a reader"
    assert text =~ "## Optional\n\n- [Every page and module](docs/llms.txt)"
  end

  test "a link that leaves /agendum/ or leads nowhere is a problem; others are fine" do
    html = ~s"""
    <a href="guide/index.html">ok</a> <a href="#try">ok</a>
    <a href="https://github.com/jamting/agendum">ok</a> <img src="filing.webp">
    <a href="/guide/index.html">bad</a> <a href="devlog/index.html">missing</a>
    """

    assert [
             "  index.html: filing.webp (no such file)",
             "  index.html: /guide/index.html (starts with /)",
             "  index.html: devlog/index.html (no such file)"
           ] = Pages.link_problems("index.html", html, @available)

    # from a page in a folder, ../ climbs out of it, and a folder means its index
    assert [] = Pages.link_problems("guide/index.html", ~s(<a href="../">home</a>), @available)
  end
end
