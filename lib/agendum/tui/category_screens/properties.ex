defmodule Agendum.TUI.CategoryScreens.Properties do
  @moduledoc """
  Category Properties (F6): its fields, its keys, and changing a
  category's type to numeric or date (User's Guide 7-3, 8-11). Pure.

  The box is drawn from `@layout` (`Agendum.TUI.Boxes.Template`), Agenda's two
  columns (screenshot 74): the name, parent, short name, Also match and
  note on the left with the children, special actions, Statistics and
  Advanced settings; the type and name matching on the right, with the
  conditions, actions and excludes (ours) below them. "Parent is" is
  shown, not a setting. A date or numeric category has Agenda's shorter
  set (`@other_layout`): the same box with blank rows where the settings
  that only a standard category has were; their values stay stored. Note, Statistics and Advanced settings show
  "...": SPACE opens each one's box, as in Agenda. Agenda's Note file is
  left out.

  The box is a box module (`Agendum.TUI.Boxes.Box`).
  """

  use Agendum.TUI.Boxes.Box, finish: :done, cancels: true

  alias Agendum.TUI.Boxes.{Box}

  alias Agendum.Core
  alias Agendum.Core.Database

  alias Agendum.TUI.{
    CategoryScreens,
    Terminal.Draw,
    Typing.LineEdit,
    State,
    Boxes.Template
  }

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
  # A date or numeric category's box, as Agenda's (checked in Agenda 2.0,
  # 2026-10-25, PLANNER's When and Amount): no short name, text matching,
  # exclusive children or conditions, and no excludes (ours), as none of
  # them apply to it; the rows stay, blank, so the box keeps its size
  @other_layout """
   Category name:      [name          ]  Type:                [type      ]
   Parent is [parent                  ]


   Note:               [note          ]

   Special actions:    [special       ]
                                         Assignment actions:
   Statistics:         [statistics    ]  [also_assign                    ]
   Advanced settings:  [advanced      ]
   
  """

  # the settings in reading order, for the cursor: the parent is only shown
  @props Template.fields(@layout) -- [:parent]
  @other_props Template.fields(@other_layout) -- [:parent]

  # Module attributes are computed once, at compile time, so each layout's
  # grid of fields is worked out only once
  @grid Template.grid(@layout, @props)
  @other_grid Template.grid(@other_layout, @other_props)

  @doc "The settings of a standard category's box, in the cursor's order (reading order)."
  def props_fields, do: @props

  # the layout, its settings and its grid for the category on show: a
  # standard category's, or the shorter date and numeric one. The type
  # (always the second setting) can change while the box is open, and the
  # cursor stays on it
  defp form(state, mode) do
    case state.db.categories[mode.cat_id].kind do
      :standard -> {@layout, @props, @grid}
      _ -> {@other_layout, @other_props, @other_grid}
    end
  end

  @help %{
    name: "The category's name. F2 (or SPACE) edits it.",
    short_name:
      "A short name for the category, also matched in item text. F2 (or SPACE) edits it.",
    type: "Standard, date or numeric. SPACE changes a standard category's type.",
    exclusive: "Whether an item can be in only one of the category's children. SPACE switches.",
    match_name: "Assign items whose text mentions the category's name. SPACE switches.",
    also_match:
      "Other words and phrases, separated by semicolons, that assign items too. F2 edits.",
    conditions:
      "Assign items to the category when they are in (or not in) other categories. SPACE.",
    also_assign:
      "What happens to items that join the category: other categories, dates, numbers. SPACE.",
    excludes:
      "Categories that may not share items with this one: joining one leaves the other. SPACE.",
    special:
      "An action for items that join the category: mark them done, or discard them. SPACE.",
    advanced: "Press SPACE BAR for how the category gets dates or matches item text.",
    statistics: "Press SPACE BAR to display current statistics for the category.",
    note: "The category's note. SPACE opens it."
  }

  @impl Box
  def field(state, mode) do
    {_layout, props, _grid} = form(state, mode)
    Enum.at(props, mode.cursor)
  end

  @impl Box
  def title(_state, _mode), do: "Category Properties"

  # two columns of settings, as Agenda's (screenshot 74)
  @impl Box
  def width(state, _mode), do: min(state.width - 8, 72)

  @impl Box
  def keys(_state, _mode),
    do: [
      {"SPACE", "Change", "Change the setting"},
      {"F2", "Edit", "Edit the name"},
      {"ENTER", "Done"},
      {"ESC", "Cancel"}
    ]

  @impl Box
  def help, do: @help

  # no hint inside: Agenda's box is full (screenshot 74); the key bar has the keys
  @impl Box
  def content(state, mode, _inner, _max_rows) do
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

    {layout, props, _grid} = form(state, mode)
    Template.render(layout, values, [selected: Enum.at(props, mode.cursor)] ++ editing)
  end

  # --- category properties -----------------------------------------------------------------------

  @impl Box
  def handle(%State{edit: edit} = state, mode, key) when edit != nil do
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
            State.run(state, {:set_short_name, mode.cat_id, text})

          :also_match ->
            State.run(state, {:set_also_match, mode.cat_id, text})
        end

      _ ->
        case LineEdit.handle(edit.line, key) do
          {:ok, line} -> %{state | edit: %{edit | line: line}}
          :unhandled -> state
        end
    end
  end

  def handle(state, _mode, _key), do: state

  # the settings box's keys; F2 and F3 change a setting too, as SPACE
  # does, F6 (which opened the box) is done (R65). F2 and F3 have commands
  # of their own so the key bar can name them as Agenda's: Edit, Choices
  @impl Box
  def keymap(_mode),
    do: Box.settings_keymap(%{{:f, 2} => :edit, {:f, 3} => :choose, {:f, 6} => :done})

  @impl Box
  def commands(_mode),
    do:
      Box.settings_commands([
        {:edit, "Edit", "Change the setting, as SPACE does"},
        {:choose, "Choices", "Change the setting, as SPACE does"}
      ])

  # F6 closes the box: Agenda's PROPS, going back
  @impl Box
  def labels(_mode), do: %{done: "Props"}

  # ENTER is done (ESC cancels: `Agendum.TUI.Boxes.BoxCancel`)
  # F8 and ALT-F8 (`Agendum.TUI.Boxes.BoxDefaults`): what a new category has
  # (`Agendum.Core.Category`); the name, the type, the note and the lists
  # (conditions, actions, excludes) have no default. Each reads the
  # category as it is when it runs
  @impl Box
  def defaults(_state, mode) do
    id = mode.cat_id
    cat = fn state -> state.db.categories[id] end

    %{
      short_name:
        &if(cat.(&1).short_name in [nil, ""],
          do: &1,
          else: State.run(&1, {:set_short_name, id, ""})
        ),
      also_match:
        &if(cat.(&1).also_match == "", do: &1, else: State.run(&1, {:set_also_match, id, ""})),
      # only a standard category matches its name by default (a date or
      # numeric one never does)
      match_name:
        &if(cat.(&1).match_name or cat.(&1).kind != :standard,
          do: &1,
          else: State.run(&1, {:toggle_match_name, id})
        ),
      exclusive: &if(cat.(&1).exclusive, do: State.run(&1, {:make_unexclusive, id}), else: &1),
      special:
        &if(cat.(&1).special == nil, do: &1, else: State.run(&1, {:set_special_action, id, nil}))
    }
  end

  @impl Box
  def run(state, mode, id) when id in [:change, :edit, :choose],
    do: open_prop(state, state.db.categories[mode.cat_id], field(state, mode))

  def run(state, mode, id) do
    {_layout, _props, grid} = form(state, mode)
    Box.run_settings(state, mode, grid, id)
  end

  # SPACE (or F2, F3) on a row of Category Properties
  defp open_prop(state, cat, :name) do
    if Database.protected?(state.db, cat.id),
      do: State.error(state, "#{cat.name} cannot be renamed"),
      else: %{state | edit: %{target: :name, line: LineEdit.new(cat.name)}}
  end

  # how much of the file uses the category (Agenda's Category Statistics)
  defp open_prop(state, cat, :statistics),
    do: Agendum.TUI.Boxes.CategoryStatsBox.open(state, cat.id)

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
    State.run(state, {:toggle_match_name, cat.id})
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
      :date -> Agendum.TUI.Boxes.DateRuleBox.open(state, cat.id)
      :standard -> Agendum.TUI.Boxes.CategoryMatchBox.open(state, cat.id)
      :numeric -> State.error(state, "Numeric categories have no advanced settings")
    end
  end

  defp open_prop(state, cat, :special) do
    next = %{nil => :done, done: :discard, discard: nil}[cat.special]
    State.run(state, {:set_special_action, cat.id, next})
  end

  defp open_prop(state, cat, :conditions) do
    CategoryScreens.open_picker(state, {:condition, cat.id}, nil)
  end

  defp open_prop(state, cat, :note) do
    Agendum.TUI.Update.Notes.open(state, {:category, cat.id}, cat.name, cat.note)
  end

  # Category type (User's Guide 7-3, 8-11 to 8-12): a standard category
  # can become numeric or date, chosen in a box, after a question when
  # items or children are affected. Neither changes back.
  defp change_type(state, cat) do
    db = state.db

    cond do
      cat.kind != :standard ->
        State.error(state, Agendum.TUI.Messages.text(:cannot_change_type))

      Database.protected?(db, cat.id) ->
        State.error(state, Agendum.TUI.Messages.text(:cannot_convert))

      Enum.any?(cat.children, &(db.categories[&1].children != [])) ->
        State.error(state, Agendum.TUI.Messages.text(:cannot_convert))

      true ->
        State.push(state, %Agendum.TUI.Modes.Choice{kind: :type, cat_id: cat.id, cursor: 0})
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
end
