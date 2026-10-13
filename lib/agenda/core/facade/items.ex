defmodule Agenda.Core.Facade.Items do
  @moduledoc """
  Items: adding and editing items (R21) and their notes, moving them
  between sections (R26), marking them done (with the next occurrence of a
  recurring item, R14a), marking groups of items (R35), discarding.

  Called through `Agenda.Core`.
  """

  alias Agenda.Core.{Assign, Database, Recurrence}
  alias Agenda.Core.Facade.Changes

  @typep db :: Agenda.Core.db()
  @typep id :: Agenda.Core.id()
  @typep clock :: Agenda.Core.clock()

  @doc """
  Adds an item, assigns it to `:section` (a category id) and runs automatic
  assignment.

  Options:
    * `:section` – category the item was typed under
    * `:after` – item to place the new item after
    * `:adjacent` – neighbouring item ids, nearest first, for resolving
      ambiguous automatic assignments
  """
  @spec add_item(db, String.t(), clock, keyword) :: {db, id}
  def add_item(db, text, today, opts \\ []) do
    before = db

    {db, id} =
      Database.insert_item(db, String.trim(text), Changes.date_of(today), after: opts[:after])

    db =
      case opts[:section] do
        nil -> db
        section -> Changes.user_assign(db, id, section)
      end

    db =
      db
      |> Assign.auto_assign(id, Keyword.get(opts, :adjacent, []))
      |> Changes.item_dates(id, nil, [:entered], today)
      |> typed_date(id, opts[:date])
      |> Changes.settle(before, id, today)

    {db, id}
  end

  # an item typed into a datebook slot (R47) gets the slot's date and time,
  # as if typed in the date column
  defp typed_date(db, _id, nil), do: db

  defp typed_date(db, id, {cat_id, date, time}),
    do: Changes.put_date_time(db, id, cat_id, date, time, nil)

  @doc """
  Changes an item's text, re-runs automatic assignment (it only adds
  assignments) and updates dates read from the text or set on edits (R14,
  R6b).
  """
  @spec edit_item(db, id, String.t(), clock, [id]) :: db
  def edit_item(db, id, text, today, adjacent \\ []) do
    text = String.trim(text)
    events = if text == db.items[id].text, do: [], else: [:item_edited]

    db
    |> Database.update_item(id, &%{&1 | text: text})
    |> Assign.auto_assign(id, adjacent)
    |> Changes.item_dates(id, db.items[id], events, today)
    |> Changes.settle(db, id, today)
  end

  @doc """
  Replaces an item's note; date categories that read dates from notes, or
  are set when the note is edited, get their dates (R14f, R6b).
  """
  @spec set_note(db, id, String.t(), clock) :: db
  def set_note(db, id, note, clock) do
    events = if note == db.items[id].note, do: [], else: [:note_edited]

    db
    |> Database.update_item(id, &%{&1 | note: note})
    |> Assign.auto_assign(id)
    |> Changes.item_dates(id, db.items[id], events, clock)
    |> Changes.settle(db, id, clock)
  end

  @doc """
  Moves an item from one section's category to another (ALT-F10). The item
  leaves `from` and joins `to` (MAIN is never left or joined explicitly).
  With `after: item_id`, it is also placed after that item in item order.
  """
  @spec move_item(db, id, id, id, keyword) :: db
  def move_item(db, item_id, from, to, opts \\ []) do
    before = db

    db =
      if to == from do
        db
      else
        db = if from == db.main_id, do: db, else: Assign.unassign(db, item_id, from)
        if to == db.main_id, do: db, else: Changes.user_assign(db, item_id, to)
      end

    db =
      case opts[:after] do
        nil -> db
        ^item_id -> db
        after_id -> Database.reorder_item(db, item_id, after_id)
      end

    Changes.settle(db, before, item_id, opts[:clock])
  end

  @doc """
  Marks an item done today, or clears its done date (F4 DONE). A recurring
  item marked done is followed by a copy with the next When date (R14a).
  """
  @spec toggle_done(db, id, clock) :: db
  def toggle_done(db, id, today) do
    if db.items[id].done,
      do: Database.update_item(db, id, &%{&1 | done: nil}),
      else: mark_done(db, id, today)
  end

  @doc "Toggles the mark used to select several items (F7 MARK)."
  @spec toggle_mark(db, id) :: db
  def toggle_mark(db, id), do: Database.update_item(db, id, &%{&1 | marked: not &1.marked})

  @doc """
  Marks an item done today unless it already has a done date (bulk F4
  DONE); a recurring one is followed by its next occurrence (R14a).
  """
  @spec mark_done(db, id, clock) :: db
  def mark_done(db, id, today) do
    case db.items[id] do
      %{done: nil} = item ->
        db
        |> Database.update_item(id, &%{&1 | done: Changes.date_of(today)})
        |> Changes.key_dates(id, :done_key, today)
        |> next_occurrence(item, today)

      _ ->
        db
    end
  end

  # A recurring item marked done is followed by a copy with the next When
  # date (User's Guide 7-12): same text, note, time, alarm and assignments.
  defp next_occurrence(db, %{recurrence: nil}, _today), do: db
  defp next_occurrence(db, %{when: nil}, _today), do: db

  defp next_occurrence(db, item, today) do
    {db, copy} = Database.insert_item(db, item.text, Changes.date_of(today), after: item.id)

    db =
      Database.update_item(db, copy, fn new ->
        %{
          new
          | note: item.note,
            when: Recurrence.next(item.recurrence, item.when),
            when_time: item.when_time,
            when_explicit: item.when_explicit,
            recurrence: item.recurrence,
            alarm_minutes: item.alarm_minutes
        }
      end)

    db
    |> Database.explicit_categories(item.id)
    |> Enum.reduce(db, fn cat, db ->
      db = Database.link(db, copy, cat)

      db =
        if Database.conditional?(db, item.id, cat),
          do: Database.mark_conditional(db, copy, cat),
          else: db

      case Database.number(db, item.id, cat) do
        nil -> db
        number -> Database.put_number(db, copy, cat, number)
      end
    end)
  end

  @doc "Marked items, in item order (the group bulk commands act on)."
  @spec marked_items(db) :: [id]
  def marked_items(db), do: for(item <- Database.items(db), item.marked, do: item.id)

  @doc "Marks (true) or unmarks (false) a group of items (F7 on a section head)."
  @spec set_marked(db, [id], boolean) :: db
  def set_marked(db, ids, marked),
    do: Enum.reduce(ids, db, &Database.update_item(&2, &1, fn i -> %{i | marked: marked} end))

  @doc "Unmarks every item in the file (ALT-F7 UNMKALL)."
  @spec unmark_all(db) :: db
  def unmark_all(db), do: set_marked(db, marked_items(db), false)

  @doc "Deletes an item from the whole file (ALT-F4 DISCARD)."
  @spec discard_item(db, id) :: db
  defdelegate discard_item(db, id), to: Database, as: :delete_item
end
