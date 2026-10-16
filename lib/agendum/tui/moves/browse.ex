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
  alias Agendum.TUI.{Keymap, Layout, State}
  alias Agendum.TUI.Update.Prompts

  # Domain: the date arithmetic is the core's (`Agendum.Core.Browse`); the
  # mode is where browsing has got to (a place: `date:`, or `scope:` and
  # `shift:`), with its view's id.

  @doc "Starts browsing the current view, if it is a datebook view or has a date filter."
  def open(state) do
    view = State.view(state)
    sidx = with %{sidx: sidx} <- Layout.current_row(state), do: sidx

    case Core.browse_start(state.db, view, sidx, State.context(state)) do
      nil ->
        State.error(state, "Browse needs a date filter (View ▸ Filter) or a datebook view")

      place ->
        State.push(state, Map.merge(%{type: :browse, view_id: view.id}, place))
    end
  end

  @doc "A view as shown while it is browsed: with the browsed dates."
  def view(%State{modes: modes} = state, view) do
    case Enum.find(modes, &match?(%{type: :browse, view_id: id} when id == view.id, &1)) do
      nil -> view
      mode -> Core.browsed_view(state.db, view, mode, State.context(state))
    end
  end

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

  defp command(state, _mode, :go_to), do: Prompts.prompt(state, "Date:", :browse_to)
  defp command(state, mode, :keep), do: keep(State.pop(state), mode)
  defp command(state, _mode, :close), do: State.pop(state)
  defp command(state, _mode, :help), do: Agendum.TUI.HelpScreen.open(state)

  # the moves: a period in a datebook, a day, week, month or year in a filter
  defp command(state, mode, id),
    do: State.put_mode(state, Core.browse_move(state.db.views[mode.view_id], mode, id))

  @doc "ALT-F5's answer: go to a typed date."
  def go_to(state, text) do
    with %{type: :browse} = mode <- State.mode(state),
         {:ok, date, _time} <- Core.read_when(state.db, text, State.context(state)) do
      view = state.db.views[mode.view_id]
      State.put_mode(state, Core.browse_to(state.db, view, mode, date, State.context(state)))
    else
      _ -> State.error(state, "Not a date: #{text}")
    end
  end

  # ENTER: what is shown becomes the view's, one undo step
  defp keep(state, mode) do
    case Core.browse_keep(state.db, state.db.views[mode.view_id], mode, State.context(state)) do
      nil -> state
      command -> State.run(state, command)
    end
  end
end
