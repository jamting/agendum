defmodule Agenda.TUI.QuestionBoxTest do
  @moduledoc """
  Yes/No questions in a box, as Agenda (screenshots 36, 141): the question
  with its answer highlighted, "Press ENTER to accept, ESC to cancel".
  """
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.Core.Database
  alias Agenda.TUI.{Render, State}

  setup do
    state = start(Agenda.Sample.build(~D[2026-10-08]), width: 80, height: 25)
    # ALT-F4 on the first item: discard it from the whole file?
    asked = press(state, [:down, {:alt_f, 4}])
    %{state: state, asked: asked, count: length(Database.items(state.db))}
  end

  defp answer(state) do
    for line <- Render.render(state), {:box_selected, text} <- line, do: String.trim(text)
  end

  test "the question is a box with its answer, Yes, highlighted", %{asked: asked} do
    assert %{type: :confirm} = State.mode(asked)
    text = screen(asked)
    assert text =~ "Discard this item from the whole file?"
    refute text =~ "(Y/N)"
    assert text =~ "Press ENTER to accept, ESC to cancel"
    assert answer(asked) == ["Yes"]
  end

  test "ENTER accepts the answer shown", %{asked: asked, count: count} do
    assert length(Database.items(press(asked, :enter).db)) == count - 1
  end

  test "SPACE switches it to No, and ENTER then does nothing", %{asked: asked, count: count} do
    no = press(asked, " ")
    assert answer(no) == ["No"]
    done = press(no, :enter)
    assert done.modes == []
    assert length(Database.items(done.db)) == count
  end

  test "Y and N answer at once; ESC cancels", %{asked: asked, count: count} do
    assert length(Database.items(press(asked, "y").db)) == count - 1
    assert length(Database.items(press(asked, "n").db)) == count
    assert press(asked, :esc).modes == []
  end

  test "the control panel says what to do", %{asked: asked} do
    assert panel(asked) =~ "SPACE switches"
  end

  test "a long question wraps in the box", %{state: state} do
    state = %{state | width: 50}
    asked = press(state, [:down, {:alt_f, 4}])
    lines = asked |> screen() |> String.split("\n")
    assert Enum.any?(lines, &(&1 =~ "Discard this item from the"))
    assert Enum.all?(lines, &(String.length(&1) <= 50))
  end
end
