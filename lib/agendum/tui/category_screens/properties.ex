defmodule Agendum.TUI.CategoryScreens.Properties do
  @moduledoc """
  Category Properties (F6): its fields, its keys, and changing a
  category's type to numeric or date (User's Guide 7-3, 8-11). Pure.

  The box is drawn from `@layout` (`Agendum.TUI.Template`), Agenda's two
  columns (screenshot 74): the name, parent, short name, Also match and
  note on the left with the children, special actions, Statistics and
  Advanced settings; the type and name matching on the right, with the
  conditions, actions and excludes (ours) below them. "Parent is" is
  shown, not a setting. Note, Statistics and Advanced settings show
  "...": SPACE opens each one's box, as in Agenda. Agenda's Note file is
  left out.
  """

  import Agendum.TUI.BoxNav, only: [is_move: 1]
  alias Agendum.TUI.BoxNav

  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.TUI.{CategoryScreens, Draw, LineEdit, State, Template, TextEdit}
  alias Agendum.TUI.Render.Text
  alias Agendum.TUI.CategoryScreens.Choices
  alias Agendum.TUI.Update.Prompts

  @layout """
   Category name:      [name          ]  Type:                [type      ]
   Parent is [parent                  ]  Match category name: [match_name]
   Short name:         [short_name    ]
   Also match:         [also_match    ]
   Note:               [note          ]
   Exclusive children: [exclusive     ]  Assignment conditions:
   Special actions:    [special       ]  [conditions                     ]
                                         Assignment actions:
   Statistics:         [statistics    ]  [also_assign                    ]
   Advanced settings:  [advanced      ]  Excludes:
                                         [excludes                       ]
  """
  # the settings in reading order, for the cursor: the parent is only shown
  @props Template.fields(@layout) -- [:parent]
  @grid Template.grid(@layout, @props)

  @doc "The settings, in the cursor's order (reading order)."
  def props_fields, do: @props

  @doc "The highlighted field, for its help in the control panel (`Agendum.TUI.FieldHelp`)."
  def field(_state, mode), do: Enum.at(@props, mode.cursor)

  @doc "The box's lines, the highlighted setting selected (or being edited)."
  def content(state, mode) do
    cat = state.db.categories[mode.cat_id]
    yes_no = fn b -> if b, do: "Yes", else: "No" end

    values = %{
      name: cat.name,
      parent: if(cat.parent_id, do: state.db.categories[cat.parent_id].name, else: "(none)"),
      # an empty value would leave the highlighted row invisible
      short_name: cat.short_name || "(none)",
      type: cat.kind |> Atom.to_string() |> String.capitalize(),
      exclusive: yes_no.(cat.exclusive),
      match_name: yes_no.(cat.match_name),
      also_match: if(cat.also_match == "", do: "(none)", else: cat.also_match),
      special:
        %{nil => "No action", done: "Mark items done", discard: "Discard items"}[cat.special],
      also_assign:
        if(cat.also_assign == [] and cat.actions == [],
          do: "(none)",
          else: Text.actions_text(state, cat)
        ),
      conditions: if(cat.conditions == [], do: "(none)", else: Text.conditions_text(state, cat)),
      excludes:
        if(cat.excludes == [], do: "(none)", else: Text.names_text(state.db, cat.excludes)),
      # boxes of their own, opened with SPACE, as Agenda's "..."
      note: "...",
      statistics: "...",
      advanced: "..."
    }

    editing =
      case state.edit do
        %{target: field, line: line} when is_atom(field) -> [editing: {field, line}]
        _ -> []
      end

    Template.render(@layout, values, [selected: Enum.at(@props, mode.cursor)] ++ editing)
  end

  # --- category properties -----------------------------------------------------------------------

  @doc "Keys of Category Properties."
  def props_key(%State{edit: edit} = state, mode, key) when edit != nil do
    case key do
      :esc ->
        %{state | edit: nil}

      :enter ->
        text = edit.line.text
        state = %{state | edit: nil}

        case edit.target do
          :name ->
            CategoryScreens.commit(state, mode, {:rename, mode.cat_id}, text)

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

  def props_key(state, mode, key) do
    cat = state.db.categories[mode.cat_id]

    case key do
      # ENTER is done (ESC cancels: `Agendum.TUI.BoxCancel`)
      k when k in [:esc, :enter, {:f, 6}] ->
        State.pop(state)

      k when is_move(k) ->
        BoxNav.move(state, mode, @grid, k)

      k when k in [{:char, " "}, {:f, 2}, {:f, 3}] ->
        open_prop(state, cat, Enum.at(@props, mode.cursor))

      _ ->
        state
    end
  end

  # SPACE (or F2, F3) on a row of Category Properties
  defp open_prop(state, cat, :name) do
    if Database.protected?(state.db, cat.id),
      do: State.error(state, "#{cat.name} cannot be renamed"),
      else: %{state | edit: %{target: :name, line: LineEdit.new(cat.name)}}
  end

  # how much of the file uses the category (Agenda's Category Statistics)
  defp open_prop(state, cat, :statistics),
    do: State.push(state, %{type: :category_stats, cat_id: cat.id})

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
    Choices.toggle_exclusive(state, cat)
  end

  defp open_prop(state, cat, :match_name) do
    State.change_db(state, Core.toggle_match_name(state.db, cat.id))
  end

  defp open_prop(state, cat, :also_assign) do
    CategoryScreens.open_picker(state, {:also_assign, cat.id}, nil)
  end

  defp open_prop(state, cat, :excludes) do
    CategoryScreens.open_picker(state, {:excludes, cat.id}, nil)
  end

  # Agenda's Advanced settings: how a date category gets dates (R6b), how
  # a standard one matches text (R16b)
  defp open_prop(state, cat, :advanced) do
    case cat.kind do
      :date -> Agendum.TUI.DateRuleBox.open(state, cat.id)
      :standard -> Agendum.TUI.CategoryMatchBox.open(state, cat.id)
      :numeric -> State.error(state, "Numeric categories have no advanced settings")
    end
  end

  defp open_prop(state, cat, :special) do
    next = %{nil => :done, done: :discard, discard: nil}[cat.special]
    {:ok, db} = Core.set_special_action(state.db, cat.id, next)
    State.change_db(state, db)
  end

  defp open_prop(state, cat, :conditions) do
    CategoryScreens.open_picker(state, {:condition, cat.id}, nil)
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

  @doc "Makes a category numeric, asking first when items or children change."
  def to_numeric(state, cat) do
    case numeric_question(cat, Core.numeric_conversion(state.db, cat.id, State.context(state))) do
      nil -> Prompts.make_numeric(state, cat.id)
      question -> Prompts.confirm(state, question, {:make_numeric, cat.id})
    end
  end

  @doc "Makes a category a date category, asking first when items or children change."
  def to_date(state, cat) do
    case date_question(cat, Core.date_conversion(state.db, cat.id, State.context(state))) do
      nil -> Prompts.make_date(state, cat.id)
      question -> Prompts.confirm(state, question, {:make_date, cat.id})
    end
  end

  @doc """
  The question to ask before `cat` becomes a date category, or nil when
  nothing would change (`Core.date_conversion/3`). Also asked by Column
  Add ▸ Category type.
  """
  def date_question(_cat, %{children: 0, assigned: 0}), do: nil

  def date_question(cat, conversion) do
    parts =
      [
        conversion.children > 0 && "children become dates",
        conversion.non_dates != [] && "dropped: " <> Enum.join(conversion.non_dates, ", "),
        conversion.assigned > 0 && "#{Draw.count(conversion.assigned, "item")} in it get no date"
      ]
      |> Enum.filter(& &1)

    "Make #{cat.name} a date category? " <> Enum.join(parts, "; ") <> ""
  end

  @doc """
  The question to ask before `cat` becomes numeric, or nil when nothing
  would change (`Core.numeric_conversion/3`).
  """
  def numeric_question(_cat, %{children: 0, assigned: 0}), do: nil

  def numeric_question(cat, conversion) do
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

    "Convert #{cat.name} to numeric? " <> Enum.join(parts, "; ") <> "."
  end

  # --- Category Statistics ---

  @stats """
   Items in category:          [items  ]
   Child categories:           [children]
   Used as section heads:      [section_heads]
   Included in view filters:   [view_filters]
   Included in conditions:     [conditions]
   Included in actions:        [actions]
  """

  @doc "The Category Statistics box's lines: counts only, nothing to change."
  def stats_content(state, mode) do
    counts = Database.category_statistics(state.db, mode.cat_id)
    Template.render(@stats, Map.new(counts, fn {k, n} -> {k, Integer.to_string(n)} end))
  end

  @doc "Keys of Category Statistics: ENTER or ESC go back to Category Properties."
  def stats_key(state, _mode, key) when key in [:enter, :esc], do: State.pop(state)
  def stats_key(state, _mode, _key), do: state
end
