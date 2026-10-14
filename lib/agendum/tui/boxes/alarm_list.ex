defmodule Agendum.TUI.Boxes.AlarmList do
  @moduledoc """
  The alarm list (Search ▸ Alarms; Agenda's Utilities Show Alarm, User's
  Guide 10-18 to 10-20): items with alarms set, and today's alarms that
  have gone off. DEL on a past alarm removes it from the list, ALT-A on a
  current one cancels it. Opening the list clears the alarm symbol in the
  title. Agenda shows this as a Show View with !Current Alarms! and !Past
  Alarms! sections; ours is a box. Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :none, indicator: nil

  alias Agendum.Core
  alias Agendum.Core.DateFormat
  alias Agendum.TUI.Boxes.Box
  alias Agendum.TUI.State
  alias Agendum.TUI.Terminal.Draw

  def open(state), do: State.push(%{state | alarm_rang: false}, %{type: :alarm_list, cursor: 0})

  @doc "The rows: `{:current, id}` and `{:past, id}`."
  def rows(state) do
    %{current: current, past: past} = Core.alarm_list(state.db, state.today)
    Enum.map(current, &{:current, &1}) ++ Enum.map(past, &{:past, &1})
  end

  @impl Box
  def handle(state, mode, key) do
    rows = rows(state)
    mode = %{mode | cursor: mode.cursor |> min(length(rows) - 1) |> max(0)}
    row = Enum.at(rows, mode.cursor)

    case {key, row} do
      {k, _} when k in [:esc, :enter] ->
        State.pop(state)

      {:up, _} ->
        State.put_mode(state, %{mode | cursor: max(mode.cursor - 1, 0)})

      {:down, _} ->
        State.put_mode(state, %{mode | cursor: min(mode.cursor + 1, max(length(rows) - 1, 0))})

      {:delete, {:past, id}} ->
        State.change_db(state, Core.remove_past_alarm(state.db, id))

      {{:alt, "a"}, {:current, id}} ->
        state |> State.change_db(Core.cancel_alarm(state.db, id)) |> State.info("Alarm cancelled")

      _ ->
        State.put_mode(state, mode)
    end
  end

  @impl Box
  def title(_state, _mode), do: "Alarm list"

  @impl Box
  def content(state, mode, inner, _max_rows) do
    rows = rows(state)
    cursor = min(mode.cursor, max(length(rows) - 1, 0))

    lines =
      rows
      |> Enum.with_index()
      |> Enum.map(fn {{kind, id}, i} ->
        item = state.db.items[id]
        text = Draw.pad(item.text, max(inner - 28, 10))

        {kind,
         [
           {:box, " "},
           {if(i == cursor, do: :box_selected, else: :box), text},
           {:box, " " <> when_text(state, kind, item)}
         ]}
      end)

    current = for {:current, line} <- lines, do: line
    past = for {:past, line} <- lines, do: line
    none = [[{:box, "   (none)"}]]

    [[{:box, " Current alarms"}]] ++
      if(current == [], do: none, else: current) ++
      [[], [{:box, " Past alarms today"}]] ++
      if(past == [], do: none, else: past) ++
      [[], Box.hint(keys(state, mode), inner)]
  end

  defp when_text(state, :current, item) do
    at = NaiveDateTime.add(Core.when_at(item), -item.alarm_minutes * 60)
    "rings " <> DateFormat.datetime(at, state.db.date_format)
  end

  defp when_text(state, :past, item),
    do:
      "rang " <> DateFormat.time(NaiveDateTime.to_time(item.alarm_rung_at), state.db.date_format)

  @impl Box
  def keys(_state, _mode),
    do: [{"DEL", "Remove past alarm"}, {"ALT-A", "Cancel alarm"}, {"ESC", "Close"}]

  @impl Box
  def help,
    do:
      "The items with alarms, and today's alarms that have gone off. " <>
        "DEL removes a past alarm, ALT-A cancels a current one."
end
