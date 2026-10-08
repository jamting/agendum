defmodule Agenda.TUI.LineEdit do
  @moduledoc "A pure single-line text editing buffer (EDIT mode)."

  @type t :: %__MODULE__{text: String.t(), pos: non_neg_integer}
  defstruct text: "", pos: 0

  @spec new(String.t()) :: t
  def new(text \\ ""), do: %__MODULE__{text: text, pos: String.length(text)}

  # Mac and emacs conventions: ⌘←/⌘→ arrive as CTRL-A/CTRL-E in many
  # terminals, ⌥←/⌥→ as ALT-B/ALT-F or ALT-arrows, ⌘⌫ as CTRL-U.
  @aliases %{
    {:ctrl, "a"} => :home,
    {:ctrl, "e"} => :end,
    {:ctrl, "b"} => :left,
    {:ctrl, "f"} => :right,
    {:ctrl, "d"} => :delete,
    {:alt, "b"} => :ctrl_left,
    {:alt, "f"} => :ctrl_right,
    {:alt, :left} => :ctrl_left,
    {:alt, :right} => :ctrl_right
  }

  @doc "Applies a key; returns `{:ok, edit}` or `:unhandled`."
  @spec handle(t, term) :: {:ok, t} | :unhandled
  def handle(%__MODULE__{} = e, key) do
    case Map.get(@aliases, key, key) do
      {:ctrl, "k"} ->
        {:ok, %{e | text: String.slice(e.text, 0, e.pos)}}

      k when k in [{:ctrl, "w"}, {:alt, :backspace}] ->
        start = word_left(e)
        {before, _} = String.split_at(e.text, start)
        {_, rest} = String.split_at(e.text, e.pos)
        {:ok, %{e | text: before <> rest, pos: start}}

      {:char, c} ->
        {:ok, insert(e, c)}

      :backspace when e.pos > 0 ->
        {:ok, %{e | text: delete_at(e.text, e.pos - 1), pos: e.pos - 1}}

      :backspace ->
        {:ok, e}

      :delete ->
        {:ok, %{e | text: delete_at(e.text, e.pos)}}

      :left ->
        {:ok, %{e | pos: max(e.pos - 1, 0)}}

      :right ->
        {:ok, %{e | pos: min(e.pos + 1, String.length(e.text))}}

      :home ->
        {:ok, %{e | pos: 0}}

      :end ->
        {:ok, %{e | pos: String.length(e.text)}}

      :ctrl_left ->
        {:ok, %{e | pos: word_left(e)}}

      :ctrl_right ->
        {:ok, %{e | pos: word_right(e)}}

      {:ctrl, "u"} ->
        {:ok, new("")}

      _ ->
        :unhandled
    end
  end

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
