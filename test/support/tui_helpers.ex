defmodule Agendum.TUIHelpers do
  @moduledoc "Drive the pure TUI with keys and inspect the rendered text."

  alias Agendum.TUI.{Terminal.Draw, Layout, Render, State, Update}

  @doc """
  A session on `db`, as the person starts it: the Extras preference off
  (R77) unless `extras: true` is given (or the `prefs:` given say so).
  """
  def start(db, opts \\ []) do
    {extras, opts} = Keyword.pop(opts, :extras)
    prefs = Keyword.get(opts, :prefs, %Agendum.Preferences{})
    prefs = if extras == nil, do: prefs, else: %{prefs | extras: extras}

    db
    |> State.new(
      Keyword.merge([today: ~D[2026-10-08], width: 100, height: 24], opts) ++ [prefs: prefs]
    )
    |> Layout.settle()
  end

  @doc """
  Presses keys; a string is typed character by character. Effects are
  collected in `:effects_seen`; a macro run's keys are played next, as the
  shell plays them (`{:play, keys}`, then `:macro_done`).
  """
  def press(state, keys) do
    keys
    |> List.wrap()
    |> Enum.flat_map(fn
      text when is_binary(text) -> text |> String.graphemes() |> Enum.map(&{:char, &1})
      key -> [key]
    end)
    |> play(state)
  end

  defp play([], state), do: state

  defp play([key | keys], state) do
    {state, effects} = Update.handle(state, key)
    Process.put(:effects_seen, (Process.get(:effects_seen) || []) ++ effects)
    played = for {:play, played} <- effects, k <- played ++ [:macro_done], do: k
    play(played ++ keys, state)
  end

  @doc """
  Moves the highlight in the box on top to the setting labelled `label`
  as on the screen ("Also match", "Confirm assignments"), by pressing keys
  as a person would: HOME, then TAB (or ↓ where TAB does not move) until
  the highlighted value has that label just left of it, or just above it
  (a value under its label, as Assignment conditions). Raises when no
  setting has it, so a test fails at the step that went wrong.

  Tests reach settings by name, not by counting ↓ presses: a box's layout
  and keys change, its labels rarely do (CLAUDE.md).
  """
  def to_setting(state, label), do: state |> press(:home) |> seek(label, 80)

  defp seek(state, label, steps) do
    here = highlights(state)

    if Enum.any?(here, &labelled?(&1, label)) do
      state
    else
      # TAB goes on to the next setting in reading order; boxes that list
      # one setting a row and ignore TAB move with ↓. Neither moving
      # means the last setting was reached.
      moved =
        Enum.find_value([:tab, :down], fn key ->
          next = press(state, key)
          if highlights(next) != here, do: next
        end)

      if moved && steps > 0,
        do: seek(moved, label, steps - 1),
        else: raise("no setting labelled #{inspect(label)}:\n" <> screen(state))
    end
  end

  # the highlighted values on the screen, each as the text of its line and
  # the line above, and its column; a box beneath the one on top may show
  # its own highlight too
  defp highlights(state) do
    texts =
      state
      |> Render.render()
      |> Enum.map(fn line -> {line, Enum.map_join(line, &elem(&1, 1))} end)

    for {{line, text}, row} <- Enum.with_index(texts),
        {before, [{:box_selected, _} | _]} <- splits(line) do
      above = if row > 0, do: elem(Enum.at(texts, row - 1), 1), else: ""
      {text, above, before |> Enum.map_join(&elem(&1, 1)) |> String.length()}
    end
  end

  # each way to split a line before one of its segments
  defp splits(line), do: for(i <- 0..(length(line) - 1)//1, do: Enum.split(line, i))

  defp labelled?({text, above, column}, label) do
    left = text |> String.slice(0, column) |> String.replace(~r/[\s:]+$/, "")

    String.ends_with?(left, label) or
      String.starts_with?(String.slice(above, column..-1//1), label)
  end

  @doc """
  Opens the filter picker of the view (`:view`) or of the highlighted
  row's section (`:section`) the way Agenda does, through View Properties
  or Section Properties ▸ Filter; `close_props/1` leaves the box after.
  """
  def filter_picker(state, :view), do: state |> props(:view) |> to_setting("Filter") |> press(" ")

  def filter_picker(state, :section),
    do: state |> props(:section) |> to_setting("Filter") |> press(" ")

  @doc """
  Switches the View Properties setting labelled `label` ("Hide done items")
  and closes the box: one change, one undo step.
  """
  def switch_view_setting(state, label),
    do: state |> props(:view) |> to_setting(label) |> press([" ", :enter])

  @doc "Opens the Sort box of the view or the section, through its Properties ▸ Item sorting."
  def sort_box(state, scope),
    do: state |> props(scope) |> to_setting("Item sorting") |> press(" ")

  @doc "Opens View Properties (`:view`) or the section's Section Properties (`:section`)."
  def props(state, :view), do: press(state, [{:f, 10}, "v", "p"])
  def props(state, :section), do: press(state, [{:f, 10}, "v", "s", "p"])

  @doc """
  Back down to the View or Section Properties box with ESC (the boxes and
  pickers over it keep their changes, as Agenda's), then closes it with
  ENTER: ESC there would put back every change made in it.
  """
  def close_props(state) do
    case State.mode(state) do
      nil -> state
      %{type: type} when type in [:view_props, :section_props] -> press(state, :enter)
      _other -> state |> press(:esc) |> close_props()
    end
  end

  def effects, do: Process.get(:effects_seen) || []

  def screen(state), do: state |> Render.render() |> Draw.to_text()

  @doc """
  The text of the control panel (the two top lines) without the indicators
  and the time, its words joined by single spaces: a long question or message
  wraps there.
  """
  def panel(state) do
    state
    |> Render.render()
    |> Enum.take(2)
    |> Enum.map_join(" ", fn line ->
      line |> Enum.reject(&(elem(&1, 0) == :indicator)) |> Enum.map_join(&elem(&1, 1))
    end)
    |> String.split()
    |> Enum.join(" ")
  end

  @doc """
  The sample file with an empty Meetings that matches no text: with
  Agenda's Ignore suffixes (R16a) its name pulls in the items about a
  "meeting", which tests that use Meetings as an empty category do not want.
  """
  def quiet_meetings(db) do
    alias Agendum.Core
    meetings = hd(Agendum.Core.Database.find_categories(db, "Meetings"))
    db = Core.toggle_match_name(db, meetings)

    db
    |> Agendum.Core.Database.items_in(meetings)
    |> Enum.reduce(db, &Core.remove_from_category(&2, &1.id, meetings))
  end
end
