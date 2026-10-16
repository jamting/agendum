defmodule Agendum.TUI.Moves.Browse do
  @moduledoc """
  Browsing (View ▸ Browse or ALT-B; User's Guide 10-12 to 10-14, Help
  "Browse Through Dates"): shifting the dates a view shows.

  In a datebook view (SPEC R47), flipping through the pages of the
  appointment book:

    * ← / → (or < / >) show the previous / next period: day, week, month
      or quarter

  In a standard view (R48), moving its date filter, or the highlighted
  section's when it has one:

    * ← / → a day, CTRL-← / CTRL-→ (or ↑ / ↓) a week, PGUP / PGDN a month,
      CTRL-PGUP / CTRL-PGDN (⌥↑ / ⌥↓ on a Mac) a year

  In both:

    * ALT-F5 (GO TO) asks for a date and goes there
    * ENTER keeps what is shown: the new dates become the view's (a
      datebook's base date, or the filter's dates, fixed); one undo step
    * ESC goes back to what the view had

  While browsing, the view shows the browsed dates (`State.view/1` asks
  `view/2`), the file is not changed, and nothing else can be done, as in
  Agenda. The control panel says BROWSE. Pure.
  """

  alias Agendum.Core
  alias Agendum.Core.{Datebook, MonthCalendar}
  alias Agendum.TUI.{Keymap, Layout, State}
  alias Agendum.TUI.Update.Prompts

  @no_shift %{days: 0, months: 0}

  @doc "Starts browsing the current view, if it is a datebook view or has a date filter."
  def open(state) do
    view = State.view(state)

    case {view.datebook, filter_scope(state, view)} do
      {%Datebook{} = d, _} ->
        date = Datebook.base_date(d, state.db.date_settings, State.context(state))
        State.push(state, %{type: :browse, view_id: view.id, date: date})

      {nil, nil} ->
        State.error(state, "Browse needs a date filter (View ▸ Filter) or a datebook view")

      {nil, scope} ->
        State.push(state, %{type: :browse, view_id: view.id, scope: scope, shift: @no_shift})
    end
  end

  # the highlighted section's date filter, else the view's
  defp filter_scope(state, view) do
    section =
      case Layout.current_row(state) do
        %{sidx: sidx} -> Enum.at(view.sections, sidx)
        nil -> nil
      end

    cond do
      section && Core.date_filters?(state.db, section.filter) ->
        {:section, Layout.current_row(state).sidx}

      Core.date_filters?(state.db, view.filter) ->
        :view

      true ->
        nil
    end
  end

  @doc "A view as shown while it is browsed: with the browsed dates."
  def view(%State{modes: modes} = state, view) do
    case Enum.find(modes, &match?(%{type: :browse, view_id: id} when id == view.id, &1)) do
      %{date: date} ->
        %{view | datebook: %{view.datebook | base: Date.to_iso8601(date)}}

      %{scope: scope, shift: shift} ->
        shifted = Core.shift_filters(state.db, filters(view, scope), shift, State.context(state))
        put_filters(view, scope, shifted)

      nil ->
        view
    end
  end

  defp filters(view, :view), do: view.filter
  defp filters(view, {:section, i}), do: Enum.at(view.sections, i).filter

  defp put_filters(view, :view, filters), do: %{view | filter: filters}

  defp put_filters(view, {:section, i}, filters),
    do: %{view | sections: List.update_at(view.sections, i, &%{&1 | filter: filters})}

  @doc "A key while browsing: the command Browse's keymap binds it to (R65)."
  def handle(state, mode, key) do
    case Keymap.lookup(:browse, key) do
      nil -> state
      id -> command(state, mode, id)
    end
  end

  @doc "F1's text while browsing dates (R65)."
  @spec about() :: String.t()
  def about do
    """
    You are browsing dates. A datebook view goes a period at a time with
    ← and → (or < and >). A view with a date filter moves its dates by a
    day (← →), a week (↑ ↓), a month (PGUP PGDN) or a year (CTRL-PGUP
    CTRL-PGDN). ALT-F5 goes to a date you type.

    ENTER keeps the dates shown; ESC goes back to the ones before.
    """
  end

  @doc "Runs a Browse command (`Agendum.TUI.Commands`)."
  @spec run(State.t(), atom) :: State.t()
  def run(state, id), do: command(state, State.mode(state), id)

  # how far each move goes in a date filter (a datebook goes a period)
  @shifts %{
    earlier: {:days, -1},
    later: {:days, 1},
    week_earlier: {:days, -7},
    week_later: {:days, 7},
    month_earlier: {:months, -1},
    month_later: {:months, 1},
    year_earlier: {:months, -12},
    year_later: {:months, 12}
  }

  defp command(state, %{date: _} = mode, :earlier), do: step(state, mode, -1)
  defp command(state, %{date: _} = mode, :later), do: step(state, mode, 1)

  defp command(state, %{shift: shift} = mode, id) when is_map_key(@shifts, id),
    do: move(state, mode, shift, @shifts[id])

  defp command(state, _mode, :go_to), do: Prompts.prompt(state, "Date:", :browse_to)
  defp command(state, mode, :keep), do: keep(State.pop(state), mode)
  defp command(state, _mode, :close), do: State.pop(state)
  defp command(state, _mode, :help), do: Agendum.TUI.HelpScreen.open(state)
  defp command(state, _mode, _id), do: state

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

  defp move(state, mode, shift, {unit, n}),
    do: State.put_mode(state, %{mode | shift: Map.update!(shift, unit, &(&1 + n))})

  @doc "ALT-F5's answer: go to a typed date."
  def go_to(state, text) do
    with %{type: :browse} = mode <- State.mode(state),
         {:ok, date, _time} <- Core.read_when(state.db, text, State.context(state)) do
      State.put_mode(state, go_to(state, mode, date))
    else
      _ -> State.error(state, "Not a date: #{text}")
    end
  end

  # a datebook shows the period of the date; a filter moves so that its
  # range starts on it (or ends, when it has no start)
  defp go_to(_state, %{date: _} = mode, date), do: %{mode | date: date}

  defp go_to(state, mode, date) do
    case first_date(state, mode) do
      nil -> mode
      shown -> %{mode | shift: Map.update!(mode.shift, :days, &(&1 + Date.diff(date, shown)))}
    end
  end

  defp first_date(state, mode) do
    view = view(state, state.db.views[mode.view_id])

    Enum.find_value(filters(view, mode.scope), fn
      {cat, {:range, from, to, _}} ->
        if Core.date_filters?(state.db, [{cat, {:range, from, to, :inside}}]) do
          with text when text != nil <- from || to,
               {:ok, date, _} <- Core.read_when(state.db, text, State.context(state)),
               do: date,
               else: (_ -> nil)
        end

      _ ->
        nil
    end)
  end

  # ENTER: what is shown becomes the view's
  defp keep(state, %{date: date} = mode) do
    d = state.db.views[mode.view_id].datebook
    now = Datebook.base_date(d, state.db.date_settings, State.context(state))

    if date == now do
      state
    else
      State.run(state, {:set_datebook, mode.view_id, %{d | base: Date.to_iso8601(date)}})
    end
  end

  defp keep(state, %{shift: @no_shift}), do: state

  defp keep(state, %{scope: scope, shift: shift} = mode) do
    view = state.db.views[mode.view_id]
    shifted = Core.shift_filters(state.db, filters(view, scope), shift, State.context(state))
    State.run(state, {:set_filters, mode.view_id, scope, shifted})
  end
end
