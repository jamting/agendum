defmodule Agendum.TUI.Template do
  @moduledoc """
  Box layouts written as they look on the screen. A layout is text in
  which a field is a name in square brackets; the brackets' width is the
  field's width:

      @layout \"""
       Category name: [name        ]   Type: [type    ]
       Note:          [note                           ]

       ESC closes
      \"""

  `render/3` fills in the values, each padded or cut (with …) to its
  field's width, so the columns line up by themselves; `fields/1` gives
  the fields in reading order, for the cursor. Text outside the fields is
  drawn in the box style.

    * a value is a string or a list of styled segments
    * `selected:` highlights that field's value (`:box_selected`)
    * `editing: {field, line_edit}` draws that field as the input line
    * a field whose value is `nil` leaves its whole row out
    * brackets that do not hold a field name (`[Yes]`) are plain text

  Pure.
  """

  alias Agendum.TUI.Draw

  @field ~r/\[[a-z_][a-z0-9_]* *\]/
  @field_name ~r/^\[([a-z_][a-z0-9_]*) *\]$/

  @typedoc "A value: text, or styled segments; nil leaves the row out."
  @type value :: String.t() | Draw.line() | nil

  @doc "The layout's lines, with `values` (a map from field name) filled in."
  @spec render(String.t(), %{atom => value}, keyword) :: [Draw.line()]
  def render(layout, values, opts \\ []) do
    layout
    |> rows()
    |> Enum.reject(&left_out?(&1, values))
    |> Enum.map(&row(&1, values, opts))
  end

  @doc "The layout's fields in reading order: left to right, top to bottom."
  @spec fields(String.t()) :: [atom]
  def fields(layout), do: for(row <- rows(layout), {:field, name, _} <- row, do: name)

  @doc """
  The layout's rows that have fields, each a keyword list of its fields and
  the column each starts at, for moving between them (`Agendum.TUI.BoxNav`).
  Only the fields in `shown` count: those the box hides are left out, and
  rows left without fields with them.
  """
  @spec grid(String.t(), [atom]) :: [[{atom, non_neg_integer}]]
  def grid(layout, shown) do
    layout
    |> rows()
    |> Enum.map(&placed(&1, shown))
    |> Enum.reject(&(&1 == []))
  end

  # a row's fields with their columns: the text and fields before each,
  # added up (`Enum.flat_map_reduce/3` carries the column along)
  defp placed(parts, shown) do
    {fields, _x} =
      Enum.flat_map_reduce(parts, 0, fn
        {:text, text}, x -> {[], x + String.length(text)}
        {:field, name, width}, x -> {if(name in shown, do: [{name, x}], else: []), x + width}
      end)

    fields
  end

  # each row: text and fields, {:text, text} | {:field, name, width}
  defp rows(layout) do
    layout
    |> String.trim_trailing("\n")
    |> String.split("\n")
    |> Enum.map(&parse/1)
  end

  defp parse(line) do
    @field
    |> Regex.split(line, include_captures: true)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn part ->
      case Regex.run(@field_name, part) do
        # layouts are written in the code, so their names are few and known
        # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
        [_, name] -> {:field, String.to_atom(name), String.length(part)}
        nil -> {:text, part}
      end
    end)
  end

  defp left_out?(parts, values),
    do: Enum.any?(parts, &match?({:field, name, _} when :erlang.map_get(name, values) == nil, &1))

  defp row(parts, values, opts) do
    Enum.flat_map(parts, fn
      {:text, text} -> [{:box, text}]
      {:field, name, width} -> field(name, width, Map.fetch!(values, name), opts)
    end)
  end

  defp field(name, width, value, opts) do
    case opts[:editing] do
      {^name, line} ->
        Draw.input(line, width, :edit)

      _ ->
        style = if opts[:selected] == name, do: :box_selected, else: :box
        fit(segments(value, style), width)
    end
  end

  # an empty selected value is one highlighted space, or the cursor would
  # vanish on it and the field look out of reach
  defp segments("", :box_selected), do: [{:box_selected, " "}]
  defp segments(text, style) when is_binary(text), do: [{style, text}]
  defp segments(segments, _style) when is_list(segments), do: segments

  # cut to `width` (the last character an ellipsis) and pad with the box style
  defp fit(segments, width) do
    if Draw.width(segments) > width do
      text = Enum.map_join(segments, fn {_, t} -> t end)
      {style, _} = hd(segments)
      [{style, Draw.truncate(text, width)}]
    else
      segments ++ [{:box, Draw.spaces(width - Draw.width(segments))}]
    end
  end
end
