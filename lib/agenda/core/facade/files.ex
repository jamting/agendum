defmodule Agenda.Core.Facade.Files do
  @moduledoc """
  Whole files: a new, empty file and the file as JSON (R44).

  Called through `Agenda.Core`.
  """

  alias Agenda.Core.Database

  # `@typep` is a private type: a local short name for `Agenda.Core.db()`,
  # so the `@spec`s below read the same as they did in `Agenda.Core`.
  @typep db :: Agenda.Core.db()

  # `as:` delegates to a function with another name: `new_file/1` here
  # calls `Database.new/1`.
  defdelegate new_file(opts \\ []), to: Database, as: :new

  # --- JSON (R44) -----------------------------------------------------------------

  @doc "The whole file as readable JSON (`Agenda.Core.JSONFile`)."
  @spec export_json(db) :: String.t()
  defdelegate export_json(db), to: Agenda.Core.JSONFile, as: :encode

  @doc "A file read from JSON, checked; errors say what is wrong and where."
  @spec import_json(String.t()) :: {:ok, db} | {:error, String.t()}
  defdelegate import_json(text), to: Agenda.Core.JSONFile, as: :decode
end
