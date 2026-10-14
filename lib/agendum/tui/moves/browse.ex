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
  alias Agendum.TUI.{Layout, State}
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

  @filter_moves %{
    :left => {:days, -1},
    :right => {:days, 1},
    :ctrl_left => {:days, -7},
    :ctrl_right => {:days, 7},
    :up => {:days, -7},
    :down => {:days, 7},
    :pgup => {:months, -1},
    :pgdn => {:months, 1},
    :ctrl_pgup => {:months, -12},
    :ctrl_pgdn => {:months, 12}
  }

  def handle(state, mode, key) do
    case {key, mode} do
      {k, %{date: _}} when k in [:left, {:char, "<"}] ->
        step(state, mode, -1)

      {k, %{date: _}} when k in [:right, {:char, ">"}] ->
        step(state, mode, 1)

      {k, %{shift: shift}} when is_map_key(@filter_moves, k) ->
        move(state, mode, shift, @filter_moves[k])

      {{:alt_f, 5}, _} ->
        Prompts.prompt(state, "Date:", :browse_to)

      {:enter, _} ->
        keep(State.pop(state), mode)

      {:esc, _} ->
        State.pop(state)

      _ ->
        state
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
      {:ok, db} = Core.set_datebook(state.db, mode.view_id, %{d | base: Date.to_iso8601(date)})
      State.change_db(state, db)
    end
  end

  defp keep(state, %{shift: @no_shift}), do: state

  defp keep(state, %{scope: scope, shift: shift} = mode) do
    view = state.db.views[mode.view_id]
    shifted = Core.shift_filters(state.db, filters(view, scope), shift, State.context(state))
    State.change_db(state, Core.set_filters(state.db, mode.view_id, scope, shifted))
  end
end
