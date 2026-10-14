defmodule Agendum.TUI.ScheduleBox do
  @moduledoc """
  The Show Schedule box (Search ▸ Schedule; Agenda's Utilities Show Sched;
  SPEC R49; User's Guide 10-14 to 10-16): the items of one date, in the
  Show View.

    * Date category (When), Section head (the date category), Date (today)
      and Filter (none)
    * SPACE (or →) changes the highlighted setting: picks a category, asks
      for the date (F3 picks it from the pop-up calendar), or lists the
      categories for the filter (ENTER there cycles + assigned, − not
      assigned, none)
    * ENTER shows the schedule; ESC closes the box

  The settings live in the box until it is used. Pure.
  """

  import Agendum.TUI.BoxNav, only: [is_move: 1]
  alias Agendum.TUI.BoxNav

  alias Agendum.Core
  alias Agendum.Core.{Database, DateFormat}
  alias Agendum.TUI.{CalendarBox, CategoryScreens, State}
  alias Agendum.TUI.Update.Prompts

  @rows [:date_category, :section, :date, :filter]

  def open(state) do
    w = state.db.special.when

    State.push(state, %{
      type: :schedule,
      date_category: w,
      section: w,
      date: state.today,
      filter: [],
      cursor: 0
    })
  end

  def handle(state, mode, key) do
    row = Enum.at(@rows, mode.cursor)

    case {key, row} do
      {:esc, _} ->
        State.pop(state)

      {k, _} when is_move(k) ->
        BoxNav.move(state, mode, BoxNav.column(@rows), k)

      {:enter, _} ->
        show(State.pop(state), mode)

      {{:f, 3}, :date} ->
        CalendarBox.open(state, {:schedule, mode.date})

      {{:char, " "}, row} ->
        change(state, mode, row)

      _ ->
        state
    end
  end

  defp change(state, _mode, field) when field in [:date_category, :section],
    do: CategoryScreens.open_picker(state, {:schedule, field}, nil)

  defp change(state, mode, :date),
    do:
      Prompts.prompt(
        state,
        "Date (e.g. friday, 2026-12-14; F3 in the box: calendar):",
        :schedule_date,
        Date.to_iso8601(mode.date)
      )

  defp change(state, _mode, :filter),
    do: CategoryScreens.open_picker(state, {:schedule_filter, nil}, nil)

  defp show(state, mode) do
    case Core.show_schedule(state.db, mode.date_category, mode.section, mode.date, mode.filter) do
      {:ok, db, view_id} ->
        day = DateFormat.date(mode.date, %{db.date_format | day_of_week: true})

        state
        |> State.change_db(db)
        |> State.switch_view(view_id)
        |> State.info("Schedule for #{day} (ALT-B: other days)")

      {:error, :not_a_date_category} ->
        State.error(state, "The date category must be a date category")
    end
  end

  # the box beneath a picker, prompt or calendar it opened
  defp update(state, fun) do
    case Enum.find_index(state.modes, &(&1.type == :schedule)) do
      nil -> state
      i -> %{state | modes: List.update_at(state.modes, i, fun)}
    end
  end

  @doc "A category picked for the Date category or Section head."
  def set_category(state, :date_category, id) do
    if Database.date_category?(state.db, id) do
      # the section head follows a date category it was set to
      update(state, fn m ->
        section = if m.section == m.date_category, do: id, else: m.section
        %{m | date_category: id, section: section}
      end)
    else
      State.error(state, "Pick a date category")
    end
  end

  def set_category(state, :section, id), do: update(state, &%{&1 | section: id})

  @doc "ENTER in the filter list: + assigned, − not assigned, none, in turn."
  def cycle_filter(state, id) do
    update(state, fn m ->
      filter =
        case List.keyfind(m.filter, id, 0) do
          nil -> m.filter ++ [{id, :assigned}]
          {_, :assigned} -> List.keyreplace(m.filter, id, 0, {id, :not_assigned})
          {_, :not_assigned} -> List.keydelete(m.filter, id, 0)
        end

      %{m | filter: filter}
    end)
  end

  @doc "The filter's mark for a category in the list: + or −, or a space."
  def filter_mark(state, id) do
    case Enum.find(state.modes, &(&1.type == :schedule)) do
      %{filter: filter} ->
        case List.keyfind(filter, id, 0) do
          {_, :assigned} -> "+"
          {_, :not_assigned} -> "-"
          nil -> " "
        end

      nil ->
        " "
    end
  end

  @doc "A typed date, or one picked from the calendar."
  def set_date(state, %Date{} = date), do: update(state, &%{&1 | date: date})

  def set_date(state, text) do
    case Core.read_when(state.db, text, State.context(state)) do
      {:ok, date, _time} -> set_date(state, date)
      :error -> State.error(state, "Not a date: #{text}")
    end
  end

  @doc "`{label, value}` for each row."
  def lines(state, mode) do
    db = state.db
    name = &db.categories[&1].name

    filter =
      case mode.filter do
        [] ->
          "(none)"

        terms ->
          Enum.map_join(terms, ", ", fn {id, t} ->
            if(t == :assigned, do: "", else: "-") <> name.(id)
          end)
      end

    [
      {"Date category", name.(mode.date_category)},
      {"Section head", name.(mode.section)},
      {"Date", DateFormat.date(mode.date, %{db.date_format | day_of_week: true})},
      {"Filter", filter}
    ]
  end

  @doc "The highlighted field, for its help in the control panel (`Agendum.TUI.FieldHelp`)."
  def field(_state, mode), do: Enum.at(@rows, mode.cursor)
end
