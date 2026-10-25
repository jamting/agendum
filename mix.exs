defmodule Agendum.MixProject do
  use Mix.Project

  def project do
    [
      app: :agendum,
      version: "0.37.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      escript: [main_module: Agendum.CLI, name: "agendum"],
      aliases: aliases(),
      deps: deps(),
      name: "Wol's Agendum",
      docs: docs(),
      # mix tasks in lib/mix/tasks (`mix agendum.starters`) use Mix itself
      dialyzer: [plt_add_apps: [:mix]],
      # the golden files' facts (`test/fixtures/formats/*.facts.exs`) are
      # data read by a test, not tests: ExUnit warns about them otherwise
      test_ignore_filters: [&String.starts_with?(&1, "test/fixtures/")]
    ]
  end

  def cli do
    # the escript is built for prod, so no dev or test tool ends up in it
    [preferred_envs: [check: :test, "escript.build": :prod]]
  end

  def application do
    [extra_applications: [:logger, :inets, :ssl, :public_key, :ssh]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:stream_data, "~> 1.1", only: [:dev, :test]},
      # code checks (dev/test only; never part of the program)
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      # API documentation, `mix docs` (dev only; ADR 0021)
      {:ex_doc, "~> 0.38", only: :dev, runtime: false}
    ]
  end

  # `mix docs` writes _build/docs/index.html (not ex_doc's default doc/,
  # too easily confused with docs/): the core facade first, for whoever
  # builds on it (a web front end, ADR 0020), then the rest, and the design
  # documents and decisions as pages.
  @docs_output "_build/docs"

  defp docs do
    [
      main: "readme",
      output: @docs_output,
      formatters: ["html", "markdown"],
      extras:
        ["README.md", "CHANGELOG.md", "CONTRIBUTING.md", "CLAUDE.md"] ++
          Path.wildcard("docs/*.md") ++
          Path.wildcard("docs/plans/*.md") ++
          Path.wildcard("docs/plans/archive/*.md") ++ Path.wildcard("docs/adr/*.md"),
      # docs/ describes Agendum as it is; docs/plans/ what is planned or
      # under way (each plan says how far it has come); docs/plans/archive/
      # finished plans, kept as records
      groups_for_extras: [
        Design: ~r{docs/[A-Z_-]+\.md},
        Plans: ~r{docs/plans/[^/]+\.md$},
        Archive: ~r{docs/plans/archive/},
        Decisions: ~r{docs/adr/}
      ],
      groups_for_modules: [
        Overview: [Agendum],
        "Core facade": [Agendum.Core, ~r/^Agendum\.Core\.Facade\./],
        Core: ~r/^Agendum\.Core\./,
        # the TUI's folders first: a module goes in the first group it fits
        "Terminal UI: boxes": ~r/^Agendum\.TUI\.Boxes\./,
        "Terminal UI: typing": ~r/^Agendum\.TUI\.Typing\./,
        "Terminal UI: moves": ~r/^Agendum\.TUI\.Moves\./,
        "Terminal UI: terminal": [Agendum.TUI.Terminal, ~r/^Agendum\.TUI\.Terminal\./],
        "Terminal UI": ~r/^Agendum\.TUI\./,
        Shell: [
          Agendum.CLI,
          Agendum.Store,
          Agendum.Preferences,
          Agendum.Extras.CalendarFetch,
          Agendum.Sample
        ]
      ],
      before_closing_body_tag: &mermaid/1
    ]
  end

  defp copy_user_docs(_args) do
    for file <- ~w(guide/index.html guide/guide.css manual/index.html manual/manual.css) do
      target = Path.join([@docs_output, "docs", file])
      File.mkdir_p!(Path.dirname(target))
      File.cp!(Path.join("docs", file), target)
    end
  end

  # renders the documents' Mermaid diagrams
  defp mermaid(:html) do
    """
    <script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
    <script>
      document.addEventListener("DOMContentLoaded", () => {
        mermaid.initialize({startOnLoad: false, theme: document.body.className.includes("dark") ? "dark" : "default"});
        let id = 0;
        for (const code of document.querySelectorAll("pre code.mermaid")) {
          const pre = code.parentElement;
          mermaid.render("mermaid-" + id++, code.textContent).then(({svg}) => {
            const div = document.createElement("div");
            div.innerHTML = svg;
            pre.replaceWith(div);
          });
        }
      });
    </script>
    """
  end

  defp mermaid(_format), do: ""

  # `mix check` is the single quality gate (used by humans, CI and AI agents).
  defp aliases do
    [
      # the user guide and the manual, where the README's links
      # (docs/guide/…, docs/manual/…) find them, then the API docs; ex_doc
      # keeps files it did not make, and gets the arguments (`--open`)
      docs: [&copy_user_docs/1, "docs"],
      # a fresh checkout: the dependencies, and git's hooks from .githooks
      # (pre-push runs `mix check`)
      setup: ["deps.get", "cmd git config core.hooksPath .githooks"],
      check: [
        "format --check-formatted",
        "compile --warnings-as-errors --force",
        "credo",
        "dialyzer",
        "test --warnings-as-errors"
      ]
    ]
  end
end
