defmodule Agendum.TUI.CategoryScreens.Profile do
  @moduledoc """
  The assignment profile (F3): an item's assignments, or the marked
  items' (User's Guide 4-17), toggled with SPACE. One module for both
  boxes (`:profile` and `:group_profile`). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :none, indicator: "ASSIGN"

  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.TUI.{Boxes.Box, CategoryScreens, Terminal.Draw, State}
  alias Agendum.TUI.Update.Prompts

  # --- the box (`Agendum.TUI.Boxes.Box`) ---------------------------------------------------

  @impl Box
  def handle(state, mode, key), do: CategoryScreens.handle(state, mode, key)

  # R65: the hierarchy's moves; SPACE or ENTER assigns or unassigns (F7
  # too for marked items); ESC, F3 and F6 close (F4 too for one item)
  @impl Box
  def keymap(mode) do
    own =
      case mode do
        %{type: :group_profile} -> %{{:f, 7} => :toggle}
        _ -> %{{:f, 4} => :close}
      end

    CategoryScreens.list_keymap()
    |> Map.merge(%{
      {:char, " "} => :toggle,
      :enter => :toggle,
      :esc => :close,
      {:f, 3} => :close,
      {:f, 6} => :close
    })
    |> Map.merge(own)
  end

  @impl Box
  def commands(_mode) do
    [{:toggle, "Assign", "Assign or unassign the category"}] ++
      CategoryScreens.list_commands() ++ [{:close, "Return", "Close the profile"}]
  end

  @impl Box
  def run(state, mode, id) when id in [:toggle, :close] do
    rows = CategoryScreens.rows(state, mode)
    mode = CategoryScreens.clamp(mode, rows)
    key = if id == :toggle, do: {:char, " "}, else: :esc
    screen_key(State.put_mode(state, mode), mode, rows, key)
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
      k when k in [:esc, {:f, 3}, {:f, 6}] ->
        State.pop(state)

      k when k in [{:char, " "}, :enter, {:f, 7}] ->
        cond do
          Database.date_category?(db, id) ->
            State.error(state, "Set dates for marked items with ALT-F2 (When) or F4 (Done)")

          CategoryScreens.numeric?(db, id) ->
            CategoryScreens.numbers_hint(state, id)

          CategoryScreens.group_count(db, mode.item_ids, id) > 0 ->
            explicit = Enum.filter(mode.item_ids, &Database.explicit?(db, &1, id))

            State.change_db(
              state,
              Enum.reduce(explicit, db, &Core.toggle_assignment(&2, &1, id, State.context(state)))
            )

          true ->
            State.change_db(
              state,
              Enum.reduce(mode.item_ids, db, &Core.assign(&2, &1, id, State.context(state)))
            )
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
      k when k in [:esc, {:f, 6}, {:f, 3}, {:f, 4}] ->
        State.pop(state)

      k when k in [{:char, " "}, :enter] ->
        cond do
          id == db.special.done ->
            State.change_db(state, Core.toggle_done(db, item_id, state.today))

          Database.date_category?(db, id) ->
            State.error(state, "Set dates by typing in a date column")

          CategoryScreens.numeric?(db, id) and not Database.explicit?(db, item_id, id) ->
            Prompts.prompt(state, "#{db.categories[id].name}:", {:item_number, item_id, id})

          true ->
            State.change_db(state, Core.toggle_assignment(db, item_id, id, State.context(state)))
        end

      _ ->
        state
    end
  end
end
