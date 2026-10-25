defmodule Agendum.TUI.CategoryScreens.Profile do
  @moduledoc """
  The assignment profile (F3): an item's assignments, or the marked
  items' (User's Guide 4-17), toggled with SPACE. One module for both
  boxes (`:profile` and `:group_profile`). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :enter_accept

  alias Agendum.Core
  alias Agendum.Core.{Database, DateFormat}
  alias Agendum.TUI.{Boxes.Box, CategoryScreens, Terminal.Draw, State}
  alias Agendum.TUI.Update.Prompts

  # --- the box (`Agendum.TUI.Boxes.Box`) ---------------------------------------------------

  # --- why the item is in the highlighted category (R67) ------------------------

  @doc """
  What the control panel says on one item's profile: why the item is in
  the highlighted category ("In Kanga: its text matches"), from the core's
  reasons (`Agendum.Core.assignment_reasons/4`); nil when it is not in it,
  or on the marked items' profile.
  """
  @spec reason(State.t()) :: String.t() | nil
  def reason(%State{} = state) do
    with %{type: :profile, item_id: item_id} = mode <- State.mode(state),
         cat_id when cat_id != nil <-
           CategoryScreens.current_id(CategoryScreens.rows(state, mode), mode),
         [_ | _] = reasons <-
           Core.assignment_reasons(state.db, item_id, cat_id, State.context(state)) do
      name = state.db.categories[cat_id].name
      "In #{name}: " <> Enum.map_join(reasons, "; ", &words(state.db, &1))
    else
      _ -> nil
    end
  end

  defp words(_db, :main), do: "every item is in MAIN"
  defp words(db, {:date, date}), do: "dated " <> DateFormat.date(date, db.date_format)
  defp words(db, {:through, child}), do: "through " <> db.categories[child].name
  defp words(_db, :text_match), do: "its text matches"
  defp words(db, {:action, other}), do: "#{db.categories[other].name}'s action assigns it"
  defp words(_db, :assigned), do: "assigned by hand, or kept from before"

  defp words(db, {:condition, conditions}),
    do: "its condition holds (" <> Enum.map_join(conditions, ", ", &condition(db, &1)) <> ")"

  # a condition: the category, "not" before one the item must not be in
  defp condition(db, {cat, :not_assigned}), do: "not " <> db.categories[cat].name
  defp condition(db, {cat, _}), do: db.categories[cat].name

  @impl Box
  def handle(state, mode, key), do: CategoryScreens.handle(state, mode, key)

  @impl Box
  def about(_state, %{type: :group_profile}) do
    """
    The assignments of the marked items: every category, with how many of
    the marked items are in it.

    SPACE on a category assigns all the marked items to it, or,
    when some are in it, takes them out. Dates and numbers are set
    elsewhere: ALT-F2 or F4 for dates, the item's column for a number.

    ↑ ↓ move, HOME goes to the parent, CTRL-PGUP CTRL-PGDN to the siblings;
    ALT-− and ALT-= collapse and expand families. ENTER or ESC closes the box.
    """
  end

  def about(_state, _mode) do
    """
    The item's assignment profile: every category, with a mark where the
    item is assigned. Assigning an item to a category is what puts it in
    that category's sections and columns. The line at the top says why the
    item is in the highlighted category: its text, a condition, an action,
    a category below it, or you.

    SPACE on a category assigns the item to it, or takes it out.
    A numeric category asks for the number; dates are typed in a date
    column. Done marks the item done.

    ↑ ↓ move, HOME goes to the parent, CTRL-PGUP CTRL-PGDN to the siblings;
    ALT-− and ALT-= collapse and expand families. ENTER, ESC, F3 or F6 closes it.
    """
  end

  # R65: the hierarchy's moves; SPACE and F7 (Agenda's INCLCAT) assign or
  # unassign; F6 (PROPS) opens the highlighted category's properties, as
  # Agenda's (checked in Agenda 2.0, 2026-10-25); ENTER, ESC and F3 close,
  # keeping it (F4 too for one item)
  @impl Box
  def keymap(mode) do
    own =
      case mode do
        %{type: :group_profile} -> %{}
        _ -> %{{:f, 4} => :close}
      end

    CategoryScreens.list_keymap()
    |> Map.merge(%{
      {:char, " "} => :toggle,
      {:f, 7} => :toggle,
      {:f, 6} => :category_props,
      :enter => :close,
      :esc => :close,
      {:f, 3} => :close
    })
    |> Map.merge(own)
  end

  @impl Box
  def commands(_mode) do
    [
      {:toggle, "Assign", "Assign or unassign the category"},
      {:category_props, "Props", "The highlighted category's properties"}
    ] ++
      CategoryScreens.list_commands() ++ [{:close, "Return", "Close the profile"}]
  end

  @impl Box
  def run(state, mode, id) when id in [:toggle, :close] do
    rows = CategoryScreens.rows(state, mode)
    mode = CategoryScreens.clamp(mode, rows)
    key = if id == :toggle, do: {:char, " "}, else: :esc
    screen_key(State.put_mode(state, mode), mode, rows, key)
  end

  def run(state, mode, :category_props) do
    rows = CategoryScreens.rows(state, mode)
    Box.category_props(state, CategoryScreens.current_id(rows, CategoryScreens.clamp(mode, rows)))
  end

  def run(state, mode, id), do: CategoryScreens.run_list(state, mode, id)

  @impl Box
  def title(_state, %{type: :group_profile, item_ids: ids}),
    do: "Assignments: #{Draw.count(length(ids), "marked item")}"

  def title(state, %{type: :profile, item_id: id}),
    do: "Assignments: " <> String.slice(state.db.items[id].text, 0, 40)

  @impl Box
  def content(state, mode, inner, max_rows),
    do: CategoryScreens.list_lines(state, mode, inner, max_rows, &marker/3) ++ [[], legend(mode)]

  defp legend(%{type: :group_profile}),
    do: [{:box, " N = marked items assigned · SPACE assigns or unassigns all"}]

  defp legend(%{type: :profile}),
    do: [{:box, " * assigned  c by a condition  + via subcategory  SPACE"}]

  # how many marked items are in the category (+ for ten or more)
  defp marker(state, %{type: :group_profile, item_ids: ids}, id) do
    case CategoryScreens.group_count(state.db, ids, id) do
      0 -> " "
      n when n < 10 -> Integer.to_string(n)
      _ -> "+"
    end
  end

  # how the item is in the category: a date, by a condition, assigned, or
  # through a subcategory
  defp marker(state, %{type: :profile, item_id: item_id}, id) do
    db = state.db

    cond do
      Database.date_category?(db, id) ->
        if Database.item_date(db, item_id, id), do: "◊", else: " "

      Database.conditional?(db, item_id, id) ->
        "c"

      Database.explicit?(db, item_id, id) ->
        "*"

      Database.member?(db, item_id, id) ->
        "+"

      true ->
        " "
    end
  end

  @impl Box
  def keys(_state, _mode),
    do: [
      {"SPACE", "Assign/Unassign", "Assign or unassign"},
      {"ESC", "Return", "Done"}
    ]

  @impl Box
  def help, do: nil

  # --- assignment profile -----------------------------------------------------------------

  @doc "Keys of the assignment profile and the marked items' profile."
  # SPACE on a category no marked item is assigned to assigns them all;
  # on one that some are assigned to (a number shows), it unassigns them all.
  def screen_key(state, %{type: :group_profile} = mode, rows, key) do
    id = CategoryScreens.current_id(rows, mode)
    db = state.db

    case key do
      k when k in [:esc, {:f, 3}] ->
        State.pop(state)

      k when k in [{:char, " "}, {:f, 7}] ->
        cond do
          Database.date_category?(db, id) ->
            State.error(state, "Set dates for marked items with ALT-F2 (When) or F4 (Done)")

          CategoryScreens.numeric?(db, id) ->
            CategoryScreens.numbers_hint(state, id)

          CategoryScreens.group_count(db, mode.item_ids, id) > 0 ->
            explicit = Enum.filter(mode.item_ids, &Database.explicit?(db, &1, id))
            State.run(state, {:batch, Enum.map(explicit, &{:toggle_assignment, &1, id})})

          true ->
            State.run(state, {:batch, Enum.map(mode.item_ids, &{:assign, &1, id})})
        end

      _ ->
        state
    end
  end

  def screen_key(state, %{type: :profile} = mode, rows, key) do
    id = CategoryScreens.current_id(rows, mode)
    item_id = mode.item_id
    db = state.db

    case key do
      k when k in [:esc, {:f, 3}, {:f, 4}] ->
        State.pop(state)

      {:char, " "} ->
        cond do
          id == db.special.done ->
            State.run(state, {:toggle_done, item_id})

          Database.date_category?(db, id) ->
            State.error(state, "Set dates by typing in a date column")

          CategoryScreens.numeric?(db, id) and not Database.explicit?(db, item_id, id) ->
            Prompts.prompt(state, "#{db.categories[id].name}:", {:item_number, item_id, id})

          true ->
            State.run(state, {:toggle_assignment, item_id, id})
        end

      _ ->
        state
    end
  end
end
