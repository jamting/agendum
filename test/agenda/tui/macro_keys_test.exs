defmodule Agenda.TUI.MacroKeysTest do
  @moduledoc "Keystrokes as macro text in Agenda's notation, and back (R50; Working with Macros 1-12 to 1-14)."
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Agenda.TUI.MacroKeys

  test "text as typed, other keys by name in braces" do
    keys = [{:f, 10}, {:char, "v"}, {:char, "c"}, :enter, {:char, "H"}, {:char, "i"}, {:alt_f, 2}]
    assert MacroKeys.encode(keys) == "{F10}vc{ENTER}Hi{AltF2}"
    assert MacroKeys.decode("{F10}vc{ENTER}Hi{AltF2}") == keys
  end

  test "Agenda's names for the special keys" do
    pairs = [
      {:tab, "{TAB}"},
      {:shift_tab, "{ShfTAB}"},
      {:backspace, "{BS}"},
      {:delete, "{DEL}"},
      {:insert, "{INS}"},
      {:esc, "{ESC}"},
      {:up, "{UP}"},
      {:pgdn, "{PGDN}"},
      {:ctrl_left, "{CtlLeft}"},
      {:ctrl_pgup, "{CtlPGUP}"},
      {:ctrl_home, "{CtlHome}"},
      {{:shift_f, 4}, "{ShfF4}"},
      {{:alt, "d"}, "{AltD}"},
      {{:alt, "-"}, "{Alt-}"},
      {{:ctrl, "n"}, "{CtlN}"},
      {{:char, "{"}, "{LBRACE}"},
      {{:char, "}"}, "{RBRACE}"},
      {{:char, " "}, " "}
    ]

    for {key, text} <- pairs do
      assert MacroKeys.encode([key]) == text
      assert MacroKeys.decode(text) == [key]
    end
  end

  test "names in any case; line breaks and the spaces that start a line are left out" do
    assert MacroKeys.decode("{f10}{altf2}{enter}{ctln}") ==
             [{:f, 10}, {:alt_f, 2}, :enter, {:ctrl, "n"}]

    assert MacroKeys.decode("{F10}\n    vc\n  {ENTER}  ") ==
             [{:f, 10}, {:char, "v"}, {:char, "c"}, :enter, {:char, " "}, {:char, " "}]
  end

  test "a misspelt name or a lone brace is typed as written, as in Agenda" do
    assert MacroKeys.decode("{ENTRE}") == Enum.map(String.graphemes("{ENTRE}"), &{:char, &1})
    assert MacroKeys.decode("a{b") == [{:char, "a"}, {:char, "{"}, {:char, "b"}]
  end

  test "keys the decoder could not name are left out" do
    assert MacroKeys.encode([:unknown, {:char, "x"}]) == "x"
  end

  test "a single key: what an attached key is" do
    assert MacroKeys.key("{shff4}") == {:ok, "{ShfF4}", {:shift_f, 4}}
    assert MacroKeys.key("x") == {:ok, "x", {:char, "x"}}
    assert MacroKeys.key("{F4}{F5}") == :error
    assert MacroKeys.key("") == :error
  end

  defp key do
    one_of([
      map(string(:printable, length: 1), &{:char, &1}),
      member_of([:enter, :tab, :shift_tab, :backspace, :delete, :insert, :esc, :up, :down]),
      member_of([:left, :right, :home, :end, :pgup, :pgdn, :ctrl_left, :ctrl_right, :ctrl_up]),
      member_of([:ctrl_down, :ctrl_pgup, :ctrl_pgdn, :ctrl_home, :ctrl_end]),
      map(integer(1..12), &{:f, &1}),
      map(integer(1..10), &{:alt_f, &1}),
      map(integer(1..10), &{:shift_f, &1}),
      map(member_of(Enum.map(?a..?z, &<<&1>>) ++ ["-", "=", "?", "D"]), &{:alt, &1}),
      map(member_of(Enum.map(?a..?z, &<<&1>>)), &{:ctrl, &1}),
      member_of([{:alt, :backspace}, {:alt, :left}])
    ])
  end

  property "any keys come back from their text" do
    check all(keys <- list_of(key(), max_length: 30)) do
      # a newline typed as text is a key of its own; and a combining mark
      # (an accent) joins the character before it, as a keyboard sends it
      keys =
        Enum.reject(keys, fn
          {:char, c} -> c in ["\n", "\r", "\t"] or String.graphemes("a" <> c) != ["a", c]
          _ -> false
        end)

      assert MacroKeys.decode(MacroKeys.encode(keys)) == keys
    end
  end
end
