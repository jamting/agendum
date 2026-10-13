defmodule Agenda.Core.Facade.Macros do
  @moduledoc """
  Macros (R50): adding, naming and attaching macros to keys, and their
  order in the macro manager.

  Called through `Agenda.Core`.
  """

  alias Agenda.Core.{Database, Macro}

  @typep db :: Agenda.Core.db()
  @typep id :: Agenda.Core.id()

  # --- macros (R50) ---

  @doc """
  Adds a macro with a name and no keys yet, at the end of the macro
  manager's list. Names have up to 35 characters and are unique, case aside.
  """
  @spec add_macro(db, String.t()) ::
          {:ok, db, id} | {:error, :empty_name | :name_too_long | :name_taken}
  def add_macro(db, name) do
    # `with` and its `do` body: runs only if `macro_name/3` gave
    # `{:ok, name}`; an `{:error, _}` is returned unchanged.
    with {:ok, name} <- macro_name(db, name, nil) do
      {db, id} = Database.add_macro(db, %Macro{name: name})
      {:ok, db, id}
    end
  end

  @spec rename_macro(db, id, String.t()) ::
          {:ok, db} | {:error, :empty_name | :name_too_long | :name_taken}
  def rename_macro(db, id, name) do
    with {:ok, name} <- macro_name(db, name, id),
         do: {:ok, Database.update_macro(db, id, &%{&1 | name: name})}
  end

  defp macro_name(db, name, own) do
    name = String.trim(name)

    cond do
      name == "" ->
        {:error, :empty_name}

      String.length(name) > Macro.max_name() ->
        {:error, :name_too_long}

      # `match?(pattern, value)` tests a pattern without binding; the pattern
      # can carry a guard (`when ...`). Here: a macro of that name exists
      # and it is not the one being renamed.
      match?(%{id: other} when other != own, Database.find_macro(db, name)) ->
        {:error, :name_taken}

      true ->
        {:ok, name}
    end
  end

  @doc "Sets a macro's keystrokes, in Agenda's notation."
  @spec set_macro_keys(db, id, String.t()) :: db
  def set_macro_keys(db, id, keys), do: Database.update_macro(db, id, &%{&1 | keys: keys})

  @doc """
  Attaches a macro to a key, in Agenda's notation (`"{ShfF4}"`), or nil to
  detach it. A key runs one macro: another macro attached to it lets go.
  """
  @spec attach_macro(db, id, String.t() | nil) :: db
  def attach_macro(db, id, key) do
    db =
      Enum.reduce(Database.macros(db), db, fn m, db ->
        if key != nil and m.key == key and m.id != id,
          do: Database.update_macro(db, m.id, &%{&1 | key: nil}),
          else: db
      end)

    Database.update_macro(db, id, &%{&1 | key: key})
  end

  @doc "Whether a macro can be run from views, notes, the category manager or everywhere else."
  @spec set_macro_run_from(db, id, Macro.place(), boolean) :: db
  def set_macro_run_from(db, id, place, allowed),
    do: Database.update_macro(db, id, &%{&1 | run_from: Map.put(&1.run_from, place, allowed)})

  defdelegate delete_macro(db, id), to: Database

  @doc "Moves a macro to position `index` in the macro manager (clamped)."
  @spec move_macro(db, id, integer) :: db
  def move_macro(db, id, index) do
    rest = List.delete(db.macro_order, id)
    # Lists are linked lists: `length/1`, `List.delete/2` and
    # `List.insert_at/3` walk the list (O(n)); fine for a few dozen macros.
    index = index |> max(0) |> min(length(rest))
    %{db | macro_order: List.insert_at(rest, index, id)}
  end

  @doc "Sorts the macros by name (ALT-F5 in the macro manager)."
  @spec sort_macros(db) :: db
  def sort_macros(db),
    do: %{
      db
      | macro_order:
          db |> Database.macros() |> Enum.sort_by(&String.downcase(&1.name)) |> Enum.map(& &1.id)
    }
end
