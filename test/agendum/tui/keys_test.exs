defmodule Agendum.TUI.KeysTest do
  use ExUnit.Case, async: true

  alias Agendum.TUI.Terminal.Keys

  test "decodes printable text, including multi-byte characters" do
    assert Keys.decode("hå!") == {[{:char, "h"}, {:char, "å"}, {:char, "!"}], ""}
  end

  test "decodes control keys" do
    assert Keys.decode("\r\t\d\x04") == {[:enter, :tab, :backspace, {:ctrl, "d"}], ""}
  end

  test "decodes function keys in both xterm styles" do
    assert Keys.decode("\eOP\eOS\e[15~\e[21~") == {[{:f, 1}, {:f, 4}, {:f, 5}, {:f, 10}], ""}
  end

  test "decodes modified keys" do
    assert Keys.decode("\e[1;3S\e[21;3~\e[1;5D\e[5;5~\e[1;3A") ==
             {[{:alt_f, 4}, {:alt_f, 10}, :ctrl_left, :ctrl_pgup, {:alt, :up}], ""}
  end

  test "decodes navigation keys" do
    assert Keys.decode("\e[A\e[B\e[H\e[F\e[2~\e[3~\e[6~\e[Z") ==
             {[:up, :down, :home, :end, :insert, :delete, :pgdn, :shift_tab], ""}
  end

  # Function keys are required (ADR 0032): ESC + digit is no stand-in for F9,
  # just ALT-9, and ESC + shifted digit no stand-in for ALT-F4.
  test "ESC + digit or shifted digit is an ALT key, not a function key" do
    assert Keys.decode("\e9\e0\e$") == {[{:alt, "9"}, {:alt, "0"}, {:alt, "$"}], ""}
  end

  test "Option-as-Meta + function key (ESC before the F-key's sequence) is ALT-Fn" do
    assert Keys.decode("\e\eOS\e\e[21~") == {[{:alt_f, 4}, {:alt_f, 10}], ""}
  end

  test "ALT + letter, including macOS Option characters" do
    assert Keys.decode("\ed∂") == {[{:alt, "d"}, {:alt, "d"}], ""}
  end

  test "incomplete sequences are kept for later, and a lone ESC flushes as :esc" do
    assert Keys.decode("a\e[1") == {[{:char, "a"}], "\e[1"}
    assert Keys.decode("\e") == {[], "\e"}
    assert Keys.flush("\e") == [:esc]
  end

  test "⌘↑ / ⌘↓ mappings (CTRL-HOME / CTRL-END) decode" do
    assert Keys.decode("\e[1;5H\e[1;5F") == {[:ctrl_home, :ctrl_end], ""}
  end

  test "ALT-minus and ALT-equals, also as macOS Option characters" do
    assert Keys.decode("\e-\e=–≠") == {[{:alt, "-"}, {:alt, "="}, {:alt, "-"}, {:alt, "="}], ""}
  end
end
