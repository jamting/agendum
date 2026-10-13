defmodule Agenda.Core.Facade.Views do
  @moduledoc """
  Views (R20–R28, R36, R37, R47–R49): adding and changing views,
  datebooks, sections and columns, filters and sorting, what a new item
  typed into a section gets, and the Show View (Show Match, Show Sched).

  Called through `Agenda.Core`.
  """

  alias Agenda.Core.{Assign, Database, Datebook, NumberFormat, RangeFilter, View, ViewColumns}
  alias Agenda.Core.ViewModel
  alias Agenda.Core.Facade.{Dates, Numbers}
  # `View.Column` and `View.Section` are nested modules; nesting is only a
  # naming convention, so they are aliased like any other module.
  alias Agenda.Core.View.{Column, Section}

  @typep db :: Agenda.Core.db()
  @typep id :: Agenda.Core.id()
  @typep clock :: Agenda.Core.clock()

  @show_view "Show View"
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
  Inserts a column headed by `cat_id` at `at` (`{section, column}`): in
  all sections, linked, or in that section only (`insert_in`, R55; see
  `Agenda.Core.ViewColumns.add/4` for where the other sections get it).
  Without `insert_in` the file's Insert new columns in decides
  (`set_insert_columns/2`); without `width` it is 16 for a date category,
  room for a date and a time, and 12 for others.
  """
  @spec add_column(db, id, id, View.at(), pos_integer | nil, :all | :section | nil) :: db
  def add_column(db, view_id, cat_id, at, width \\ nil, insert_in \\ nil) do
    # `||` gives its right side when the left is nil (or false)
    width = width || default_column_width(db, cat_id)
    column = %Column{category_id: cat_id, width: width}
    insert_in = insert_in || db.insert_columns
    Database.update_view(db, view_id, &ViewColumns.add(&1, at, column, insert_in))
  end

  @doc """
  The width a new column headed by `cat_id` gets unless told otherwise:
  16 for a date category, room for a date and a time, and 12 for others
  (also without a head yet, as in the Column Add box).
  """
  @spec default_column_width(db, id | nil) :: pos_integer
  def default_column_width(db, cat_id) do
    if cat_id && Database.date_category?(db, cat_id), do: 16, else: 12
  end

  @doc """
  Column Properties ▸ Column head (R55): the column at `at` and the columns
  linked to it show `cat_id` instead (`Agenda.Core.ViewColumns.set_head/3`).
  """
  @spec set_column_head(db, id, View.at(), id) :: db
  def set_column_head(db, view_id, at, cat_id),
    do: Database.update_view(db, view_id, &ViewColumns.set_head(&1, at, cat_id))

  @doc """
  Column Properties ▸ Link with other sections (R55): `false` unlinks the
  column at `at`, `true` links it (`Agenda.Core.ViewColumns.set_linked/3`).
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
  (and the linked ones, `Agenda.Core.ViewColumns.update_items/3`):
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
  Item Column Properties ▸ Link with other sections: `false` unlinks the
  item column of section `sidx`, `true` links it, taking the linked ones'
  settings (`Agenda.Core.ViewColumns.set_items_linked/3`).
  """
  @spec set_item_column_linked(db, id, non_neg_integer, boolean) :: db
  def set_item_column_linked(db, view_id, sidx, linked) when is_boolean(linked),
    do: Database.update_view(db, view_id, &ViewColumns.set_items_linked(&1, sidx, linked))

  @doc """
  View ▸ Column ▸ Move: the column at `at` goes to place `to` in its
  section only (`Agenda.Core.ViewColumns.move/3`).
  """
  @spec move_column(db, id, View.at(), non_neg_integer) :: db
  def move_column(db, view_id, at, to),
    do: Database.update_view(db, view_id, &ViewColumns.move(&1, at, to))

  @doc "Sets how a numeric column shows its numbers and calculations (R29)."
  @spec set_column_format(db, id, View.at(), NumberFormat.t()) :: db
  def set_column_format(db, view_id, at, %NumberFormat{} = format),
    do: update_column(db, view_id, at, &%{&1 | number: format})

  @doc """
  Gives a date column its own display format, or `nil` to use the file's
  again (Global defaults, R41a).
  """
  @spec set_column_date_format(db, id, View.at(), Agenda.Core.DateFormat.t() | nil) :: db
  def set_column_date_format(db, view_id, at, format),
    do: update_column(db, view_id, at, &%{&1 | date: format})

  @doc """
  View ▸ Column ▸ Width: the column at `at` and the columns linked to it
  become `width` wide, at least 3 and at most #{@fit_room}.
  """
  @spec set_column_width(db, id, View.at(), integer) :: db
  def set_column_width(db, view_id, at, width),
    do: update_column(db, view_id, at, &%{&1 | width: width |> max(3) |> min(@fit_room)})

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
  @spec show_match(db, Agenda.Core.Search.t()) :: {db, id}
  def show_match(db, %Agenda.Core.Search{} = search), do: show(db, search)

  # The Show View, made the first time; each use starts it afresh, so one
  # use's section and filter do not linger into the next.
  # private functions take defaults too: this defines `show/2`, `show/3`
  # and `show/4`
  defp show(db, match, section \\ nil, filter \\ []) do
    {db, view_id} =
      case Enum.find(Database.views(db), &(&1.name == @show_view)) do
        nil -> Database.insert_view(db, @show_view)
        view -> {db, view.id}
      end

    section = %Section{category_id: section || db.main_id}

    db =
      Database.update_view(
        db,
        view_id,
        &%{&1 | match: match, sections: [section], filter: filter, datebook: nil}
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
  @spec toggle_view_option(db, id, :hide_done | :hide_empty | :hide_inherited | :hide_dependent) ::
          db
  def toggle_view_option(db, view_id, option) do
    # `Map.update!/3` applies a function to the current value of one key
    Database.update_view(db, view_id, &Map.update!(&1, option, fn value -> not value end))
  end
end
