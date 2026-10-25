defmodule Agendum.TUI.Update.Notes do
  @moduledoc """
  Keys in the full-screen note of an item, a category or a macro: editing,
  ALT-D / ALT-T, ALT-N / ALT-P to the next note, F7 MARK, F3 COPY, F4 CUT,
  ALT-F4 DELETE and F2 PASTE (R63), ALT-F7 MAKEITM and ALT-F2 MAKECAT
  (R42), and saving on close. Commands run through the note's keymap
  (R65); other keys edit the text. Pure.
  """

  alias Agendum.Core.DateFormat
  alias Agendum.TUI.{CategoryScreens, Keymap, Layout, Typing.NoteSearch, State, Typing.TextEdit}
  alias Agendum.TUI.Typing.Wrap
  alias Agendum.TUI.Update.Actions

  # --- notes --------------------------------------------------------------------

  @doc "F1's text in a note (R65)."
  @spec about() :: String.t()
  def about do
    """
    You are writing a note: of an item, of a category, or a macro's
    keystrokes. Type as in any editor; long lines wrap, and ↑ ↓ HOME END
    follow the rows you see.

    F7 marks text (move the cursor to stretch it; F7 again unmarks). F3
    copies it, F4 cuts it, ALT-F4 deletes it; F2 pastes what you copied or
    cut last. With nothing marked, they ask: the word, the line or all.

    ALT-F6 searches or replaces, ALT-S finds the next one. ALT-D and ALT-T
    type today's date and the time. ALT-F7 makes the marked text an item,
    ALT-F2 a category.

    F5 saves the note and goes back. ESC asks "Discard changes?" when you
    changed it: No (ENTER) saves it as F5 does, Yes puts it back as it was
    when you opened it. ALT-N and ALT-P save it and go on to the next or
    the previous item's note. F10 is the note's menu:
    Import puts a text file in at the cursor, Export writes the note to
    one, Clear empties the note, Return goes back, Quit leaves Agendum.
    """
  end

  @doc """
  A key in a note: it runs the command the note's keymap binds it to
  (`Agendum.TUI.Keymap`, R65); any other key edits the text.
  """
  def note_key(state, mode, key) do
    case Keymap.lookup(:note, key) do
      nil -> edit_text(state, mode, key)
      id -> command(state, mode, id)
    end
  end

  @doc "Runs a note command (`Agendum.TUI.Commands`) in the note on top."
  @spec run(State.t(), atom) :: State.t()
  def run(state, id), do: command(state, State.mode(state), id)

  @step_unsupported "ALT-N / ALT-P work in notes opened from a view or the category manager"

  @doc """
  A note's commands that cannot run now, each with why (R65a): F1 `c`
  greys them. The reasons are the ones running them reports.
  """
  @spec unavailable(State.t()) :: %{atom => String.t()}
  def unavailable(state) do
    mode = State.mode(state)

    [
      paste: state.last.copied == nil && "Nothing to paste: F3 copies, F4 cuts",
      search_next: state.searches.note == nil && "Nothing to search for yet; press ALT-F6",
      make_item: length(state.modes) > 1 && "ALT-F7 makes items from a note opened in a view",
      insert_link: link_text(state) |> link_reason(),
      next_note: stepped(state, mode, 1),
      previous_note: stepped(state, mode, -1)
    ]
    |> Enum.filter(fn {_id, reason} -> is_binary(reason) end)
    |> Map.new()
  end

  # R73b: links to the marked items, `[[bonalaku]]`, each needing an id
  defp link_text(state) do
    marked = Agendum.Core.marked_items(state.db)
    words = Enum.map(marked, &Agendum.Core.zettel(state.db.items[&1]))

    cond do
      marked == [] -> {:error, "Mark the items to link to with F7 first"}
      nil in words -> {:error, "Give the marked items Zettel ids first (Item ▸ Zettel ▸ Attach)"}
      true -> {:ok, Enum.map_join(words, " ", &"[[#{&1}]]")}
    end
  end

  defp link_reason({:error, reason}), do: reason
  defp link_reason({:ok, _text}), do: nil

  defp stepped(state, mode, step) do
    below = state.modes |> Enum.drop(1) |> List.first()

    case next_note_target(state, below, mode.target, step) do
      :unsupported -> @step_unsupported
      nil -> "No more notes in this direction"
      _target -> nil
    end
  end

  defp page(state, mode, key) do
    width = Wrap.width(state)

    edit =
      Enum.reduce(1..State.body_height(state)//1, mode.edit, fn _, edit ->
        case TextEdit.handle(edit, key, width) do
          {:ok, moved} -> moved
          :unhandled -> edit
        end
      end)

    State.put_mode(state, %{mode | edit: edit, match: nil})
  end

  defp edit_text(state, mode, key) do
    case TextEdit.handle(mode.edit, key, Wrap.width(state)) do
      {:ok, edit} -> State.put_mode(state, Map.merge(mode, %{edit: edit, match: nil}))
      :unhandled -> state
    end
  end

  defp command(state, _mode, :search), do: NoteSearch.open(state)
  defp command(state, mode, :search_next), do: NoteSearch.next(state, mode)
  defp command(state, mode, :close), do: close_note(state, mode)

  # ESC (R64d): with changes, Agenda's "Discard changes?", No shown first
  defp command(state, mode, :cancel) do
    if changed?(mode),
      do:
        State.push(state, %Agendum.TUI.Modes.Confirm{
          question: "Discard changes?",
          action: :discard_note,
          answer: false
        }),
      else: close_note(state, mode)
  end

  defp command(state, _mode, :help), do: Agendum.TUI.HelpScreen.open(state)

  defp command(state, mode, :mark),
    do: State.put_mode(state, %{mode | edit: TextEdit.toggle_mark(mode.edit)})

  # F4 is CUT in a note, as in Agenda
  defp command(state, _mode, :copy), do: clip(state, :copy)
  defp command(state, _mode, :cut), do: clip(state, :cut)
  defp command(state, _mode, :delete), do: clip(state, :delete)
  defp command(state, mode, :paste), do: paste(state, mode)

  defp command(state, mode, :insert_date),
    do: type_in_note(state, mode, DateFormat.date(state.today, state.db.date_format))

  defp command(state, mode, :insert_time) do
    time = DateFormat.time(NaiveDateTime.to_time(state.now), state.db.date_format)
    type_in_note(state, mode, time)
  end

  defp command(state, mode, :insert_link) do
    case link_text(state) do
      {:ok, text} -> type_in_note(state, mode, text)
      {:error, reason} -> State.error(state, reason)
    end
  end

  defp command(state, mode, :next_note), do: step_note(state, mode, 1)
  defp command(state, mode, :previous_note), do: step_note(state, mode, -1)
  defp command(state, mode, :quit), do: state |> close_note(mode) |> Actions.perform(:quit)
  defp command(state, _mode, :key_map), do: State.cycle_key_bar(state)
  defp command(state, _mode, :menu), do: Agendum.TUI.Menu.open(state, :note)

  # INS (R64e): typing over, or not; TAB: spaces to the next tab stop,
  # File Properties ▸ Tab size apart
  defp command(state, mode, :overwrite),
    do: State.put_mode(state, %{mode | edit: TextEdit.toggle_overwrite(mode.edit)})

  defp command(state, mode, :tab) do
    size = state.db.tab_size
    type_in_note(state, mode, String.duplicate(" ", size - rem(mode.edit.col, size)))
  end

  # PGUP / PGDN (R64e): as many rows as the screen shows, as ↑ ↓ move
  defp command(state, mode, :page_up), do: page(state, mode, :up)
  defp command(state, mode, :page_down), do: page(state, mode, :down)

  # Import and Export (R64c): a file name, F3 lists text files; the shell
  # reads or writes it (`Agendum.TUI.Update.note_text_read/3`)
  defp command(state, _mode, :import),
    do:
      Agendum.TUI.Update.Prompts.prompt(state, "Text file to import into the note:", :note_import)

  defp command(state, _mode, :export),
    do: Agendum.TUI.Update.Prompts.prompt(state, "Export the note to text file:", :note_export)

  # Clear (R64b): asks first, as Agenda ("Clear all text from the note?")
  defp command(state, _mode, :clear),
    do: Agendum.TUI.Update.Prompts.confirm(state, "Clear all text from the note?", :clear_note)

  defp command(state, _mode, :run_by_name), do: Agendum.TUI.Boxes.RunByName.open(state)
  defp command(state, _mode, :make_item), do: ask_make_item(state)
  defp command(state, mode, :append), do: ask_append(state, mode)
  defp command(state, mode, :get_items), do: get_items(state, mode)
  defp command(state, _mode, :calendar), do: Agendum.TUI.Boxes.CalendarBox.open(state, :note)
  defp command(state, mode, :make_category), do: make_category(state, mode)

  # --- ALT-F7 MAKEITM and ALT-F2 MAKECAT (User's Guide 12-8 to 12-9) ---

  # the longest item text and category name Agenda allowed; the rest of
  # the text goes into the new item's or category's note
  @item_room 350
  @name_room 69

  # The new item goes into the view's section, so the note must have been
  # opened from a view (nothing under it on the mode stack). Marked text
  # is taken as it is; else Agenda asks Word, Line or All text.
  defp ask_make_item(state) do
    cond do
      length(state.modes) > 1 ->
        State.error(state, "ALT-F7 makes items from a note opened in a view")

      marked?(State.mode(state)) ->
        make_item(state, :mark)

      true ->
        State.push(state, %Agendum.TUI.Modes.Choice{kind: :make_item, cursor: 0})
    end
  end

  defp marked?(mode), do: TextEdit.marked(mode.edit) not in [nil, ""]

  # --- F3 COPY, F4 CUT, ALT-F4 DELETE, F2 PASTE (User's Guide 14-5 to 14-8) ---

  # the marked text, or else what the person chooses: Word, Line, All text
  defp clip(state, action) do
    if marked?(State.mode(state)),
      do: clip(state, action, :mark),
      else: Agendum.TUI.Boxes.WhatToCopyBox.open(state, action, :note)
  end

  @doc """
  Copies, cuts or deletes the marked text, or the word, line or all text
  at the cursor. Copied and cut text is kept for F2 (one piece, for the
  session); deleted text is not.
  """
  def clip(state, action, what) do
    mode = State.mode(state)

    case TextEdit.take(mode.edit, what) do
      nil ->
        State.error(state, "Nothing there to #{action}")

      {text, taken} ->
        # copying leaves the text where it is (and drops the mark)
        edit = if action == :copy, do: %{mode.edit | mark: nil}, else: taken
        # Map.merge, not %{mode | …}: the macro edit screen's mode has no :match
        state = State.put_mode(state, Map.merge(mode, %{edit: edit, match: nil}))

        case action do
          :delete -> State.info(state, "Deleted")
          _ -> %{state | last: %{state.last | copied: text}} |> State.info(clipped(action))
        end
    end
  end

  defp clipped(:copy), do: "Copied; F2 pastes it"
  defp clipped(:cut), do: "Cut; F2 pastes it"

  # F2: the text last copied or cut, at the cursor; it stays kept
  defp paste(%State{last: %{copied: nil}} = state, _mode),
    do: State.error(state, "Nothing to paste: F3 copies, F4 cuts")

  defp paste(state, mode),
    do:
      State.put_mode(
        state,
        Map.merge(mode, %{edit: TextEdit.insert(mode.edit, state.last.copied), match: nil})
      )

  @doc """
  ALT-F7, after Word, Line or All text was chosen: that text leaves the
  note and becomes a new item in the section the highlight is in, below
  the note's item. The shorter note and the new item are one change.
  """
  def make_item(state, what) do
    mode = State.mode(state)

    case TextEdit.take(mode.edit, what) do
      nil ->
        State.error(state, "Nothing there to make into an item")

      {text, edit} ->
        row = Layout.current_row(state)
        # an item is one line: line breaks become spaces
        {text, rest} =
          String.split_at(text |> String.replace("\n", " ") |> String.trim(), @item_room)

        after_id = if row.kind == :item, do: row.item.id

        # the shorter note, the new item and its note are one change (one
        # undo step): all three happen within this one key
        command =
          {:batch,
           [
             save_command(mode.target, TextEdit.text(edit)),
             {:add_item, text, section: row.category.id, after: after_id}
           ]}

        case State.run_with_changes(state, command) do
          {saved, %{new: id}} ->
            saved
            |> State.put_mode(Map.merge(mode, %{edit: edit, match: nil}))
            |> note_rest(id, rest)
            |> State.info("New item in #{row.category.name}: #{text}")

          # only spaces taken: no item, and the note keeps them
          {_refused, nil} ->
            State.error(state, "Nothing there to make into an item")
        end
    end
  end

  # --- ALT-F9 APPEND, ALT-F8 GETITMS, ALT-C (R64f; User's Guide 12-7, 12-10) ---

  # a macro's keystrokes have no item text to append to
  defp ask_append(state, %{target: {:macro, _}}),
    do: State.error(state, "ALT-F9 appends to an item or a category")

  defp ask_append(state, mode) do
    if marked?(mode),
      do: append(state, :mark),
      else: State.push(state, %Agendum.TUI.Modes.Choice{kind: :append, cursor: 0})
  end

  @doc """
  ALT-F9, after Word, Line or All text was chosen (or with text marked):
  that text leaves the note and goes on the end of the item's text (the
  category's name), after a space. What does not fit (350 characters for
  an item, 69 for a category) stays in the note, at the cursor. The
  shorter note and the longer text are one change.
  """
  @spec append(State.t(), atom) :: State.t()
  def append(state, what) do
    mode = State.mode(state)

    with {kind, _id} when kind in [:item, :category] <- mode.target,
         {text, edit} <- TextEdit.take(mode.edit, what),
         text = text |> String.replace("\n", " ") |> String.trim(),
         true <- text != "" do
      {current, room} = appended_to(state.db, mode.target)
      {fits, rest} = String.split_at(text, max(room - String.length(current) - 1, 0))
      append_fitting(state, mode, edit, current, fits, rest)
    else
      {:macro, _} -> State.error(state, "ALT-F9 appends to an item or a category")
      _ -> State.error(state, "Nothing there to append")
    end
  end

  defp append_fitting(state, _mode, _edit, _current, "", _rest),
    do: State.error(state, "There is no room left; the text stays in the note")

  defp append_fitting(state, mode, edit, current, fits, rest) do
    edit = if rest == "", do: edit, else: TextEdit.insert(edit, rest)
    longer = current <> " " <> fits

    change =
      case mode.target do
        {:item, id} -> {:edit_item, id, longer}
        {:category, id} -> {:rename_category, id, longer}
      end

    state
    |> State.run({:batch, [save_command(mode.target, TextEdit.text(edit)), change]})
    |> State.put_mode(Map.merge(mode, %{edit: edit, match: nil, title: longer}))
    |> State.info("Appended: #{fits}")
  end

  defp appended_to(db, {:item, id}), do: {db.items[id].text, @item_room}
  defp appended_to(db, {:category, id}), do: {db.categories[id].name, @name_room}

  # ALT-F8: the marked items' text, each with its note, typed in at the
  # cursor between blank lines; the items stay, marked
  defp get_items(state, mode) do
    case Agendum.Core.marked_items(state.db) do
      [] ->
        State.error(state, "There are no marked items in the file.")

      ids ->
        blocks =
          Enum.map_join(ids, "\n\n", fn id ->
            item = state.db.items[id]
            if item.note == "", do: item.text, else: item.text <> "\n" <> item.note
          end)

        state
        |> State.put_mode(%{
          mode
          | edit: TextEdit.insert(mode.edit, "\n" <> blocks <> "\n\n"),
            match: nil
        })
        |> State.info("Copied #{length(ids)} marked item(s) into the note")
    end
  end

  @doc "Types `text` at the cursor of the note being edited (ALT-C's date, R64f)."
  @spec type_text(State.t(), String.t()) :: State.t()
  def type_text(state, text),
    do: update_note(state, &%{&1 | edit: TextEdit.insert(&1.edit, text), match: nil})

  defp note_rest(state, _id, ""), do: state
  defp note_rest(state, id, rest), do: State.run(state, {:set_note, id, String.trim(rest)})

  # ALT-F2: the word at the cursor, its punctuation off, becomes a category
  # under the parent picked next (`Agendum.TUI.CategoryScreens.Picker`)
  defp make_category(state, mode) do
    text = if marked?(mode), do: TextEdit.marked(mode.edit), else: TextEdit.word(mode.edit)

    case name_of(text) do
      nil -> State.error(state, "No word at the cursor to make into a category")
      name -> CategoryScreens.open_picker(state, {:make_category, name}, nil)
    end
  end

  defp name_of(nil), do: nil

  defp name_of(word) do
    # punctuation at either end goes ("Jones," is Jones); a name is one line
    case word
         |> String.replace("\n", " ")
         |> String.trim()
         |> String.replace(~r/^[[:punct:]]+|[[:punct:]]+$/u, "") do
      "" -> nil
      name -> name
    end
  end

  @doc "ALT-F2's parent was picked: the category is added under it."
  def add_category(state, name, parent) do
    {name, rest} = String.split_at(name, @name_room)

    case State.command(state, {:add_category, parent, name, []}) do
      {:ok, state, %{new: id}} ->
        state = if rest == "", do: state, else: State.run(state, {:set_category_note, id, rest})
        parent = state.db.categories[parent].name
        State.info(state, "New category #{name} under #{parent}")

      {:error, :duplicate} ->
        State.error(state, "#{state.db.categories[parent].name} already has a #{name}")

      {:error, _} ->
        state
    end
  end

  # the command that saves a note's text where it belongs
  defp save_command({:item, id}, text), do: {:set_note, id, text}
  defp save_command({:category, id}, text), do: {:set_category_note, id, text}
  defp save_command({:macro, id}, text), do: {:set_macro_keys, id, text}

  # Saves the note and closes it.
  defp close_note(state, mode), do: state |> save(mode) |> State.pop()

  # whether the text differs from the text as opened (read through
  # `TextEdit` both, so that the macro editor's line breaks compare alike)
  defp changed?(mode),
    do: TextEdit.text(mode.edit) != TextEdit.text(TextEdit.new(mode.original))

  @doc """
  The answer to "Discard changes?" (R64d): Yes puts the note's text back
  as it was opened, what Search/Replace and Clear saved on the way
  included, and closes it; No saves it and closes it, as F5. The note is
  found on the stack, under the question.
  """
  @spec discard(State.t(), boolean) :: State.t()
  def discard(state, yes?) do
    case Enum.split_while(state.modes, &(&1.type != :note)) do
      {_above, [note | below]} ->
        text = if yes?, do: note.original, else: TextEdit.text(note.edit)
        %{State.run(state, save_command(note.target, text)) | modes: below}

      {_, []} ->
        state
    end
  end

  @doc """
  Opens the note editor on `text`, the note of `target` (`{:item, id}`,
  `{:category, id}`, `{:macro, id}`), headed by `title`. The text as
  opened is kept, for ESC's "Discard changes?" (R64d).
  """
  @spec open(State.t(), {atom, pos_integer}, String.t(), String.t()) :: State.t()
  def open(state, target, title, text) do
    State.push(state, %Agendum.TUI.Modes.Note{
      target: target,
      title: title,
      edit: TextEdit.new(text),
      original: text
    })
  end

  @doc """
  Puts text read from a file in at the cursor of the note being edited
  (Import, R64c): CR LF and CR read as LF; the cursor ends after it. The
  note is found on the stack, as for `clear/1`.
  """
  @spec import_text(State.t(), String.t()) :: State.t()
  def import_text(state, text) do
    text = text |> String.replace("\r\n", "\n") |> String.replace("\r", "\n")

    update_note(state, fn note ->
      %{note | edit: TextEdit.insert(note.edit, text), match: nil}
    end)
  end

  @doc "The text of the note being edited as a text file (Export, R64c): LF line ends."
  @spec export_text(State.t()) :: String.t() | nil
  def export_text(state) do
    case Enum.find(state.modes, &(&1.type == :note)) do
      nil -> nil
      note -> TextEdit.text(note.edit) <> "\n"
    end
  end

  # the first note on the stack, changed by `fun`, where it is
  defp update_note(state, fun) do
    case Enum.find_index(state.modes, &(&1.type == :note)) do
      nil -> state
      i -> %{state | modes: List.update_at(state.modes, i, fun)}
    end
  end

  @doc """
  Empties the note being edited (Clear, R64b), which stays open. The note
  is saved before and after, as a Search/Replace replacement is: what was
  typed before is one undo step, the clearing another. The note is found
  on the stack, since the question and the menu may be above it.
  """
  @spec clear(State.t()) :: State.t()
  def clear(state) do
    case Enum.find(state.modes, &(&1.type == :note)) do
      nil ->
        state

      note ->
        cleared = %{note | edit: %TextEdit{lines: [""], row: 0, col: 0}}

        state
        |> save(note)
        |> State.end_step()
        |> update_note(fn _ -> cleared end)
        |> save(cleared)
    end
  end

  @doc """
  Saves the note being edited (`mode`) into the database, the note staying
  open: on closing it, and after each Search/Replace replacement, so that
  each replacement is an undo step of its own.
  """
  def save(state, mode) do
    State.run(state, save_command(mode.target, TextEdit.text(mode.edit)))
  end

  defp type_in_note(state, mode, text) do
    {:ok, edit} = TextEdit.handle(mode.edit, {:char, text})
    State.put_mode(state, %{mode | edit: edit})
  end

  # ALT-N / ALT-P: save this note and show the note of the next / previous
  # item (or section) in the view, or category in the category manager.
  defp step_note(state, mode, step) do
    below = state.modes |> Enum.drop(1) |> List.first()

    case {below, next_note_target(state, below, mode.target, step)} do
      {_, :unsupported} ->
        State.error(state, @step_unsupported)

      {_, nil} ->
        State.error(state, "No more notes in this direction")

      {nil, index} ->
        state |> close_note(mode) |> Layout.move_to(index) |> Actions.perform(:note)

      {%{type: :catmgr}, {index, id}} ->
        state = close_note(state, mode)

        state
        |> State.put_mode(%{State.mode(state) | cursor: index})
        |> CategoryScreens.open_note(id)
    end
  end

  defp next_note_target(state, nil, target, step) do
    kind = if match?({:item, _}, target), do: :item, else: :section
    rows = Layout.rows(state)

    candidates =
      if step > 0,
        do: (state.cursor + 1)..(length(rows) - 1)//1,
        else: (state.cursor - 1)..0//-1

    Enum.find(candidates, &(Enum.at(rows, &1).kind == kind))
  end

  defp next_note_target(state, %{type: :catmgr} = catmgr, {:category, _}, step) do
    rows = CategoryScreens.rows(state, catmgr)
    index = catmgr.cursor + step

    case Enum.at(rows, index) do
      {id, _} when index >= 0 -> {index, id}
      _ -> nil
    end
  end

  defp next_note_target(_state, _below, _target, _step), do: :unsupported
end
