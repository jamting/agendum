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

  alias Agendum.Core.Database
  alias Agendum.TUI.{Terminal.Draw, Typing.LineEdit, State, Typing.TextEdit}
  alias Agendum.TUI.Render.Text
  alias Agendum.TUI.CategoryScreens.{Manager, Picker, Profile}

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

  # A box listing categories shows as many as Agenda's Assignment Profile
  # (13), however tall the terminal; below them the box adds a blank line
  # and a hint (`@below`)
  @list_rows 13
  @below 2

  @doc """
  The lines of a box listing categories, `inner` wide, scrolled to the
  cursor: each with the mark `marker.(state, mode, id)` gives it (one
  character) to its left. As many as fit in `max_rows` with the two lines
  the box adds below them, and no more than Agenda's box shows.
  """
  def list_lines(state, mode, inner, max_rows, marker) do
    max_rows = (max_rows - @below) |> min(@list_rows) |> max(1)
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

  # the category manager's keys run commands through its keymap (R65)
  def handle(state, %{type: :catmgr} = mode, key), do: Manager.handle(state, mode, key)

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

  # where each moving key goes, in every screen listing the hierarchy
  @moves %{
    up: :up,
    down: :down,
    pgup: :page_up,
    pgdn: :page_down,
    ctrl_home: :first,
    ctrl_end: :last,
    home: :parent,
    end: :last_sibling,
    ctrl_pgup: :previous_sibling,
    ctrl_pgdn: :next_sibling
  }

  defp navigate(state, mode, rows, key) do
    case @moves[key] do
      nil -> :unhandled
      where -> {:moved, move(state, mode, rows, where)}
    end
  end

  @doc """
  The keys every box listing the hierarchy shares (R65): the moves and
  ALT-− / ALT-= (collapse, expand), for the box's `keymap/1`.
  """
  def list_keymap do
    @moves
    |> Map.new(fn {key, where} -> {key, where} end)
    |> Map.merge(%{{:alt, "-"} => :collapse, {:alt, "="} => :expand})
  end

  @doc "Their commands, `{id, name, summary}`, for the box's `commands/1`."
  def list_commands do
    [
      {:up, "Up", "The category above"},
      {:down, "Down", "The category below"},
      {:page_up, "Page up", "A screen up"},
      {:page_down, "Page down", "A screen down"},
      {:first, "First", "The first category"},
      {:last, "Last", "The last category"},
      {:parent, "Parent", "The parent"},
      {:last_sibling, "Last sibling", "The last of the siblings"},
      {:previous_sibling, "Previous sibling", "The sibling above"},
      {:next_sibling, "Next sibling", "The sibling below"},
      {:collapse, "Collapse", "Collapse the family (twice: all)"},
      {:expand, "Expand", "Expand the family (twice: all)"}
    ]
  end

  @doc """
  Runs one of `list_commands/0` in the box on top (`mode`); the box's own
  commands are its own. The cursor is kept on a row first.
  """
  def run_list(state, mode, id) when id in [:collapse, :expand] do
    case Enum.at(rows(state, mode), mode.cursor) do
      nil ->
        state

      {cat, _} ->
        collapse_key(state, cat, if(id == :collapse, do: {:alt, "-"}, else: {:alt, "="}))
    end
  end

  def run_list(state, mode, where) do
    case rows(state, mode) do
      [] -> state
      rows -> State.put_mode(state, move(state, clamp(mode, rows), rows, where))
    end
  end

  @doc "The mode with its cursor on one of `rows`."
  def clamp(mode, rows), do: %{mode | cursor: mode.cursor |> min(length(rows) - 1) |> max(0)}

  @doc """
  The mode with its cursor moved in `rows`: `:up`, `:down`, `:page_up`,
  `:page_down`, `:first`, `:last`, to the `:parent`, the `:last_sibling`,
  the `:previous_sibling` or the `:next_sibling`.
  """
  def move(state, mode, rows, where) do
    count = length(rows)
    id = current_id(rows, mode)
    page = State.body_height(state) - 2
    index_of = fn target -> Enum.find_index(rows, fn {i, _} -> i == target end) end

    index =
      case where do
        :up -> mode.cursor - 1
        :down -> mode.cursor + 1
        :page_up -> mode.cursor - page
        :page_down -> mode.cursor + page
        :first -> 0
        :last -> count - 1
        :parent -> index_of.(state.db.categories[id].parent_id) || 0
        :last_sibling -> index_of.(last_sibling(state.db, id)) || mode.cursor
        :previous_sibling -> index_of.(Database.previous_sibling(state.db, id)) || mode.cursor
        :next_sibling -> index_of.(Database.next_sibling(state.db, id)) || mode.cursor
      end

    %{mode | cursor: index |> min(count - 1) |> max(0)}
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
  def hierarchy_change(_state, {:ok, state, _changes}), do: state
  def hierarchy_change(state, {:error, why}), do: State.error(state, hierarchy_message(why))

  @doc """
  Why a change to the hierarchy failed, as the person reads it; also what
  F1 `c` says about a command that would fail so (R65a).
  """
  @spec hierarchy_message(atom) :: String.t()
  def hierarchy_message(:top_level), do: "Already at the top level"

  def hierarchy_message(:no_previous_sibling),
    do: "Demote needs a category above at the same level"

  def hierarchy_message(:protected), do: "This category cannot be moved"
  def hierarchy_message(:cycle), do: "A category cannot be moved under itself"

  def hierarchy_message(:excluded_lineage),
    do: "Not moved: a category would be under one it excludes"

  def hierarchy_message(:empty), do: "A category needs a name"
  def hierarchy_message(:duplicate), do: "That category already exists there"

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

  @doc """
  ALT-− collapses the family the highlight is in (its own children when it
  has any, otherwise its parent's); pressed twice, every family. ALT-=
  expands the highlighted category's family; pressed twice, everything.
  """
  def collapse_key(state, id, key) do
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
    case State.command(state, {:rename_category, id, text}) do
      {:ok, state, _} -> state
      {:error, _} -> State.error(state, "A category needs a name")
    end
  end

  def commit(state, _mode, {:new, parent, after_id}, text) do
    case State.command(state, {:add_category, parent, text, after: after_id}) do
      {:ok, state, %{new: id}} ->
        move_cursor_to(state, id)

      {:error, :empty} ->
        state

      {:error, :duplicate} ->
        State.error(state, "#{String.trim(text)} already exists at this level")
    end
  end

  def commit(state, mode, :new_pick, text) do
    parent = mode.root || state.db.main_id

    case State.command(state, {:add_category, parent, text, []}) do
      {:ok, state, %{new: id}} ->
        state |> State.pop() |> Picker.pick(mode.purpose, id)

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
