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
  alias Agenda.TUI.{Draw, LineEdit, State, TextEdit}
  alias Agenda.TUI.Update.Prompts

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

  # MAIN is a valid choice for sections, views and new parents only
  defp all_rows(state, %{type: :picker, root: nil, purpose: {tag, _}})
       when tag in [:add_section, :change_section, :new_view, :move_category, :schedule],
       do: Database.hierarchy(state.db)

  defp all_rows(state, %{type: :picker, root: nil}), do: state.db |> Database.hierarchy() |> tl()

  defp all_rows(state, %{type: :picker, root: root}) do
    base = Database.depth(state.db, root) + 1
    state.db |> Database.descendants(root) |> Enum.map(&{&1, Database.depth(state.db, &1) - base})
  end

  @props [
    :name,
    :short_name,
    :type,
    :exclusive,
    :match_name,
    :also_match,
    :conditions,
    :also_assign,
    :excludes,
    :special,
    :advanced,
    :note
  ]
  def props_fields, do: @props

  # --- dispatch ----------------------------------------------------------------------

  def handle(state, %{type: :props} = mode, key), do: props_key(state, mode, key)
  def handle(state, %{type: :choice} = mode, key), do: choice_key(state, mode, key)

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

  defp current_id(rows, mode) do
    case Enum.at(rows, mode.cursor) do
      {id, _} -> id
      nil -> nil
    end
  end

  # --- category manager ------------------------------------------------------------

  # One branch per key, like Agenda's key chart.
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
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

      k when k in [:insert, {:alt, "d"}, {:alt, "i"}] ->
        new_category(state, id, "")

      {:alt, "u"} ->
        insert_category(state, id, :above)

      {:alt, "e"} ->
        Agenda.TUI.ExecuteBox.run(state, id, :all)

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
        move(state, id, :promote)

      {:f, 8} ->
        move(state, id, :demote)

      {:alt, :up} ->
        reorder(state, id, -1)

      {:alt, :down} ->
        reorder(state, id, 1)

      {:f, 5} ->
        open_note(state, id)

      {:f, 6} ->
        open_props(state, id)

      {:alt_f, 5} ->
        Prompts.confirm(
          state,
          "Sort the children of #{cat.name} alphabetically? (Y/N)",
          {:sort_children, id}
        )

      {:alt_f, 10} ->
        if Database.protected?(db, id),
          do: State.error(state, "#{cat.name} cannot be moved"),
          else: open_picker(state, {:move_category, id}, nil)

      k when k in [:delete, {:alt_f, 4}, {:ctrl, "d"}] ->
        if Database.protected?(db, id),
          do: State.error(state, "#{cat.name} cannot be discarded"),
          else:
            Prompts.confirm(
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
      :esc when mode.search != "" ->
        State.put_mode(state, %{mode | search: ""})

      :esc ->
        State.pop(state)

      # filters, conditions and actions are set several at a time: the box stays open
      :enter
      when elem(mode.purpose, 0) in [
             :filter,
             :condition,
             :also_assign,
             :excludes,
             :schedule_filter
           ] ->
        pick(state, mode.purpose, current_id(rows, mode))

      :enter ->
        pick(State.pop(state), mode.purpose, current_id(rows, mode))

      :insert ->
        %{state | edit: %{target: :new_pick, line: LineEdit.new()}}

      :backspace ->
        search(state, mode, rows, String.slice(mode.search, 0..-2//1))

      {:char, c} ->
        search(state, mode, rows, mode.search <> c)

      _ ->
        state
    end
  end

  # --- assignment profile -----------------------------------------------------------------

  # SPACE on a category no marked item is assigned to assigns them all;
  # on one that some are assigned to (a number shows), it unassigns them all.
  defp screen_key(state, %{type: :group_profile} = mode, rows, key) do
    id = current_id(rows, mode)
    db = state.db

    case key do
      k when k in [:esc, {:f, 3}, {:f, 6}] ->
        State.pop(state)

      k when k in [{:char, " "}, :enter, {:f, 7}] ->
        cond do
          Database.date_category?(db, id) ->
            State.error(state, "Set dates for marked items with ALT-F2 (When) or F4 (Done)")

          numeric?(db, id) ->
            numbers_hint(state, id)

          group_count(db, mode.item_ids, id) > 0 ->
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

          Database.date_category?(db, id) ->
            State.error(state, "Set dates by typing in a date column")

          numeric?(db, id) and not Database.explicit?(db, item_id, id) ->
            Prompts.prompt(state, "#{db.categories[id].name}:", {:item_number, item_id, id})

          true ->
            State.change_db(state, Core.toggle_assignment(db, item_id, id, State.context(state)))
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

  defp hierarchy_change(state, {:ok, db}), do: State.change_db(state, db)

  defp hierarchy_change(state, {:error, :top_level}),
    do: State.error(state, "Already at the top level")

  defp hierarchy_change(state, {:error, :no_previous_sibling}),
    do: State.error(state, "Demote needs a category above at the same level")

  defp hierarchy_change(state, {:error, :protected}),
    do: State.error(state, "This category cannot be moved")

  defp hierarchy_change(state, {:error, :cycle}),
    do: State.error(state, "A category cannot be moved under itself")

  defp hierarchy_change(state, {:error, :excluded_lineage}),
    do: State.error(state, "Not moved: a category would be under one it excludes")

  defp hierarchy_change(state, {:error, :empty}),
    do: State.error(state, "A category needs a name")

  defp hierarchy_change(state, {:error, :duplicate}),
    do: State.error(state, "That category already exists there")

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

  defp pick(state, {:schedule, field}, id),
    do: Agenda.TUI.ScheduleBox.set_category(state, field, id)

  defp pick(state, {:schedule_filter, _}, id), do: Agenda.TUI.ScheduleBox.cycle_filter(state, id)

  defp pick(state, {:datebook, view_id, row}, id),
    do: Agenda.TUI.DatebookBox.set_category(state, view_id, row, id)

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
    width = if Database.date_category?(state.db, id), do: 16, else: 12

    %{
      State.change_db(state, Core.add_column(state.db, state.view_id, id, index, width))
      | col: index + 1
    }
  end

  defp pick(state, {:filter, scope}, id) do
    if Agenda.Core.RangeFilter.range_category?(state.db, id) do
      Agenda.TUI.RangeFilterBox.open(state, scope, id)
    else
      {:ok, db} = Core.cycle_filter(state.db, state.view_id, scope, id)
      State.change_db(state, db)
    end
  end

  defp pick(state, :execute_root, id), do: Agenda.TUI.ExecuteBox.set_root(state, id)

  defp pick(state, {:sort_note, scope, index}, id),
    do: Agenda.TUI.SortBox.set_note(state, scope, index, id)

  defp pick(state, {:sort_category, scope, index}, id),
    do: Agenda.TUI.SortBox.set_category(state, scope, index, id)

  # ALT-M (MakeAssign): one item or all marked items
  defp pick(state, {:assign_items, ids}, id) do
    cond do
      Database.date_category?(state.db, id) ->
        State.error(state, "Set dates with ALT-F2 (When) or F4 (Done)")

      numeric?(state.db, id) ->
        numbers_hint(state, id)

      true ->
        db = Enum.reduce(ids, state.db, &Core.assign(&2, &1, id, State.context(state)))
        noun = if length(ids) == 1, do: "Item", else: "#{length(ids)} items"

        state
        |> State.change_db(db)
        |> State.info("#{noun} assigned to #{db.categories[id].name}")
    end
  end

  defp pick(state, {:assign_column, item_id, _head}, id),
    do: State.change_db(state, Core.assign(state.db, item_id, id, State.context(state)))

  defp pick(state, {:new_view, name}, id) do
    {db, view_id} = Core.add_view(state.db, name, [id])
    %{State.switch_view(State.change_db(state, db), view_id) | modes: []}
  end

  defp pick(state, {:move_category, cat_id}, parent),
    do: move(state, cat_id, {:move, parent, nil})

  # ENTER on a category cycles its condition: none → assigned → not assigned
  defp pick(state, {:condition, cat_id}, target) do
    if Agenda.Core.RangeFilter.range_category?(state.db, target),
      do: Agenda.TUI.RangeFilterBox.open_condition(state, cat_id, target),
      else: cycle_condition(state, cat_id, target)
  end

  # Assignment actions (R15b): a date or numeric category opens the action
  # box; another category cycles assign → remove → none.
  defp pick(state, {:also_assign, cat_id}, target) do
    cat = state.db.categories[cat_id]

    cond do
      Agenda.Core.RangeFilter.range_category?(state.db, target) ->
        Agenda.TUI.ActionBox.open(state, cat_id, target)

      target in cat.also_assign ->
        action_result(state, Core.set_action(state.db, cat_id, target, :remove))

      List.keymember?(cat.actions, target, 0) ->
        State.change_db(state, Core.remove_action(state.db, cat_id, target))

      true ->
        action_result(state, Core.set_action(state.db, cat_id, target, :assign))
    end
  end

  # Negative links (R9): ENTER toggles one between the two categories.
  defp pick(state, {:excludes, cat_id}, target) do
    names = fn -> {state.db.categories[cat_id].name, state.db.categories[target].name} end

    case Core.toggle_exclude(state.db, cat_id, target) do
      {:ok, db} ->
        State.change_db(state, db)

      {:error, :self} ->
        State.error(state, "A category cannot exclude itself")

      {:error, :lineage} ->
        State.error(state, "A category cannot exclude its parents or children")

      {:error, :not_allowed} ->
        State.error(state, "Only standard categories can exclude each other")

      {:error, {:shared, items}} ->
        {a, b} = names.()
        what = if length(items) == 1, do: "1 item is", else: "#{length(items)} items are"
        it = if length(items) == 1, do: "it", else: "them"
        State.error(state, "#{what} in both #{a} and #{b}; move #{it} first")
    end
  end

  # --- making children mutually exclusive -----------------------------------------------------

  @doc "The choices offered when items are in several children (Agenda 2.0, Figure 16-10)."
  def exclusive_resolutions do
    [
      {"Parent category", "Remove them from the children and assign them to the parent", :parent},
      {"Existing category", "Keep only the child closest to the top of the family", :first_child},
      {"New category", "Type a name; a new child category gets them", :new_child}
    ]
  end

  defp toggle_exclusive(state, cat) do
    cond do
      cat.exclusive ->
        state
        |> State.change_db(Core.make_unexclusive(state.db, cat.id))
        |> State.info("Children of #{cat.name} are no longer mutually exclusive")

      Database.protected?(state.db, cat.id) ->
        State.error(state, "#{cat.name} cannot have mutually exclusive children")

      Core.exclusive_conflicts(state.db, cat.id) == [] ->
        apply_exclusive(state, cat.id, :parent)

      true ->
        conflicts = length(Core.exclusive_conflicts(state.db, cat.id))

        State.push(state, %{
          type: :choice,
          kind: :exclusive,
          cat_id: cat.id,
          conflicts: conflicts,
          cursor: 0
        })
    end
  end

  # --- moving categories (promote, demote, move) ---------------------------------------------

  @doc "The choices offered when a move puts items in two exclusive branches (Figure 16-16)."
  def move_resolutions do
    [
      {"Removing from current category", "Remove them from the category being moved",
       :remove_moved},
      {"Removing from conflicting category", "Remove them from the category they clash with",
       :remove_other},
      {"Moving to new category",
       "Type a name; a new category under the conflicting one gets them", :new_category}
    ]
  end

  @doc "Options and explanatory lines for a choice box."
  def choice_options(%{kind: :exclusive}), do: exclusive_resolutions()
  def choice_options(%{kind: :move}), do: move_resolutions()

  def choice_options(%{kind: :type}),
    do: [
      {"Numeric", "A number for each item: totals and averages; children become numbers",
       :numeric},
      {"Date", "A date and time for each item; children become dates; cannot change back", :date}
    ]

  def choice_options(%{kind: :learn}),
    do: [
      {"Replace", "Record new keystrokes instead of the macro's", :replace},
      {"Append", "Record keystrokes to add after the macro's", :append}
    ]

  def choice_options(%{kind: :view_type}),
    do: [
      {"Standard", "Sections headed by categories you choose", :standard},
      {"Datebook", "Sections for the hours, days, weeks or months of a period", :datebook}
    ]

  def choice_lines(%{kind: :learn}),
    do: ["The macro already has keystrokes.", "Learn mode should:"]

  def choice_lines(%{kind: :view_type}),
    do: ["Sections by category, or by date like an appointment book.", "Type of view:"]

  def choice_lines(%{kind: :type}),
    do: ["Standard categories can become numeric or date categories.", "Change the type to:"]

  def choice_lines(%{kind: :exclusive, conflicts: n}),
    do: ["#{n} item(s) are assigned to more than one child.", "Assign conflicting item(s) to:"]

  def choice_lines(%{kind: :move, conflicts: n}),
    do: [
      "#{n} item(s) would be in two conflicting categories.",
      "Process conflicting item(s) by:"
    ]

  # `relocation` is :promote, :demote or {:move, parent, after_id} (see Core.relocate/4).
  defp move(state, id, relocation) do
    case Core.relocation_conflicts(state.db, id, relocation) do
      {:ok, []} ->
        apply_move(state, id, relocation, :remove_moved)

      {:ok, conflicts} ->
        State.push(state, %{
          type: :choice,
          kind: :move,
          cat_id: id,
          relocation: relocation,
          conflicts: length(conflicts),
          cursor: 0
        })

      error ->
        hierarchy_change(state, error)
    end
  end

  @doc "Relocates a category with the given conflict resolution and reports the result."
  def apply_move(state, id, relocation, rule) do
    conflicts =
      with {:ok, items} <- Core.relocation_conflicts(state.db, id, relocation), do: length(items)

    case Core.relocate(state.db, id, relocation, rule) do
      {:ok, db} ->
        state = state |> State.change_db(db) |> move_cursor_to(id)

        if conflicts > 0,
          do: State.info(state, "#{conflicts} conflicting item(s) reassigned"),
          else: state

      error ->
        hierarchy_change(state, error)
    end
  end

  defp choice_key(state, mode, key) do
    options = choice_options(mode)

    pick = fn index ->
      resolve_choice(State.pop(state), mode, elem(Enum.at(options, index), 2))
    end

    case key do
      :up ->
        State.put_mode(state, %{mode | cursor: max(mode.cursor - 1, 0)})

      :down ->
        State.put_mode(state, %{mode | cursor: min(mode.cursor + 1, length(options) - 1)})

      :enter ->
        pick.(mode.cursor)

      :esc ->
        State.pop(state)

      {:char, c} ->
        case Enum.find_index(options, fn {label, _, _} ->
               String.downcase(String.first(label)) == String.downcase(c)
             end) do
          nil -> state
          index -> pick.(index)
        end

      _ ->
        state
    end
  end

  defp resolve_choice(state, %{kind: :move} = mode, :new_category) do
    Prompts.prompt(
      state,
      "New category for the conflicting items:",
      {:move_new_category, mode.cat_id, mode.relocation}
    )
  end

  defp resolve_choice(state, %{kind: :move} = mode, rule),
    do: apply_move(state, mode.cat_id, mode.relocation, rule)

  defp resolve_choice(state, %{kind: :learn, macro_id: id}, how),
    do: Agenda.TUI.Macros.learn(state, state.db.macros[id], how)

  defp resolve_choice(state, %{kind: :view_type, name: name}, :standard),
    do: open_picker(state, {:new_view, name}, nil)

  # a datebook view with Agenda's defaults (When, a week from today), then
  # its settings (R47)
  defp resolve_choice(state, %{kind: :view_type, name: name}, :datebook) do
    {:ok, db, view_id} = Core.add_datebook_view(state.db, name, %Agenda.Core.Datebook{})

    state
    |> State.change_db(db)
    |> State.switch_view(view_id)
    |> Agenda.TUI.DatebookBox.open(view_id)
  end

  defp resolve_choice(state, %{kind: :type} = mode, :numeric),
    do: to_numeric(state, state.db.categories[mode.cat_id])

  defp resolve_choice(state, %{kind: :type} = mode, :date),
    do: to_date(state, state.db.categories[mode.cat_id])

  defp resolve_choice(state, mode, :new_child),
    do:
      Prompts.prompt(
        state,
        "New category for the conflicting items:",
        {:exclusive_new_child, mode.cat_id}
      )

  defp resolve_choice(state, mode, rule), do: apply_exclusive(state, mode.cat_id, rule)

  @doc "Makes a category's children exclusive with the given resolution and reports the result."
  def apply_exclusive(state, cat_id, rule) do
    name = state.db.categories[cat_id].name
    conflicts = length(Core.exclusive_conflicts(state.db, cat_id))

    case Core.make_exclusive(state.db, cat_id, rule) do
      {:ok, db} ->
        resolved =
          if conflicts == 0, do: "", else: "; #{conflicts} conflicting item(s) reassigned"

        state
        |> State.change_db(db)
        |> State.info("Children of #{name} are now mutually exclusive" <> resolved)

      {:error, :empty} ->
        State.error(state, "A category needs a name")

      {:error, :duplicate} ->
        State.error(state, "That category already exists under #{name}")

      {:error, :protected} ->
        State.error(state, "#{name} cannot have mutually exclusive children")
    end
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

          :also_match ->
            {:ok, db} = Core.set_also_match(state.db, mode.cat_id, text)
            State.change_db(state, db)
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
        open_prop(state, cat, Enum.at(@props, mode.cursor))

      _ ->
        state
    end
  end

  # ENTER (or SPACE, F2, F3) on a row of Category Properties
  defp open_prop(state, cat, :name) do
    if Database.protected?(state.db, cat.id),
      do: State.error(state, "#{cat.name} cannot be renamed"),
      else: %{state | edit: %{target: :name, line: LineEdit.new(cat.name)}}
  end

  defp open_prop(state, cat, :short_name) do
    %{state | edit: %{target: :short_name, line: LineEdit.new(cat.short_name || "")}}
  end

  defp open_prop(state, cat, :also_match) do
    %{state | edit: %{target: :also_match, line: LineEdit.new(cat.also_match)}}
  end

  defp open_prop(state, cat, :type) do
    change_type(state, cat)
  end

  defp open_prop(state, cat, :exclusive) do
    toggle_exclusive(state, cat)
  end

  defp open_prop(state, cat, :match_name) do
    State.change_db(state, Core.toggle_match_name(state.db, cat.id))
  end

  defp open_prop(state, cat, :also_assign) do
    open_picker(state, {:also_assign, cat.id}, nil)
  end

  defp open_prop(state, cat, :excludes) do
    open_picker(state, {:excludes, cat.id}, nil)
  end

  # Agenda's Advanced settings: how a date category gets dates (R6b), how
  # a standard one matches text (R16b)
  defp open_prop(state, cat, :advanced) do
    case cat.kind do
      :date -> Agenda.TUI.DateRuleBox.open(state, cat.id)
      :standard -> Agenda.TUI.CategoryMatchBox.open(state, cat.id)
      :numeric -> State.error(state, "Numeric categories have no advanced settings")
    end
  end

  defp open_prop(state, cat, :special) do
    next = %{nil => :done, done: :discard, discard: nil}[cat.special]
    {:ok, db} = Core.set_special_action(state.db, cat.id, next)
    State.change_db(state, db)
  end

  defp open_prop(state, cat, :conditions) do
    open_picker(state, {:condition, cat.id}, nil)
  end

  defp open_prop(state, cat, :note) do
    State.push(state, %{
      type: :note,
      target: {:category, cat.id},
      title: cat.name,
      edit: TextEdit.new(cat.note)
    })
  end

  # Category type (User's Guide 7-3, 8-11 to 8-12): a standard category
  # can become numeric or date, chosen in a box, after a question when
  # items or children are affected. Neither changes back.
  defp change_type(state, cat) do
    db = state.db

    cond do
      cat.kind != :standard ->
        State.error(state, "Only standard categories can change type")

      Database.protected?(db, cat.id) ->
        State.error(state, "#{cat.name} cannot change type")

      Enum.any?(cat.children, &(db.categories[&1].children != [])) ->
        State.error(state, "A category with grandchildren cannot change type")

      true ->
        State.push(state, %{type: :choice, kind: :type, cat_id: cat.id, cursor: 0})
    end
  end

  defp to_numeric(state, cat) do
    case numeric_question(cat, Core.numeric_conversion(state.db, cat.id, State.context(state))) do
      nil -> Prompts.make_numeric(state, cat.id)
      question -> Prompts.confirm(state, question, {:make_numeric, cat.id})
    end
  end

  defp to_date(state, cat) do
    case date_question(cat, Core.date_conversion(state.db, cat.id, State.context(state))) do
      nil -> Prompts.make_date(state, cat.id)
      question -> Prompts.confirm(state, question, {:make_date, cat.id})
    end
  end

  defp date_question(_cat, %{children: 0, assigned: 0}), do: nil

  defp date_question(cat, conversion) do
    parts =
      [
        conversion.children > 0 && "children become dates",
        conversion.non_dates != [] && "dropped: " <> Enum.join(conversion.non_dates, ", "),
        conversion.assigned > 0 && "#{Draw.count(conversion.assigned, "item")} in it get no date"
      ]
      |> Enum.filter(& &1)

    "Make #{cat.name} a date category? " <> Enum.join(parts, "; ") <> " (Y/N)"
  end

  defp numeric_question(_cat, %{children: 0, assigned: 0}), do: nil

  defp numeric_question(cat, conversion) do
    zeros =
      case conversion.non_numeric do
        [] -> nil
        [one] -> "#{one} becomes 0"
        names -> Enum.join(names, ", ") <> " become 0"
      end

    parts =
      [
        conversion.children > 0 && "Its #{conversion.children} children become numbers",
        zeros,
        conversion.assigned > 0 &&
          "#{Draw.count(conversion.assigned, "item")} assigned to it get 0"
      ]
      |> Enum.filter(& &1)

    "Convert #{cat.name} to numeric? " <> Enum.join(parts, "; ") <> ". (Y/N)"
  end

  defp action_result(state, {:ok, db}), do: State.change_db(state, db)

  defp action_result(state, {:error, :self}),
    do: State.error(state, "A category cannot act on itself")

  defp cycle_condition(state, cat_id, target) do
    case Core.cycle_condition(state.db, cat_id, target) do
      {:ok, db} ->
        state |> State.change_db(db) |> State.info(condition_message(db, cat_id, target))

      {:error, :self} ->
        State.error(state, "A category cannot depend on itself")
    end
  end

  defp condition_message(db, cat_id, target) do
    name = db.categories[cat_id].name
    other = db.categories[target].name

    case List.keyfind(db.categories[cat_id].conditions, target, 0) do
      {_, :assigned} ->
        "#{name} now assigns items in #{other} (Recalc applies it to existing items)"

      {_, :not_assigned} ->
        "#{name} now assigns items not in #{other} (Recalc applies it to existing items)"

      nil ->
        "Condition on #{other} removed"
    end
  end

  defp numeric?(db, id), do: db.categories[id].kind == :numeric

  defp numbers_hint(state, id),
    do: State.error(state, "Type numbers in the #{state.db.categories[id].name} column")

  @doc "How many of the given items are explicitly assigned to a category."
  def group_count(db, item_ids, cat_id),
    do: Enum.count(item_ids, &Database.explicit?(db, &1, cat_id))
end
