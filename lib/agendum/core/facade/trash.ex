defmodule Agendum.Core.Facade.Trash do
  @moduledoc """
  The trash (R24a; User's Guide 3-4 to 3-5 and 13-18 to 13-19; checked in
  Agenda 2.0, 2026-10-26): a discarded item leaves the file and waits in
  the trash until it is emptied. Item ▸ Undisc brings it back into a
  section, with only that section's category: its other assignments, its
  dates and its alarm went when it was discarded, as in Agenda. Utilities ▸
  Trash empties it, and File Properties ▸ Empty trash says when it empties
  by itself: On demand, When file is closed, End of day (the default) or
  When item is discarded (no trash at all).

  Called through `Agendum.Core`.
  """

  alias Agendum.Core.{Context, Database, Item}
  alias Agendum.Core.Facade.Items

  @typep db :: Agendum.Core.db()
  @typep id :: Agendum.Core.id()

  @typedoc "File Properties ▸ Empty trash, Agenda's four choices in its order."
  @type when_empty :: :on_demand | :file_closed | :end_of_day | :discarded

  @choices [:on_demand, :file_closed, :end_of_day, :discarded]

  @doc "Empty trash's choices, in Agenda's order."
  @spec empty_trash_choices() :: [when_empty]
  def empty_trash_choices, do: @choices

  @doc """
  Discards items from the file (ALT-F4, a category's discard action, R15b):
  each goes to the end of the trash without its assignments, unless Empty
  trash is When item is discarded. The clock's day starts the day of a
  trash that was empty, for End of day.
  """
  @spec discard_items(db, [id], Agendum.Core.clock()) :: db
  def discard_items(db, ids, clock) do
    today = Context.today(clock)

    Enum.reduce(ids, db, fn id, db ->
      case db.items[id] do
        nil -> db
        item -> db |> Database.delete_item(id) |> keep(item, today)
      end
    end)
  end

  defp keep(%{trash: %{empty: :discarded}} = db, _item, _today), do: db

  # Domain: what Agenda keeps of a discarded item is its text and note;
  # every assignment is broken, the When and Done dates and the alarm with
  # them (an item undiscarded in Agenda came back without its date). The
  # Entry date stays: it is when the item was made, and every item has one.
  defp keep(db, item, today) do
    bare = %Item{
      id: item.id,
      text: item.text,
      note: item.note,
      entry: item.entry,
      zettel: item.zettel
    }

    %{db | trash: %{db.trash | items: db.trash.items ++ [bare], day: db.trash.day || today}}
  end

  @doc """
  Item ▸ Undisc: the last item discarded (`:last`) or every item in the
  trash (`:all`) back into the section headed by `category`, after the
  item `after_id` (nil: in its usual place), the most recently discarded
  first, as Agenda. Each is assigned to the category alone, and its
  conditions and actions run, as when it is assigned by hand. Refused with
  `:empty_trash` when there is nothing to bring back.
  """
  @spec undiscard(db, :last | :all, id, id | nil, Agendum.Core.clock()) ::
          {:ok, db, [id]} | {:error, :empty_trash}
  def undiscard(%{trash: %{items: []}}, _which, _category, _after_id, _clock),
    do: {:error, :empty_trash}

  def undiscard(db, which, category, after_id, clock) do
    trash = db.trash

    {back, kept} =
      case which do
        :last -> {[List.last(trash.items)], Enum.drop(trash.items, -1)}
        :all -> {trash.items, []}
      end

    db = %{db | trash: %{trash | items: kept, day: if(kept == [], do: nil, else: trash.day)}}

    # `Enum.reverse/1`: the newest first, each after the one before it, so
    # they read newest to oldest below the highlight
    {db, _after} =
      back
      |> Enum.reverse()
      |> Enum.reduce({db, after_id}, fn item, {db, after_id} ->
        db = Database.restore_item(db, item, after_id)
        {Items.move_item(db, item.id, db.main_id, category, clock: clock), item.id}
      end)

    {:ok, db, Enum.map(back, & &1.id)}
  end

  @doc """
  Utilities ▸ Trash: the items in the trash are gone for good. Refused with
  `:empty_trash` when there are none, as Agenda says so.
  """
  @spec empty_trash(db) :: {:ok, db} | {:error, :empty_trash}
  def empty_trash(%{trash: %{items: []}}), do: {:error, :empty_trash}
  def empty_trash(db), do: {:ok, emptied(db)}

  @doc """
  The trash emptied by itself, as File Properties ▸ Empty trash says, when
  the file is opened (`:open`) or the clock moves on (`:clock`): End of
  day empties it once the oldest item in it was discarded before today;
  When file is closed empties it when the file is opened again (the
  same, seen from the next time). Anything else leaves it.
  """
  @spec tidy_trash(db, :open | :clock, Agendum.Core.clock()) :: db
  def tidy_trash(%{trash: %{items: []}} = db, _event, _clock), do: db

  def tidy_trash(%{trash: %{empty: :file_closed}} = db, :open, _clock), do: emptied(db)

  def tidy_trash(%{trash: %{empty: :end_of_day, day: day}} = db, _event, clock) do
    if day == nil or Date.compare(day, Context.today(clock)) == :lt,
      do: emptied(db),
      else: db
  end

  def tidy_trash(db, _event, _clock), do: db

  defp emptied(db), do: %{db | trash: %{db.trash | items: [], day: nil}}

  @doc """
  File Properties ▸ Empty trash. The trash stays as it is until it next
  empties: choosing When item is discarded only stops keeping new ones.
  """
  @spec set_empty_trash(db, when_empty) :: {:ok, db} | {:error, :bad_arguments}
  def set_empty_trash(db, choice) when choice in @choices,
    do: {:ok, %{db | trash: %{db.trash | empty: choice}}}

  def set_empty_trash(_db, _choice), do: {:error, :bad_arguments}
end
