defmodule Agenda.TUI.CategoryScreens do
  @moduledoc """
  Screens that list the category hierarchy:

    * the **category manager** (F9) – add, rename, promote/demote, move and
      discard categories
    * the **category picker** – choose a category for a new section or
      column, a column entry, a view, or a new parent
    * the **assignment profile** – every category, marked where the item is
      assigned; SPACE toggles
    * **category properties** – name, short name, exclusivity, matching,
      category links
  """

  alias Agenda.Core
  alias Agenda.Core.Database
  alias Agenda.TUI.{LineEdit, State, TextEdit, Update}

  # --- opening -------------------------------------------------------------------

  def open_catmgr(state), do: State.push(state, %{type: :catmgr, cursor: 0})

  def open_picker(state, purpose, root) do
    State.push(state, %{type: :picker, purpose: purpose, root: root, cursor: 0, search: ""})
  end

  def open_profile(state, item_id),
    do: State.push(state, %{type: :profile, item_id: item_id, cursor: 0})

  def open_props(state, cat_id), do: State.push(state, %{type: :props, cat_id: cat_id, cursor: 0})

  @doc "The `{category_id, depth}` rows a hierarchy screen lists."
  def rows(state, %{type: :catmgr}), do: Database.hierarchy(state.db)
  def rows(state, %{type: :profile}), do: state.db |> Database.hierarchy() |> tl()

  # MAIN is a valid choice for sections, views and new parents only
  def rows(state, %{type: :picker, root: nil, purpose: {tag, _}})
      when tag in [:add_section, :change_section, :new_view, :move_category],
      do: Database.hierarchy(state.db)

  def rows(state, %{type: :picker, root: nil}), do: state.db |> Database.hierarchy() |> tl()

  def rows(state, %{type: :picker, root: root}) do
    base = Database.depth(state.db, root) + 1
    state.db |> Database.descendants(root) |> Enum.map(&{&1, Database.depth(state.db, &1) - base})
  end

  @props [:name, :short_name, :exclusive, :match_name, :also_assign, :note]
  def props_fields, do: @props

  # --- dispatch ----------------------------------------------------------------------

  def handle(state, %{type: :props} = mode, key), do: props_key(state, mode, key)

  def handle(%State{edit: edit} = state, mode, key) when edit != nil do
    case key do
      :esc ->
        %{state | edit: nil}

      :enter ->
        commit(%{state | edit: nil}, mode, edit.target, edit.line.text)

      _ ->
        case LineEdit.handle(edit.line, key) do
          {:ok, line} -> %{state | edit: %{edit | line: line}}
          :unhandled -> state
        end
    end
  end

  def handle(state, mode, key) do
    rows = rows(state, mode)
    mode = %{mode | cursor: mode.cursor |> min(length(rows) - 1) |> max(0)}

    case navigate(state, mode, rows, key) do
      {:moved, mode} -> State.put_mode(state, mode)
      :unhandled -> screen_key(State.put_mode(state, mode), mode, rows, key)
    end
  end

  @nav_keys [:up, :down, :pgup, :pgdn, :home, :end, :ctrl_home, :ctrl_end, :ctrl_pgup, :ctrl_pgdn]

  # An empty list (e.g. choices for a column head with no subcategories yet)
  # has nothing to move to.
  defp navigate(_state, mode, [], key) when key in @nav_keys, do: {:moved, mode}

  defp navigate(state, mode, rows, key) do
    count = length(rows)
    id = current_id(rows, mode)
    page = State.body_height(state) - 2
    at = fn index -> {:moved, %{mode | cursor: index |> min(count - 1) |> max(0)}} end
    index_of = fn target -> Enum.find_index(rows, fn {i, _} -> i == target end) end

    case key do
      :up -> at.(mode.cursor - 1)
      :down -> at.(mode.cursor + 1)
      :pgup -> at.(mode.cursor - page)
      :pgdn -> at.(mode.cursor + page)
      :ctrl_home -> at.(0)
      :ctrl_end -> at.(count - 1)
      :home -> at.(index_of.(state.db.categories[id].parent_id) || 0)
      :end -> at.(index_of.(last_sibling(state.db, id)) || mode.cursor)
      :ctrl_pgup -> at.(index_of.(Database.previous_sibling(state.db, id)) || mode.cursor)
      :ctrl_pgdn -> at.(index_of.(Database.next_sibling(state.db, id)) || mode.cursor)
      _ -> :unhandled
    end
  end

  defp last_sibling(db, id) do
    case db.categories[id].parent_id do
      nil -> id
      parent -> List.last(db.categories[parent].children)
    end
  end

  defp current_id(rows, mode) do
    case Enum.at(rows, mode.cursor) do
      {id, _} -> id
      nil -> nil
    end
  end

  # --- category manager ------------------------------------------------------------

  defp screen_key(state, %{type: :catmgr} = mode, rows, key) do
    id = current_id(rows, mode)
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

      :insert ->
        new_category(state, id, "")

      {:char, c} ->
        new_category(state, id, c)

      {:f, 2} ->
        if Database.protected?(db, id),
          do: State.error(state, "#{cat.name} cannot be renamed"),
          else: %{state | edit: %{target: {:rename, id}, line: LineEdit.new(cat.name)}}

      {:f, 7} ->
        hierarchy_change(state, Core.promote(db, id))

      {:f, 8} ->
        hierarchy_change(state, Core.demote(db, id))

      {:alt, :up} ->
        reorder(state, id, -1)

      {:alt, :down} ->
        reorder(state, id, 1)

      {:f, 5} ->
        State.push(state, %{
          type: :note,
          target: {:category, id},
          title: cat.name,
          edit: TextEdit.new(cat.note)
        })

      {:f, 6} ->
        open_props(state, id)

      {:alt_f, 10} ->
        if Database.protected?(db, id),
          do: State.error(state, "#{cat.name} cannot be moved"),
          else: open_picker(state, {:move_category, id}, nil)

      k when k in [:delete, {:alt_f, 4}, {:ctrl, "d"}] ->
        if Database.protected?(db, id),
          do: State.error(state, "#{cat.name} cannot be discarded"),
          else:
            Update.confirm(
              state,
              "Discard #{cat.name} and all its children? (Y/N)",
              {:discard_category, id}
            )

      _ ->
        state
    end
  end

  # --- category picker ------------------------------------------------------------------

  defp screen_key(state, %{type: :picker} = mode, rows, key) do
    case key do
      :esc when mode.search != "" -> State.put_mode(state, %{mode | search: ""})
      :esc -> State.pop(state)
      :enter -> pick(State.pop(state), mode.purpose, current_id(rows, mode))
      :insert -> %{state | edit: %{target: :new_pick, line: LineEdit.new()}}
      :backspace -> search(state, mode, rows, String.slice(mode.search, 0..-2//1))
      {:char, c} -> search(state, mode, rows, mode.search <> c)
      _ -> state
    end
  end

  # --- assignment profile -----------------------------------------------------------------

  defp screen_key(state, %{type: :profile} = mode, rows, key) do
    id = current_id(rows, mode)
    item_id = mode.item_id
    db = state.db

    case key do
      k when k in [:esc, {:f, 6}, {:f, 3}, {:f, 4}] ->
        State.pop(state)

      k when k in [{:char, " "}, :enter] ->
        cond do
          id == db.special.done ->
            State.change_db(state, Core.toggle_done(db, item_id, state.today))

          Database.date_field(db, id) ->
            State.error(state, "Set dates by typing in a date column")

          true ->
            State.change_db(state, Core.toggle_assignment(db, item_id, id))
        end

      _ ->
        state
    end
  end

  defp search(state, mode, rows, text) do
    wanted = String.downcase(text)

    index =
      Enum.find_index(rows, fn {id, _} ->
        String.starts_with?(String.downcase(state.db.categories[id].name), wanted)
      end)

    State.put_mode(state, %{mode | search: text, cursor: index || mode.cursor})
  end

  defp new_category(state, id, text) do
    db = state.db

    target =
      if id == db.main_id,
        do: {:new, db.main_id, nil},
        else: {:new, db.categories[id].parent_id, id}

    %{state | edit: %{target: target, line: LineEdit.new(text)}}
  end

  defp hierarchy_change(state, {:ok, db}), do: State.change_db(state, db)

  defp hierarchy_change(state, {:error, :top_level}),
    do: State.error(state, "Already at the top level")

  defp hierarchy_change(state, {:error, :no_previous_sibling}),
    do: State.error(state, "Demote needs a category above at the same level")

  defp hierarchy_change(state, {:error, :protected}),
    do: State.error(state, "This category cannot be moved")

  defp hierarchy_change(state, {:error, :cycle}),
    do: State.error(state, "A category cannot be moved under itself")

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

    state = hierarchy_change(state, result)
    move_cursor_to(state, id)
  end

  defp move_cursor_to(state, id) do
    mode = State.mode(state)
    index = state |> rows(mode) |> Enum.find_index(fn {i, _} -> i == id end)
    if index, do: State.put_mode(state, %{mode | cursor: index}), else: state
  end

  # --- committing inline edits ---------------------------------------------------------------

  defp commit(state, _mode, {:rename, id}, text) do
    case Core.rename_category(state.db, id, text) do
      {:ok, db} -> State.change_db(state, db)
      {:error, _} -> State.error(state, "A category needs a name")
    end
  end

  defp commit(state, _mode, {:new, parent, after_id}, text) do
    case Core.add_category(state.db, parent, text, after: after_id) do
      {:ok, db, id} ->
        state |> State.change_db(db) |> move_cursor_to(id)

      {:error, :empty} ->
        state

      {:error, :duplicate} ->
        State.error(state, "#{String.trim(text)} already exists at this level")
    end
  end

  defp commit(state, mode, :new_pick, text) do
    parent = mode.root || state.db.main_id

    case Core.add_category(state.db, parent, text) do
      {:ok, db, id} ->
        state |> State.change_db(db) |> State.pop() |> pick(mode.purpose, id)

      {:error, :empty} ->
        state

      {:error, :duplicate} ->
        State.error(state, "#{String.trim(text)} already exists; select it from the list")
    end
  end

  # --- picker results -------------------------------------------------------------------------

  defp pick(state, _purpose, nil), do: state

  defp pick(state, {:add_section, index}, id) do
    index = min(index, length(State.view(state).sections))

    %{
      State.change_db(state, Core.add_section(state.db, state.view_id, id, index))
      | cursor_key: {:section, index}
    }
  end

  defp pick(state, {:change_section, sidx}, id) do
    db = Core.set_section_category(state.db, state.view_id, sidx, id)
    %{State.change_db(state, db) | cursor_key: {:section, sidx}}
  end

  defp pick(state, {:add_column, index}, id) do
    width = if Database.date_field(state.db, id), do: 10, else: 12

    %{
      State.change_db(state, Core.add_column(state.db, state.view_id, id, index, width))
      | col: index + 1
    }
  end

  defp pick(state, {:assign_column, item_id, _head}, id),
    do: State.change_db(state, Core.assign(state.db, item_id, id))

  defp pick(state, {:new_view, name}, id) do
    {db, view_id} = Core.add_view(state.db, name, [id])

    %{
      State.change_db(state, db)
      | view_id: view_id,
        modes: [],
        cursor: 0,
        cursor_key: nil,
        col: 0,
        scroll: 0
    }
  end

  defp pick(state, {:move_category, cat_id}, parent) do
    case Core.move_category(state.db, cat_id, parent, nil) do
      {:ok, db} -> state |> State.change_db(db) |> move_cursor_to(cat_id)
      error -> hierarchy_change(state, error)
    end
  end

  defp pick(state, {:also_assign, cat_id}, target) do
    State.change_db(state, Core.toggle_also_assign(state.db, cat_id, target))
  end

  # --- category properties -----------------------------------------------------------------------

  defp props_key(%State{edit: edit} = state, mode, key) when edit != nil do
    case key do
      :esc ->
        %{state | edit: nil}

      :enter ->
        text = edit.line.text
        state = %{state | edit: nil}

        case edit.target do
          :name ->
            commit(state, mode, {:rename, mode.cat_id}, text)

          :short_name ->
            State.change_db(state, Core.set_short_name(state.db, mode.cat_id, text))
        end

      _ ->
        case LineEdit.handle(edit.line, key) do
          {:ok, line} -> %{state | edit: %{edit | line: line}}
          :unhandled -> state
        end
    end
  end

  defp props_key(state, mode, key) do
    cat = state.db.categories[mode.cat_id]
    count = length(@props)

    case key do
      k when k in [:esc, {:f, 6}] ->
        State.pop(state)

      :up ->
        State.put_mode(state, %{mode | cursor: max(mode.cursor - 1, 0)})

      :down ->
        State.put_mode(state, %{mode | cursor: min(mode.cursor + 1, count - 1)})

      k when k in [:enter, {:char, " "}, {:f, 2}, {:f, 3}] ->
        case Enum.at(@props, mode.cursor) do
          :name ->
            if Database.protected?(state.db, cat.id),
              do: State.error(state, "#{cat.name} cannot be renamed"),
              else: %{state | edit: %{target: :name, line: LineEdit.new(cat.name)}}

          :short_name ->
            %{state | edit: %{target: :short_name, line: LineEdit.new(cat.short_name || "")}}

          :exclusive ->
            State.change_db(state, Core.toggle_exclusive(state.db, cat.id))

          :match_name ->
            State.change_db(state, Core.toggle_match_name(state.db, cat.id))

          :also_assign ->
            open_picker(state, {:also_assign, cat.id}, nil)

          :note ->
            State.push(state, %{
              type: :note,
              target: {:category, cat.id},
              title: cat.name,
              edit: TextEdit.new(cat.note)
            })
        end

      _ ->
        state
    end
  end
end
