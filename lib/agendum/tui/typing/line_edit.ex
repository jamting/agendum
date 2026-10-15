defmodule Agendum.TUI.Typing.LineEdit do
  @moduledoc "A pure single-line text editing buffer (EDIT mode)."

  alias Agendum.TUI.Keymap

  @type t :: %__MODULE__{text: String.t(), pos: non_neg_integer}
  defstruct text: "", pos: 0

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
      id -> {:ok, run(e, id)}
    end
  end

  @doc "Runs a line-editing command (`Agendum.TUI.Commands`, `:line`)."
  @spec run(t, atom) :: t
  def run(e, :delete_to_end), do: %{e | text: String.slice(e.text, 0, e.pos)}

  def run(e, :delete_word) do
    start = word_left(e)
    {before, _} = String.split_at(e.text, start)
    {_, rest} = String.split_at(e.text, e.pos)
    %{e | text: before <> rest, pos: start}
  end

  def run(%{pos: 0} = e, :delete_back), do: e

  def run(e, :delete_back),
    do: %{e | text: delete_at(e.text, e.pos - 1), pos: e.pos - 1}

  def run(e, :delete), do: %{e | text: delete_at(e.text, e.pos)}
  def run(e, :left), do: %{e | pos: max(e.pos - 1, 0)}
  def run(e, :right), do: %{e | pos: min(e.pos + 1, String.length(e.text))}
  def run(e, :line_start), do: %{e | pos: 0}
  def run(e, :line_end), do: %{e | pos: String.length(e.text)}
  def run(e, :word_left), do: %{e | pos: word_left(e)}
  def run(e, :word_right), do: %{e | pos: word_right(e)}
  def run(_e, :clear), do: new("")

  @spec insert(t, String.t()) :: t
  def insert(%__MODULE__{} = e, str) do
    {before, rest} = String.split_at(e.text, e.pos)
    %{e | text: before <> str <> rest, pos: e.pos + String.length(str)}
  end

  defp delete_at(text, pos) do
    {before, rest} = String.split_at(text, pos)
    before <> String.slice(rest, 1..-1//1)
  end

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
