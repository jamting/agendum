defmodule Agendum.TUI.Update.Notes do
  @moduledoc """
  Keys in the full-screen note of an item, a category or a macro: editing,
  ALT-D / ALT-T, ALT-N / ALT-P to the next note, F7 MARK, F3 COPY, F4 CUT,
  ALT-F4 DELETE and F2 PASTE (R63), ALT-F7 MAKEITM and ALT-F2 MAKECAT
  (R42), and saving on close. Pure.
  """

  alias Agendum.Core
  alias Agendum.Core.DateFormat
  alias Agendum.TUI.{CategoryScreens, Layout, Typing.NoteSearch, State, Typing.TextEdit}
  alias Agendum.TUI.Update.Actions

  # --- notes --------------------------------------------------------------------

  @doc "A key in a note."
  def note_key(state, mode, key) do
    case key do
      {:alt_f, 6} ->
        NoteSearch.open(state)

      {:alt, "s"} ->
        NoteSearch.next(state, mode)

      # F4 is CUT in a note, as in Agenda
      k when k in [:esc, {:f, 5}] ->
        close_note(state, mode)

      {:f, 7} ->
        State.put_mode(state, %{mode | edit: TextEdit.toggle_mark(mode.edit)})

      {:f, 3} ->
        clip(state, :copy)

      {:f, 4} ->
        clip(state, :cut)

      {:alt_f, 4} ->
        clip(state, :delete)

      {:f, 2} ->
        paste(state, mode)

      {:alt, "d"} ->
        type_in_note(state, mode, DateFormat.date(state.today, state.db.date_format))

      {:alt, "t"} ->
        type_in_note(
          state,
          mode,
          DateFormat.time(NaiveDateTime.to_time(state.now), state.db.date_format)
        )

      {:alt, "n"} ->
        step_note(state, mode, 1)

      {:alt, "p"} ->
        step_note(state, mode, -1)

      {:alt, "q"} ->
        state |> close_note(mode) |> Actions.perform(:quit)

      {:alt, "k"} ->
        State.toggle_key_map(state)

      {:alt_f, 7} ->
        ask_make_item(state)

      {:alt_f, 2} ->
        make_category(state, mode)

      _ ->
        case TextEdit.handle(mode.edit, key) do
          {:ok, edit} -> State.put_mode(state, Map.merge(mode, %{edit: edit, match: nil}))
          :unhandled -> state
        end
    end
  end

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
        State.push(state, %{type: :choice, kind: :make_item, cursor: 0})
    end
  end

  defp marked?(mode), do: TextEdit.marked(mode.edit) not in [nil, ""]

  # --- F3 COPY, F4 CUT, ALT-F4 DELETE, F2 PASTE (User's Guide 14-5 to 14-8) ---

  # the marked text, or else what the person chooses: Word, Line, All text
  defp clip(state, action) do
    if marked?(State.mode(state)),
      do: clip(state, action, :mark),
      else: State.push(state, %{type: :choice, kind: :clip, action: action, cursor: 0})
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
        clock = State.context(state)
        # an item is one line: line breaks become spaces
        {text, rest} =
          String.split_at(text |> String.replace("\n", " ") |> String.trim(), @item_room)

        after_id = if row.kind == :item, do: row.item.id

        db = save(state.db, mode.target, TextEdit.text(edit), clock)
        {db, id} = Core.add_item(db, text, clock, section: row.category.id, after: after_id)
        db = if rest == "", do: db, else: Core.set_note(db, id, String.trim(rest), clock)

        state
        |> State.put_mode(Map.merge(mode, %{edit: edit, match: nil}))
        |> State.change_db(db)
        |> State.info("New item in #{row.category.name}: #{text}")
    end
  end

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

    case Core.add_category(state.db, parent, name) do
      {:ok, db, id} ->
        db = if rest == "", do: db, else: Core.set_category_note(db, id, rest)
        parent = state.db.categories[parent].name
        state |> State.change_db(db) |> State.info("New category #{name} under #{parent}")

      {:error, :duplicate} ->
        State.error(state, "#{state.db.categories[parent].name} already has a #{name}")

      {:error, _} ->
        state
    end
  end

  defp save(db, {:item, id}, text, clock), do: Core.set_note(db, id, text, clock)
  defp save(db, {:category, id}, text, _clock), do: Core.set_category_note(db, id, text)

  # Saves the note and closes it.
  defp close_note(state, mode), do: state |> save(mode) |> State.pop()

  @doc """
  Saves the note being edited (`mode`) into the database, the note staying
  open: on closing it, and after each Search/Replace replacement, so that
  each replacement is an undo step of its own.
  """
  def save(state, mode) do
    text = TextEdit.text(mode.edit)

    db =
      case mode.target do
        {:item, id} -> Core.set_note(state.db, id, text, State.context(state))
        {:category, id} -> Core.set_category_note(state.db, id, text)
        {:macro, id} -> Core.set_macro_keys(state.db, id, text)
      end

    if db == state.db, do: state, else: State.change_db(state, db)
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
        State.error(
          state,
          "ALT-N / ALT-P work in notes opened from a view or the category manager"
        )

      {_, nil} ->
        state |> State.effect(:bell) |> State.error("No more notes in this direction")

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
