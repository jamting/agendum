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

  @doc """
  The file's structure without its items (File ▸ Transfer ▸ Template, R82;
  User's Guide 23-26): its categories, views, macros, conditions and
  actions and settings are kept; its items go, and with them every
  assignment, value, dependency and suggestion. A Show View listing items
  lists none. Ids keep counting on, as in the file it came from.
  """
  @spec template(db) :: db
  def template(db) do
    views =
      Map.new(db.views, fn
        {id, %{match: {:items, _}} = view} -> {id, %{view | match: nil}}
        pair -> pair
      end)

    %{
      db
      | items: %{},
        item_order: [],
        links: Agendum.Core.Links.new(),
        conditional: MapSet.new(),
        numbers: %{},
        texts: %{},
        dates: %{},
        dependencies: Agendum.Core.Links.new(),
        suggestions: %{},
        views: views,
        trash: %{db.trash | items: [], day: nil}
    }
  end

  @doc """
  A new file with Agenda's New File box's description and password (R82,
  ADR 0046), both optional; refused as `set_description/2` and
  `set_password/2` refuse them.
  """
  @spec new_file_with(String.t(), String.t()) :: {:ok, db} | {:error, :too_long}
  def new_file_with(description, password) do
    with {:ok, db} <- set_description(Database.new(), description),
         do: set_password(db, password)
  end

  # --- settings -------------------------------------------------------------------

  @doc """
  File Properties ▸ Tab size (R64e): how far apart the note editor's tab
  stops are, 1 to 16 characters (5, Agenda's, in a new file).
  """
  @spec set_tab_size(db, 1..16) :: db
  def set_tab_size(db, size) when is_integer(size) and size in 1..16, do: %{db | tab_size: size}

  @doc """
  File Properties ▸ File description (R82): a short description of the
  file, up to 40 characters as Agenda's, shown in the Select File box.
  """
  @spec set_description(db, String.t()) :: {:ok, db} | {:error, :too_long}
  def set_description(db, text) when is_binary(text) do
    text = String.trim(text)
    if String.length(text) > 40, do: {:error, :too_long}, else: {:ok, %{db | description: text}}
  end

  @doc """
  File Properties ▸ Set file password (R82, ADR 0046): up to 12 characters,
  as Agenda's; an empty one removes it. The file is encrypted with it when
  saved (`Agendum.Store`), and cannot be opened without it.
  """
  @spec set_password(db, String.t()) :: {:ok, db} | {:error, :too_long}
  def set_password(db, ""), do: {:ok, %{db | password: nil}}

  def set_password(db, password) when is_binary(password) do
    if String.length(password) > 12,
      do: {:error, :too_long},
      else: {:ok, %{db | password: password}}
  end

  @doc """
  File Properties ▸ Make backup on open (R82): when on, opening the file
  first copies it to a backup beside it (`my.agendum.bak`).
  """
  @spec set_backup_on_open(db, boolean) :: db
  def set_backup_on_open(db, on?) when is_boolean(on?), do: %{db | backup_on_open: on?}

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
