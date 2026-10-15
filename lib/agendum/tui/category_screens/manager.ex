defmodule Agendum.TUI.CategoryScreens.Manager do
  @moduledoc """
  The category manager (F9, User's Guide 16-1 to 16-12): its commands
  (`Agendum.TUI.Commands`, run through its keymap, R65), adding categories
  beside, above and under the highlighted one, and reordering them. Pure.
  """

  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.TUI.{CategoryScreens, Keymap, Typing.LineEdit, State}
  alias Agendum.TUI.CategoryScreens.Choices
  alias Agendum.TUI.Update.Prompts

  # --- category manager ------------------------------------------------------------

  @doc """
  A key in the category manager (F9): it runs the command the manager's
  keymap binds it to (`Agendum.TUI.Keymap`, R65); an unbound character
  starts typing a new category below the highlighted one.
  """
  def handle(state, %{type: :catmgr} = mode, key) do
    state = clamp(state, mode)

    case {Keymap.lookup(:catmgr, key), key} do
      {nil, {:char, c}} -> new_category(state, current(state), c)
      {nil, _} -> state
      {id, _} -> run(state, id)
    end
  end

  @doc "Runs a category manager command (`Agendum.TUI.Commands`) on the highlighted category."
  @spec run(State.t(), atom) :: State.t()
  def run(state, command) do
    state = clamp(state, State.mode(state))
    command(state, command, current(state))
  end

  defp clamp(state, mode) do
    last = length(CategoryScreens.rows(state, mode)) - 1
    State.put_mode(state, %{mode | cursor: mode.cursor |> min(last) |> max(0)})
  end

  defp current(state) do
    mode = State.mode(state)
    CategoryScreens.current_id(CategoryScreens.rows(state, mode), mode)
  end

  # moving the highlight, as in every screen listing the hierarchy
  @moves [:up, :down, :page_up, :page_down, :first, :last, :parent, :last_sibling] ++
           [:previous_sibling, :next_sibling]

  defp command(state, where, _id) when where in @moves do
    mode = State.mode(state)

    State.put_mode(
      state,
      CategoryScreens.move(state, mode, CategoryScreens.rows(state, mode), where)
    )
  end

  defp command(state, :close, _id), do: State.pop(state)
  defp command(state, :help, _id), do: Agendum.TUI.HelpScreen.open(state)
  defp command(state, :add_below, id), do: new_category(state, id, "")
  defp command(state, :add_above, id), do: insert_category(state, id, :above)
  defp command(state, :add_family, id), do: insert_category(state, id, :uncle)
  defp command(state, :add_child, id), do: insert_category(state, id, :child)
  defp command(state, :execute, id), do: Agendum.TUI.Boxes.ExecuteBox.run(state, id, :all)

  defp command(state, :rename, id) do
    cat = state.db.categories[id]

    if Database.protected?(state.db, id),
      do: State.error(state, "#{cat.name} cannot be renamed"),
      else: %{state | edit: %{target: {:rename, id}, line: LineEdit.new(cat.name)}}
  end

  defp command(state, :promote, id), do: Choices.move(state, id, :promote)
  defp command(state, :demote, id), do: Choices.move(state, id, :demote)
  defp command(state, :move_up, id), do: reorder(state, id, -1)
  defp command(state, :move_down, id), do: reorder(state, id, 1)
  defp command(state, :note, id), do: CategoryScreens.open_note(state, id)
  defp command(state, :properties, id), do: CategoryScreens.open_props(state, id)

  defp command(state, :sort, id) do
    Prompts.confirm(
      state,
      "Sort the children of #{state.db.categories[id].name} alphabetically?",
      {:sort_children, id}
    )
  end

  defp command(state, :move, id) do
    if Database.protected?(state.db, id),
      do: State.error(state, "#{state.db.categories[id].name} cannot be moved"),
      else: CategoryScreens.open_picker(state, {:move_category, id}, nil)
  end

  defp command(state, :discard, id) do
    name = state.db.categories[id].name

    if Database.protected?(state.db, id),
      do: State.error(state, "#{name} cannot be discarded"),
      else:
        Prompts.confirm(state, "Discard #{name} and all its children?", {:discard_category, id})
  end

  defp command(state, :collapse, id), do: CategoryScreens.collapse_key(state, id, {:alt, "-"})
  defp command(state, :expand, id), do: CategoryScreens.collapse_key(state, id, {:alt, "="})

  defp new_category(state, id, text) do
    db = state.db

    target =
      if id == db.main_id,
        do: {:new, db.main_id, nil},
        else: {:new, db.categories[id].parent_id, id}

    %{state | edit: %{target: target, line: LineEdit.new(text)}}
  end

  # ALT-U, ALT-L and ALT-R (User's Guide 16-11): a sibling above, a new
  # family after the parent, or the first child.
  defp insert_category(state, id, where) do
    db = state.db
    cat = db.categories[id]
    parent = cat.parent_id && db.categories[cat.parent_id]

    target =
      case where do
        _ when id == db.main_id and where != :child ->
          {:error, "Nothing can be added beside MAIN"}

        :above ->
          {:new, cat.parent_id, Database.previous_sibling(db, id) || :first}

        :uncle when parent.id == db.main_id ->
          {:error, "Nothing can be added at the same level as MAIN"}

        :uncle ->
          {:new, parent.parent_id, parent.id}

        :child when cat.kind != :standard ->
          {:error, "Children can be added only to standard categories"}

        :child ->
          {:new, id, :first}
      end

    case target do
      {:error, message} -> State.error(state, message)
      target -> %{state | edit: %{target: target, line: LineEdit.new("")}}
    end
  end

  defp reorder(state, id, direction) do
    db = state.db
    parent = db.categories[id].parent_id

    result =
      cond do
        parent == nil ->
          {:error, :protected}

        direction < 0 ->
          case Database.previous_sibling(db, id) do
            nil ->
              {:ok, db}

            prev ->
              Core.move_category(db, id, parent, Database.previous_sibling(db, prev) || :first)
          end

        true ->
          case Database.next_sibling(db, id) do
            nil -> {:ok, db}
            next -> Core.move_category(db, id, parent, next)
          end
      end

    state = CategoryScreens.hierarchy_change(state, result)
    CategoryScreens.move_cursor_to(state, id)
  end
end
