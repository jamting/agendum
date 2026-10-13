defmodule Agenda.Core.Facade.Files do
  @moduledoc """
  Whole files: a new, empty file and the file as JSON (R44).

  Called through `Agenda.Core`.
  """

  alias Agenda.Core.Database

  @typep db :: Agenda.Core.db()

  defdelegate new_file(opts \\ []), to: Database, as: :new

  # --- JSON (R44) -----------------------------------------------------------------

  @doc "The whole file as readable JSON (`Agenda.Core.JSONFile`)."
  @spec export_json(db) :: String.t()
  defdelegate export_json(db), to: Agenda.Core.JSONFile, as: :encode

  @doc "A file read from JSON, checked; errors say what is wrong and where."
  @spec import_json(String.t()) :: {:ok, db} | {:error, String.t()}
  defdelegate import_json(text), to: Agenda.Core.JSONFile, as: :decode
end
