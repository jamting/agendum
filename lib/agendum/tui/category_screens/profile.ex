defmodule Agendum.TUI.CategoryScreens.Profile do
  @moduledoc """
  The assignment profile (F3): an item's assignments, or the marked
  items' (User's Guide 4-17), toggled with SPACE. Pure.
  """

  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.TUI.{CategoryScreens, State}
  alias Agendum.TUI.Update.Prompts

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
