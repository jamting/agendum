# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Boxes.RunByName do
  @moduledoc """
  CTRL-X, run a command by its name (R65d, ADR 0040): a small box shaped
  like Agenda's choice lists. An input line; under it the commands that
  can run where CTRL-X was pressed and match what is typed, best first,
  each with its key; at the bottom the highlighted one's summary. ↑↓
  choose, ENTER runs it there, as its key would; ESC closes.

  The commands are F1 `c`'s (`Agendum.TUI.HelpScreen.entries/2`) without
  those that cannot run now, matched by `Agendum.TUI.Commands.match/3`
  (initials, letters in order); with nothing typed, the recently run by
  name come first. Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :accept

  alias Agendum.TUI.Boxes.Box
  alias Agendum.TUI.{HelpScreen, Keymap, State}

  # the most rows of matches shown at once
  @rows 10

  @doc "Opens the box over where the person is; in the box itself, does nothing."
  @spec open(State.t()) :: State.t()
  def open(%State{modes: [%{type: :run_by_name} | _]} = state), do: state

  def open(state) do
    State.push(state, %Agendum.TUI.Modes.RunByName{
      cursor: 0,
      filter: "",
      from: HelpScreen.place(state)
    })
  end

  @doc """
  The entries shown, best first: those of the command list where the box
  was opened that can run now and match what is typed.
  """
  @spec matches(State.t(), Box.mode()) :: [{Agendum.TUI.Command.t(), term, [term]}]
  def matches(state, mode) do
    under = under(state, mode)
    unavailable = HelpScreen.unavailable(under, mode.from)

    under
    |> HelpScreen.entries(mode.from)
    |> Enum.reject(fn {command, place, _keys} ->
      command.id == :run_by_name or Map.has_key?(unavailable, {place, command.id})
    end)
    |> HelpScreen.match(under, mode.from, mode.filter)
  end

  # the state where the box was opened: the modes under it (the help can
  # be open over the box, so it is not always on top)
  defp under(state, mode) do
    case Enum.drop_while(state.modes, &(&1 != mode)) do
      [_box | rest] -> %{state | modes: rest}
      [] -> State.pop(state)
    end
  end

  # --- keys -----------------------------------------------------------------------

  @impl Box
  # a character is typed into the input line; BACKSPACE takes one back.
  # Either way the best match is highlighted again
  def handle(state, mode, {:char, c}), do: retype(state, mode, mode.filter <> c)

  def handle(state, %{filter: filter} = mode, :backspace) when filter != "",
    do: retype(state, mode, String.slice(filter, 0..-2//1))

  def handle(state, _mode, _key), do: state

  defp retype(state, mode, filter),
    do: State.put_mode(state, %{mode | filter: filter, cursor: 0})

  @impl Box
  def keymap(_mode) do
    %{
      :up => :up,
      :down => :down,
      :home => :first,
      :end => :last,
      :enter => :run,
      :esc => :close
    }
  end

  @impl Box
  def commands(_mode) do
    [{:run, "Run", "Run the highlighted command"}] ++
      Box.list_moves() ++ [{:close, "Cancel", "Close without running anything"}]
  end

  @impl Box
  def run(state, _mode, :close), do: State.pop(state)

  # the box goes first, so that the command runs where CTRL-X was pressed
  def run(state, mode, :run) do
    entry = Enum.at(matches(state, mode), mode.cursor)
    state |> State.pop() |> HelpScreen.run_or_say(mode.from, entry)
  end

  def run(state, mode, id), do: Box.list_move(state, mode, length(matches(state, mode)), id)

  # --- drawing --------------------------------------------------------------------

  @impl Box
  def title(_state, _mode), do: "Run a command"

  # a small box, as Agenda's choice lists
  @impl Box
  def width(state, _mode), do: min(state.width - 8, 56)

  @impl Box
  def content(state, mode, inner, max_rows) do
    list = matches(state, mode)
    rows = max(min(@rows, max_rows - 4), 1)
    top = max(mode.cursor - rows + 1, 0)

    shown =
      list
      |> Enum.with_index()
      |> Enum.drop(top)
      |> Enum.take(rows)
      |> Enum.map(fn {entry, i} -> row(entry, i == mode.cursor, inner) end)

    input = [
      {:box, " Command: "}
      | Agendum.TUI.Terminal.Draw.field(mode.filter, String.length(mode.filter), :edit)
    ]

    [input, [{:box, ""}]] ++
      shown ++
      List.duplicate([{:box, ""}], rows - length(shown)) ++
      [[{:box, ""}], [{:box, " " <> summary(list, mode)}]]
  end

  # a command's name, and on the right its first key; only the name is
  # highlighted, as in Agenda's choice lists
  defp row({command, _place, keys}, highlighted?, inner) do
    key = keys |> Enum.take(1) |> Enum.map_join(&Keymap.name/1)
    room = max(inner - 2 - String.length(key), 1)
    name = String.slice(command.name, 0, room - 1)
    gap = String.duplicate(" ", room - String.length(name))

    [
      {:box, " "},
      {if(highlighted?, do: :box_selected, else: :box), name},
      {:box, gap <> key <> " "}
    ]
  end

  defp summary([], %{filter: filter}), do: ~s(No command here matches "#{filter}")

  defp summary(list, mode) do
    {command, _place, _keys} = Enum.at(list, mode.cursor) || hd(list)
    command.summary
  end

  @impl Box
  def keys(_state, _mode),
    do: [
      {"type", "Find", "Type part of a name"},
      {"↑↓", "Highlight", "Highlight a command"},
      {"ENTER", "Run"},
      {"ESC", "Cancel"}
    ]

  @impl Box
  def help,
    do: "Type part of a command's name, or its initials; ENTER runs the highlighted one."

  @impl Box
  def about(_state, _mode) do
    """
    Run a command by its name (CTRL-X): the commands that can run where you
    pressed it, with their keys, so a command without a key of its own can
    be run too, and a key can be learnt.

    Type part of the name, its letters in order, or the initials of its
    words: "azi" finds Attach Zettel id. The best match comes first; with
    nothing typed, the commands you last ran by name. ↑ ↓ choose, ENTER
    runs the highlighted one, as its key would; ESC closes.
    """
  end
end
