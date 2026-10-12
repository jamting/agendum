defmodule Agenda.TUI.Browse do
  @moduledoc """
  Browsing a datebook view (View ▸ Browse or ALT-B; SPEC R47; User's Guide
  10-12 to 10-14): flipping through the pages of the appointment book.

    * ← / → (or < / >) show the previous / next period: day, week, month
      or quarter
    * ALT-F5 (GO TO) asks for a date and shows its period
    * ENTER keeps the period shown: the view's base date becomes its date
    * ESC goes back to the period the view had

  While browsing, the view shows the browsed period (`State.view/1` asks
  `browsed/1`), the file is not changed, and nothing else can be done,
  as in Agenda. The control panel says BROWSE. Pure.
  """

  alias Agenda.Core
  alias Agenda.Core.{Datebook, MonthCalendar}
  alias Agenda.TUI.{State, Update}

  @doc "Starts browsing the current view, if it is a datebook view."
  def open(state) do
    case State.view(state).datebook do
      nil ->
        State.error(state, "Browse needs a datebook view (View ▸ Add, Type Datebook)")

      d ->
        date = Datebook.base_date(d, state.db.date_settings, State.context(state))
        State.push(state, %{type: :browse, view_id: state.view_id, date: date})
    end
  end

  @doc "The date being browsed to for a view, if it is being browsed."
  def browsed(%State{modes: modes}, view_id) do
    Enum.find_value(modes, fn
      %{type: :browse, view_id: ^view_id, date: date} -> date
      _ -> nil
    end)
  end

  def handle(state, mode, key) do
    case key do
      k when k in [:left, {:char, "<"}] -> step(state, mode, -1)
      k when k in [:right, {:char, ">"}] -> step(state, mode, 1)
      {:alt_f, 5} -> Update.prompt(state, "Date:", :browse_to)
      :enter -> keep(State.pop(state), mode)
      :esc -> State.pop(state)
      _ -> state
    end
  end

  defp step(state, mode, n) do
    d = state.db.views[mode.view_id].datebook

    date =
      case d.period do
        :day -> MonthCalendar.move(mode.date, :day, n)
        :week -> MonthCalendar.move(mode.date, :week, n)
        :month -> MonthCalendar.move(mode.date, :month, n)
        :quarter -> MonthCalendar.move(mode.date, :month, 3 * n)
      end

    State.put_mode(state, %{mode | date: date})
  end

  @doc "ALT-F5's answer: the period of a typed date."
  def go_to(state, text) do
    with %{type: :browse} = mode <- State.mode(state),
         {:ok, date, _time} <- Core.read_when(state.db, text, State.context(state)) do
      State.put_mode(state, %{mode | date: date})
    else
      _ -> State.error(state, "Not a date: #{text}")
    end
  end

  # ENTER: the browsed period becomes the view's, by its date (an absolute
  # base date, as Agenda saved it)
  defp keep(state, mode) do
    d = state.db.views[mode.view_id].datebook
    now = Datebook.base_date(d, state.db.date_settings, State.context(state))

    if mode.date == now do
      state
    else
      {:ok, db} =
        Core.set_datebook(state.db, mode.view_id, %{d | base: Date.to_iso8601(mode.date)})

      State.change_db(state, db)
    end
  end
end
