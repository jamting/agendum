# SPDX-License-Identifier: AGPL-3.0-only
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

  # CTRL-F1 … F4 come as `ESC [1;5P` … `S`, F5 and up as `ESC [15;5~` …;
  # Agenda's CtlF keys, for macros (Working with Macros, 1-12)
  test "CTRL and a function key is a key of its own, not the plain F-key" do
    assert Keys.decode("\e[1;5P\e[1;5S\e[15;5~\e[21;5~") ==
             {[{:ctrl_f, 1}, {:ctrl_f, 4}, {:ctrl_f, 5}, {:ctrl_f, 10}], ""}
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

  test "a read may end anywhere: a cut character or ALT-sequence waits for its rest" do
    # å is two bytes, ∂ (Option-d, ALT-d) three
    assert Keys.decode("aå" |> binary_part(0, 2)) == {[{:char, "a"}], <<0xC3>>}
    assert Keys.decode(<<0xE2, 0x88>>) == {[], <<0xE2, 0x88>>}
    assert Keys.decode(<<0xE2, 0x88, 0x82>>) == {[{:alt, "d"}], ""}
    # ESC ESC [ A is ALT-↑ (Option-as-Meta)
    assert Keys.decode("\e\e[") == {[], "\e\e["}
    assert Keys.decode("\e\e[A") == {[{:alt, :up}], ""}
    # never completed: the bytes as they came
    assert Keys.flush(<<0xC3>>) == [{:char, <<0xC3>>}]
    assert Keys.flush("\e\e[") == [:esc, :esc, {:char, "["}]
  end

  test "⌘↑ / ⌘↓ mappings (CTRL-HOME / CTRL-END) decode" do
    assert Keys.decode("\e[1;5H\e[1;5F") == {[:ctrl_home, :ctrl_end], ""}
  end

  test "ALT-minus and ALT-equals, also as macOS Option characters" do
    assert Keys.decode("\e-\e=–≠") == {[{:alt, "-"}, {:alt, "="}, {:alt, "-"}, {:alt, "="}], ""}
  end
end

defmodule Agendum.TUI.KeysPropertyTest do
  @moduledoc """
  Keys arrive in pieces: the terminal may hand over an arrow's ESC and its
  `[B` in two reads (the debug logs show it on almost every arrow). The
  reader (`IO.getn/2`, Unicode) never cuts a character in two today, but
  `Keys` does not rely on it, so the cuts here fall anywhere. `App` keeps what `Keys.decode/1` could not finish and
  puts the next read after it; this checks that loop, which the fuzz test
  (handing `Update` ready-made keys) never reaches.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Agendum.TUI.Terminal.Keys

  # what keys send: text (å is two bytes), control keys, arrows, function
  # keys in both styles, modified keys, ALT-letters and macOS Option keys
  @sends [
    "a",
    "Z",
    "1",
    " ",
    "å",
    "ö",
    "\r",
    "\t",
    "\d",
    "\x04",
    "\e[A",
    "\e[B",
    "\e[1;5H",
    "\eOP",
    "\e[15~",
    "\e[21~",
    "\e[1;3A",
    "\ex",
    "\ed",
    "\e\e[A",
    "∂",
    "\e[3~"
  ]

  # App's loop: each read is put after what was left unfinished
  defp in_pieces(pieces) do
    {keys, rest} =
      Enum.reduce(pieces, {[], ""}, fn piece, {keys, buffer} ->
        {new, rest} = Keys.decode(buffer <> piece)
        {keys ++ new, rest}
      end)

    keys ++ Keys.flush(rest)
  end

  # cuts a binary at the given byte positions (anywhere, even inside a
  # character or an escape sequence)
  defp cut(bytes, cuts) do
    cuts
    |> Enum.map(&rem(&1, byte_size(bytes) + 1))
    |> Enum.uniq()
    |> Enum.sort()
    |> then(&Enum.zip([0 | &1], &1 ++ [byte_size(bytes)]))
    |> Enum.map(fn {from, to} -> binary_part(bytes, from, to - from) end)
  end

  property "keys cut into pieces anywhere decode as the whole" do
    check all(
            sends <- list_of(member_of(@sends), min_length: 1, max_length: 30),
            cuts <- list_of(non_negative_integer(), max_length: 10)
          ) do
      bytes = Enum.join(sends)
      assert in_pieces(cut(bytes, cuts)) == in_pieces([bytes])
    end
  end
end
