defmodule Agendum.Core.Facade.Files do
  @moduledoc """
  Whole files: a new, empty file, a setting of the whole file (Tab size),
  the file as JSON (R44), and a Lotus Agenda file imported (R72).

  Called through `Agendum.Core`.
  """

  alias Agendum.Core.Database

  # `@typep` is a private type: a local short name for `Agendum.Core.db()`,
  # so the `@spec`s below read the same as they did in `Agendum.Core`.
  @typep db :: Agendum.Core.db()

  # `as:` delegates to a function with another name: `new_file/1` here
  # calls `Database.new/1`.
  defdelegate new_file(opts \\ []), to: Database, as: :new

  # --- settings -------------------------------------------------------------------

  @doc """
  File Properties ▸ Tab size (R64e): how far apart the note editor's tab
  stops are, 1 to 16 characters (5, Agenda's, in a new file).
  """
  @spec set_tab_size(db, 1..16) :: db
  def set_tab_size(db, size) when is_integer(size) and size in 1..16, do: %{db | tab_size: size}

  # --- JSON (R44) -----------------------------------------------------------------

  @doc "The whole file as readable JSON (`Agendum.Core.JSONFile`)."
  @spec export_json(db) :: String.t()
  defdelegate export_json(db), to: Agendum.Core.JSONFile, as: :encode

  @doc "A file read from JSON, checked; errors say what is wrong and where."
  @spec import_json(String.t()) :: {:ok, db} | {:error, String.t()}
  defdelegate import_json(text), to: Agendum.Core.JSONFile, as: :decode

  # --- Lotus Agenda files (R72) ---------------------------------------------------

  @doc """
  Whether bytes are a Lotus Agenda file (`.AG`) rather than JSON, for an
  import that takes both.
  """
  @spec agenda_file?(binary) :: boolean
  defdelegate agenda_file?(bytes), to: Agendum.Core.AgFile

  @doc """
  A Lotus Agenda file imported as a new file, with the report of what came
  over (`Agendum.Core.AgFile`); `opts`: `password:`, `clock:`.
  """
  @spec import_ag(binary, keyword) ::
          {:ok, db, Agendum.Core.AgFile.report()} | {:error, atom | String.t()}
  defdelegate import_ag(bytes, opts \\ []), to: Agendum.Core.AgFile, as: :import
end
