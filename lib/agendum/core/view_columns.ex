# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.ViewColumns do
  @moduledoc """
  Columns per section (R55; User's Guide 3-16, 3-27, 5-22 to 5-25): adding,
  changing and removing a view's columns, section by section or in all
  sections at once.

  A column added to all sections is *linked*: it is one column shown in
  several sections (the columns with the same `link`), so a change to its
  width or format is made in every one of them. A column added to one
  section is not linked, and changes alone. Each column added is a column
  of its own, even with the same head as another: removing or widening
  it leaves the other alone, as in Agenda.

  A column is addressed by `{section index, column index}` (`View.at/0`).
  A datebook view's slots share one set of columns (`view.columns`), so in
  a datebook view the section index does not matter.

  The item column has a place among a section's columns too
  (`ItemColumn.position`, the number of columns left of it; User's Guide
  5-20). A section's *slots* are its columns and its item column (`:items`)
  in the order they are shown (`slots/2`); adding, removing and moving go
  through them, so the item column keeps its place among the columns. A
  datebook view's item column is always first. Pure.
  """

  alias Agendum.Core.View
  alias Agendum.Core.View.{Column, ItemColumn}

  @doc """
  The column at `at` and the columns linked to it, as places: just `[at]`
  for an unlinked column or one in a datebook view.
  """
  @spec linked(View.t(), View.at()) :: [View.at()]
  def linked(%View{datebook: nil} = view, {sidx, index} = at) do
    case view |> View.columns(sidx) |> Enum.at(index) do
      %Column{link: link} when link != nil ->
        # a comprehension over two generators walks every column of every
        # section; the filter after them keeps those of the same link
        for {section, s} <- Enum.with_index(view.sections),
            {column, i} <- Enum.with_index(section.columns),
            column.link == link,
            do: {s, i}

      _ ->
        [at]
    end
  end

  def linked(%View{}, at), do: [at]

  @doc """
  Changes the column at `at` with `fun`, and the columns linked to it, so
  they stay one column (R55).
  """
  @spec update(View.t(), View.at(), (Column.t() -> Column.t())) :: View.t()
  def update(%View{} = view, at, fun) do
    view
    |> linked(at)
    |> Enum.reduce(view, fn place, view -> update_one(view, place, fun) end)
  end

  @typedoc """
  Where a new column goes in its section: a column index (it becomes that
  column; the item column keeps the columns left of it), or right or left
  of the item column (`:items`) or of the column with that index, as
  Agenda's Position says.
  """
  @type place :: non_neg_integer | {:right_of | :left_of, :items | non_neg_integer}

  @doc """
  The section's slots, in the order they are shown: `:items` for the item
  column, and the index of each column.
  """
  @spec slots(View.t(), non_neg_integer) :: [:items | non_neg_integer]
  def slots(%View{} = view, sidx) do
    n = length(View.columns(view, sidx))
    List.insert_at(Enum.to_list(0..(n - 1)//1), items_at(view, sidx), :items)
  end

  @doc "The index a column added at `place` in section `sidx` gets."
  @spec insert_index(View.t(), non_neg_integer, place) :: non_neg_integer
  def insert_index(%View{} = view, sidx, place) do
    # the columns left of the slot it goes into
    slot = slot_for(view, sidx, place)
    view |> slots(sidx) |> Enum.take(slot) |> Enum.count(&(&1 != :items))
  end

  @doc """
  Inserts `column` at `{sidx, place}`. With `:section` only that section
  gets it, not linked. With `:all` every section does, linked under a new
  link: in each other section beside the same column as where it was
  added (after the nearest column to its left, or else before the nearest
  one to its right), at the end when the section has neither.
  """
  @spec add(View.t(), {non_neg_integer, place}, Column.t(), :all | :section) :: View.t()
  def add(%View{datebook: %{}} = view, {sidx, place}, column, _insert_in),
    do: put_slots(view, sidx, &List.insert_at(&1, slot_for(view, sidx, place), column))

  def add(%View{} = view, {sidx, place}, column, :section) do
    slot = slot_for(view, sidx, place)
    put_slots(view, sidx, &List.insert_at(&1, slot, %{column | link: nil}))
  end

  def add(%View{} = view, {sidx, place}, column, :all) do
    column = %{column | link: next_link(view)}
    slot = slot_for(view, sidx, place)
    here = section_slots(view, sidx)
    # the nearest columns it goes between (the item column does not count)
    left = here |> Enum.take(slot) |> Enum.reject(&(&1 == :items)) |> List.last()
    right = here |> Enum.drop(slot) |> Enum.find(&(&1 != :items))

    view.sections
    |> Enum.with_index()
    |> Enum.reduce(view, fn
      {_section, ^sidx}, view -> put_slots(view, sidx, &List.insert_at(&1, slot, column))
      {_section, s}, view -> put_slots(view, s, &beside(&1, column, left, right))
    end)
  end

  # the slot a place means: a column index counts the columns, an anchor
  # is right or left of the item column's or that column's slot
  defp slot_for(view, sidx, index) when is_integer(index) do
    if index < items_at(view, sidx), do: index, else: index + 1
  end

  defp slot_for(view, sidx, {side, anchor}) do
    at = Enum.find_index(slots(view, sidx), &(&1 == anchor)) || 0
    if side == :right_of, do: at + 1, else: at
  end

  @doc """
  Removes the column at `at`: from that section only (`:section`), or with
  the columns linked to it (`:all`, "All sections in view"). Other
  columns of the same head stay.
  """
  @spec remove(View.t(), View.at(), :all | :section) :: View.t()
  def remove(%View{} = view, at, :section), do: remove_places(view, [at])
  def remove(%View{} = view, at, :all), do: remove_places(view, linked(view, at))

  @doc """
  Column Properties ▸ Link with other sections (R55; User's Guide 5-24 to
  5-25). No unlinks the column at `at`: it changes alone from then on.
  Yes links it: to a linked column of its head not yet in its section, if
  there is one, taking its width and formats so they are one column;
  otherwise to the unlinked columns of its head with the same width and
  formats (one in each other section), as Agenda links "columns with the
  same column head, category type, format, and width".
  """
  @spec set_linked(View.t(), View.at(), boolean) :: View.t()
  def set_linked(%View{} = view, at, false), do: update_one(view, at, &%{&1 | link: nil})

  def set_linked(%View{} = view, {sidx, index} = at, true) do
    column = view |> View.columns(sidx) |> Enum.at(index)

    cond do
      column.link != nil -> view
      joined = linked_to_join(view, column, sidx) -> update_one(view, at, fn _ -> joined end)
      true -> link_alike(view, column, at)
    end
  end

  # A linked column of the same head with no column of its link in section
  # `sidx`. (`cond` above binds `joined` and tests it in one go: a match is
  # truthy unless it gives nil.)
  defp linked_to_join(view, column, sidx) do
    here = view |> View.columns(sidx) |> MapSet.new(& &1.link)

    view.sections
    |> Enum.flat_map(& &1.columns)
    |> Enum.find(
      &(&1.link != nil and &1.category_id == column.category_id and &1.link not in here)
    )
  end

  # A new link for the column at `at` and, in each other section, the first
  # unlinked column just like it. A `for` with `reduce:` folds over what it
  # generates, like `Enum.reduce/3`: `view` starts as the value after
  # `reduce:`, each pass returns the next.
  defp link_alike(view, column, {sidx, _} = at) do
    link = next_link(view)

    for {section, s} <- Enum.with_index(view.sections),
        s != sidx,
        i = Enum.find_index(section.columns, &(&1.link == nil and same_settings?(&1, column))),
        i != nil,
        reduce: update_one(view, at, &%{&1 | link: link}) do
      view -> update_one(view, {s, i}, &%{&1 | link: link})
    end
  end

  @doc """
  Column Properties ▸ Column head (R55): the column at `at`, and the
  columns linked to it, show `cat_id` instead. It stays a column of its
  own, even where another column has that head.
  """
  @spec set_head(View.t(), View.at(), Agendum.Core.Category.id()) :: View.t()
  def set_head(%View{} = view, at, cat_id),
    do: update(view, at, &%{&1 | category_id: cat_id})

  @doc """
  View ▸ Column ▸ Move (User's Guide 5-20): what is at slot `from` of
  section `sidx` (a column or the item column, `slots/2`) goes to slot
  `to` (the end, past the last). Only that section changes, even for a
  linked column, as in Agenda; it stays linked. In a datebook view the
  item column stays first.
  """
  @spec move(View.t(), non_neg_integer, non_neg_integer, non_neg_integer) :: View.t()
  def move(%View{} = view, sidx, from, to) do
    put_slots(view, sidx, fn slots ->
      # `List.pop_at/2` gives the element and the list without it
      {moved, rest} = List.pop_at(slots, from)
      List.insert_at(rest, min(to, length(rest)), moved)
    end)
  end

  @doc """
  Item Column Properties (R55): changes the item column of section `sidx`
  with `fun`, and, when it is linked, the linked item columns of the
  other sections too, so they stay one.
  """
  @spec update_items(View.t(), non_neg_integer, (ItemColumn.t() -> ItemColumn.t())) :: View.t()
  def update_items(%View{} = view, sidx, fun) do
    linked = Enum.at(view.sections, sidx).item_column.linked

    sections =
      view.sections
      |> Enum.with_index()
      |> Enum.map(fn {section, i} ->
        if i == sidx or (linked and section.item_column.linked),
          do: %{section | item_column: fun.(section.item_column)},
          else: section
      end)

    %{view | sections: sections}
  end

  @doc """
  Item Column Properties ▸ Link with other sections: No unlinks the item
  column of section `sidx`, which then changes alone; Yes links it again,
  and it takes the settings of the linked ones (if any are left).
  """
  @spec set_items_linked(View.t(), non_neg_integer, boolean) :: View.t()
  def set_items_linked(%View{} = view, sidx, false),
    do: put_items(view, sidx, &%{&1 | linked: false})

  # (its place among its section's columns stays its own)
  def set_items_linked(%View{} = view, sidx, true),
    do: put_items(view, sidx, &%{linked_items(view, sidx) | position: &1.position})

  @doc """
  The item column a section added next to the one at `sidx` starts with:
  the linked ones' settings (a new section is linked), or the defaults
  when no section is linked; placed after as many of the new section's
  columns (`for_new_section/2`) as are left of it in section `sidx`.
  """
  @spec items_for_new_section(View.t(), non_neg_integer) :: ItemColumn.t()
  def items_for_new_section(%View{} = view, sidx) do
    left =
      view
      |> View.columns(sidx)
      |> Enum.take(items_at(view, sidx))
      |> Enum.count(&(&1.link != nil))

    %{linked_items(view, sidx) | position: left}
  end

  # the settings of a linked item column, that of section `sidx` first
  defp linked_items(view, sidx) do
    {here, others} = List.pop_at(view.sections, sidx)
    found = Enum.find([here | others], &(&1 && &1.item_column.linked))
    if found, do: found.item_column, else: %ItemColumn{}
  end

  defp put_items(view, sidx, fun),
    do: %{
      view
      | sections: List.update_at(view.sections, sidx, &%{&1 | item_column: fun.(&1.item_column)})
    }

  @doc "The columns a section added next to the one at `sidx` starts with: its linked ones."
  @spec for_new_section(View.t(), non_neg_integer) :: [Column.t()]
  def for_new_section(%View{} = view, sidx),
    do: view |> View.columns(sidx) |> Enum.filter(&(&1.link != nil))

  # Deleting from the back of each section first, so the earlier indexes
  # still point at the right columns.
  defp remove_places(view, places) do
    places
    |> Enum.sort(:desc)
    |> Enum.reduce(view, fn {sidx, index}, view ->
      slot = slot_for(view, sidx, index)
      put_slots(view, sidx, &List.delete_at(&1, slot))
    end)
  end

  # The item column's slot: after `position` columns (fewer when the
  # section has fewer); first in a datebook view.
  defp items_at(%View{datebook: %{}}, _sidx), do: 0

  defp items_at(%View{} = view, sidx) do
    case Enum.at(view.sections, sidx) do
      nil -> 0
      section -> min(section.item_column.position, length(section.columns))
    end
  end

  # A section's columns with `:items` where the item column is shown.
  defp section_slots(view, sidx),
    do: List.insert_at(View.columns(view, sidx), items_at(view, sidx), :items)

  # Changes a section's slots with `fun`: its columns are the slots left
  # when `:items` is taken out, and the item column's place is where
  # `:items` was. A datebook's shared columns keep their item column first.
  defp put_slots(%View{datebook: %{}} = view, sidx, fun) do
    columns = view |> section_slots(sidx) |> fun.() |> Enum.reject(&(&1 == :items))
    %{view | columns: columns}
  end

  defp put_slots(%View{} = view, sidx, fun) do
    slots = fun.(section_slots(view, sidx))
    position = Enum.find_index(slots, &(&1 == :items))
    columns = Enum.reject(slots, &(&1 == :items))

    put_items(
      %{view | sections: List.update_at(view.sections, sidx, &%{&1 | columns: columns})},
      sidx,
      &%{&1 | position: position}
    )
  end

  defp update_one(view, {sidx, index}, fun),
    do: put_columns(view, sidx, &List.update_at(&1, index, fun))

  # Changes one section's columns, or a datebook's shared ones.
  defp put_columns(%View{datebook: %{}} = view, _sidx, fun),
    do: %{view | columns: fun.(view.columns)}

  defp put_columns(%View{} = view, sidx, fun) do
    %{view | sections: List.update_at(view.sections, sidx, &%{&1 | columns: fun.(&1.columns)})}
  end

  # The next link number in the view: one more than the highest.
  defp next_link(view) do
    links = for section <- view.sections, c <- section.columns, c.link != nil, do: c.link
    Enum.max(links, fn -> 0 end) + 1
  end

  # Where a column added beside `left` and `right` (the columns it went
  # between where it was added) goes in another section's slots: beside
  # the same column there, that is the one linked to it, or else one of the
  # same head (an unlinked one); at the end when there is neither.
  defp beside(slots, column, left, right) do
    # `a && b` is nil when `a` is nil; only nil and false are falsy, so a
    # found index of 0 still counts below
    after_left = left && same_index(slots, left)
    before_right = right && same_index(slots, right)

    # `cond` takes the first branch whose condition is truthy
    cond do
      after_left -> List.insert_at(slots, after_left + 1, column)
      before_right -> List.insert_at(slots, before_right, column)
      true -> slots ++ [column]
    end
  end

  # (the slots' `:items` is no column, so `match?/2` keeps it out)
  defp same_index(slots, %Column{link: nil, category_id: head}),
    do: Enum.find_index(slots, &match?(%Column{category_id: ^head}, &1))

  defp same_index(slots, %Column{link: link, category_id: head}) do
    Enum.find_index(slots, &match?(%Column{link: ^link}, &1)) ||
      Enum.find_index(slots, &match?(%Column{category_id: ^head}, &1))
  end

  defp same_settings?(a, b),
    do: {a.category_id, a.width, a.number, a.date} == {b.category_id, b.width, b.number, b.date}
end
