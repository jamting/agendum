defmodule Agenda.Core.ViewColumns do
  @moduledoc """
  Columns per section (R55; User's Guide 3-16, 3-27, 5-22 to 5-25): adding,
  changing and removing a view's columns, section by section or in all
  sections at once.

  A column added to all sections is *linked*: the linked columns of a view
  with the same head are one column shown in several sections, so a
  change to its width or format is made to every one of them. A column
  added to one section is not linked, and changes alone.

  A column is addressed by `{section index, column index}` (`View.at/0`).
  A datebook view's slots share one set of columns (`view.columns`), so in
  a datebook view the section index does not matter. Pure.
  """

  alias Agenda.Core.View
  alias Agenda.Core.View.Column

  @doc """
  The column at `at` and the columns linked to it, as places: just `[at]`
  for an unlinked column or one in a datebook view.
  """
  @spec linked(View.t(), View.at()) :: [View.at()]
  def linked(%View{datebook: nil} = view, {sidx, index} = at) do
    case view |> View.columns(sidx) |> Enum.at(index) do
      %Column{linked: true, category_id: head} ->
        # a comprehension over two generators walks every column of every
        # section; the filters after them keep the linked ones of that head
        for {section, s} <- Enum.with_index(view.sections),
            {column, i} <- Enum.with_index(section.columns),
            column.linked and column.category_id == head,
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

  @doc """
  Inserts `column` at `at`. With `:section` only that section gets it, not
  linked. With `:all` every section does, linked: in each other section
  beside the same column as where it was added (after the column to its
  left, or else before the one to its right), at the end when the
  section has neither. If the view already has linked columns of that
  head, the new one takes their width and formats, as it joins them.
  """
  @spec add(View.t(), View.at(), Column.t(), :all | :section) :: View.t()
  def add(%View{datebook: %{}} = view, {_sidx, index}, column, _insert_in),
    do: %{view | columns: List.insert_at(view.columns, index, column)}

  def add(%View{} = view, {sidx, index}, column, :section),
    do: put_columns(view, sidx, &List.insert_at(&1, index, %{column | linked: false}))

  def add(%View{} = view, {sidx, index}, column, :all) do
    column = like_linked(view, %{column | linked: true})
    here = View.columns(view, sidx)
    # the heads it goes between; `index - 1` is -1 at the start, and
    # `Enum.at/2` would read -1 from the end, so that case is spelled out
    left = if index > 0, do: head_at(here, index - 1)
    right = head_at(here, index)

    sections =
      view.sections
      |> Enum.with_index()
      |> Enum.map(fn
        {section, ^sidx} ->
          %{section | columns: List.insert_at(section.columns, index, column)}

        {section, _} ->
          %{section | columns: beside(section.columns, column, left, right)}
      end)

    %{view | sections: sections}
  end

  @doc """
  Removes the column at `at`: from that section only (`:section`), or with
  the columns linked to it (`:all`, "All sections in view").
  """
  @spec remove(View.t(), View.at(), :all | :section) :: View.t()
  def remove(%View{} = view, at, :section), do: remove_places(view, [at])
  def remove(%View{} = view, at, :all), do: remove_places(view, linked(view, at))

  @doc "The columns a section added next to the one at `sidx` starts with: its linked ones."
  @spec for_new_section(View.t(), non_neg_integer) :: [Column.t()]
  def for_new_section(%View{} = view, sidx),
    do: view |> View.columns(sidx) |> Enum.filter(& &1.linked)

  # Deleting from the back of each section first, so the earlier indexes
  # still point at the right columns.
  defp remove_places(view, places) do
    places
    |> Enum.sort(:desc)
    |> Enum.reduce(view, fn {sidx, index}, view ->
      put_columns(view, sidx, &List.delete_at(&1, index))
    end)
  end

  defp update_one(view, {sidx, index}, fun),
    do: put_columns(view, sidx, &List.update_at(&1, index, fun))

  # Changes one section's columns, or a datebook's shared ones.
  defp put_columns(%View{datebook: %{}} = view, _sidx, fun),
    do: %{view | columns: fun.(view.columns)}

  defp put_columns(%View{} = view, sidx, fun) do
    %{view | sections: List.update_at(view.sections, sidx, &%{&1 | columns: fun.(&1.columns)})}
  end

  defp head_at(columns, index) do
    case Enum.at(columns, index) do
      nil -> nil
      column -> column.category_id
    end
  end

  defp beside(columns, column, left, right) do
    heads = Enum.map(columns, & &1.category_id)
    # `a && b` is nil when `a` is nil; only nil and false are falsy, so a
    # found index of 0 still counts below
    after_left = left && Enum.find_index(heads, &(&1 == left))
    before_right = right && Enum.find_index(heads, &(&1 == right))

    # `cond` takes the first branch whose condition is truthy
    cond do
      after_left -> List.insert_at(columns, after_left + 1, column)
      before_right -> List.insert_at(columns, before_right, column)
      true -> columns ++ [column]
    end
  end

  # A column joining linked columns of its head takes their settings, so
  # all of them stay one column.
  defp like_linked(view, column) do
    twin =
      Enum.find_value(view.sections, fn section ->
        Enum.find(section.columns, &(&1.linked and &1.category_id == column.category_id))
      end)

    case twin do
      nil -> column
      twin -> %{column | width: twin.width, number: twin.number, date: twin.date}
    end
  end
end
