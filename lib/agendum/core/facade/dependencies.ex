defmodule Agendum.Core.Facade.Dependencies do
  @moduledoc """
  Dependencies between items (R43): prerequisites, dependents and the
  items related by them.

  Called through `Agendum.Core`.
  """

  alias Agendum.Core.{Database, Links}

  @typep db :: Agendum.Core.db()
  @typep id :: Agendum.Core.id()

  # --- dependencies (R43) ------------------------------------------------------

  @doc """
  Makes an item depend on prerequisite items (ALT-O with marked items;
  User's Guide 13-12), adding to any it already has. An item cannot depend
  on itself, or on an item that depends on it.
  """
  @spec make_dependent(db, id, [id]) :: {:ok, db} | {:error, :cycle}
  def make_dependent(db, item_id, prerequisite_ids) do
    below = related_items(db, item_id, :dependents, :all)

    # `&(...)` with `&1` inside: a one-argument anonymous function. `in` is
    # list membership (a linear scan; fine for a few items).
    if Enum.any?(prerequisite_ids, &(&1 == item_id or &1 in below)) do
      {:error, :cycle}
    else
      links = Enum.reduce(prerequisite_ids, db.dependencies, &Links.link(&2, item_id, &1))
      {:ok, %{db | dependencies: links}}
    end
  end

  @doc "Clears all of an item's prerequisites (ALT-O on a dependent item)."
  @spec clear_dependencies(db, id) :: db
  def clear_dependencies(db, item_id),
    do: %{db | dependencies: Links.drop_left(db.dependencies, item_id)}

  @doc "Stops an item depending on one prerequisite (DEL in Item Properties)."
  @spec remove_dependency(db, id, id) :: db
  def remove_dependency(db, item_id, prerequisite_id),
    do: %{db | dependencies: Links.unlink(db.dependencies, item_id, prerequisite_id)}

  @doc "The items an item depends on, in item order."
  @spec prerequisites(db, id) :: [id]
  defdelegate prerequisites(db, item_id), to: Database

  @doc "The items that depend on an item, in item order."
  @spec dependents(db, id) :: [id]
  defdelegate dependents(db, item_id), to: Database

  @doc "Whether an item still waits for a prerequisite that is not done (shown with &)."
  @spec waiting?(db, id) :: boolean
  defdelegate waiting?(db, item_id), to: Database

  @doc """
  Items related to an item by dependencies, in item order (Utilities Show
  Depends / Show Prereqs): `:one` level, `:all` levels, or `:every` item in
  the file that has dependents (or prerequisites); `item_id` is ignored
  for `:every`.
  """
  @spec related_items(db, id | nil, :dependents | :prerequisites, :one | :all | :every) :: [id]
  # A literal in the head (`:every`) selects this clause for that atom only;
  # every other level falls to the next clause. Clauses of one function
  # must sit together; the compiler warns otherwise.
  def related_items(db, _item_id, direction, :every) do
    # `step` holds a function; calling a function value needs the dot:
    # `step.(db, id)`, which tells it apart from a named function call.
    step = step_fun(direction)
    for id <- db.item_order, step.(db, id) != [], do: id
  end

  def related_items(db, item_id, direction, level) do
    found = reach(db, step_fun(direction), [item_id], [], level)
    Enum.filter(db.item_order, &(&1 in found and &1 != item_id))
  end

  defp step_fun(:dependents), do: &Database.dependents/2
  defp step_fun(:prerequisites), do: &Database.prerequisites/2

  # The items reached from `frontier`, one step (or all steps) at a time.
  # Recursion instead of a while loop: the base clause (empty frontier)
  # ends it. The recursive call is the last thing the function does (a tail
  # call), so the BEAM runs it in constant stack space, like a loop.
  defp reach(_db, _step, [], seen, _level), do: seen

  defp reach(db, step, frontier, seen, level) do
    next = frontier |> Enum.flat_map(&step.(db, &1)) |> Enum.uniq() |> Enum.reject(&(&1 in seen))
    seen = seen ++ next
    if level == :one, do: seen, else: reach(db, step, next, seen, level)
  end
end
