defmodule Agendum.TUI.Help.Topic do
  @moduledoc """
  One help topic (ADR 0047; `docs/plans/HELP.md`): a title and its body,
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
  title) or `**label|Target**`. Pure.
  """

  alias Agendum.TUI.Terminal.Draw

  @type segment :: {:text, String.t()} | {:link, String.t(), String.t()}
  @type block ::
          {:line, [segment]}
          | {:wrap, String.t(), String.t()}
          | {:hang, [segment], pos_integer, String.t()}
          | {:lines, (pos_integer -> [[segment]])}

  @type t :: %__MODULE__{title: String.t(), body: [block]}

  defstruct title: "", body: []

  @doc "A topic from a hand-written text: its first line the title, the rest its body."
  @spec parse(String.t()) :: t
  def parse(text) do
    [title | body] = text |> String.trim_trailing() |> String.split("\n")
    # the blank line under the title belongs to the layout, not the body
    body = Enum.drop_while(body, &(String.trim(&1) == ""))
    %__MODULE__{title: String.trim(title), body: Enum.map(body, &{:line, segments(&1)})}
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
