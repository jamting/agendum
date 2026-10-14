defmodule Agendum.TUI.CategoryScreens do
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

  This module opens them, lists their rows, moves the cursor, collapses
  families and dispatches keys; each screen's own keys are in
  `CategoryScreens.Manager`, `Picker`, `Profile` and `Properties`, the
  choice boxes (exclusive children, moves) in `Choices`. Pure.
  """

  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.TUI.{Terminal.Draw, Typing.LineEdit, State, Typing.TextEdit}
  alias Agendum.TUI.Render.Text
  alias Agendum.TUI.CategoryScreens.{Choices, Manager, Picker, Profile}

  # --- opening -------------------------------------------------------------------

  def open_catmgr(state), do: State.push(state, %{type: :catmgr, cursor: 0})

  def open_picker(state, purpose, root) do
    State.push(state, %{type: :picker, purpose: purpose, root: root, cursor: 0, search: ""})
  end

  def open_profile(state, item_id),
    do: State.push(state, %{type: :profile, item_id: item_id, cursor: 0})

  @doc "The assignment profile for a group of marked items (User's Guide 4-17)."
  def open_group_profile(state, item_ids),
    do: State.push(state, %{type: :group_profile, item_ids: item_ids, cursor: 0})

  def open_props(state, cat_id), do: State.push(state, %{type: :props, cat_id: cat_id, cursor: 0})

  @doc "The `{category_id, depth}` rows a hierarchy screen lists."
  def rows(state, mode) do
    all = all_rows(state, mode)
    listed = MapSet.new(all, &elem(&1, 0))
    Enum.filter(all, &shown?(state, mode, listed, elem(&1, 0)))
  end

  # Categories inside a collapsed family are hidden, when the screen lists
  # the family's head (so it can be expanded again); the assignment profile
  # still shows those the item is assigned to (User's Guide 16-9).
  defp shown?(state, mode, listed, id) do
    visible =
      not Enum.any?(
        Database.ancestors(state.db, id),
        &(MapSet.member?(state.collapsed, &1) and MapSet.member?(listed, &1))
      )

    visible or (mode.type == :profile and assigned_here?(state.db, mode.item_id, id))
  end

  defp assigned_here?(db, item_id, id) do
    if Database.date_category?(db, id),
      do: Database.item_date(db, item_id, id) != nil,
      else: Database.explicit?(db, item_id, id)
  end

  defp all_rows(state, %{type: :catmgr}), do: Database.hierarchy(state.db)

  defp all_rows(state, %{type: type}) when type in [:profile, :group_profile],
    do: state.db |> Database.hierarchy() |> tl()

  # MAIN is a valid choice for sections, views and new parents only.
  # (`elem(purpose, 0)` is the tag, whatever the purpose tuple's size;
  # `elem/2` is allowed in a guard.)
  defp all_rows(state, %{type: :picker, root: nil, purpose: purpose})
       when is_tuple(purpose) and
              elem(purpose, 0) in [
                :add_section,
                :change_section,
                :new_view,
                :move_category,
                :schedule
              ],
       do: Database.hierarchy(state.db)

  defp all_rows(state, %{type: :picker, root: nil}), do: state.db |> Database.hierarchy() |> tl()

  defp all_rows(state, %{type: :picker, root: root}) do
    base = Database.depth(state.db, root) + 1
    state.db |> Database.descendants(root) |> Enum.map(&{&1, Database.depth(state.db, &1) - base})
  end

  @doc """
  The lines of a box listing categories, `inner` wide, at most `max_rows`
  of them, scrolled to the cursor: each with the mark `marker.(state, mode,
  id)` gives it (one character) to its left.
  """
  def list_lines(state, mode, inner, max_rows, marker) do
    rows = rows(state, mode)
    cursor = min(mode.cursor, max(length(rows) - 1, 0))
    top = max(cursor - max_rows + 1, 0)

    list =
      rows
      |> Enum.with_index()
      |> Enum.drop(top)
      |> Enum.take(max_rows)
      |> Enum.map(fn {{id, depth}, i} ->
        style = if i == cursor, do: :box_selected, else: :box
        cat = state.db.categories[id]
        name = String.duplicate("  ", depth) <> cat.name <> Text.ellipsis(state, cat)
        [{:box, " " <> marker.(state, mode, id) <> " "}, {style, Draw.pad(name, inner - 6)}]
      end)

    if list == [], do: [[{:box, "  (no categories yet — press INS to create one)"}]], else: list
  end

  # --- dispatch ----------------------------------------------------------------------

  def handle(state, %{type: :choice} = mode, key), do: Choices.choice_key(state, mode, key)

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

  def handle(state, mode, key) when key in [{:alt, "-"}, {:alt, "="}] do
    rows = rows(state, mode)

    case Enum.at(rows, mode.cursor) do
      nil -> state
      {id, _} -> collapse_key(state, id, key)
    end
  end

  def handle(state, mode, key) do
    rows = rows(state, mode)
    mode = %{mode | cursor: mode.cursor |> min(length(rows) - 1) |> max(0)}

    case navigate(state, mode, rows, key) do
      {:moved, mode} -> State.put_mode(state, mode)
      :unhandled when rows == [] -> empty_key(State.put_mode(state, mode), mode, key)
      :unhandled -> screen_key(State.put_mode(state, mode), mode, rows, key)
    end
  end

  # With nothing listed, only leaving the screen means anything (a picker
  # may still create a category).
  defp empty_key(state, %{type: :picker} = mode, key), do: screen_key(state, mode, [], key)

  defp empty_key(state, _mode, key) when key in [:esc, {:f, 3}, {:f, 6}, {:f, 9}, {:f, 10}],
    do: State.pop(state)

  defp empty_key(state, _mode, _key), do: state

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

  @doc "The category under the cursor, or nil when nothing is listed."
  def current_id(rows, mode) do
    case Enum.at(rows, mode.cursor) do
      {id, _} -> id
      nil -> nil
    end
  end

  defp screen_key(state, %{type: :catmgr} = mode, rows, key),
    do: Manager.screen_key(state, mode, rows, key)

  defp screen_key(state, %{type: :picker} = mode, rows, key),
    do: Picker.screen_key(state, mode, rows, key)

  defp screen_key(state, mode, rows, key), do: Profile.screen_key(state, mode, rows, key)

  @doc "Opens a category's note (F5)."
  def open_note(state, id) do
    cat = state.db.categories[id]

    State.push(state, %{
      type: :note,
      target: {:category, id},
      title: cat.name,
      edit: TextEdit.new(cat.note)
    })
  end

  @doc "Applies a change to the hierarchy, or reports why it failed."
  def hierarchy_change(state, {:ok, db}), do: State.change_db(state, db)

  def hierarchy_change(state, {:error, :top_level}),
    do: State.error(state, "Already at the top level")

  def hierarchy_change(state, {:error, :no_previous_sibling}),
    do: State.error(state, "Demote needs a category above at the same level")

  def hierarchy_change(state, {:error, :protected}),
    do: State.error(state, "This category cannot be moved")

  def hierarchy_change(state, {:error, :cycle}),
    do: State.error(state, "A category cannot be moved under itself")

  def hierarchy_change(state, {:error, :excluded_lineage}),
    do: State.error(state, "Not moved: a category would be under one it excludes")

  def hierarchy_change(state, {:error, :empty}),
    do: State.error(state, "A category needs a name")

  def hierarchy_change(state, {:error, :duplicate}),
    do: State.error(state, "That category already exists there")

  @doc "Moves the cursor to a category, expanding the families above it."
  def move_cursor_to(state, id) do
    state = reveal(state, id)
    mode = State.mode(state)
    index = state |> rows(mode) |> Enum.find_index(fn {i, _} -> i == id end)
    if index, do: State.put_mode(state, %{mode | cursor: index}), else: state
  end

  # Expands the families above a category, e.g. after moving it into a
  # collapsed family, so it stays visible.
  defp reveal(state, id) do
    case Map.has_key?(state.db.categories, id) do
      true ->
        %{
          state
          | collapsed:
              MapSet.difference(state.collapsed, MapSet.new(Database.ancestors(state.db, id)))
        }

      false ->
        state
    end
  end

  # --- collapsing and expanding families (User's Guide 16-8) -----------------------------------

  # ALT-- collapses the family the highlight is in (its own children when it
  # has any, otherwise its parent's); pressed twice, every family. ALT-=
  # expands the highlighted category's family; pressed twice, everything.
  defp collapse_key(state, id, key) do
    db = state.db
    twice = state.last_key.key == key

    {collapsed, target} =
      case key do
        {:alt, "-"} when twice ->
          {all_parents(db), db.main_id}

        {:alt, "-"} ->
          target =
            if db.categories[id].children != [] and not MapSet.member?(state.collapsed, id),
              do: id,
              else: db.categories[id].parent_id || id

          {MapSet.put(state.collapsed, target), target}

        {:alt, "="} when twice ->
          {MapSet.new(), id}

        {:alt, "="} ->
          {MapSet.delete(state.collapsed, id), id}
      end

    move_cursor_to(%{state | collapsed: collapsed}, target)
  end

  defp all_parents(db),
    do: for({id, %{children: [_ | _]}} <- db.categories, into: MapSet.new(), do: id)

  # --- committing inline edits ---------------------------------------------------------------

  @doc "Commits an inline edit: a rename, a new category, or a new category picked."
  def commit(state, _mode, {:rename, id}, text) do
    case Core.rename_category(state.db, id, text) do
      {:ok, db} -> State.change_db(state, db)
      {:error, _} -> State.error(state, "A category needs a name")
    end
  end

  def commit(state, _mode, {:new, parent, after_id}, text) do
    case Core.add_category(state.db, parent, text, after: after_id) do
      {:ok, db, id} ->
        state |> State.change_db(db) |> move_cursor_to(id)

      {:error, :empty} ->
        state

      {:error, :duplicate} ->
        State.error(state, "#{String.trim(text)} already exists at this level")
    end
  end

  def commit(state, mode, :new_pick, text) do
    parent = mode.root || state.db.main_id

    case Core.add_category(state.db, parent, text) do
      {:ok, db, id} ->
        state |> State.change_db(db) |> State.pop() |> Picker.pick(mode.purpose, id)

      {:error, :empty} ->
        state

      {:error, :duplicate} ->
        State.error(state, "#{String.trim(text)} already exists; select it from the list")
    end
  end

  @doc "Whether a category is numeric."
  def numeric?(db, id), do: db.categories[id].kind == :numeric

  @doc "Tells where numbers for a numeric category are typed."
  def numbers_hint(state, id),
    do: State.error(state, "Type numbers in the #{state.db.categories[id].name} column")

  @doc "How many of the given items are explicitly assigned to a category."
  def group_count(db, item_ids, cat_id),
    do: Enum.count(item_ids, &Database.explicit?(db, &1, cat_id))
end
