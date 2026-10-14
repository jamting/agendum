defmodule Agendum.TUI.CategoryScreens.Manager do
  @moduledoc """
  The category manager (F9, User's Guide 16-1 to 16-12): the keys of the
  full-screen hierarchy, adding categories beside, above and under the
  highlighted one, and reordering them. Pure.
  """

  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.TUI.{CategoryScreens, Typing.LineEdit, State}
  alias Agendum.TUI.CategoryScreens.Choices
  alias Agendum.TUI.Update.Prompts

  # --- category manager ------------------------------------------------------------

  @doc "Keys of the category manager (F9)."
  # One branch per key, like Agenda's key chart.
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def screen_key(state, %{type: :catmgr} = mode, rows, key) do
    id = CategoryScreens.current_id(rows, mode)
    db = state.db
    cat = db.categories[id]

    case key do
      k when k in [:esc, {:f, 9}, {:f, 10}] ->
        State.pop(state)

      :backspace ->
        State.put_mode(state, %{mode | cursor: max(mode.cursor - 1, 0)})

      :enter ->
        State.put_mode(state, %{mode | cursor: min(mode.cursor + 1, length(rows) - 1)})

      {:f, 1} ->
        State.push(state, %{type: :help, top: 0})

      k when k in [:insert, {:alt, "d"}, {:alt, "i"}] ->
        new_category(state, id, "")

      {:alt, "u"} ->
        insert_category(state, id, :above)

      {:alt, "e"} ->
        Agendum.TUI.Boxes.ExecuteBox.run(state, id, :all)

      {:alt, "l"} ->
        insert_category(state, id, :uncle)

      {:alt, "r"} ->
        insert_category(state, id, :child)

      {:char, c} ->
        new_category(state, id, c)

      {:f, 2} ->
        if Database.protected?(db, id),
          do: State.error(state, "#{cat.name} cannot be renamed"),
          else: %{state | edit: %{target: {:rename, id}, line: LineEdit.new(cat.name)}}

      {:f, 7} ->
        Choices.move(state, id, :promote)

      {:f, 8} ->
        Choices.move(state, id, :demote)

      {:alt, :up} ->
        reorder(state, id, -1)

      {:alt, :down} ->
        reorder(state, id, 1)

      {:f, 5} ->
        CategoryScreens.open_note(state, id)

      {:f, 6} ->
        CategoryScreens.open_props(state, id)

      {:alt_f, 5} ->
        Prompts.confirm(
          state,
          "Sort the children of #{cat.name} alphabetically?",
          {:sort_children, id}
        )

      {:alt_f, 10} ->
        if Database.protected?(db, id),
          do: State.error(state, "#{cat.name} cannot be moved"),
          else: CategoryScreens.open_picker(state, {:move_category, id}, nil)

      k when k in [:delete, {:alt_f, 4}, {:ctrl, "d"}] ->
        if Database.protected?(db, id),
          do: State.error(state, "#{cat.name} cannot be discarded"),
          else:
            Prompts.confirm(
              state,
              "Discard #{cat.name} and all its children?",
              {:discard_category, id}
            )

      _ ->
        state
    end
  end

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
