defmodule Agendum.TUI.BoxChoicesTest do
  @moduledoc """
  Choosing a setting's value as Agenda (User's Guide 2-17): the first
  letter of a choice picks it, and F3 lists the choices.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.TUI.{History, State}

  setup do
    %{state: start(Agendum.Sample.build(~D[2026-10-08]), width: 80, height: 30)}
  end

  # File ▸ Properties ▸ Global date settings ▸ Display format
  defp display_format(state), do: press(state, [{:f, 10}, "f", "p", :down, :down, " ", " "])

  # Date format, the third row
  defp date_format(state), do: press(display_format(state), [:down, :down])

  test "a letter picks the next choice that starts with it", %{state: state} do
    state = date_format(state)
    assert state.db.date_format.order == :yyyymmdd

    state = press(state, "r")
    assert state.db.date_format.order == :relative
    assert screen(state) =~ ~r/Date format +: Relative/

    # again: the next one starting with R
    assert press(state, "r").db.date_format.order == :relative_number
    # upper case is the same
    assert press(state, "R").db.date_format.order == :relative_number
  end

  test "picking by letter is one change, one undo step", %{state: state} do
    state = date_format(state)
    picked = press(state, "r")
    assert History.undo(picked).db.date_format.order == :yyyymmdd
  end

  test "a letter no choice starts with says so and changes nothing", %{state: state} do
    state = date_format(state)
    after_ = press(state, "q")
    assert after_.db == state.db
    assert panel(after_) =~ "No choice starts with Q"
  end

  test "on a setting that is typed, letters are typed as before", %{state: state} do
    # Column Properties: Column head takes a typed name
    state = press(state, [:down, :right, {:f, 10}, "v", "c", "p", "x"])
    assert %{type: :column_props, typing: {:head, _}} = State.mode(state)
  end

  test "F3, then ENTER on the choice already set, changes nothing", %{state: state} do
    state = date_format(state)
    chosen = press(state, [{:f, 3}, :enter])
    assert chosen.db.date_format.order == :yyyymmdd
  end

  test "F3 lists the choices; ENTER takes the highlighted one", %{state: state} do
    state = press(date_format(state), {:f, 3})
    assert %{type: :choice_list} = State.mode(state)
    text = screen(state)
    assert text =~ "Choices: Date format"
    assert text =~ "YYYYMMDD"
    assert text =~ "Relative"
    # a narrow box: Agenda's words, shortened
    assert text =~ "ENTER accept · ESC cancel"

    state = press(state, [:down, :down, :enter])
    assert state.db.date_format.order == :yyyyddmm
    assert %{type: :display_format} = State.mode(state)
  end

  test "ESC leaves the list and changes nothing", %{state: state} do
    state = date_format(state)
    after_ = press(state, [{:f, 3}, :down, :esc])
    assert after_.db == state.db
    assert %{type: :display_format} = State.mode(after_)
  end

  test "F3 on a setting without a list of choices leaves it to the box", %{state: state} do
    # Global date settings ▸ Morning is typed: no list
    state =
      press(state, [{:f, 10}, "f", "p"])
      |> to_setting("Global date settings")
      |> press(" ")
      |> to_setting("Morning")

    assert %{type: :date_settings} = State.mode(press(state, {:f, 3}))
  end

  test "in Customize, a letter picks a theme and saves it", %{state: state} do
    state = %{state | prefs: %Agendum.Preferences{path: "/prefs"}}
    state = press(state, [{:f, 10}, "u", "c"])
    {state, effects} = Agendum.TUI.Update.handle(state, {:char, "z"})
    assert state.theme == :zenburn
    # saved once, as it is now
    assert [{:save_preferences, "/prefs", %{theme: :zenburn}}] = effects
  end
end
