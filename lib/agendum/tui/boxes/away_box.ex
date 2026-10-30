defmodule Agendum.TUI.Boxes.AwayBox do
  @moduledoc """
  "While you were away" (R70; meeting 2026-10-16-1905, § 6): when a file is
  opened, the alarms that came due while it was closed, so that none is
  lost silently. Shown after the splash screen, only when there are any:
  the latest first, alarms with the same text in one line with a count
  (`Agendum.Core.group_alarms/2`), each at the time it was due. ENTER or
  ESC closes it; the alarms stay in Utilities ▸ Show ▸ Alarm with the other past
  alarms. Not in Agenda, which is not known to have shown them. Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :return

  alias Agendum.Core
  alias Agendum.Core.DateFormat
  alias Agendum.TUI.Boxes.Box
  alias Agendum.TUI.State
  alias Agendum.TUI.Terminal.Draw

  @doc "Opens the box for the alarms `rung`, grouped as they are now."
  @spec open(State.t(), [Agendum.Core.id()]) :: State.t()
  def open(state, rung),
    do: State.push(state, %Agendum.TUI.Modes.Away{groups: Core.group_alarms(state.db, rung)})

  @impl Box
  def about(_state, _mode) do
    """
    The alarms that came due while the file was closed, the latest first;
    alarms with the same text are counted on one line. ENTER or ESC closes
    the box. Utilities ▸ Show ▸ Alarm lists them with the other past alarms.
    """
  end

  @impl Box
  def handle(state, _mode, _key), do: state

  # R65
  @impl Box
  def keymap(_mode), do: %{:enter => :close, :esc => :close}

  @impl Box
  def commands(_mode), do: [{:close, "Return", "Close the box"}]

  @impl Box
  def run(state, _mode, :close), do: State.pop(state)

  @impl Box
  def title(_state, _mode), do: "While you were away"

  @impl Box
  def width(state, _mode), do: min(state.width - 8, 64)

  # one line a group: when it was due, the text, and how many; past the
  # room there is, a line says how many more, and where they all are
  @impl Box
  def content(state, mode, inner, max_rows) do
    groups = mode.groups
    count = Enum.sum(Enum.map(groups, & &1.count))
    heading = " " <> Draw.count(count, "alarm") <> " came due:"
    room = max(max_rows - 2, 1)

    {shown, more} =
      if length(groups) > room,
        do: Enum.split(groups, room - 1),
        else: {groups, []}

    lines = Enum.map(shown, &line(state, &1, inner))

    more =
      case more do
        [] -> []
        more -> [[{:dim, " … #{length(more)} more: Utilities ▸ Show ▸ Alarm lists them all"}]]
      end

    [[{:box, heading}], []] ++ lines ++ more
  end

  defp line(state, group, inner) do
    at = DateFormat.datetime(group.at, state.db.date_format)
    times = if group.count > 1, do: " ×#{group.count}", else: ""
    room = max(inner - String.length(at) - String.length(times) - 4, 10)
    text = group.text |> String.replace("\n", " ") |> Draw.truncate(room)
    [{:box, " #{at}  "}, {:box, text}, {:box, times}]
  end

  @impl Box
  def keys(_state, _mode), do: [{"ENTER/ESC", "Return"}]

  @impl Box
  def help,
    do: "Alarms that came due while the file was closed. Utilities ▸ Show ▸ Alarm lists them all."
end
