defmodule Mix.Tasks.Agendum.Starters do
  @shortdoc "Writes the starter files (starters/planner.agendum)"
  @moduledoc """
  Writes the Activities Planner starter file (R60) from
  `Agendum.Starters.Planner`:

      mix agendum.starters                    # starters/planner.agendum
      mix agendum.starters --samples          # tmp/planner-samples.agendum
      mix agendum.starters --samples --today 2026-10-12
      mix agendum.starters --output PATH      # somewhere else
      mix agendum.starters --clinic           # tmp/hundred-acre-clinic.agendum

  `--clinic` writes Christopher Robin's clinic (`Agendum.Starters.Clinic`,
  an Easter egg also opened by `agendum --clinic`), dated from `--today`.

  `--samples` fills a copy with sample data for testing (never the
  committed file, so it goes to `tmp/` unless `--output` says otherwise).
  Its dates are counted from `--today`, by default today, so the same day
  gives the same file.
  """
  use Mix.Task

  alias Agendum.Starters.Planner
  alias Agendum.Store

  @impl Mix.Task
  def run(args) do
    {opts, _rest} =
      OptionParser.parse!(args,
        strict: [samples: :boolean, clinic: :boolean, today: :string, output: :string]
      )

    {db, default} =
      cond do
        opts[:clinic] ->
          {Agendum.Starters.Clinic.build(today(opts[:today])), "tmp/hundred-acre-clinic.agendum"}

        opts[:samples] ->
          {Planner.with_samples(Planner.build(), today(opts[:today])),
           "tmp/planner-samples.agendum"}

        true ->
          {Planner.build(), "starters/planner.agendum"}
      end

    path = opts[:output] || default

    case Store.save(db, path) do
      :ok -> Mix.shell().info("Wrote #{path}")
      {:error, reason} -> Mix.raise("Could not write #{path}: #{inspect(reason)}")
    end
  end

  defp today(nil), do: Agendum.TUI.App.local_today()

  defp today(text) do
    case Date.from_iso8601(text) do
      {:ok, date} -> date
      {:error, _} -> Mix.raise("--today takes a date as YYYY-MM-DD, not #{text}")
    end
  end
end
