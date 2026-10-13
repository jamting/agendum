defmodule Agenda.Core.ViewColumns do
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

  @doc """
  Inserts `column` at `at`. With `:section` only that section gets it, not
  linked. With `:all` every section does, linked under a new link: in
  each other section beside the same column as where it was added (after
  the column to its left, or else before the one to its right), at the
  end when the section has neither.
  """
  @spec add(View.t(), View.at(), Column.t(), :all | :section) :: View.t()
  def add(%View{datebook: %{}} = view, {_sidx, index}, column, _insert_in),
    do: %{view | columns: List.insert_at(view.columns, index, column)}

  def add(%View{} = view, {sidx, index}, column, :section),
    do: put_columns(view, sidx, &List.insert_at(&1, index, %{column | link: nil}))

  def add(%View{} = view, {sidx, index}, column, :all) do
    column = %{column | link: next_link(view)}
    here = View.columns(view, sidx)
    # the columns it goes between; `index - 1` is -1 at the start, and
    # `Enum.at/2` would read -1 from the end, so that case is spelled out
    left = if index > 0, do: Enum.at(here, index - 1)
    right = Enum.at(here, index)

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
  @spec set_head(View.t(), View.at(), Agenda.Core.Category.id()) :: View.t()
  def set_head(%View{} = view, at, cat_id),
    do: update(view, at, &%{&1 | category_id: cat_id})

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

  # The next link number in the view: one more than the highest.
  defp next_link(view) do
    links = for section <- view.sections, c <- section.columns, c.link != nil, do: c.link
    Enum.max(links, fn -> 0 end) + 1
  end

  # Where a column added beside `left` and `right` (the columns it went
  # between where it was added) goes in another section: beside the same
  # column there, that is the one linked to it, or else one of the same
  # head (an unlinked one).
  defp beside(columns, column, left, right) do
    # `a && b` is nil when `a` is nil; only nil and false are falsy, so a
    # found index of 0 still counts below
    after_left = left && same_index(columns, left)
    before_right = right && same_index(columns, right)

    # `cond` takes the first branch whose condition is truthy
    cond do
      after_left -> List.insert_at(columns, after_left + 1, column)
      before_right -> List.insert_at(columns, before_right, column)
      true -> columns ++ [column]
    end
  end

  defp same_index(columns, %Column{link: nil, category_id: head}),
    do: Enum.find_index(columns, &(&1.category_id == head))

  defp same_index(columns, %Column{link: link, category_id: head}) do
    Enum.find_index(columns, &(&1.link == link)) ||
      Enum.find_index(columns, &(&1.category_id == head))
  end

  defp same_settings?(a, b),
    do: {a.category_id, a.width, a.number, a.date} == {b.category_id, b.width, b.number, b.date}
end
