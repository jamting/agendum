defmodule Agendum.Core.Command.Changes do
  @moduledoc """
  What a command changed (R66, ADR 0036): the ids of the items,
  categories, views, macros and calendars it added, changed or removed,
  and which of the file's own settings it changed. A command that makes
  an item also says which one (`new:`).

  It is found by comparing the database before and after, never reported
  by hand, so it is right for every command, the ones still to come
  included, as undo is (ADR 0005). Comparing is cheap: data never changes
  in place, so the parts a command did not touch are the same terms in
  both databases, and `==` sees that at once.

  An item counts as changed when anything stored about it changed: the
  item itself, its assignments, its numbers and dates in columns, its
  dependencies, whether an assignment is conditional, and its suggested
  assignments. Assigning an item changes the item, not the category.
  """

  alias Agendum.Core.{Database, Links}

  @typedoc "Ids added, changed and removed, each list in id order."
  @type ids :: %{added: [Database.id()], changed: [Database.id()], removed: [Database.id()]}

  # The `optional(…) =>` keys come first: in a map type, the `key: type`
  # pairs must come last. They are added by the command, not found by
  # comparing: `new:` the id of what it made, `result:` anything else its
  # function returned (such as `:date` for typing a date), `steps:` what
  # each command of a batch made.
  @type t :: %{
          optional(:new) => Database.id(),
          optional(:result) => term,
          optional(:steps) => [map],
          items: ids,
          categories: ids,
          views: ids,
          macros: ids,
          calendars: ids,
          file: [atom]
        }

  # The database's fields that hold objects by id, each compared by key.
  @objects [:items, :categories, :views, :macros, :calendars]

  # The fields that hold something about items, keyed by item: an item
  # whose entry changed counts as changed.
  @about_items [:links, :numbers, :dates, :dependencies, :conditional, :suggestions]

  @doc "What changed between two versions of a database."
  @spec between(Database.t(), Database.t()) :: t
  def between(before, after_) do
    objects = Map.new(@objects, &{&1, compare(Map.fetch!(before, &1), Map.fetch!(after_, &1))})

    # an item that something about it changed, and that was neither added
    # nor removed, is changed
    touched = Enum.flat_map(@about_items, &touched_items(&1, before, after_))
    items = objects.items
    new_or_gone = items.added ++ items.removed
    changed = Enum.sort(Enum.uniq(items.changed ++ (touched -- new_or_gone)))

    Map.merge(objects, %{
      items: %{items | changed: changed},
      file: file_changes(before, after_)
    })
  end

  @doc "Whether nothing changed."
  @spec none?(t) :: boolean
  def none?(changes) do
    changes.file == [] and
      Enum.all?(@objects, fn kind ->
        Enum.all?(Map.values(changes[kind]), &(&1 == []))
      end)
  end

  # Two maps by id: which keys are new, which are gone, which hold
  # something else now. A variable named twice in a pattern (`same, same`)
  # matches only when both arguments are equal: nothing touched, nothing
  # to walk.
  defp compare(same, same), do: %{added: [], changed: [], removed: []}

  defp compare(before, after_) do
    %{
      added: after_ |> Map.keys() |> Enum.reject(&Map.has_key?(before, &1)) |> Enum.sort(),
      removed: before |> Map.keys() |> Enum.reject(&Map.has_key?(after_, &1)) |> Enum.sort(),
      changed:
        for(
          {id, value} <- after_,
          Map.has_key?(before, id),
          Map.fetch!(before, id) != value,
          do: id
        )
        |> Enum.sort()
    }
  end

  # The items whose entry in one of the item-keyed fields differs.
  defp touched_items(field, before, after_) do
    case {Map.fetch!(before, field), Map.fetch!(after_, field)} do
      {same, same} -> []
      {old, new} -> item_keys(field, old, new)
    end
  end

  # assignments and dependencies: item → categories (or items), and back
  defp item_keys(field, %Links{} = old, %Links{} = new) when field in [:links, :dependencies] do
    left = differing_keys(old.by_left, new.by_left)

    # a dependency is between two items: the other side changed too
    right = if field == :dependencies, do: differing_keys(old.by_right, new.by_right), else: []
    left ++ right
  end

  # `{item, category}` pairs: a set of them, or a map keyed by them
  defp item_keys(:conditional, old, new) do
    MapSet.symmetric_difference(old, new) |> Enum.map(&elem(&1, 0))
  end

  defp item_keys(field, old, new) when field in [:numbers, :dates] do
    old |> differing_keys(new) |> Enum.map(&elem(&1, 0))
  end

  defp item_keys(:suggestions, old, new), do: differing_keys(old, new)

  defp differing_keys(old, new) do
    keys = Enum.uniq(Map.keys(old) ++ Map.keys(new))
    Enum.filter(keys, &(Map.get(old, &1) != Map.get(new, &1)))
  end

  # every other field of the file whose value differs, such as the order of
  # items or the date format
  defp file_changes(before, after_) do
    for field <- before |> Map.from_struct() |> Map.keys() |> Enum.sort(),
        field not in @objects and field not in @about_items,
        Map.fetch!(before, field) != Map.fetch!(after_, field),
        do: field
  end
end
