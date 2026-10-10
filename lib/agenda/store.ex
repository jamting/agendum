defmodule Agenda.Store do
  @moduledoc """
  Saving and loading Agenda files (imperative shell).

  A file is the database serialized with `:erlang.term_to_binary/1`,
  wrapped in a versioned envelope so the format can evolve.

  Versions: 1 (initial); 2 adds `Item.when_explicit` and
  `Database.auto_date` (R14); 3 adds `Category.conditions` and
  `Database.conditional` (R15); 4 adds view and section `filter` and
  `sort` (R28, R36). Older versions are upgraded on load by filling new
  struct fields with their defaults.
  """

  alias Agenda.Core.Database

  @format_version 4
  @extension ".agenda"

  def extension, do: @extension

  @spec save(Database.t(), Path.t()) :: :ok | {:error, term}
  def save(%Database{} = db, path) do
    binary = :erlang.term_to_binary({:agenda, @format_version, db}, [:compressed])
    tmp = path <> ".tmp"

    with :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- File.write(tmp, binary) do
      File.rename(tmp, path)
    end
  end

  @spec load(Path.t()) :: {:ok, Database.t()} | {:error, term}
  def load(path) do
    with {:ok, binary} <- File.read(path) do
      # `:safe` decoding refuses unknown atoms, and struct field names only
      # exist once their modules are loaded (modules load lazily).
      ensure_modules_loaded()

      try do
        case :erlang.binary_to_term(binary, [:safe]) do
          {:agenda, version, %Database{} = db} when version in 1..@format_version ->
            {:ok, upgrade(db)}

          {:agenda, version, _} ->
            {:error, {:unsupported_version, version}}

          _ ->
            {:error, :not_an_agenda_file}
        end
      rescue
        ArgumentError -> {:error, :not_an_agenda_file}
      end
    end
  end

  @doc """
  Brings a database from any older format version up to date: every struct
  is rebuilt so fields added since it was saved get their defaults.
  """
  @spec upgrade(Database.t()) :: Database.t()
  def upgrade(%Database{} = db) do
    alias Agenda.Core.{Category, Item, View}

    db = struct(Database, Map.from_struct(db))

    %{
      db
      | items: Map.new(db.items, fn {id, i} -> {id, struct(Item, Map.from_struct(i))} end),
        categories:
          Map.new(db.categories, fn {id, c} -> {id, struct(Category, Map.from_struct(c))} end),
        views: Map.new(db.views, fn {id, v} -> {id, upgrade_view(v)} end)
    }
  end

  defp upgrade_view(view) do
    alias Agenda.Core.View
    view = struct(View, Map.from_struct(view))

    %{
      view
      | sections: Enum.map(view.sections, &struct(View.Section, Map.from_struct(&1))),
        columns: Enum.map(view.columns, &struct(View.Column, Map.from_struct(&1)))
    }
  end

  defp ensure_modules_loaded do
    {:ok, modules} = :application.get_key(:agenda, :modules)
    Enum.each(modules, &Code.ensure_loaded/1)
  end

  @doc "Adds the default extension when the path has none."
  @spec normalize_path(String.t()) :: String.t()
  def normalize_path(path) do
    path = Path.expand(String.trim(path))
    if Path.extname(path) == "", do: path <> @extension, else: path
  end
end
