defmodule Agendum.TUI.Boxes.AlarmList do
  @moduledoc """
  The alarm list (Utilities ▸ Show ▸ Alarm; Agenda's Utilities Show Alarm, User's
  Guide 10-18 to 10-20): items with alarms set, and the alarms that have
  gone off since the date changed, each at the time it was due (R70). DEL on a past alarm removes it from the list, ALT-A on a
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
    %{current: current, past: past} = Core.alarm_list(state.db)
    Enum.map(current, &{:current, &1}) ++ Enum.map(past, &{:past, &1})
  end

  @impl Box
  def about(_state, _mode) do
    """
    The alarms: those still to ring, and those that rang since the date
    changed (or while the file was closed). ALT-A
    cancels the highlighted one; DEL removes a past one from the list.
    ENTER or ESC goes back.
    """
  end

  @impl Box
  # keys it has no command for keep the highlight on a row (undo can take
  # rows away)
  def handle(state, mode, _key), do: State.put_mode(state, clamp(state, mode))

  defp clamp(state, mode),
    do: %{mode | cursor: mode.cursor |> min(length(rows(state)) - 1) |> max(0)}

  # R65
  @impl Box
  def keymap(_mode) do
    %{
      :up => :up,
      :down => :down,
      :delete => :remove,
      {:alt, "a"} => :cancel_alarm,
      :enter => :close,
      :esc => :close
    }
  end

  @impl Box
  def commands(_mode) do
    Enum.take(Box.list_moves(), 2) ++
      [
        {:cancel_alarm, "Cancel alarm", "Cancel the highlighted alarm"},
        {:remove, "Remove", "Remove the highlighted past alarm"},
        {:close, "Return", "Back to the view"}
      ]
  end

  @impl Box
  def run(state, _mode, :close), do: State.pop(state)

  def run(state, mode, id) do
    mode = clamp(state, mode)
    command(State.put_mode(state, mode), mode, id, Enum.at(rows(state), mode.cursor))
  end

  defp command(state, _mode, :remove, {:past, id}),
    do: State.run(state, {:remove_past_alarm, id})

  defp command(state, _mode, :cancel_alarm, {:current, id}),
    do: State.run(state, {:cancel_alarm, id}, "Alarm cancelled")

  defp command(state, mode, id, _row) when id in [:up, :down],
    do: Box.list_move(state, mode, max(length(rows(state)), 1), id)

  defp command(state, _mode, _id, _row), do: state

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
      [[], [{:box, " Past alarms"}]] ++
      if(past == [], do: none, else: past) ++
      [[], Box.hint(keys(state, mode), inner)]
  end

  defp when_text(state, :current, item) do
    at = NaiveDateTime.add(Core.when_at(item), -item.alarm_minutes * 60)
    "rings " <> DateFormat.datetime(at, state.db.date_format)
  end

  # when it was due (R70): the time alone today, else the date too, for an
  # alarm that came due while the file was closed
  defp when_text(state, :past, %{alarm_rung_at: at}) do
    if NaiveDateTime.to_date(at) == state.today,
      do: "rang " <> DateFormat.time(NaiveDateTime.to_time(at), state.db.date_format),
      else: "rang " <> DateFormat.datetime(at, state.db.date_format)
  end

  @impl Box
  def keys(_state, _mode),
    do: [{"DEL", "Remove past alarm"}, {"ALT-A", "Cancel alarm"}, {"ESC", "Close"}]

  @impl Box
  def help,
    do:
      "The items with alarms, and the alarms that have gone off. " <>
        "DEL removes a past alarm, ALT-A cancels a current one."
end
