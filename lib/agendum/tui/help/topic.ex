# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Help.Topic do
  @moduledoc """
  One help topic (ADR 0047; `docs/plans/archive/HELP.md`): a title and its body,
  as Agenda's help pages are. The body is a list of blocks, laid out to
  the help's width when it is drawn (`lines/2`):

    * `{:line, segments}`: a line as written, for a hand-written topic's
      own layout (PURPOSE, STEPS … in their columns);
    * `{:wrap, indent, text}`: plain text wrapped to the width, each line
      after `indent` (a string of spaces);
    * `{:hang, segments, width, text}`: `segments` in a left column
      `width` wide, then `text` wrapped beside it (a setting and what it
      does, a menu entry and its description);
    * `{:lines, fun}`: lines made for the width (`fun.(width)`), already
      segments: the key charts.

  A segment is `{:text, string}` or `{:link, label, target}`, a link to
  the topic titled `target` (shown as `label`, in bold, as Agenda's).
  Hand-written topics write a link `**label**` (to the topic of that
  title) or `**label|Target**`.

  `index` is where the Help Index lists the topic, as Agenda's keyword
  index (the owner's choice, 2026-10-26): `{heading, sub}` pairs, sub nil
  for the heading itself. A written topic gives them on `INDEX` lines,
  `INDEX  Add > Items; Items > Enter`, which are not shown. Pure.
  """

  alias Agendum.TUI.Terminal.Draw

  @type segment :: {:text, String.t()} | {:link, String.t(), String.t()}
  @type block ::
          {:line, [segment]}
          | {:wrap, String.t(), String.t()}
          | {:hang, [segment], pos_integer, String.t()}
          | {:lines, (pos_integer -> [[segment]])}

  @type entry :: {String.t(), String.t() | nil}
  @type t :: %__MODULE__{title: String.t(), body: [block], index: [entry]}

  defstruct title: "", body: [], index: []

  @doc "A topic from a hand-written text: its first line the title, the rest its body."
  @spec parse(String.t()) :: t
  def parse(text) do
    [title | body] = text |> String.trim_trailing() |> String.split("\n")
    # the blank line under the title belongs to the layout, not the body;
    # INDEX lines are for the Help Index, not shown
    {index, body} = Enum.split_with(body, &String.starts_with?(&1, "INDEX"))
    body = body |> Enum.drop_while(&(String.trim(&1) == "")) |> drop_trailing_blanks()

    %__MODULE__{
      title: String.trim(title),
      body: Enum.map(body, &{:line, segments(&1)}),
      index: Enum.flat_map(index, &entries/1)
    }
  end

  defp drop_trailing_blanks(lines),
    do: lines |> Enum.reverse() |> Enum.drop_while(&(String.trim(&1) == "")) |> Enum.reverse()

  # "INDEX  Add > Items; Items" is [{"Add", "Items"}, {"Items", nil}]
  defp entries(line) do
    line
    |> String.replace_prefix("INDEX", "")
    |> String.split(";", trim: true)
    |> Enum.map(fn entry ->
      case entry |> String.split(">") |> Enum.map(&String.trim/1) do
        [heading, sub] -> {heading, sub}
        [heading] -> {heading, nil}
      end
    end)
  end

  # `**label**` or `**label|Target**` become links; the rest stays text
  @link ~r/\*\*([^*|]+)(?:\|([^*]+))?\*\*/

  @doc "A line's segments, its `**links**` found."
  @spec segments(String.t()) :: [segment]
  def segments(line) do
    # `Regex.split/3` with `include_captures: true` keeps the links
    # between the plain parts, in order
    @link
    |> Regex.split(line, include_captures: true)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn part ->
      case Regex.run(@link, part) do
        [^part, label] -> {:link, label, label}
        [^part, label, target] -> {:link, label, target}
        _ -> {:text, part}
      end
    end)
  end

  @doc "Every link's target in the topic, in reading order (for the checks)."
  @spec targets(t, pos_integer) :: [String.t()]
  def targets(topic, width \\ 76) do
    for line <- lines(topic, width), {:link, _, target} <- line, do: target
  end

  @doc "The topic's body as lines of segments, `width` wide."
  @spec lines(t, pos_integer) :: [[segment]]
  def lines(%__MODULE__{body: body}, width), do: Enum.flat_map(body, &block(&1, width))

  defp block({:line, segments}, _width), do: [segments]

  defp block({:wrap, indent, text}, width) do
    text
    |> Draw.wrap(max(width - String.length(indent), 10))
    |> Enum.map(&[{:text, indent <> &1}])
  end

  defp block({:hang, segments, column, text}, width) do
    used = segments |> Enum.map_join(&label/1) |> String.length()
    pad = {:text, String.duplicate(" ", max(column - used, 1))}
    indent = String.duplicate(" ", column)

    # `Draw.wrap/2` always gives at least one line
    [first | rest] = Draw.wrap(text, max(width - column, 10))
    [segments ++ [pad, {:text, first}] | Enum.map(rest, &[{:text, indent <> &1}])]
  end

  defp block({:lines, fun}, width), do: fun.(width)

  @doc "What a segment shows."
  @spec label(segment) :: String.t()
  def label({:text, text}), do: text
  def label({:link, label, _target}), do: label
end
