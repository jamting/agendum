defmodule Agenda.TUI.Update.Prompts do
  @moduledoc """
  Prompts and confirmations in the control panel: a line of text
  (`prompt/4`) and what is done with it, and Y/N questions (`confirm/3`,
  `ask/3`) and their answers. Pure.
  """

  alias Agenda.Core
  alias Agenda.Core.DateFormat
  alias Agenda.TUI.{CalendarBox, Draw, LineEdit, State, Update}
  alias Agenda.TUI.CategoryScreens.Choices
  alias Agenda.TUI.Update.Actions

  # --- prompts and confirmations ------------------------------------------------

  @doc "Opens a one-line prompt; `action` is passed to `prompt_submitted/3`."
  def prompt(state, label, action, initial \\ "") do
    state
    |> State.push(%{type: :prompt, label: label, action: action})
    |> Map.put(:edit, %{line: LineEdit.new(initial)})
  end

  @doc "Converts a category to numeric (R29), reporting the result."
  def make_numeric(state, cat_id) do
    case Core.make_numeric(state.db, cat_id, State.context(state)) do
      {:ok, db} ->
        state |> State.change_db(db) |> State.info("#{db.categories[cat_id].name} is now numeric")

      {:error, _} ->
        State.error(state, "#{state.db.categories[cat_id].name} cannot become numeric")
    end
  end

  @doc "Converts a category to a date category (R6a), reporting the result."
  def make_date(state, cat_id) do
    case Core.make_date(state.db, cat_id, State.context(state)) do
      {:ok, db} ->
        state
        |> State.change_db(db)
        |> State.info("#{db.categories[cat_id].name} is now a date category")

      {:error, _} ->
        State.error(state, "#{state.db.categories[cat_id].name} cannot become a date category")
    end
  end

  @doc """
  Asks "are you sure?" (Y/N) before `action`; with Confirm mode off (R54)
  the action is done at once, as if Y. Questions whose answers lead to
  different things are `ask/3`.
  """
  def confirm(%State{prefs: %{confirm: false}} = state, _question, action),
    do: confirmed(state, action, true)

  def confirm(state, question, action), do: ask(state, question, action)

  @doc "Asks a Y/N question, whatever Confirm mode says: Y and N do different things."
  def ask(state, question, action),
    do: State.push(state, %{type: :confirm, question: question, action: action})

  @doc "A key in a one-line prompt; ENTER does its action, ESC cancels."
  def prompt_key(state, mode, key) do
    case key do
      :esc ->
        State.pop(state)

      # a file name can be picked from a list (R51)
      {:f, 3} ->
        if Agenda.TUI.SelectFile.file_prompt?(mode.action),
          do: Agenda.TUI.SelectFile.open(state, mode),
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

  defp prompt_action(state, :save_as, text) do
    path = Agenda.Store.normalize_path(text)
    State.effect(%{state | path: path}, {:save, path})
  end

  defp prompt_action(state, :save_as_then_quit, text) do
    path = Agenda.Store.normalize_path(text)
    state |> Map.put(:path, path) |> State.effect({:save, path}) |> State.effect(:quit)
  end

  defp prompt_action(state, {:save_as_then, command}, text) do
    path = Agenda.Store.normalize_path(text)
    state |> Map.put(:path, path) |> State.effect({:save, path}) |> replace_file(command)
  end

  defp prompt_action(state, :calendar_jump, text), do: CalendarBox.jump(state, text)

  # Calendars (R45): the address, then a name for its category
  defp prompt_action(state, :calendar_url, text),
    do: prompt(state, "Name of its category (its events go there):", {:calendar_name, text})

  defp prompt_action(state, {:calendar_name, url}, name) do
    case Core.subscribe_calendar(state.db, name, url) do
      {:ok, db, id} ->
        state
        |> State.change_db(db)
        |> State.info("Subscribed to #{name}")
        |> Update.fetch_calendar(id, :manual)

      {:error, :bad_url} ->
        State.error(state, "A calendar needs an https:// or webcal:// address")

      {:error, :no_name} ->
        State.error(state, "A calendar needs a name")
    end
  end

  defp prompt_action(state, :startup_open, text),
    do: State.effect(state, {:open_or_create, Agenda.Store.normalize_path(text)})

  defp prompt_action(state, :retrieve, text),
    do: State.effect(state, {:load, Agenda.Store.normalize_path(text)})

  defp prompt_action(state, :new_file, text) do
    path = Agenda.Store.normalize_path(text)

    %{
      State.reopen(state, Core.new_file(), path)
      | dirty: true,
        saved_db: nil
    }
    |> State.info("New file #{Path.basename(path)} (not saved yet)")
  end

  defp prompt_action(state, :add_category, text) do
    case Core.add_category(state.db, state.db.main_id, text) do
      {:ok, db, _} -> state |> State.change_db(db) |> State.info("Added #{text} under MAIN")
      {:error, :duplicate} -> State.error(state, "#{text} already exists")
    end
  end

  # a new view's name, then its type: Standard or Datebook (R47)
  defp prompt_action(state, :add_view, text),
    do: State.push(state, %{type: :choice, kind: :view_type, name: text, cursor: 0})

  defp prompt_action(state, {:datebook_time, view_id, row}, text),
    do: Agenda.TUI.DatebookBox.set_time(state, view_id, row, text)

  defp prompt_action(state, :browse_to, text), do: Agenda.TUI.Browse.go_to(state, text)
  defp prompt_action(state, :new_macro, text), do: Agenda.TUI.Macros.create(state, text)

  defp prompt_action(state, {:rename_macro, id}, text),
    do: Agenda.TUI.MacroProps.rename(state, id, text)

  defp prompt_action(state, {:attach_macro, id}, text),
    do: Agenda.TUI.MacroProps.attach(state, id, text)

  defp prompt_action(state, :schedule_date, text),
    do: Agenda.TUI.ScheduleBox.set_date(state, text)

  defp prompt_action(state, {:datebook_base, view_id}, text),
    do: Agenda.TUI.DatebookBox.set_base(state, view_id, text)

  defp prompt_action(state, {:when_items, ids}, text) do
    Enum.reduce_while(ids, {:ok, state.db}, fn id, {:ok, db} ->
      case Core.when_key(db, id, text, State.context(state)) do
        {:ok, db} -> {:cont, {:ok, db}}
        {:error, _} -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, db} ->
        state
        |> State.change_db(db)
        |> State.info("When date set for #{Draw.count(length(ids), "item")}")

      :error ->
        State.error(state, "Not a date: #{text} (try friday, next week, 12/24, December 24)")
    end
  end

  defp prompt_action(state, {:when, item_id}, text) do
    case Core.when_key(state.db, item_id, text, State.context(state)) do
      {:ok, db} ->
        state
        |> State.change_db(db)
        |> State.info("When: " <> DateFormat.date(db.items[item_id].when, db.date_format))

      {:error, :invalid_date} ->
        State.error(state, "Not a date: #{text} (try friday, next week, 12/24, December 24)")
    end
  end

  defp prompt_action(state, :rename_view, text) do
    State.change_db(state, Core.rename_view(state.db, state.view_id, text))
  end

  defp prompt_action(state, {:move_new_category, id, relocation}, text) do
    Choices.apply_move(state, id, relocation, {:new_category, text})
  end

  defp prompt_action(state, {:alarm, item_id}, text) do
    with {minutes, ""} <- Integer.parse(String.trim(text)),
         {:ok, db} <- Core.set_alarm(state.db, item_id, minutes) do
      at = Core.when_at(db.items[item_id]) |> NaiveDateTime.add(-minutes * 60)

      state
      |> State.change_db(db)
      |> State.info("Alarm set for " <> DateFormat.datetime(at, db.date_format))
    else
      _ -> State.error(state, "Type a number of minutes from 0 to 60")
    end
  end

  defp prompt_action(state, {:item_date, item_id, cat_id}, text) do
    case Core.assign_by_name(state.db, item_id, cat_id, text, State.context(state)) do
      {:ok, db, :date} ->
        State.change_db(state, db)

      {:error, :invalid_date} ->
        State.error(state, "Not a date: #{text} (try friday, next week, 12/24)")
    end
  end

  defp prompt_action(state, {:item_number, item_id, cat_id}, text) do
    case Core.assign_by_name(state.db, item_id, cat_id, text, State.context(state)) do
      {:ok, db, :number} ->
        State.change_db(state, db)

      {:error, :empty} ->
        State.change_db(state, Core.clear_number(state.db, item_id, cat_id, State.context(state)))

      {:error, :not_a_number} ->
        State.error(state, "Not a number: #{String.trim(text)}")
    end
  end

  defp prompt_action(state, {:exclusive_new_child, cat_id}, text) do
    Choices.apply_exclusive(state, cat_id, {:new_child, text})
  end

  defp prompt_action(state, :export_json, text),
    do: State.effect(state, {:write_text, Path.expand(text), Core.export_json(state.db)})

  defp prompt_action(state, :import_json, text),
    do: State.effect(state, {:import_json, Path.expand(text)})

  defp prompt_action(state, :export, text) do
    path = Path.expand(text)
    State.effect(state, {:write_text, path, Agenda.TUI.Render.Export.text(state)})
  end

  @doc "A key in a Y/N question; ESC cancels."
  def confirm_key(state, mode, key) do
    case key do
      {:char, c} when c in ["y", "Y"] -> state |> State.pop() |> confirmed(mode.action, true)
      {:char, c} when c in ["n", "N"] -> state |> State.pop() |> confirmed(mode.action, false)
      :esc -> State.pop(state)
      _ -> state
    end
  end

  defp confirmed(state, {:make_numeric, id}, true), do: make_numeric(state, id)

  defp confirmed(state, {:delete_macro, id}, true),
    do: State.change_db(state, Core.delete_macro(state.db, id))

  defp confirmed(state, {:make_date, id}, true), do: make_date(state, id)

  # Column Add ▸ Category type: the conversion is agreed to; the box is on top again
  defp confirmed(state, :column_add, true), do: Agenda.TUI.ColumnAddBox.add_now(state)

  defp confirmed(state, {:make_dependent, id, prerequisites}, true) do
    case Core.make_dependent(state.db, id, prerequisites) do
      {:ok, db} ->
        count = length(Core.prerequisites(db, id))
        state |> State.change_db(db) |> State.info("Depends on #{Draw.count(count, "item")}")

      {:error, :cycle} ->
        State.error(state, "Not done: the item would depend on itself (through the marked items)")
    end
  end

  defp confirmed(state, {:clear_dependencies, id}, true) do
    state
    |> State.change_db(Core.clear_dependencies(state.db, id))
    |> State.info("Dependencies cleared")
  end

  defp confirmed(state, {:sort_children, id}, true) do
    State.change_db(state, Core.sort_children(state.db, id))
  end

  defp confirmed(state, {:discard_items, ids}, true) do
    db = Enum.reduce(ids, state.db, &Core.discard_item(&2, &1))
    state |> State.change_db(db) |> State.info("#{Draw.count(length(ids), "item")} discarded")
  end

  defp confirmed(state, {:discard_item, id}, true) do
    state |> State.change_db(Core.discard_item(state.db, id)) |> State.info("Item discarded")
  end

  defp confirmed(state, {:discard_category, id}, true) do
    case Core.discard_category(state.db, id) do
      {:ok, db} -> state |> State.change_db(db) |> State.info("Category discarded")
      {:error, :protected} -> State.error(state, "This category cannot be discarded")
    end
  end

  defp confirmed(state, {:discard_view, id}, true) do
    case Core.discard_view(state.db, id) do
      {:ok, db} ->
        view_id = if state.view_id == id, do: hd(db.view_order), else: state.view_id
        %{State.change_db(state, db) | view_id: view_id, cursor: 0, cursor_key: nil}

      {:error, :last_view} ->
        State.error(state, "A file must have at least one view")
    end
  end

  defp confirmed(state, {:unsubscribe_calendar, id}, discard) do
    name = state.db.calendars[id].name

    state
    |> State.change_db(Core.unsubscribe_calendar(state.db, id, discard))
    |> State.info("Unsubscribed from #{name}")
  end

  defp confirmed(state, {:leave_for, command}, true) do
    if state.path,
      do: state |> State.effect({:save, state.path}) |> replace_file(command),
      else: prompt(state, "Save file as:", {:save_as_then, command})
  end

  defp confirmed(state, {:leave_for, command}, false), do: replace_file(state, command)

  defp confirmed(state, :quit, true), do: Actions.perform(state, :save_and_quit)
  defp confirmed(state, :quit, false), do: State.effect(state, :quit)
  defp confirmed(state, _action, false), do: state

  @doc "Asks which file replaces the open one (after any question about saving)."
  def replace_file(state, :retrieve), do: prompt(state, "File to retrieve:", :retrieve)
  def replace_file(state, :new_file), do: prompt(state, "Name of new file:", :new_file)

  def replace_file(state, :import_json),
    do: prompt(state, "JSON file to import (opens as a new file):", :import_json)
end
