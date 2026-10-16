defmodule Mix.Tasks.Agendum.Golden do
  @shortdoc "Writes the golden file of the current format version"
  @moduledoc """
  Writes the golden file of the current file format version
  (`Agendum.Store.format_version/0`) from `Agendum.Starters.Golden`, with
  its facts beside it:

      mix agendum.golden
      # test/fixtures/formats/v33.agendum and v33.facts.exs

  Run it in the commit that raises the format version, and commit both
  files; `test/agendum/golden_files_test.exs` fails until they are there.
  A golden file is never written again: it is a record of what that
  version wrote, so an existing one is left alone.
  """
  use Mix.Task

  alias Agendum.Starters.Golden
  alias Agendum.Store

  @dir "test/fixtures/formats"

  @impl Mix.Task
  def run(_args) do
    version = Store.format_version()
    file = Path.join(@dir, "v#{version}.agendum")
    facts = Path.join(@dir, "v#{version}.facts.exs")

    if File.exists?(file), do: Mix.raise("#{file} exists; a golden file is never rewritten")

    db = Golden.build()

    with :ok <- Store.save(db, file),
         :ok <- File.write(facts, facts_text(db, version)) do
      Mix.shell().info("Wrote #{file} and #{facts}; commit them both")
    else
      {:error, reason} -> Mix.raise("Could not write the golden file: #{inspect(reason)}")
    end
  end

  # An Elixir term the test reads back with `Code.eval_file/1`, laid out
  # as `mix format` would (it checks every .exs under test/).
  defp facts_text(db, version) do
    term = inspect(Golden.facts(db), limit: :infinity, printable_limit: :infinity)

    """
    # What the golden file v#{version}.agendum says (Agendum.Starters.Golden.facts/1),
    # written with it by `mix agendum.golden`. Every later version must still
    # read these facts out of it. Never edit by hand.
    #{IO.iodata_to_binary(Code.format_string!(term))}
    """
  end
end
