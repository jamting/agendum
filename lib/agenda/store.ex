defmodule Agenda.Store do
  @moduledoc """
  Saving and loading Agenda files (imperative shell).

  A file is the database serialized with `:erlang.term_to_binary/1`,
  wrapped in a versioned envelope so the format can evolve.
  """

  alias Agenda.Core.Database

  @format_version 1
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
          {:agenda, @format_version, %Database{} = db} -> {:ok, db}
          {:agenda, version, _} -> {:error, {:unsupported_version, version}}
          _ -> {:error, :not_an_agenda_file}
        end
      rescue
        ArgumentError -> {:error, :not_an_agenda_file}
      end
    end
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
