# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Typing.LineEdit do
  @moduledoc """
  A pure single-line text editing buffer (EDIT mode). `mark` is where F7
  (MARK) started marking, or nil: the marked text runs from it to the
  cursor, as in a note (R63); a move keeps it, a change drops it.
  """

  alias Agendum.TUI.{Keymap, Typing.Wrap}

  @type t :: %__MODULE__{text: String.t(), pos: non_neg_integer, mark: non_neg_integer | nil}
  defstruct text: "", pos: 0, mark: nil

  # moves keep the mark; every other command changes the text and drops it
  @moves [:left, :right, :line_start, :line_end, :word_left, :word_right]
  @clipboard [:copy, :cut, :delete_marked, :paste, :note, :help]

  @spec new(String.t()) :: t
  def new(text \\ ""), do: %__MODULE__{text: text, pos: String.length(text)}

  @doc """
  Applies a key; returns `{:ok, edit}` or `:unhandled`. A character is
  typed; other keys run the command the `:line` keymap binds them to
  (`Agendum.TUI.Keymap`, R65): Mac and emacs conventions, as ⌘←/⌘→
  arrive as CTRL-A/CTRL-E in many terminals, ⌥←/⌥→ as ALT-B/ALT-F or
  ALT-arrows, ⌘⌫ as CTRL-U.
  """
  @spec handle(t, term) :: {:ok, t} | :unhandled
  def handle(%__MODULE__{} = e, {:char, c}), do: {:ok, insert(e, c)}

  def handle(%__MODULE__{} = e, key) do
    case Keymap.lookup(:line, key) do
      nil -> :unhandled
      # the clipboard's keys need the session (`Typing.LineClip`)
      id when id in @clipboard -> :unhandled
      id -> {:ok, run(e, id)}
    end
  end

  @doc """
  A move in a line shown wrapped on rows `width` wide (`Typing.Wrap`), as an
  item's text being typed is (R21, as Agenda's): `:up` and `:down` a row,
  keeping the column (nothing on the first or last row), `:line_start` and
  `:line_end` the row's start and end, `:text_start` and `:text_end` the
  whole text's. The mark stays, as with every move.
  """
  @spec wrapped_move(
          t,
          :up | :down | :line_start | :line_end | :text_start | :text_end,
          pos_integer
        ) :: t
  def wrapped_move(e, :text_start, _width), do: %{e | pos: 0}
  def wrapped_move(e, :text_end, _width), do: %{e | pos: String.length(e.text)}

  def wrapped_move(e, id, width) do
    rows = Wrap.rows(e.text, width)
    i = Wrap.locate(rows, e.pos)
    {start, _len} = Enum.at(rows, i)

    # `cond` takes the first branch whose condition is true
    pos =
      cond do
        id == :up and i > 0 -> Wrap.column(rows, i - 1, e.pos - start)
        id == :down and i < length(rows) - 1 -> Wrap.column(rows, i + 1, e.pos - start)
        id == :line_start -> start
        id == :line_end -> Wrap.row_end(rows, i)
        true -> e.pos
      end

    %{e | pos: pos}
  end

  @doc "Runs a line-editing command (`Agendum.TUI.Commands`, `:line`)."
  @spec run(t, atom) :: t
  # F7: marking starts at the cursor; again, it stops (Agenda's MARK)
  def run(%{mark: nil} = e, :mark), do: %{e | mark: e.pos}
  def run(e, :mark), do: %{e | mark: nil}
  def run(e, id) when id in @moves, do: move(e, id)
  def run(e, id), do: e |> change(id) |> Map.put(:mark, nil)

  defp change(e, :delete_to_end), do: %{e | text: String.slice(e.text, 0, e.pos)}

  defp change(e, :delete_word) do
    start = word_left(e)
    {before, _} = String.split_at(e.text, start)
    {_, rest} = String.split_at(e.text, e.pos)
    %{e | text: before <> rest, pos: start}
  end

  defp change(%{pos: 0} = e, :delete_back), do: e

  defp change(e, :delete_back),
    do: %{e | text: delete_at(e.text, e.pos - 1), pos: e.pos - 1}

  defp change(e, :delete), do: %{e | text: delete_at(e.text, e.pos)}
  defp change(_e, :clear), do: new("")

  defp move(e, :left), do: %{e | pos: max(e.pos - 1, 0)}
  defp move(e, :right), do: %{e | pos: min(e.pos + 1, String.length(e.text))}
  defp move(e, :line_start), do: %{e | pos: 0}
  defp move(e, :line_end), do: %{e | pos: String.length(e.text)}
  defp move(e, :word_left), do: %{e | pos: word_left(e)}
  defp move(e, :word_right), do: %{e | pos: word_right(e)}

  @spec insert(t, String.t()) :: t
  def insert(%__MODULE__{} = e, str) do
    {before, rest} = String.split_at(e.text, e.pos)
    %{e | text: before <> str <> rest, pos: e.pos + String.length(str), mark: nil}
  end

  @doc "The marked part, `{from, to}` (from before to), or nil when nothing is marked."
  @spec region(t) :: {non_neg_integer, non_neg_integer} | nil
  def region(%{mark: nil}), do: nil
  def region(%{mark: same, pos: same}), do: nil
  def region(%{mark: mark, pos: pos}), do: {min(mark, pos), max(mark, pos)}

  @doc """
  Takes text out of the line for F3, F4 and ALT-F4: the marked text, the
  word at the cursor (`:word`) or all of it (`:all`). `{text, line
  without it}`, or nil when there is nothing there.
  """
  @spec take(t, :mark | :word | :line | :all) :: {String.t(), t} | nil
  def take(e, :mark) do
    case region(e) do
      nil -> nil
      {from, to} -> cut(e, from, to)
    end
  end

  # a line is one line: Line is All text
  def take(e, :line), do: take(e, :all)
  def take(%{text: ""}, :all), do: nil
  def take(e, :all), do: {e.text, new("")}

  def take(e, :word) do
    # the word the cursor is in or just after
    from = word_left(%{e | pos: min(e.pos + 1, String.length(e.text))})
    to = word_right(%{e | pos: from})
    if String.trim(String.slice(e.text, from, to - from)) == "", do: nil, else: cut(e, from, to)
  end

  defp cut(e, from, to) do
    {before, rest} = String.split_at(e.text, from)
    {taken, after_} = String.split_at(rest, to - from)
    {taken, %{e | text: before <> after_, pos: from, mark: nil}}
  end

  defp delete_at(text, pos) do
    {before, rest} = String.split_at(text, pos)
    before <> String.slice(rest, 1..-1//1)
  end

  @doc """
  Where the word before `pos` in `text` starts (spaces before `pos`
  skipped); 0 when there is none. The note editor's word keys use it too.
  """
  @spec previous_word(String.t(), non_neg_integer) :: non_neg_integer
  def previous_word(text, pos), do: word_left(%{text: text, pos: pos})

  @doc "Where the word after `pos` in `text` ends; the end of the text when there is none."
  @spec next_word(String.t(), non_neg_integer) :: non_neg_integer
  def next_word(text, pos), do: word_right(%{text: text, pos: pos})

  defp word_left(%{text: text, pos: pos}) do
    before = text |> String.slice(0, pos) |> String.trim_trailing()

    case Regex.run(~r/\S+$/u, before, return: :index) do
      [{start, _}] -> before |> binary_part(0, start) |> String.length()
      nil -> 0
    end
  end

  defp word_right(%{text: text, pos: pos}) do
    rest = String.slice(text, pos..-1//1)

    case Regex.run(~r/^\s*\S+/u, rest) do
      [match] -> pos + String.length(match)
      nil -> String.length(text)
    end
  end
end
