defmodule Agenda.TUI.Keys do
  @moduledoc """
  Decodes raw terminal input into key events. Pure.

  Key events:
    * `{:char, "a"}` – printable text
    * `:enter`, `:tab`, `:shift_tab`, `:backspace`, `:delete`, `:insert`, `:esc`
    * `:up`, `:down`, `:left`, `:right`, `:home`, `:end`, `:pgup`, `:pgdn`
    * `:ctrl_left`, `:ctrl_right`, `:ctrl_up`, `:ctrl_down`, `:ctrl_pgup`, `:ctrl_pgdn`, `:ctrl_home`, `:ctrl_end`
    * `{:f, n}`, `{:alt_f, n}`, `{:shift_f, n}` – function keys
    * `{:alt, "d"}`, `{:ctrl, "a"}`

  Because many terminals (and macOS laptops) make function keys awkward,
  ESC/ALT followed by a digit is decoded as the matching function key
  (`Alt-1` = F1 ... `Alt-0` = F10), and ESC/ALT followed by `!`..`)`
  (shifted digits) as ALT-F1..ALT-F10.
  """

  @csi_tilde %{
    "1" => :home,
    "2" => :insert,
    "3" => :delete,
    "4" => :end,
    "5" => :pgup,
    "6" => :pgdn,
    "7" => :home,
    "8" => :end,
    "11" => {:f, 1},
    "12" => {:f, 2},
    "13" => {:f, 3},
    "14" => {:f, 4},
    "15" => {:f, 5},
    "17" => {:f, 6},
    "18" => {:f, 7},
    "19" => {:f, 8},
    "20" => {:f, 9},
    "21" => {:f, 10},
    "23" => {:f, 11},
    "24" => {:f, 12}
  }

  @csi_letter %{
    "A" => :up,
    "B" => :down,
    "C" => :right,
    "D" => :left,
    "H" => :home,
    "F" => :end,
    "P" => {:f, 1},
    "Q" => {:f, 2},
    "R" => {:f, 3},
    "S" => {:f, 4},
    "Z" => :shift_tab
  }

  @shifted_digits %{
    "!" => 1,
    "@" => 2,
    "#" => 3,
    "$" => 4,
    "%" => 5,
    "^" => 6,
    "&" => 7,
    "*" => 8,
    "(" => 9,
    ")" => 10
  }

  # macOS Option+letter without "Option as Meta"
  @mac_option %{
    "∂" => "d",
    "®" => "r",
    "¬" => "l",
    "†" => "t",
    "∑" => "w",
    "–" => "-",
    "≠" => "="
  }

  @doc """
  Decodes as many complete keys as possible.

  Returns `{keys, rest}`; `rest` is an incomplete escape sequence that
  should be completed by further input, or flushed with `flush/1` after a
  short timeout (a lone ESC press).
  """
  @spec decode(String.t()) :: {[term], String.t()}
  def decode(input), do: decode(input, [])

  defp decode("", acc), do: {Enum.reverse(acc), ""}

  defp decode("\e" <> _ = input, acc) do
    case escape(input) do
      {:ok, key, rest} -> decode(rest, [key | acc])
      :incomplete -> {Enum.reverse(acc), input}
    end
  end

  defp decode(<<c, rest::binary>>, acc) when c in [?\r, ?\n], do: decode(rest, [:enter | acc])
  defp decode(<<?\t, rest::binary>>, acc), do: decode(rest, [:tab | acc])
  defp decode(<<c, rest::binary>>, acc) when c in [127, 8], do: decode(rest, [:backspace | acc])
  defp decode(<<0, rest::binary>>, acc), do: decode(rest, acc)

  defp decode(<<c, rest::binary>>, acc) when c in 1..26,
    do: decode(rest, [{:ctrl, <<c + ?a - 1>>} | acc])

  defp decode(<<c, rest::binary>>, acc) when c in 28..31, do: decode(rest, acc)

  defp decode(input, acc) do
    case String.next_grapheme(input) do
      {g, rest} when is_map_key(@mac_option, g) -> decode(rest, [{:alt, @mac_option[g]} | acc])
      {g, rest} -> decode(rest, [{:char, g} | acc])
      nil -> {Enum.reverse(acc), ""}
    end
  end

  @doc "Turns leftover input (after a timeout) into keys: a lone ESC is the Escape key."
  @spec flush(String.t()) :: [term]
  def flush(""), do: []

  def flush("\e" <> rest) do
    {keys, rest} = decode(rest)
    [:esc | keys] ++ flush(rest)
  end

  def flush(other), do: other |> decode() |> elem(0)

  # --- escape sequences -------------------------------------------------------

  defp escape("\e"), do: :incomplete
  defp escape("\e[" <> rest), do: csi(rest)
  defp escape("\eO"), do: :incomplete

  defp escape("\eO" <> <<c, rest::binary>>) do
    case Map.fetch(@csi_letter, <<c>>) do
      {:ok, key} -> {:ok, key, rest}
      :error -> {:ok, {:alt, "O"}, <<c, rest::binary>>}
    end
  end

  # ESC ESC <seq> is how some terminals send ALT + special key.
  defp escape("\e\e" <> rest = input) do
    case escape("\e" <> rest) do
      {:ok, key, rest} ->
        {:ok, altify(key), rest}

      :incomplete ->
        if rest == "",
          do: :incomplete,
          else: {:ok, :esc, binary_part(input, 1, byte_size(input) - 1)}
    end
  end

  defp escape("\e" <> <<c, rest::binary>>) when c in ?0..?9 do
    {:ok, {:f, if(c == ?0, do: 10, else: c - ?0)}, rest}
  end

  defp escape("\e" <> rest) do
    case String.next_grapheme(rest) do
      {g, rest} when is_map_key(@shifted_digits, g) -> {:ok, {:alt_f, @shifted_digits[g]}, rest}
      {"\r", rest} -> {:ok, {:alt, :enter}, rest}
      {"\d", rest} -> {:ok, {:alt, :backspace}, rest}
      {g, rest} -> {:ok, {:alt, String.downcase(g)}, rest}
    end
  end

  defp csi(rest) do
    case Regex.run(~r/^([0-9;]*)([A-Za-z~])/, rest) do
      [match, params, final] ->
        rest = binary_part(rest, byte_size(match), byte_size(rest) - byte_size(match))
        {:ok, csi_key(String.split(params, ";", trim: true), final), rest}

      nil ->
        # Incomplete if it could still become a valid sequence
        if Regex.match?(~r/^[0-9;]*$/, rest), do: :incomplete, else: {:ok, :esc, "[" <> rest}
    end
  end

  defp csi_key([code | mods], "~"), do: modify(Map.get(@csi_tilde, code, :unknown), mods)

  defp csi_key(params, letter),
    do: modify(Map.get(@csi_letter, letter, :unknown), Enum.drop(params, 1))

  # xterm modifier parameter: 2 shift, 3 alt, 5 ctrl (bitmask + 1)
  defp modify(key, []), do: key

  defp modify(key, [mod | _]) do
    bits = String.to_integer(mod) - 1

    cond do
      Bitwise.band(bits, 4) != 0 -> ctrlify(key)
      Bitwise.band(bits, 2) != 0 -> altify(key)
      Bitwise.band(bits, 1) != 0 -> shiftify(key)
      true -> key
    end
  end

  defp altify({:f, n}), do: {:alt_f, n}
  defp altify(key) when is_atom(key), do: {:alt, key}
  defp altify(key), do: key

  defp shiftify({:f, n}), do: {:shift_f, n}
  defp shiftify(key), do: key

  defp ctrlify(key) when key in [:left, :right, :up, :down, :pgup, :pgdn, :home, :end],
    do: String.to_atom("ctrl_#{key}")

  defp ctrlify(key), do: key
end
