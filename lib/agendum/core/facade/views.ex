# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Facade.Views do
  @moduledoc """
  Views (R20–R28, R36, R37, R47–R49): adding and changing views,
  datebooks, sections and columns, filters and sorting, what a new item
  typed into a section gets, and the Show View (Show Match, Show Sched).

  Called through `Agendum.Core`.
  """

  alias Agendum.Core.{Assign, Database, Datebook, NumberFormat, RangeFilter, View, ViewColumns}
  alias Agendum.Core.ViewModel
  alias Agendum.Core.Facade.{Assignments, Categories, Dates, Numbers}
  # `View.Column` and `View.Section` are nested modules; nesting is only a
  # naming convention, so they are aliased like any other module.
  alias Agendum.Core.View.{Column, ItemColumn, Section}

  @typep db :: Agendum.Core.db()
  @typep id :: Agendum.Core.id()
  @typep clock :: Agendum.Core.clock()

  # Agenda's name for its Show view; files from before 0.50 have the old one
  @show_view "*Show View*"
  @old_show_view "Show View"
  # the widest a fitted column gets (R22a)
  @fit_room 80
  # the widest item column: Agenda's 77 was the screen; terminals are wider
  @item_room 200

  @doc """
  Adds a datebook view (R47). Its settings default to Agenda's: When as the
  date category and section head, a week from today. Fails unless the date
  and end categories are date categories.
  """
  @spec add_datebook_view(db, String.t(), Datebook.t()) ::
          {:ok, db, id} | {:error, :not_a_date_category}
  def add_datebook_view(db, name, %Datebook{} = datebook) do
    with {:ok, datebook} <- check_datebook(db, datebook) do
      {db, id} = Database.insert_view(db, String.trim(name))
      {:ok, Database.update_view(db, id, &%{&1 | datebook: datebook}), id}
    end
  end

  @doc "Changes a datebook view's settings (R47), checked as when it was added."
  @spec set_datebook(db, id, Datebook.t()) :: {:ok, db} | {:error, :not_a_date_category}
  def set_datebook(db, view_id, %Datebook{} = datebook) do
    with {:ok, datebook} <- check_datebook(db, datebook),
         do: {:ok, Database.update_view(db, view_id, &%{&1 | datebook: datebook})}
  end

  defp check_datebook(db, d) do
    date_cat = d.date_category || db.special.when
    # `d` is rebound to a copy with the defaults filled in; the caller's
    # struct is untouched
    d = %{d | date_category: date_cat, section_category: d.section_category || date_cat}

    if Database.date_category?(db, date_cat) and
         (d.end_category == nil or Database.date_category?(db, d.end_category)) and
         Map.has_key?(db.categories, d.section_category),
       do: {:ok, d},
       else: {:error, :not_a_date_category}
  end

  @spec add_view(db, String.t(), [id]) :: {db, id}
  def add_view(db, name, section_ids),
    do: Database.insert_view(db, String.trim(name), sections: section_ids)

  @spec rename_view(db, id, String.t()) :: db
  def rename_view(db, view_id, name),
    do: Database.update_view(db, view_id, &%{&1 | name: String.trim(name)})

  defdelegate discard_view(db, view_id), to: Database, as: :delete_view

  @doc "Moves a view to position `index` in the view manager (clamped)."
  @spec move_view(db, id, integer) :: db
  def move_view(db, view_id, index) do
    rest = List.delete(db.view_order, view_id)
    index = index |> max(0) |> min(length(rest))
    %{db | view_order: List.insert_at(rest, index, view_id)}
  end

  @doc """
  Moves the section at `from` to place `to` (kept within the view), with
  its columns, filter and sort (R62; User's Guide 5-8): in this view only,
  the category hierarchy unchanged. The order is the one shown when the
  view does not sort its sections.
  """
  @spec move_section(db, id, non_neg_integer, integer) :: db
  def move_section(db, view_id, from, to) do
    Database.update_view(db, view_id, fn view ->
      {section, rest} = List.pop_at(view.sections, from)
      %{view | sections: List.insert_at(rest, to |> max(0) |> min(length(rest)), section)}
    end)
  end

  @doc "Changes the category heading the section at `index`."
  @spec set_section_category(db, id, non_neg_integer, id) :: db
  def set_section_category(db, view_id, index, cat_id) do
    Database.update_view(db, view_id, fn v ->
      # Updating something nested means rebuilding the path to it: a new
      # view with a new sections list holding one new section.
      # (`update_in/2` with an `Access` path, e.g. `Access.at(index)`, can
      # do it in one call; the code here spells it out.)
      %{v | sections: List.update_at(v.sections, index, &%{&1 | category_id: cat_id})}
    end)
  end

  @doc """
  Inserts a section headed by `cat_id` at `index` in the view. It gets the
  linked columns of the section at `from` (R55), the one the user was in;
  by default the one above where it goes, or the first.
  """
  @spec add_section(db, id, id, non_neg_integer, non_neg_integer | nil) :: db
  def add_section(db, view_id, cat_id, index, from \\ nil) do
    # an anonymous function can pattern match its argument like a `def`
    Database.update_view(db, view_id, fn %View{} = v ->
      from = from || max(index - 1, 0)
      columns = ViewColumns.for_new_section(v, from)
      items = ViewColumns.items_for_new_section(v, from)
      section = %Section{category_id: cat_id, columns: columns, item_column: items}
      %{v | sections: List.insert_at(v.sections, index, section)}
    end)
  end

  @doc """
  Agenda's rule for a category just inserted in a family (User's Guide
  16-11, R42; checked in Agenda 2.0, 2026-10-27): a view whose sections
  hold every other child of its parent (at least one) gets a section for
  it too, right after the section of its previous sibling, or at the top
  of the view when it is the first child, with the linked columns, those
  every section has (R55). Other sections in the view, or another order,
  do not matter. Not a datebook view, whose sections are its dates (R47).
  """
  @spec add_family_sections(db, id) :: db
  def add_family_sections(db, cat_id) do
    siblings = db.categories[db.categories[cat_id].parent_id].children
    others = List.delete(siblings, cat_id)
    # the sibling just before it in the hierarchy, nil for a first child
    previous = siblings |> Enum.take_while(&(&1 != cat_id)) |> List.last()

    Enum.reduce(Database.views(db), db, fn view, db ->
      if family_view?(view, cat_id, others),
        do: add_family_section(db, view, cat_id, previous),
        else: db
    end)
  end

  defp family_view?(view, cat_id, others) do
    heads = Enum.map(view.sections, & &1.category_id)

    view.datebook == nil and others != [] and cat_id not in heads and
      Enum.all?(others, &(&1 in heads))
  end

  # the first child goes to the top, the columns from the section it is
  # put above; any other right after its previous sibling's section
  defp add_family_section(db, view, cat_id, nil), do: add_section(db, view.id, cat_id, 0, 0)

  defp add_family_section(db, view, cat_id, previous) do
    at = Enum.find_index(view.sections, &(&1.category_id == previous))
    add_section(db, view.id, cat_id, at + 1, at)
  end

  @spec remove_section(db, id, non_neg_integer) :: db
  def remove_section(db, view_id, index) do
    Database.update_view(db, view_id, &%{&1 | sections: List.delete_at(&1.sections, index)})
  end

  @doc "Collapses (true) or expands (false) the section at `index`."
  @spec set_section_collapsed(db, id, non_neg_integer, boolean) :: db
  def set_section_collapsed(db, view_id, index, collapsed) do
    Database.update_view(db, view_id, fn v ->
      %{v | sections: List.update_at(v.sections, index, &%{&1 | collapsed: collapsed})}
    end)
  end

  @doc "Collapses or expands every section of a view."
  @spec set_all_sections_collapsed(db, id, boolean) :: db
  def set_all_sections_collapsed(db, view_id, collapsed) do
    Database.update_view(db, view_id, fn v ->
      %{v | sections: Enum.map(v.sections, &%{&1 | collapsed: collapsed})}
    end)
  end

  @spec toggle_section_collapsed(db, id, non_neg_integer) :: db
  def toggle_section_collapsed(db, view_id, index) do
    Database.update_view(db, view_id, fn v ->
      %{v | sections: List.update_at(v.sections, index, &%{&1 | collapsed: not &1.collapsed})}
    end)
  end

  @doc """
  Inserts a column headed by `cat_id` at `at` (`{section, place}`: a
  column index, or right or left of the item column or a column,
  `t:Agendum.Core.ViewColumns.place/0`): in
  all sections, linked, or in that section only (`insert_in`, R55; see
  `Agendum.Core.ViewColumns.add/4` for where the other sections get it).
  Without `insert_in` the file's Insert new columns in decides
  (`set_insert_columns/2`); without `width` it is 16 for a date category,
  room for a date and a time, and 12 for others.
  """
  @spec add_column(
          db,
          id,
          id,
          {non_neg_integer, ViewColumns.place()},
          pos_integer | nil,
          :all | :section | nil
        ) :: db
  def add_column(db, view_id, cat_id, at, width \\ nil, insert_in \\ nil) do
    # `||` gives its right side when the left is nil (or false)
    width = width || default_column_width(db, cat_id)
    insert_column(db, view_id, %Column{category_id: cat_id, width: width}, at, insert_in)
  end

  defp insert_column(db, view_id, column, at, insert_in) do
    insert_in = insert_in || db.insert_columns
    Database.update_view(db, view_id, &ViewColumns.add(&1, at, column, insert_in))
  end

  @doc """
  Column Add with a Category type (User's Guide 3-17): a standard
  `cat_id` is first made a date or numeric category (`kind`; see
  `Agendum.Core.Facade.Dates.make_date/3` and
  `Agendum.Core.Facade.Numbers.make_numeric/3` for what becomes of its
  children and items), then added as `add_column/6` does, so the whole is
  one change. A category already of `kind` is just added; a date or
  numeric one cannot change type (`{:error, :not_standard}`), as in
  Agenda. Options: `width:`, `insert_in:`, and `clock:` for reading
  children as dates.
  """
  @spec add_column_as(
          db,
          id,
          id,
          Agendum.Core.Category.kind(),
          {non_neg_integer, ViewColumns.place()},
          keyword
        ) :: {:ok, db} | {:error, :not_standard | :protected | :too_deep}
  def add_column_as(db, view_id, cat_id, kind, at, opts \\ []) do
    clock = Keyword.get(opts, :clock)

    converted =
      case {db.categories[cat_id].kind, kind} do
        {same, same} -> {:ok, db}
        {:standard, :date} -> Dates.make_date(db, cat_id, clock)
        {:standard, :numeric} -> Numbers.make_numeric(db, cat_id, clock)
        {:standard, :unindexed} -> Agendum.Core.Facade.Texts.make_unindexed(db, cat_id, clock)
        _ -> {:error, :not_standard}
      end

    # `with` goes on while each clause matches; an error falls through as it is
    with {:ok, db} <- converted do
      # a Format is for standard columns only (R56)
      format = if kind == :standard, do: Keyword.get(opts, :format, :name), else: :name

      column = %Column{
        category_id: cat_id,
        width: opts[:width] || default_column_width(db, cat_id, kind, format),
        format: format,
        note_line: opts |> Keyword.get(:note_line, 1) |> max(1) |> min(999),
        title: column_title(opts[:title])
      }

      {:ok, insert_column(db, view_id, column, at, opts[:insert_in])}
    end
  end

  @doc """
  The width a new column headed by `cat_id` gets unless told otherwise:
  16 for a date category, room for a date and a time, and 12 for others
  (also without a head yet, as in the Column Add box). With `kind`, the
  width for a head about to become that type (Column Add ▸ Category type),
  and for a standard one in `format`: 2 for Star and Yes/No (R56).
  """
  @spec default_column_width(
          db,
          id | nil,
          Agendum.Core.Category.kind() | nil,
          Column.format()
        ) :: pos_integer
  def default_column_width(db, cat_id, kind \\ nil, format \\ :name)
  def default_column_width(_db, _cat_id, :date, _format), do: 16
  def default_column_width(_db, _cat_id, :numeric, _format), do: 12
  def default_column_width(_db, _cat_id, :unindexed, _format), do: 12
  # a Star or Yes/No column is two wide (User's Guide 5-31, 5-33)
  def default_column_width(_db, _cat_id, :standard, format) when format in [:star, :yes_no], do: 2
  # a Zettel id is eight letters (R73a)
  def default_column_width(_db, _cat_id, :standard, :zettel), do: 9
  def default_column_width(_db, _cat_id, :standard, _format), do: 12

  def default_column_width(db, cat_id, nil, _format) do
    if cat_id && Database.date_category?(db, cat_id), do: 16, else: 12
  end

  @doc """
  Column Properties ▸ Column head (R55): the column at `at` and the columns
  linked to it show `cat_id` instead (`Agendum.Core.ViewColumns.set_head/3`).
  """
  @spec set_column_head(db, id, View.at(), id) :: db
  def set_column_head(db, view_id, at, cat_id) do
    db = Database.update_view(db, view_id, &ViewColumns.set_head(&1, at, cat_id))

    # "% tot" is for numbers only: a column given another head drops it
    if db.categories[cat_id].kind == :numeric,
      do: db,
      else: update_column(db, view_id, at, &%{&1 | number: %{&1.number | percent: false}})
  end

  @doc """
  Column Properties ▸ Link with other sections (R55): `false` unlinks the
  column at `at`, `true` links it (`Agendum.Core.ViewColumns.set_linked/3`).
  """
  @spec set_column_linked(db, id, View.at(), boolean) :: db
  def set_column_linked(db, view_id, at, linked) when is_boolean(linked),
    do: Database.update_view(db, view_id, &ViewColumns.set_linked(&1, at, linked))

  @doc """
  File Properties ▸ Insert new columns in (R55): whether a column added
  without saying where goes into all sections (`:all`, Agenda's default)
  or only the one it is added in (`:section`).
  """
  @spec set_insert_columns(db, :all | :section) :: db
  def set_insert_columns(db, where) when where in [:all, :section],
    do: %{db | insert_columns: where}

  @doc """
  Removes the column at `at` from all sections, with the columns linked to
  it (`:all`), or from its section only (`:section`, R55).
  """
  @spec remove_column(db, id, View.at(), :all | :section) :: db
  def remove_column(db, view_id, at, from \\ :all),
    do: Database.update_view(db, view_id, &ViewColumns.remove(&1, at, from))

  @doc """
  Item Column Properties (R55): sets the item column of section `sidx`
  (and the linked ones, `Agendum.Core.ViewColumns.update_items/3`):
  `set: :auto | :manual`, `width:` and `minimum:`, each width kept
  between 5 and #{@item_room}.
  """
  @spec set_item_column(db, id, non_neg_integer, keyword) :: db
  def set_item_column(db, view_id, sidx, changes) do
    changes =
      Map.new(changes, fn
        {key, n} when key in [:width, :minimum] -> {key, n |> max(5) |> min(@item_room)}
        {:set, set} when set in [:auto, :manual] -> {:set, set}
      end)

    Database.update_view(
      db,
      view_id,
      &ViewColumns.update_items(&1, sidx, fn c -> Map.merge(c, changes) end)
    )
  end

  @doc """
  View ▸ Column ▸ Width, SHIFT-? on the item text (R55): the width that
  fits the item column of section `sidx`: its longest item text or section
  name, in it and the sections its item column is linked with (collapsed
  ones left out), at least 5 and at most what its columns leave on a
  screen `screen` wide. Only worked out; `set_item_column/4` sets it.
  """
  @spec item_column_fit(db, id, non_neg_integer, clock, pos_integer) :: pos_integer
  def item_column_fit(db, view_id, sidx, clock, screen) do
    view = db.views[view_id]
    here = Enum.at(view.sections, sidx)

    # the stored sections whose item column is this one: itself, and the
    # linked ones when it is linked
    together =
      for {section, i} <- Enum.with_index(view.sections),
          i == sidx or (here.item_column.linked and section.item_column.linked),
          into: MapSet.new(),
          do: i

    texts =
      for section <- ViewModel.build(db, view, clock),
          section.index in together,
          text <- [section.category.name | collapsed_or(section, & &1.item.text)],
          do: text

    room = ItemColumn.text_width(%ItemColumn{minimum: 5}, here.columns, screen)

    texts
    |> Enum.map(&String.length/1)
    |> Enum.max(fn -> 5 end)
    |> max(5)
    |> min(room)
  end

  # a collapsed section's items are not shown, so they do not count
  defp collapsed_or(%{collapsed: true}, _fun), do: []
  defp collapsed_or(section, fun), do: Enum.map(section.rows, fun)

  @doc """
  Item Column Properties ▸ Link with other sections: `false` unlinks the
  item column of section `sidx`, `true` links it, taking the linked ones'
  settings (`Agendum.Core.ViewColumns.set_items_linked/3`).
  """
  @spec set_item_column_linked(db, id, non_neg_integer, boolean) :: db
  def set_item_column_linked(db, view_id, sidx, linked) when is_boolean(linked),
    do: Database.update_view(db, view_id, &ViewColumns.set_items_linked(&1, sidx, linked))

  @doc """
  View ▸ Column ▸ Move: what is at slot `from` of section `sidx` (a column
  or the item column, `Agendum.Core.ViewColumns.slots/2`) goes to slot `to`,
  in that section only (`Agendum.Core.ViewColumns.move/4`).
  """
  @spec move_column(db, id, non_neg_integer, non_neg_integer, non_neg_integer) :: db
  def move_column(db, view_id, sidx, from, to),
    do: Database.update_view(db, view_id, &ViewColumns.move(&1, sidx, from, to))

  @doc """
  Column Properties ▸ Format of a standard column (User's Guide 5-26 to
  5-37; `View.Column`), in the column at `at` and those linked to it:
  `format:` (`View.Column.formats/0`), `note_line:` (1 to 999) and
  `title:` (at most 69 characters; blank for none) for Category note.
  """
  @spec set_column_display(db, id, View.at(), keyword) :: db
  def set_column_display(db, view_id, at, changes) do
    changes =
      Map.new(changes, fn
        {:format, format} -> {:format, format}
        {:note_line, n} -> {:note_line, n |> max(1) |> min(999)}
        {:title, title} -> {:title, column_title(title)}
      end)

    update_column(db, view_id, at, &Map.merge(&1, changes))
  end

  @doc """
  SPACE in a Star column, Y or N in a Yes/No column (User's Guide 5-31 to
  5-34): `true` assigns the item to the column head itself, unless it is
  in it already (directly or through a descendant); `false` takes it out
  of the head and of every category under it, so the column shows it as
  not in.
  """
  @spec set_in_column(db, id, id, boolean, clock) :: db
  def set_in_column(db, item_id, head_id, true, clock) do
    if Database.member?(db, item_id, head_id),
      do: db,
      else: Assignments.assign(db, item_id, head_id, clock)
  end

  def set_in_column(db, item_id, head_id, false, clock) do
    db
    |> Database.subtree(head_id)
    |> Enum.filter(&Database.explicit?(db, item_id, &1))
    |> Enum.reduce(db, &Assignments.remove_from_category(&2, item_id, &1, clock))
  end

  @doc """
  Typing in a Category note column (User's Guide 5-37: "Agenda puts it in
  the correct line of the category note"): line `n` of the note of the
  category the item has in the column headed by `head_id` (the first, if
  several) becomes `text`, after the label the line had ("Telephone:
  555-9999"); missing lines are added empty. An item with no category in
  the column has no note to write: `{:error, :no_category}`.
  """
  @spec set_column_note(db, id, id, pos_integer, String.t()) :: {:ok, db} | {:error, :no_category}
  def set_column_note(db, item_id, head_id, n, text) do
    case ViewModel.column_entries(db, item_id, head_id) do
      [] ->
        {:error, :no_category}

      [cat_id | _] ->
        lines = String.split(db.categories[cat_id].note, "\n")
        # as many lines as line `n` needs (`max/2` with 0 when there are more)
        lines = lines ++ List.duplicate("", max(n - length(lines), 0))
        lines = List.update_at(lines, n - 1, &with_label(&1, String.trim(text)))

        {:ok,
         Categories.set_category_note(
           db,
           cat_id,
           lines |> Enum.join("\n") |> String.trim_trailing()
         )}
    end
  end

  # the line's label (up to its colon), kept before the new text
  defp with_label(line, text) do
    case String.split(line, ":", parts: 2) do
      [label, _value] -> String.trim_trailing(label <> ": " <> text)
      [_text] -> text
    end
  end

  defp column_title(nil), do: nil

  defp column_title(title) do
    case String.trim(title) do
      "" -> nil
      title -> String.slice(title, 0, 69)
    end
  end

  @doc "Sets how a numeric column shows its numbers and calculations (R29)."
  @spec set_column_format(db, id, View.at(), NumberFormat.t()) :: db
  def set_column_format(db, view_id, at, %NumberFormat{} = format),
    do: update_column(db, view_id, at, &%{&1 | number: format})

  @doc """
  Select numeric functions (R61, R29; User's Guide 8-10): gives every
  numeric column of section `sidx` the calculations `calcs`, in Agenda's
  order, as one change. They are the columns' own settings, so a linked
  column changes in its other sections too.
  """
  @spec set_section_calcs(db, id, non_neg_integer, [NumberFormat.calc()]) :: db
  def set_section_calcs(db, view_id, sidx, calcs) do
    calcs = Enum.filter(NumberFormat.calcs(), &(&1 in calcs))

    db
    |> numeric_columns(view_id, sidx)
    |> Enum.reduce(db, fn index, db ->
      update_column(db, view_id, {sidx, index}, &put_in(&1.number.calcs, calcs))
    end)
  end

  @doc """
  View Properties ▸ View statistics (R78; Help "View Statistics Box"): how
  many marked items the view shows, how many sections it has (empty ones
  too) and how many items its sections show, an item in two sections
  counted in each, as the view shows it twice.
  """
  @spec view_statistics(db, id, clock) :: %{
          marked: non_neg_integer,
          sections: non_neg_integer,
          items: non_neg_integer
        }
  def view_statistics(db, view_id, clock) do
    view = db.views[view_id]
    # every row the view shows, section after section
    rows = db |> ViewModel.build(view, clock) |> Enum.flat_map(& &1.rows)
    marked = rows |> Enum.filter(& &1.item.marked) |> Enum.uniq_by(& &1.item.id)
    %{marked: length(marked), sections: length(view.sections), items: length(rows)}
  end

  @doc """
  The calculations section `sidx` shows for all its numeric columns: those
  every one of them has; nil when it has no numeric column.
  """
  @spec section_calcs(db, id, non_neg_integer) :: [NumberFormat.calc()] | nil
  def section_calcs(db, view_id, sidx) do
    columns = View.columns(db.views[view_id], sidx)

    case numeric_columns(db, view_id, sidx) do
      [] ->
        nil

      indexes ->
        Enum.filter(NumberFormat.calcs(), fn calc ->
          Enum.all?(indexes, &(calc in Enum.at(columns, &1).number.calcs))
        end)
    end
  end

  # the indexes of the section's columns headed by a numeric category
  defp numeric_columns(db, view_id, sidx) do
    for {column, index} <- Enum.with_index(View.columns(db.views[view_id], sidx)),
        db.categories[column.category_id].kind == :numeric,
        do: index
  end

  @doc """
  Gives a date column its own display format, or `nil` to use the file's
  again (Global defaults, R41a).
  """
  @spec set_column_date_format(db, id, View.at(), Agendum.Core.DateFormat.t() | nil) :: db
  def set_column_date_format(db, view_id, at, format),
    do: update_column(db, view_id, at, &%{&1 | date: format})

  @doc """
  View ▸ Column ▸ Width: the column at `at` and the columns linked to it
  become `width` wide, at least 1 (Agenda's least, for a Star or Yes/No
  column) and at most #{@fit_room}.
  """
  @spec set_column_width(db, id, View.at(), integer) :: db
  def set_column_width(db, view_id, at, width),
    do: update_column(db, view_id, at, &%{&1 | width: width |> max(1) |> min(@fit_room)})

  @spec resize_column(db, id, View.at(), integer) :: db
  def resize_column(db, view_id, at, delta),
    do: update_column(db, view_id, at, &%{&1 | width: max(3, &1.width + delta)})

  @doc """
  Fits a column to its contents (R22a): its width becomes that of the
  widest of its head and the entries of the items the view shows now
  (collapsed sections left out), full names rather than short ones, and
  its calculation lines; at least 3, at most #{@fit_room}. A linked column
  fits the entries of every section it is in (R55). Done once: the width
  does not follow later changes.
  """
  # (`#{@fit_room}` above: a `@doc` is a normal string, so it can
  # interpolate a module attribute, evaluated at compile time.)
  @spec fit_column(db, id, View.at(), clock) :: db
  def fit_column(db, view_id, {sidx, index} = at, clock) do
    view = db.views[view_id]
    column = view |> View.columns(sidx) |> Enum.at(index)
    places = ViewColumns.linked(view, at)
    # as wide as anything could be, so every entry shows its full names
    roomy = ViewColumns.update(view, at, &%{&1 | width: @fit_room})

    entries =
      for section <- ViewModel.build(db, roomy, clock),
          not section.collapsed,
          # which of this section's columns it is: a datebook slot has no
          # index of its own and shares the view's columns
          i <- column_indexes(section, places, index),
          # `& &1.cells` is `fn row -> row.cells end`; `elem(t, 1)` reads a
          # tuple's second element (tuples are zero-indexed)
          cells <- Enum.map(section.rows, & &1.cells) ++ Enum.map(section.calcs, &elem(&1, 1)),
          do: cells |> Enum.at(i) |> String.trim()

    width =
      [db.categories[column.category_id].name | entries]
      |> Enum.map(&String.length/1)
      |> Enum.max()
      |> max(3)
      |> min(@fit_room)

    update_column(db, view_id, at, &%{&1 | width: width})
  end

  defp column_indexes(%{index: nil}, _places, index), do: [index]

  defp column_indexes(%{index: sidx}, places, _index),
    do: for({^sidx, i} <- places, do: i)

  # A change to a column is made to the columns linked to it too (R55).
  defp update_column(db, view_id, at, fun),
    do: Database.update_view(db, view_id, &ViewColumns.update(&1, at, fun))

  # --- filters (R28) and sorting (R36) ---

  @doc """
  Cycles the filter on `cat_id` for a view (`:view`) or one of its sections
  (`{:section, index}`): none → assigned → not assigned → none. A filtered
  view shows only items meeting all its criteria (mutually exclusive
  categories count as alternatives).
  """
  @spec cycle_filter(db, id, :view | {:section, non_neg_integer}, id) :: {:ok, db}
  def cycle_filter(db, view_id, scope, cat_id) do
    filter = get_scoped(db, view_id, scope, :filter)

    filter =
      case List.keyfind(filter, cat_id, 0) do
        nil -> filter ++ [{cat_id, :assigned}]
        {_, :assigned} -> List.keyreplace(filter, cat_id, 0, {cat_id, :not_assigned})
        {_, :not_assigned} -> List.keydelete(filter, cat_id, 0)
      end

    {:ok, put_scoped(db, view_id, scope, :filter, filter)}
  end

  @doc """
  Sets the filter on a date or numeric category (R28a): `{:assigned, from,
  to, :inside | :outside}` shows items with a date or number in (or outside)
  the range, or any date or number when `from` and `to` are blank;
  `{:not_assigned, _, _, _}` shows items without one. Dates may be relative
  ("monday"); they are checked against `today` here and read again whenever
  the view is shown.
  """
  @spec set_range_filter(
          db,
          id,
          :view | {:section, non_neg_integer},
          id,
          {:assigned | :not_assigned, String.t() | nil, String.t() | nil, :inside | :outside},
          clock
        ) :: {:ok, db} | {:error, :not_a_range_category | :invalid_date | :not_a_number}
  def set_range_filter(db, view_id, scope, cat_id, {show, from, to, where}, today) do
    cond do
      not RangeFilter.range_category?(db, cat_id) ->
        {:error, :not_a_range_category}

      show == :not_assigned ->
        {:ok, put_filter(db, view_id, scope, cat_id, :not_assigned)}

      true ->
        with {:ok, range} <- RangeFilter.build(db, cat_id, from, to, where, today) do
          term = if match?({:range, nil, nil, _}, range), do: :assigned, else: range
          {:ok, put_filter(db, view_id, scope, cat_id, term)}
        end
    end
  end

  @doc "Removes a category from a view's or section's filter."
  @spec remove_filter(db, id, :view | {:section, non_neg_integer}, id) :: db
  def remove_filter(db, view_id, scope, cat_id) do
    filter = db |> get_scoped(view_id, scope, :filter) |> List.keydelete(cat_id, 0)
    put_scoped(db, view_id, scope, :filter, filter)
  end

  defp put_filter(db, view_id, scope, cat_id, term) do
    filter = get_scoped(db, view_id, scope, :filter)

    filter =
      if List.keymember?(filter, cat_id, 0),
        do: List.keyreplace(filter, cat_id, 0, {cat_id, term}),
        else: filter ++ [{cat_id, term}]

    put_scoped(db, view_id, scope, :filter, filter)
  end

  @doc """
  The dates and numbers a new item typed into section `index` gets from
  the date and numeric filters (R28a; see `RangeFilter.entry_value/4`).
  """
  @spec entry_values(db, id, non_neg_integer, clock) ::
          [{id, {:date, Date.t()} | {:number, float}}]
  def entry_values(db, view_id, index, today) do
    view = Database.view(db, view_id)
    section = Enum.at(view.sections, index)

    # The generator's pattern keeps only range criteria: `{cat, :assigned}`
    # doesn't match `{cat, {:range, ...}}`, so it is skipped silently.
    for {cat, {:range, _, _, _} = range} <- view.filter ++ section.filter,
        value = RangeFilter.entry_value(db, cat, range, today),
        do: {cat, value}
  end

  @doc "Gives an item the dates and numbers from `entry_values/4`."
  @spec apply_entry_values(db, id, [{id, {:date, Date.t()} | {:number, float}}], clock | nil) ::
          db
  def apply_entry_values(db, item_id, values, clock \\ nil) do
    # `fn` with several clauses, chosen by pattern like a `def`'s
    Enum.reduce(values, db, fn
      {cat, {:date, date}}, db ->
        Dates.set_date(db, item_id, cat, date, clock)

      {cat, {:number, number}}, db ->
        {:ok, db} = Numbers.set_number(db, item_id, cat, number, clock)
        db
    end)
  end

  @doc """
  Sets the sort keys (`[View.SortKey.t()]`, at most two are used) for a view
  or a section; a section's `nil` means "as the view".
  """
  @spec set_sort(db, id, :view | {:section, non_neg_integer}, [View.SortKey.t()] | nil) :: db
  def set_sort(db, view_id, scope, keys),
    do: put_scoped(db, view_id, scope, :sort, keys && Enum.take(keys, 2))

  @doc """
  The categories a new item typed into section `index` must have to pass
  the view's and the section's filters (User's Guide 11-4). Of mutually
  exclusive alternatives, the first is used.
  """
  @spec entry_categories(db, id, non_neg_integer) :: [id]
  def entry_categories(db, view_id, index) do
    view = Database.view(db, view_id)
    section = Enum.at(view.sections, index)

    (view.filter ++ section.filter)
    |> Enum.filter(&(elem(&1, 1) == :assigned))
    |> Enum.map(&elem(&1, 0))
    |> Enum.reject(&RangeFilter.range_category?(db, &1))
    |> Enum.reduce([], fn cat, chosen ->
      if Enum.any?(chosen, &Assign.conflict?(db, cat, &1)), do: chosen, else: chosen ++ [cat]
    end)
  end

  @doc """
  Searches the whole file (Agenda's Utilities Show Match, R37): the "Show
  View" lists every matching item under MAIN. It is created the first
  time and updated afterwards. Returns the view.
  """
  @spec show_match(db, Agendum.Core.Search.t()) :: {db, id}
  def show_match(db, %Agendum.Core.Search{} = search), do: show(db, search)

  @doc """
  The Show View (Show Match, Sched, Alarm …), or nil when the file has
  none: Agenda keeps only one, and asks before it is replaced. One named
  "Show View" by an older Agendum is it too.
  """
  @spec show_view(db) :: id | nil
  def show_view(db) do
    views = Database.views(db)

    found =
      Enum.find(views, &(&1.name == @show_view)) || Enum.find(views, &(&1.name == @old_show_view))

    found && found.id
  end

  # The Show View, made the first time; each use starts it afresh, so one
  # use's section and filter do not linger into the next.
  # private functions take defaults too: this defines `show/2`, `show/3`
  # and `show/4`
  defp show(db, match, section \\ nil, filter \\ []) do
    {db, view_id} =
      case show_view(db) do
        nil -> Database.insert_view(db, @show_view)
        id -> {db, id}
      end

    section = %Section{category_id: section || db.main_id}

    db =
      Database.update_view(
        db,
        view_id,
        &%{
          &1
          | name: @show_view,
            match: match,
            sections: [section],
            filter: filter,
            datebook: nil
        }
      )

    {db, view_id}
  end

  @doc """
  Shows a schedule (Agenda's Utilities Show Sched, R49): the items whose
  date in `date_category` is `date`, in the Show View under `section`
  (often the date category itself), narrowed by `filter`, criteria such
  as `[{calls, :assigned}]`. The date is a date filter, so the Show View
  can be browsed to other days (R48). Returns the view.
  """
  @spec show_schedule(db, id, id, Date.t(), [{id, View.filter_term()}]) ::
          {:ok, db, id} | {:error, :not_a_date_category}
  def show_schedule(db, date_category, section, %Date{} = date, filter) do
    if Database.date_category?(db, date_category) do
      day = Date.to_iso8601(date)

      {db, view_id} =
        show(db, nil, section, [{date_category, {:range, day, day, :inside}} | filter])

      {:ok, db, view_id}
    else
      {:error, :not_a_date_category}
    end
  end

  @doc """
  The alarm list in the Show View (Agenda's Utilities Show Alarm, R38;
  User's Guide 10-18 to 10-20): two sections, !Current Alarms! and !Past
  Alarms! (`Agendum.Core.ViewModel`), stored as two MAIN sections so that
  each has its own columns, as any section. Returns the view.
  """
  @spec show_alarms(db) :: {db, id}
  def show_alarms(db) do
    {db, view_id} = show(db, :alarms)
    main = %Section{category_id: db.main_id}
    {Database.update_view(db, view_id, &%{&1 | sections: [main, main]}), view_id}
  end

  @doc """
  The items caught in a circular reference (User's Guide 20-21): their
  conditions keep assigning them to a category and taking them out again.
  `ids` checks only those items (a front end keeping the set up to date
  as items change); nil checks every item.
  """
  @spec circular_items(db, clock, [id] | nil) :: [id]
  def circular_items(db, clock, ids \\ nil), do: Agendum.Core.Assign.unsettled(db, clock, ids)

  @doc """
  The items caught in a circular reference in the Show View, under a
  section called !Circular Reference! (Agenda's Utilities Show Circular;
  User's Guide 20-21 to 20-22). Returns the view.
  """
  @spec show_circular(db, clock) :: {db, id}
  def show_circular(db, clock) do
    {db, view_id} = show(db, {:circular, circular_items(db, clock)})
    {Database.update_view(db, view_id, &%{&1 | hide_done: false}), view_id}
  end

  @doc """
  Every done item in the Show View, under a section called *Show* (Agenda's
  Utilities Show ItemsDone; User's Guide 13-9). Returns the view.
  """
  @spec show_done(db) :: {db, id}
  def show_done(db) do
    {db, view_id} = show(db, :done)
    {Database.update_view(db, view_id, &%{&1 | hide_done: false}), view_id}
  end

  @doc """
  Every item in the Show View, under MAIN (Agenda's Utilities Show Every;
  User's Guide 13-21). Returns the view.
  """
  @spec show_every(db) :: {db, id}
  def show_every(db) do
    {db, view_id} = show(db, nil)
    {Database.update_view(db, view_id, &%{&1 | hide_done: false}), view_id}
  end

  @doc """
  Lists items in the Show View (User's Guide 13-15, R43), as `show_match/2`
  does for a search. Returns the view.
  """
  @spec show_items(db, [id]) :: {db, id}
  def show_items(db, ids), do: show(db, {:items, ids})

  @doc """
  How a view orders its section heads (User's Guide 15-20): `:none` (as
  added), `:category` (hierarchy order), `:alpha` or `:numeric` (by name).
  """
  @spec set_section_sort(db, id, :none | :category | :alpha | :numeric, :asc | :desc) :: db
  def set_section_sort(db, view_id, sort, order),
    do: Database.update_view(db, view_id, &%{&1 | section_sort: sort, section_order: order})

  @doc "Sorts the views alphabetically (ALT-F5 in the view manager)."
  @spec sort_views(db) :: db
  def sort_views(db),
    do: %{db | view_order: Enum.sort_by(db.view_order, &String.downcase(db.views[&1].name))}

  # `scope` is `:view` or `{:section, index}`, one clause each. `Map.fetch!`
  # raises if the key is missing; the bang (`!`) names functions that raise
  # instead of returning an error.
  defp get_scoped(db, view_id, :view, field), do: Map.fetch!(Database.view(db, view_id), field)

  defp get_scoped(db, view_id, {:section, index}, field),
    do:
      db |> Database.view(view_id) |> Map.fetch!(:sections) |> Enum.at(index) |> Map.fetch!(field)

  defp put_scoped(db, view_id, :view, field, value),
    do: Database.update_view(db, view_id, &Map.put(&1, field, value))

  defp put_scoped(db, view_id, {:section, index}, field, value) do
    Database.update_view(db, view_id, fn v ->
      %{v | sections: List.update_at(v.sections, index, &Map.put(&1, field, value))}
    end)
  end

  @doc """
  Whether filters have a date range, which browsing can move (R48).
  """
  @spec date_filters?(db, [{id, View.filter_term()}]) :: boolean
  def date_filters?(db, filters),
    do:
      Enum.any?(
        filters,
        &(match?({_, {:range, _, _, _}}, &1) and Database.date_category?(db, elem(&1, 0)))
      )

  @doc """
  Filters with their date ranges moved by `%{days: n, months: n}`, as fixed
  dates (browsing, R48); other criteria as they are.
  """
  @spec shift_filters(db, [{id, View.filter_term()}], %{days: integer, months: integer}, clock) ::
          [{id, View.filter_term()}]
  def shift_filters(db, filters, shift, clock) do
    Enum.map(filters, fn
      {cat, {:range, _, _, _} = range} = criterion ->
        if Database.date_category?(db, cat),
          do: {cat, RangeFilter.shift(db, range, shift, clock)},
          else: criterion

      criterion ->
        criterion
    end)
  end

  @doc "Replaces the filters of a view (`:view`) or one of its sections."
  @spec set_filters(db, id, :view | {:section, non_neg_integer}, [{id, View.filter_term()}]) :: db
  def set_filters(db, view_id, scope, filters),
    do: put_scoped(db, view_id, scope, :filter, filters)

  @doc "Toggles a boolean view option such as `:hide_done`."
  @spec toggle_view_option(
          db,
          id,
          :hide_done
          | :hide_empty
          | :hide_inherited
          | :hide_dependent
          | :hide_column_heads
          | :section_separators
          | :number_items
        ) :: db
  def toggle_view_option(db, view_id, option) do
    # `Map.update!/3` applies a function to the current value of one key
    Database.update_view(db, view_id, &Map.update!(&1, option, fn value -> not value end))
  end
end
