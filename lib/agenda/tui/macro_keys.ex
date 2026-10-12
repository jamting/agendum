defmodule Agenda.TUI.MacroKeys do
  @moduledoc """
  Keystrokes as macro text, in Agenda's notation, and back (SPEC R50;
  Working with Macros 1-12 to 1-14): text is itself (`Hello`); other keys
  are names in braces: `{ENTER}`, `{F10}`, `{AltF2}`, `{ShfF4}`, `{AltD}`,
  `{CtlN}`, `{CtlLeft}`, `{PGDN}` … Names are read in any case. As in
  Agenda, a misspelt name is typed as written, line breaks are not keys,
  and the spaces that start a continuation line are left out (the end of a
  line keeps its spaces). Ours: `{LBRACE}` and `{RBRACE}` type braces, and
  keys Agenda had no name for get one in its style (`{AltBS}`, `{AltShfD}`).

  Pure; the key events are `Agenda.TUI.Keys`'.
  """

  @names %{
    enter: "ENTER",
    tab: "TAB",
    shift_tab: "ShfTAB",
    backspace: "BS",
    delete: "DEL",
    insert: "INS",
    esc: "ESC",
    up: "UP",
    down: "DOWN",
    left: "LEFT",
    right: "RIGHT",
    home: "HOME",
    end: "END",
    pgup: "PGUP",
    pgdn: "PGDN",
    ctrl_left: "CtlLeft",
    ctrl_right: "CtlRight",
    ctrl_up: "CtlUp",
    ctrl_down: "CtlDown",
    ctrl_pgup: "CtlPGUP",
    ctrl_pgdn: "CtlPGDN",
    ctrl_home: "CtlHome",
    ctrl_end: "CtlEnd"
  }
  @by_name Map.new(@names, fn {key, name} -> {String.downcase(name), key} end)

  @doc "The text of a series of keys; keys without a name are left out."
  @spec encode([term]) :: String.t()
  def encode(keys), do: Enum.map_join(keys, &name/1)

  defp name({:char, "{"}), do: "{LBRACE}"
  defp name({:char, "}"}), do: "{RBRACE}"
  defp name({:char, c}), do: c
  defp name({:f, n}), do: "{F#{n}}"
  defp name({:alt_f, n}), do: "{AltF#{n}}"
  defp name({:shift_f, n}), do: "{ShfF#{n}}"
  defp name({:ctrl, c}), do: "{Ctl#{String.upcase(c)}}"
  defp name({:alt, key}) when is_atom(key) and is_map_key(@names, key), do: "{Alt#{@names[key]}}"

  defp name({:alt, c}) when is_binary(c) do
    if c =~ ~r/^\p{Lu}$/u and String.downcase(c) != c,
      do: "{AltShf#{c}}",
      else: "{Alt#{String.upcase(c)}}"
  end

  defp name(key) when is_map_key(@names, key), do: "{#{@names[key]}}"
  defp name(_unknown), do: ""

  @doc "The keys of a macro's text."
  @spec decode(String.t()) :: [term]
  def decode(text) do
    [first | rest] = String.split(text, ~r/\r?\n/)

    [first | Enum.map(rest, &String.trim_leading(&1, " "))]
    |> Enum.join()
    |> String.graphemes()
    |> keys([])
  end

  defp keys([], acc), do: Enum.reverse(acc)

  defp keys(["{" | rest], acc) do
    {inside, after_} = Enum.split_while(rest, &(&1 not in ["}", "{"]))

    case {after_, inside != [] && key_named(Enum.join(inside))} do
      {["}" | rest], key} when key not in [nil, false] -> keys(rest, [key | acc])
      _ -> keys(rest, [{:char, "{"} | acc])
    end
  end

  defp keys([c | rest], acc), do: keys(rest, [{:char, c} | acc])

  # a name in braces, or nil
  defp key_named(name) do
    lower = String.downcase(name)

    cond do
      lower == "lbrace" -> {:char, "{"}
      lower == "rbrace" -> {:char, "}"}
      Map.has_key?(@by_name, lower) -> @by_name[lower]
      true -> numbered(lower) || modified(name, lower)
    end
  end

  defp numbered(lower) do
    case Regex.run(~r/^(f|altf|shff)(\d{1,2})$/, lower) do
      [_, "f", n] -> {:f, String.to_integer(n)}
      [_, "altf", n] -> {:alt_f, String.to_integer(n)}
      [_, "shff", n] -> {:shift_f, String.to_integer(n)}
      nil -> nil
    end
  end

  defp modified(name, lower) do
    cond do
      Map.has_key?(@by_name, String.replace_prefix(lower, "alt", "")) and lower != "alt" ->
        {:alt, @by_name[String.replace_prefix(lower, "alt", "")]}

      match?([_], lower |> String.replace_prefix("altshf", "") |> String.graphemes()) and
          String.starts_with?(lower, "altshf") ->
        {:alt, name |> String.slice(6..-1//1) |> String.upcase()}

      match?([_], lower |> String.replace_prefix("alt", "") |> String.graphemes()) and
          String.starts_with?(lower, "alt") ->
        {:alt, String.slice(lower, 3..-1//1)}

      String.starts_with?(lower, "ctl") and String.length(lower) == 4 ->
        {:ctrl, String.slice(lower, 3..-1//1)}

      true ->
        nil
    end
  end

  @doc """
  A single key typed for Attach to key: `{:ok, its text, the key}`, the
  text in the notation's own spelling; :error unless exactly one key.
  """
  @spec key(String.t()) :: {:ok, String.t(), term} | :error
  def key(text) do
    case decode(String.trim(text)) do
      [key] -> {:ok, name(key), key}
      _ -> :error
    end
  end
end
