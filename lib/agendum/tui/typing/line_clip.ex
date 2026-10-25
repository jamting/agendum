defmodule Agendum.TUI.Typing.LineClip do
  @moduledoc """
  Agenda's editing keys while a line is typed (User's Guide 3-4; checked
  in Agenda 2.0, 2026-10-25), wherever it is: an item's text in a view, a
  category's name, a column entry, a prompt, a box's field. F7 (MARK)
  marks, from the cursor (`Typing.LineEdit`); F3 (COPY) and F4 (CUT) keep
  the marked text for F2 (PASTE), ALT-F4 (DELETE) throws it away; with
  nothing marked they ask, as Agenda's "What to copy", for the word at the
  cursor or all the text. What is kept is the note editor's too (R63), for
  the session. F5 (NOTE) on an item's text keeps the text and opens its
  note; F1 opens the help, and ESC there comes back to the typing.

  The keys are taken here, before the screen on top sees them, so every
  place that types a line has them. They are left to the place while
  automatic completion offers names (F7 and F8 go through them there) and
  in a file name's prompt, where F3 lists the files. Pure.
  """

  alias Agendum.TUI.{Keymap, State}
  alias Agendum.TUI.Typing.{Completion, LineEdit}

  # the `:line` keymap's commands taken here; the moves and the deletes
  # are `LineEdit`'s
  @keys [:mark, :copy, :cut, :delete_marked, :paste, :note, :help]

  @doc "A key while a line is typed; `:pass` when it is not one of these, or no line is."
  @spec key(State.t(), term) :: State.t() | :pass
  def key(state, key) do
    with false <- over_the_line?(State.mode(state)),
         {where, line} <- typed(state),
         id when id in @keys <- Keymap.lookup(:line, key),
         # completion's F7 and F8 (and F3, F5) are its own; F1 is the help
         false <- Completion.active?(state) and id != :help,
         false <- id == :copy and file_prompt?(state) do
      run(state, where, line, id)
    else
      _ -> :pass
    end
  end

  defp run(state, where, line, :mark), do: put(state, where, LineEdit.run(line, :mark))
  defp run(state, _where, _line, :help), do: over(state, Agendum.TUI.HelpScreen.open(state))

  defp run(state, where, line, :paste) do
    case state.last.copied do
      nil -> State.error(state, "Nothing to paste: F3 copies, F4 cuts")
      # a note's lines become one line
      text -> put(state, where, LineEdit.insert(line, String.replace(text, "\n", " ")))
    end
  end

  defp run(state, where, line, :note) do
    case state.edit do
      %{target: {target, _, _}} when target == :new_item -> note(state)
      %{target: {:edit_item, _}} -> note(state)
      _ -> put(state, where, line)
    end
  end

  defp run(state, where, line, action) do
    action = if action == :delete_marked, do: :delete, else: action

    if LineEdit.region(line),
      do: clip(state, where, line, action, :mark),
      else:
        over(
          state,
          State.push(state, %Agendum.TUI.Modes.Choice{kind: :line_clip, action: action, cursor: 0})
        )
  end

  # the help or the question opened over a line being typed keeps it in its
  # mode; `State.pop/1` gives it back when it closes
  defp over(%State{edit: nil}, opened), do: opened

  defp over(state, opened) do
    [top | rest] = opened.modes
    %{opened | modes: [%{top | edit: state.edit} | rest]}
  end

  @doc """
  F3, F4 or ALT-F4 once what to take is known (`:mark`, `:word`, `:all`),
  on the line being typed: kept for F2, but for ALT-F4.
  """
  @spec clip(State.t(), :copy | :cut | :delete, :mark | :word | :all) :: State.t()
  def clip(state, action, what) do
    case typed(state) do
      {where, line} -> clip(state, where, line, action, what)
      nil -> state
    end
  end

  defp clip(state, where, line, action, what) do
    case LineEdit.take(line, what) do
      nil ->
        State.error(state, "Nothing there to #{action}")

      {text, taken} ->
        # copying leaves the text as it was, the mark dropped
        state = put(state, where, if(action == :copy, do: %{line | mark: nil}, else: taken))
        if action == :delete, do: state, else: %{state | last: %{state.last | copied: text}}
    end
  end

  # F5 on an item's text: as ENTER, which keeps it, then F5 on the item
  defp note(state) do
    state = Agendum.TUI.Update.box_key(state, :enter)
    if state.edit == nil, do: Agendum.TUI.Update.box_key(state, {:f, 5}), else: state
  end

  # The line being typed: `state.edit`'s, or the typing of a box's field
  # (`Boxes.FieldTyping`) on top, or under the "What to copy" question.
  defp typed(%State{edit: %{line: %LineEdit{} = line}}), do: {:edit, line}

  defp typed(state) do
    case Enum.find_index(state.modes, &match?(%{typing: {_, %LineEdit{}}}, &1)) do
      nil -> nil
      i -> {{:mode, i}, state.modes |> Enum.at(i) |> Map.fetch!(:typing) |> elem(1)}
    end
  end

  defp put(state, :edit, line), do: %{state | edit: %{state.edit | line: line}}

  defp put(state, {:mode, i}, line) do
    modes =
      List.update_at(state.modes, i, fn %{typing: {field, _}} = mode ->
        %{mode | typing: {field, line}}
      end)

    %{state | modes: modes}
  end

  # the help, a question or the developer tools over the line take its keys
  defp over_the_line?(%{type: type}), do: type in [:help, :choice, :confirm, :devtools, :menu]
  defp over_the_line?(nil), do: false

  defp file_prompt?(state) do
    case State.mode(state) do
      %{type: :prompt, action: action} -> Agendum.TUI.Boxes.SelectFile.file_prompt?(action)
      _ -> false
    end
  end
end
