defmodule Agendum.TUI.HelpLayoutTest do
  @moduledoc """
  The help screen's frame (R65c): every page has the same heading, a line
  under it and a rule; the command list (F1 `c`) has a fixed pane of five
  lines at the foot, with the highlighted command's longer text (← →
  page through a text that does not fit) and why it cannot run now, so
  the list above it does not move as the highlight moves.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Starters.Planner
  alias Agendum.TUI.{HelpScreen, State}

  @today ~D[2026-10-12]

  setup do
    db = Planner.build() |> Planner.with_samples(@today)
    %{state: start(db, today: @today, height: 30, width: 90)}
  end

  # the help screen's body, as text lines, and as styled segments
  defp body(state), do: Enum.map(styled(state), fn l -> Enum.map_join(l, &elem(&1, 1)) end)
  defp styled(state), do: HelpScreen.lines(state, State.mode(state))

  defp line_with(state, text), do: Enum.find_index(body(state), &(&1 =~ text))

  describe "the frame of every page" do
    test "a heading, a line under it, then a rule", %{state: state} do
      for keys <- [[{:f, 1}], [{:f, 1}, "c"], [{:f, 1}, "d"], [{:f, 1}, "a"]] do
        [heading, _sub, rule | _] = body(press(state, keys))
        assert heading =~ ~r/^ (HELP|COMMANDS|DESCRIBE KEY|ALL KEYS)/
        assert rule =~ ~r/^ ─+$/u
      end
    end

    test "the heading has a colour of its own", %{state: state} do
      [[{style, _} | _] | _] = styled(press(state, {:f, 1}))
      assert style == :help_title
    end

    test "the heading stays while the page scrolls", %{state: state} do
      scrolled = press(state, [{:f, 1}, "a", :pgdn])
      assert hd(body(scrolled)) =~ "ALL KEYS"
      refute Enum.at(body(scrolled), 3) == Enum.at(body(press(state, [{:f, 1}, "a"])), 3)
    end
  end

  describe "the command list's pane" do
    test "five lines at the foot, under a rule", %{state: state} do
      listed = press(state, [{:f, 1}, "c"])
      lines = body(listed)
      assert length(lines) == elem(HelpScreen.size(listed), 1)
      assert Enum.at(lines, -6) =~ ~r/^ ─/
      assert Enum.at(lines, -5) =~ ~r/^ Up · ↑/
    end

    test "it has the highlighted command's text; the rows under it stay put",
         %{state: state} do
      listed = press(state, [{:f, 1}, "c", "remove"])
      assert Enum.take(body(listed), -5) |> Enum.join() =~ "Takes the item out of this"
      # the row under Remove is Yank, not the text
      remove = line_with(listed, ~r/^ Remove /)
      assert Enum.at(body(listed), remove + 1) =~ ~r/^ Yank /

      at_top = press(state, [{:f, 1}, "c"])
      moved = press(at_top, [:down, :down, :down])
      assert line_with(at_top, ~r/^ Edit /) == line_with(moved, ~r/^ Edit /)
    end

    test "a command without a longer text shows its summary there", %{state: state} do
      pane = state |> press([{:f, 1}, "c"]) |> body() |> Enum.take(-4) |> Enum.join()
      assert pane =~ "Highlight the row above"
    end

    test "the pane has colours of its own", %{state: state} do
      lines = styled(press(state, [{:f, 1}, "c"]))
      assert hd(Enum.at(lines, -5)) |> elem(0) == :help_pane_title
      assert hd(Enum.at(lines, -4)) |> elem(0) == :help_pane
    end

    test "why it cannot run now is on its first line", %{state: state} do
      listed = press(state, [:down, {:f, 1}, "c", "yank"])
      assert Enum.at(body(listed), -5) =~ ~r/Yank · ALT-Y +Not now: No removed item to yank back/
      assert Enum.any?(Enum.at(styled(listed), -5), &(elem(&1, 0) == :error))
    end

    test "→ and ← page through a text longer than the pane", %{state: state} do
      narrow = %{state | width: 50}
      listed = press(narrow, [{:f, 1}, "c", "remove"])
      first = Enum.take(body(listed), -4)
      [_, pages] = Regex.run(~r{← → 1/(\d)}u, Enum.at(body(listed), -6))
      pages = String.to_integer(pages)
      assert pages >= 2

      next = press(listed, :right)
      assert Enum.take(body(next), -4) != first
      assert Enum.at(body(next), -6) =~ "← → 2/#{pages}"

      last = press(listed, List.duplicate(:right, pages + 2))
      assert Enum.at(body(last), -6) =~ "← → #{pages}/#{pages}"
      assert press(next, :left) |> body() |> Enum.take(-4) == first
    end

    test "moving the highlight starts the next text at its beginning", %{state: state} do
      narrow = %{state | width: 50}
      moved = press(narrow, [{:f, 1}, "c", "re", :down, :down, :right, :up, :down])
      assert State.mode(moved).pane == 0
    end

    test "the list scrolls only when the highlight reaches its edge", %{state: state} do
      listed = press(state, [{:f, 1}, "c"])
      rows = elem(HelpScreen.size(listed), 1) - 9
      down = press(listed, List.duplicate(:down, rows + 3))
      first = Enum.at(body(down), 3)
      refute first =~ ~r/^ Up /
      # going back up a row does not move the list
      assert Enum.at(body(press(down, :up)), 3) == first
      assert Enum.at(body(down), -6) =~ "more"
    end

    test "a summary too long for the screen ends in …", %{state: state} do
      narrow = %{state | width: 60}
      lines = body(press(narrow, [{:f, 1}, "c"]))
      assert Enum.any?(lines, &String.ends_with?(&1, "…"))
      assert Enum.all?(lines, &(String.length(&1) <= 60))
    end

    test "the key bar names ← →", %{state: state} do
      assert screen(press(state, [{:f, 1}, "c"])) =~ "← → More"
    end
  end
end
