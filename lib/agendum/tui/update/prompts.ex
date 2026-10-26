defmodule Agendum.TUI.Update.Prompts do
  @moduledoc """
  Prompts and confirmations in the control panel: a line of text
  (`prompt/4`) and what is done with it, and Y/N questions (`confirm/3`,
  `ask/3`) and their answers. A Y/N question is a box, this module's
  (`Agendum.TUI.Boxes.Box`, `:confirm`). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :accept

  alias Agendum.Core
  alias Agendum.Core.DateFormat
  alias Agendum.TUI.{Boxes.Box, Boxes.CalendarBox, Terminal.Draw, Typing.LineEdit, State, Update}
  alias Agendum.TUI.CategoryScreens.Choices
  alias Agendum.TUI.Update.Actions

  # --- prompts and confirmations ------------------------------------------------

  @doc "Opens a one-line prompt; `action` is passed to `prompt_submitted/3`."
  def prompt(state, label, action, initial \\ "") do
    state
    |> State.push(%Agendum.TUI.Modes.Prompt{label: label, action: action})
    |> Map.put(:edit, %{line: LineEdit.new(initial)})
  end

  @doc """
  A prompt whose text is hidden as it is typed, and kept out of the debug
  log (`password_prompt?/1`): the password of an Agenda file (R72).
  """
  def password(state, label, action), do: prompt(state, label, action)

  @doc """
  Whether a password is being typed (a prompt for one, or a password box,
  ADR 0046), whose keys are not shown or logged.
  """
  @spec password_prompt?(State.t()) :: boolean
  def password_prompt?(state) do
    case State.mode(state) do
      %{type: :password_box} ->
        true

      # the New File box's password, while it is typed (ADR 0046)
      %{type: :new_file, typing: {:password, _}} ->
        true

      # an action is an atom or a tuple; a password prompt's is a tuple
      %{type: :prompt, action: action} when is_tuple(action) ->
        elem(action, 0) in [:ag_password, :sftp_password, :file_password]

      _ ->
        false
    end
  end

  @doc "Converts a category to numeric (R29), reporting the result."
  def make_numeric(state, cat_id) do
    case State.command(state, {:make_numeric, cat_id}) do
      {:ok, state, _} ->
        State.info(state, "#{state.db.categories[cat_id].name} is now numeric")

      {:error, _} ->
        State.error(state, Agendum.TUI.Messages.text(:cannot_convert))
    end
  end

  @doc "Makes a category unindexed (R29b), saying why not when it cannot be."
  def make_unindexed(state, cat_id) do
    case State.command(state, {:make_unindexed, cat_id}) do
      {:ok, state, _} -> state
      {:error, _} -> State.error(state, Agendum.TUI.Messages.text(:cannot_convert))
    end
  end

  @doc "Converts a category to a date category (R6a), reporting the result."
  def make_date(state, cat_id) do
    case State.command(state, {:make_date, cat_id}) do
      {:ok, state, _} ->
        State.info(state, "#{state.db.categories[cat_id].name} is now a date category")

      {:error, _} ->
        State.error(state, Agendum.TUI.Messages.text(:cannot_convert))
    end
  end

  @doc """
  Asks "are you sure?" (Y/N) before `action`; with Confirm mode off (R54)
  the action is done at once, as if Y. Questions whose answers lead to
  different things are `ask/3`.
  """
  def confirm(state, question, action, opts \\ [])

  def confirm(%State{prefs: %{confirm: false}} = state, _question, action, _opts),
    do: confirmed(state, action, true)

  def confirm(state, question, action, opts), do: ask(state, question, action, opts)

  @doc """
  Asks a Y/N question, whatever Confirm mode says: Y and N do different
  things. It is a box, as Agenda's (screenshots 36, 141): the question with
  its answer, Yes at first, "Press ENTER to accept, ESC to cancel".
  `opts`: `answer:`, the answer shown first (Yes unless `false`); `help:`,
  Agenda's line for the question on the control panel in
  place of the usual "Y or N answers …"; `note:`, a second line under the
  question, as Agenda's "(Use ALT-F4 to discard the item completely.)".
  """
  def ask(state, question, action, opts \\ []),
    do:
      State.push(state, %Agendum.TUI.Modes.Confirm{
        question: question,
        action: action,
        answer: Keyword.get(opts, :answer, true),
        help: opts[:help],
        note: opts[:note]
      })

  @doc """
  Shows something in the Show View (Show Match, Sched, Alarm, Prereqs …):
  `then` is `{module, function, args}`, called with the state first. With a
  Show View already there, Agenda's question comes first ("Delete the
  existing Show view?", checked in Agenda 2.0, 2026-10-25): Agenda keeps
  one Show view, and ESC leaves it as it is.
  """
  @spec replace_show_view(State.t(), {module, atom, list}) :: State.t()
  def replace_show_view(state, then) do
    if Agendum.Core.show_view(state.db),
      do:
        confirm(state, "Delete the existing Show view?", {:replace_show_view, then},
          help:
            "You can have only one Show view.  Press ENTER to create the new " <>
              "Show view and delete the existing one."
        ),
      else: show(state, then)
  end

  # `apply/3` calls a function named by data: the module, its name and the
  # arguments, here with the state put first. The question's action stays
  # plain data this way, not a function kept in the state.
  defp show(state, {module, function, args}), do: apply(module, function, [state | args])

  @doc "A key in a one-line prompt; ENTER does its action, ESC cancels."
  def prompt_key(state, mode, key) do
    case key do
      :esc ->
        State.pop(state)

      # a file name can be picked from a list (R51)
      {:f, 3} ->
        if Agendum.TUI.Boxes.SelectFile.file_prompt?(mode.action),
          do: Agendum.TUI.Boxes.SelectFile.open(state, mode),
          else: state

      :enter ->
        state.edit.line.text |> then(&prompt_submitted(State.pop(state), mode.action, &1))

      _ ->
        case LineEdit.handle(state.edit.line, key) do
          {:ok, line} -> %{state | edit: %{line: line}}
          :unhandled -> state
        end
    end
  end

  # the pop-up calendar's F6: an empty time means none (R46)
  defp prompt_submitted(state, :calendar_time, text),
    do: CalendarBox.set_time(state, String.trim(text))

  defp prompt_submitted(state, action, text) do
    text = String.trim(text)

    if text == "", do: state, else: prompt_action(state, action, text)
  end

  # The file takes the new name once it is saved there (`Update.saved/4`),
  # so a save that fails leaves it under its old one.
  defp prompt_action(state, :save_as, text),
    do: State.save(state, Agendum.Store.normalize_path(text))

  # File ▸ Maintenance ▸ MakeCopy (R82): the copy, then the file saved, as
  # Agenda saves it too. Agenda saved first; writing the copy first gives
  # the same two files, and when the file changed on disk (R71) and is not
  # saved over, the changes are kept in the copy. An untitled file has
  # nothing to save.
  defp prompt_action(state, :make_copy, text) do
    path = Agendum.Store.normalize_path(text)

    cond do
      path == state.path ->
        State.error(state, "That is the file you are in")

      state.path == nil ->
        State.effect(state, {:save_copy, path, state.db})

      true ->
        state
        |> State.effect({:save_copy, path, state.db})
        |> State.save(state.path, then: {:copied, path})
    end
  end

  # File ▸ Maintenance ▸ Erase (R82): Agenda's question, No first, and
  # its refusal for the open file
  defp prompt_action(state, :erase_file, text) do
    path = Agendum.Store.normalize_path(text)

    if path == state.path,
      do: State.error(state, "You can't discard a file while it is open."),
      else:
        ask(state, "Discard #{Path.basename(path)}?", {:trash_file, path},
          answer: false,
          help: "Press Y to discard the file from your disk."
        )
  end

  # File ▸ Transfer ▸ Template (R82): the structure, without items, to
  # another file, whatever is there (Agenda's caution)
  defp prompt_action(state, :template, text) do
    path = Agendum.Store.normalize_path(text)

    if path == state.path,
      do: State.error(state, "That is the file you are in"),
      else: State.effect(state, {:save_copy, path, Agendum.Core.template(state.db)})
  end

  defp prompt_action(state, :save_as_then_quit, text),
    do: State.save(state, Agendum.Store.normalize_path(text), then: :quit)

  defp prompt_action(state, {:save_as_then, command}, text),
    do: State.save(state, Agendum.Store.normalize_path(text), then: {:replace_file, command})

  defp prompt_action(state, :calendar_jump, text), do: CalendarBox.jump(state, text)

  # an Agendum file's password (ADR 0046): it is opened again with it
  defp prompt_action(state, {:file_password, path}, text),
    do: State.effect(state, {:load_password, path, text})

  # an Agenda file's password (R72): the import is tried again with it
  defp prompt_action(state, {:ag_password, path, bytes}, text),
    do: Update.import_ag(state, path, bytes, text)

  # the SFTP server's password (R74): the publish is tried again with it;
  # the preview box is still under the prompt
  defp prompt_action(state, {:sftp_password}, text),
    do: Agendum.TUI.Extras.PublishPreviewBox.publish(state, State.mode(state), text)

  # Calendars (R45): the address, then a name for its category
  defp prompt_action(state, :calendar_url, text),
    do: prompt(state, "Name of its category (its events go there):", {:calendar_name, text})

  defp prompt_action(state, {:calendar_name, url}, name) do
    case State.command(state, {:subscribe_calendar, name, url}) do
      {:ok, state, %{new: id}} ->
        state
        |> State.info("Subscribed to #{name}")
        |> Update.fetch_calendar(id, :manual)

      {:error, :bad_url} ->
        State.error(state, "A calendar needs an https:// or webcal:// address")

      {:error, :no_name} ->
        State.error(state, "A calendar needs a name")
    end
  end

  # Feeds (R75): the address, then its name (its category under Feeds)
  defp prompt_action(state, :feed_url, text),
    do: prompt(state, "Name of the feed (its category under Feeds):", {:feed_name, text})

  defp prompt_action(state, {:feed_name, url}, name) do
    case State.command(state, {:subscribe_feed, name, url}) do
      {:ok, state, %{new: id}} ->
        state
        |> State.info("Subscribed to #{String.trim(name)}")
        |> Update.fetch_feed(id, :manual)

      {:error, :bad_url} ->
        State.error(state, "A feed needs an https:// or feed:// address")

      {:error, :no_name} ->
        State.error(state, "A feed needs a name")
    end
  end

  defp prompt_action(state, :import_opml, text),
    do: State.effect(state, {:read_opml, String.trim(text)})

  defp prompt_action(state, :export_opml, text),
    do:
      State.effect(
        state,
        {:write_text, Path.expand(String.trim(text)), Agendum.Core.export_opml(state.db)}
      )

  defp prompt_action(state, :startup_open, text),
    do: State.effect(state, {:open_or_create, Agendum.Store.normalize_path(text)})

  defp prompt_action(state, :retrieve, text),
    do: State.effect(state, {:load, Agendum.Store.normalize_path(text)})

  defp prompt_action(state, :add_category, text) do
    case State.command(state, {:add_category, state.db.main_id, text, []}) do
      {:ok, state, _} -> State.info(state, "Added #{text} under MAIN")
      {:error, :duplicate} -> State.error(state, "#{text} already exists")
    end
  end

  # a new view's name, then its type: Standard or Datebook (R47)
  defp prompt_action(state, :add_view, text),
    do: State.push(state, %Agendum.TUI.Modes.Choice{kind: :view_type, name: text, cursor: 0})

  defp prompt_action(state, {:datebook_time, view_id, row}, text),
    do: Agendum.TUI.Boxes.DatebookSettings.set_time(state, view_id, row, text)

  defp prompt_action(state, {:date_setting_time, row}, text),
    do: Agendum.TUI.Boxes.DateSettingsBox.set_time(state, row, text)

  defp prompt_action(state, :browse_to, text), do: Agendum.TUI.Moves.Browse.go_to(state, text)
  defp prompt_action(state, :new_macro, text), do: Agendum.TUI.Macros.create(state, text)

  defp prompt_action(state, {:rename_macro, id}, text),
    do: Agendum.TUI.Boxes.MacroProps.rename(state, id, text)

  defp prompt_action(state, {:attach_macro, id}, text),
    do: Agendum.TUI.Boxes.MacroProps.attach(state, id, text)

  defp prompt_action(state, :schedule_date, text),
    do: Agendum.TUI.Boxes.ScheduleBox.set_date(state, text)

  defp prompt_action(state, {:datebook_base, view_id}, text),
    do: Agendum.TUI.Boxes.DatebookSettings.set_base(state, view_id, text)

  defp prompt_action(state, {:when_items, ids}, text) do
    case State.command(state, {:batch, Enum.map(ids, &{:when_key, &1, text})}) do
      {:ok, state, _} ->
        State.info(state, "When date set for #{Draw.count(length(ids), "item")}")

      {:error, _} ->
        State.error(state, Agendum.TUI.Messages.text(:bad_date))
    end
  end

  defp prompt_action(state, {:when, item_id}, text) do
    case State.command(state, {:when_key, item_id, text}) do
      {:ok, %{db: db} = state, _} ->
        State.info(state, "When: " <> DateFormat.date(db.items[item_id].when, db.date_format))

      {:error, :invalid_date} ->
        State.error(state, Agendum.TUI.Messages.text(:bad_date))
    end
  end

  defp prompt_action(state, {:move_new_category, id, relocation}, text) do
    Choices.apply_move(state, id, relocation, {:new_category, text})
  end

  defp prompt_action(state, {:item_date, item_id, cat_id}, text) do
    case State.command(state, {:assign_by_name, item_id, cat_id, text}) do
      {:ok, state, %{result: :date}} ->
        state

      {:error, :invalid_date} ->
        State.error(state, Agendum.TUI.Messages.text(:bad_date))
    end
  end

  defp prompt_action(state, {:item_number, item_id, cat_id}, text) do
    case State.command(state, {:assign_by_name, item_id, cat_id, text}) do
      {:ok, state, %{result: :number}} ->
        state

      {:error, :empty} ->
        State.run(state, {:clear_number, item_id, cat_id})

      {:error, :not_a_number} ->
        State.error(state, Agendum.TUI.Messages.text(:bad_number))
    end
  end

  # an item's text in an unindexed category (R29b): empty takes it out
  defp prompt_action(state, {:item_text, item_id, cat_id}, text),
    do: State.run(state, {:set_text, item_id, cat_id, text})

  defp prompt_action(state, {:exclusive_new_child, cat_id}, text) do
    Choices.apply_exclusive(state, cat_id, {:new_child, text})
  end

  # a note's Import and Export (R64c); the shell reads or writes the file
  defp prompt_action(state, :note_import, text),
    do: State.effect(state, {:read_note_text, Path.expand(text)})

  defp prompt_action(state, :note_export, text) do
    case Agendum.TUI.Update.Notes.export_text(state) do
      nil -> state
      note -> State.effect(state, {:write_text, Path.expand(text), note})
    end
  end

  defp prompt_action(state, :export_json, text),
    do: State.effect(state, {:write_text, Path.expand(text), Core.export_json(state.db)})

  defp prompt_action(state, :import_json, text),
    do: State.effect(state, {:import_json, Path.expand(text)})

  defp prompt_action(state, :export, text) do
    path = Path.expand(text)
    State.effect(state, {:write_text, path, Agendum.TUI.Render.Export.text(state)})
  end

  @doc """
  A key in a Y/N question: SPACE (or an arrow) switches the answer, ENTER
  accepts the answer shown, Y or N answer at once (our choice: Agenda's
  first letter only picked it), ESC cancels.
  """
  @impl Box
  def handle(state, _mode, _key), do: state

  # R65
  @impl Box
  def keymap(_mode) do
    %{
      {:char, "y"} => :yes,
      {:char, "Y"} => :yes,
      {:char, "n"} => :no,
      {:char, "N"} => :no,
      :enter => :accept,
      {:char, " "} => :switch,
      :left => :switch,
      :right => :switch,
      :up => :switch,
      :down => :switch,
      :esc => :close
    }
  end

  @impl Box
  def commands(_mode) do
    [
      {:yes, "Yes", "Answer yes"},
      {:no, "No", "Answer no"},
      {:switch, "Switch", "Switch the answer shown"},
      {:accept, "Accept", "Give the answer shown"},
      {:close, "Cancel", "Do not answer"}
    ]
  end

  @impl Box
  def run(state, mode, :yes), do: state |> State.pop() |> confirmed(mode.action, true)
  def run(state, mode, :no), do: state |> State.pop() |> confirmed(mode.action, false)
  def run(state, mode, :accept), do: state |> State.pop() |> confirmed(mode.action, mode.answer)
  def run(state, mode, :switch), do: State.put_mode(state, %{mode | answer: not mode.answer})
  def run(state, mode, :close), do: state |> State.pop() |> cancelled(mode.action)

  @impl Box
  def about(_state, mode) do
    """
    A question: #{mode.question}

    Y answers yes, N no. SPACE switches the answer shown, ENTER gives it.
    ESC does not answer.
    """
  end

  # a question has no title, as Agenda's
  @impl Box
  def title(_state, _mode), do: ""

  # the question, its answer highlighted after it; a long question goes on
  # over more lines
  @impl Box
  def content(_state, mode, inner, _max_rows) do
    answer = if mode.answer, do: "Yes", else: "No "
    lines = Draw.wrap(mode.question, inner - 7)
    {first, [last]} = Enum.split(lines, -1)

    Enum.map(first, &[{:box, " " <> &1}]) ++
      [[{:box, " " <> last <> "  "}, {:box_selected, answer}]] ++
      if(mode.note, do: [[{:box, "   " <> mode.note}]], else: [])
  end

  # as wide as the question and its answer need, as Agenda's (and wide
  # enough for the words in its frame)
  @impl Box
  def width(state, %{question: q, note: note}),
    do:
      max(String.length(q) + 7, String.length(note || "") + 4)
      |> max(40)
      |> min(state.width - 8)

  @impl Box
  def keys(_state, _mode),
    do: [
      {"Y", "Yes"},
      {"N", "No"},
      {"SPACE", "Switch", "Switch the answer"},
      {"ENTER", "Accept"},
      {"ESC", "Cancel"}
    ]

  @impl Box
  def help, do: "Y or N answers. SPACE switches the answer; ENTER accepts the one shown."

  defp confirmed(state, {:make_numeric, id}, true), do: make_numeric(state, id)
  defp confirmed(state, {:trash_file, path}, true), do: State.effect(state, {:trash_file, path})

  defp confirmed(state, {:replace_show_view, then}, true), do: show(state, then)

  # DEL on an item in a view
  defp confirmed(state, {:remove_item, item_id, cat_id}, true),
    do: Agendum.TUI.Update.ViewKeys.remove_item(state, item_id, cat_id)

  # DEL in the alarm list (R38)
  defp confirmed(state, {:remove_alarm, :current, id}, true),
    do: State.run(state, {:cancel_alarm, id})

  defp confirmed(state, {:remove_alarm, :past, id}, true),
    do: State.run(state, {:remove_past_alarm, id})

  defp confirmed(state, {:make_unindexed, id}, true), do: make_unindexed(state, id)

  # Search/Replace in a note: Y replaces this occurrence, N skips it
  defp confirmed(state, {:note_replace, asked}, answer),
    do: Agendum.TUI.Typing.NoteSearch.answer(state, asked, answer)

  defp confirmed(state, :clear_note, true), do: Agendum.TUI.Update.Notes.clear(state)

  # ESC in a note (R64d): both answers leave the note
  defp confirmed(state, :discard_note, yes?), do: Agendum.TUI.Update.Notes.discard(state, yes?)

  # the macro's own properties box and editor, wherever they are on the
  # stack, go with it (a manager can be opened over them). `^id` pins the
  # pattern to this id, instead of binding a new name
  defp confirmed(state, {:delete_macro, id}, true) do
    state = State.run(state, {:delete_macro, id})

    modes =
      Enum.reject(state.modes, fn mode ->
        match?(%{type: :macro_props, macro_id: ^id}, mode) or
          match?(%{type: :note, target: {:macro, ^id}}, mode)
      end)

    %{state | modes: modes}
  end

  defp confirmed(state, {:make_date, id}, true), do: make_date(state, id)

  # Column Add ▸ Category type: the conversion is agreed to; the box is on top again
  defp confirmed(state, :column_add, true), do: Agendum.TUI.Boxes.ColumnAddBox.add_now(state)

  defp confirmed(state, {:make_dependent, id, prerequisites}, true) do
    case State.command(state, {:make_dependent, id, prerequisites}) do
      {:ok, state, _} ->
        count = length(Core.prerequisites(state.db, id))
        State.info(state, "Depends on #{Draw.count(count, "item")}")

      {:error, :cycle} ->
        State.error(state, Agendum.TUI.Messages.text(:depends_on_itself))
    end
  end

  defp confirmed(state, {:clear_dependencies, id}, true) do
    State.run(state, {:clear_dependencies, id}, "Dependencies cleared")
  end

  defp confirmed(state, {:sort_children, id}, true) do
    State.run(state, {:sort_children, id})
  end

  defp confirmed(state, {:discard_items, ids}, true) do
    State.run(state, {:discard_items, ids}, "#{Draw.count(length(ids), "item")} discarded")
  end

  defp confirmed(state, {:discard_item, id}, true) do
    State.run(state, {:discard_items, [id]}, "Item discarded")
  end

  # Utilities ▸ Trash (R24a): gone for good; undo can still bring it back
  # while Agendum is open
  defp confirmed(state, :empty_trash, true), do: State.run(state, :empty_trash)

  # ALT-F8 in the category manager (R15f)
  defp confirmed(state, {:clear_conditions_actions, id, which}, true),
    do: State.run(state, {:clear_conditions_actions, id, which})

  defp confirmed(state, {:discard_category, id}, true) do
    case State.command(state, {:discard_category, id}) do
      {:ok, state, _} ->
        State.info(state, "Category discarded")

      {:error, :protected} ->
        State.error(state, Agendum.TUI.Messages.cannot_discard(state.db, id))
    end
  end

  defp confirmed(state, {:discard_view, id}, true) do
    case State.command(state, {:discard_view, id}) do
      {:ok, state, _} ->
        view_id = if state.view_id == id, do: hd(state.db.view_order), else: state.view_id
        %{state | view_id: view_id, cursor: 0, cursor_key: nil}

      {:error, :last_view} ->
        State.error(state, "A file must have at least one view")
    end
  end

  defp confirmed(state, {:unsubscribe_feed, id}, discard) do
    name = state.db.feeds[id].name
    State.run(state, {:unsubscribe_feed, id, discard}, "Unsubscribed from #{name}")
  end

  defp confirmed(state, {:unsubscribe_calendar, id}, discard) do
    name = state.db.calendars[id].name

    State.run(state, {:unsubscribe_calendar, id, discard}, "Unsubscribed from #{name}")
  end

  # Domain: the answers to "Save changes first?" (Retrieve, New, Import)
  # and "Save changes before quitting?". Yes saves (asking for a name when
  # the file has none) and then goes on; No goes on without saving.
  defp confirmed(state, {:leave_for, command}, true) do
    if state.path,
      do: State.save(state, state.path, then: {:replace_file, command}),
      else: prompt(state, "Save file as:", {:save_as_then, command})
  end

  defp confirmed(state, {:leave_for, command}, false), do: replace_file(state, command)

  # Domain: the file changed on disk since it was read or saved (R71). Yes
  # saves over it, then goes on as the save would have (quit, open another
  # file); No keeps the changes unsaved, and nothing else happens.
  defp confirmed(state, {:overwrite, path, then}, true),
    do: State.save(state, path, expect: :any, then: then)

  defp confirmed(state, {:overwrite, _path, _then}, false),
    do:
      State.error(
        state,
        "Not saved. File ▸ Maintenance ▸ MakeCopy writes it to another file, keeping both"
      )

  defp confirmed(state, :quit, true), do: Actions.perform(state, :save_and_quit)
  defp confirmed(state, :quit, false), do: State.effect(state, :quit)
  defp confirmed(state, _action, false), do: state

  # ESC in a question: most questions just close; a note's replacements
  # stop there and report how many were made
  defp cancelled(state, {:note_replace, asked}),
    do: Agendum.TUI.Typing.NoteSearch.stop(state, asked)

  defp cancelled(state, _action), do: state

  @doc """
  A new, empty file named `path`, not saved yet: Retrieve with a name that
  is not a file yet, after asking (Agenda's way to make a file, User's
  Guide 22-3).
  """
  @spec new_file(State.t(), String.t()) :: State.t()
  def new_file(state, path, db \\ Core.new_file()) do
    %{
      State.reopen(state, db, path)
      | dirty: true,
        saved: %{db: nil, stamp: nil, conflict: false}
    }
    |> State.info("New file #{Path.basename(path)} (not saved yet)")
  end

  @doc "Asks which file replaces the open one (after any question about saving)."
  def replace_file(state, :retrieve), do: prompt(state, "File to retrieve:", :retrieve)

  def replace_file(state, :import_json),
    do: prompt(state, "JSON or Agenda (.AG) file to import (opens as a new file):", :import_json)
end
