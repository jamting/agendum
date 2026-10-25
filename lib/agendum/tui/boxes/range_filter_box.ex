defmodule Agendum.TUI.Boxes.RangeFilterBox do
  @moduledoc """
  The Date Filter and Numeric Filter boxes (SPEC R28a; User's Guide 11-6
  and 11-11), opened when a date or numeric category is chosen in the
  filter box of a view or section, and the Date Condition and Numeric
  Condition boxes (R15a; User's Guide 20-5 to 20-7), opened from a
  category's conditions. The `purpose` says which: `{:filter, scope}` or
  `{:condition, category}`.

  Rows: Show items (Assigned / Not assigned), Start date and End date (or
  Minimum and Maximum value; blank means open), and Items should be
  (Inside / Outside range). The arrows or TAB move (in a date or number,
  ← → move in the text); SPACE changes a choice;
  typing goes into the dates or numbers. ENTER applies the filter, ESC
  cancels, DEL on a choice row removes the category from the filter. The
  rules are `Agendum.Core.RangeFilter`. Drawn from a layout
  (`Agendum.TUI.Boxes.Template`), one for dates and one for numbers. Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done, indicator: "PROPS", choices: true

  alias Agendum.TUI.Boxes.{Box, Template}
  alias Agendum.TUI.{Typing.LineEdit, State}
  alias Agendum.TUI.Update.Editing

  @date_layout """
   Show items       : [show                                   ]
   Start date       : [from                                   ]
   End date         : [to                                     ]
   Items should be  : [where                                  ]
  """
  @number_layout """
   Show items       : [show                                   ]
   Minimum value    : [from                                   ]
   Maximum value    : [to                                     ]
   Items should be  : [where                                  ]
  """

  @rows Template.fields(@date_layout)
  @grid Template.grid(@date_layout, @rows)

  @help %{
    show: "Choose items assigned to the category, or items not assigned. SPACE switches.",
    from: "Type the start of the range: a date or a number. Leave it blank for no start.",
    to: "Type the end of the range: a date or a number. Leave it blank for no end.",
    where:
      "Choose items inside the range or outside it. SPACE switches. " <>
        "ENTER applies, DEL removes the category."
  }

  @doc "Opens the box for a view's or section's filter on `cat_id`."
  def open(state, scope, cat_id), do: open_for(state, {:filter, scope}, cat_id)

  @doc "Opens the box for `owner`'s condition on the date or numeric category `cat_id`."
  def open_condition(state, owner, cat_id), do: open_for(state, {:condition, owner}, cat_id)

  defp open_for(state, purpose, cat_id) do
    {show, from, to, where} =
      case List.keyfind(criteria(state, purpose), cat_id, 0) do
        {_, :not_assigned} ->
          {:not_assigned, "", "", :inside}

        {_, {:range, from, to, where}} ->
          opts = State.number_opts(state)
          {:assigned, text(from, opts), text(to, opts), where}

        _ ->
          {:assigned, "", "", :inside}
      end

    State.push(state, %Agendum.TUI.Modes.RangeFilter{
      purpose: purpose,
      cat_id: cat_id,
      show: show,
      from: LineEdit.new(from),
      to: LineEdit.new(to),
      where: where,
      cursor: 0
    })
  end

  defp criteria(state, {:filter, :view}), do: State.view(state).filter

  defp criteria(state, {:filter, {:section, i}}),
    do: Enum.at(State.view(state).sections, i).filter

  defp criteria(state, {:condition, owner}), do: state.db.categories[owner].conditions

  defp text(nil, _opts), do: ""
  defp text(number, opts) when is_number(number), do: Editing.number_text(number, opts)
  defp text(date_expression, _opts), do: date_expression

  @doc "Whether the box is about a numeric category (else a date category)."
  def numeric?(state, mode), do: state.db.categories[mode.cat_id].kind == :numeric

  @impl Box
  # On a date or number the person types: ← → HOME END move in it, other
  # keys edit it; ↑ ↓ TAB still move between settings, ENTER and ESC end.
  def handle(state, mode, key) when key in [:up, :down, :tab, :shift_tab, :enter, :esc],
    do: run(state, mode, Map.fetch!(keymap(mode), key))

  def handle(state, mode, key) do
    row = Enum.at(@rows, mode.cursor)

    case LineEdit.handle(Map.fetch!(mode, row), key) do
      {:ok, line} -> State.put_mode(state, Map.put(mode, row, line))
      :unhandled -> state
    end
  end

  @impl Box
  def typing?(_state, mode), do: Enum.at(@rows, mode.cursor) in [:from, :to]

  # the settings box's keys; ENTER sets it, DEL removes it (R65)
  @impl Box
  def keymap(_mode), do: Box.settings_keymap(%{:delete => :remove})

  @impl Box
  def commands(_mode),
    do:
      Box.settings_commands([
        {:done, "Done", "Set it and close"},
        {:remove, "Remove", "Remove it"}
      ])

  @impl Box
  def run(state, mode, :done), do: apply_filter(state, mode)

  def run(state, mode, :change),
    do: State.put_mode(state, toggle(mode, Enum.at(@rows, mode.cursor)))

  def run(state, mode, :remove), do: state |> State.pop() |> State.run(remove(state, mode))
  def run(state, mode, id), do: Box.run_settings(state, mode, @grid, id)

  defp toggle(mode, :show),
    do: %{mode | show: if(mode.show == :assigned, do: :not_assigned, else: :assigned)}

  defp toggle(mode, :where),
    do: %{mode | where: if(mode.where == :inside, do: :outside, else: :inside)}

  # the command that takes the filter or condition out
  defp remove(state, %{purpose: {:filter, scope}, cat_id: cat_id}),
    do: {:remove_filter, state.view_id, scope, cat_id}

  defp remove(_state, %{purpose: {:condition, owner}, cat_id: cat_id}),
    do: {:remove_condition, owner, cat_id}

  defp apply_filter(state, mode) do
    case State.command(state, set(state, mode)) do
      {:ok, state, _} ->
        State.pop(state)

      {:error, :invalid_date} ->
        State.error(state, Agendum.TUI.Messages.text(:bad_date))

      {:error, :not_a_number} ->
        State.error(state, Agendum.TUI.Messages.text(:bad_number))

      {:error, :self} ->
        State.error(state, "A category cannot depend on itself")
    end
  end

  defp set(state, %{purpose: {:filter, scope}} = mode) do
    settings = {mode.show, mode.from.text, mode.to.text, mode.where}
    {:set_range_filter, state.view_id, scope, mode.cat_id, settings}
  end

  # A condition with Not assigned: items without a date (or number).
  defp set(_state, %{purpose: {:condition, owner}, show: :not_assigned} = mode),
    do: {:set_condition, owner, mode.cat_id, :not_assigned}

  defp set(_state, %{purpose: {:condition, owner}} = mode) do
    range = {mode.from.text, mode.to.text, mode.where}
    {:set_range_condition, owner, mode.cat_id, range}
  end

  @doc "`{label, value}` for each row; text rows give their `LineEdit`."
  @impl Box
  def title(state, mode) do
    kind = if numeric?(state, mode), do: "Numeric", else: "Date"
    what = if match?({:condition, _}, mode.purpose), do: "condition", else: "filter"
    "#{kind} #{what}: #{state.db.categories[mode.cat_id].name}"
  end

  @impl Box
  def content(state, mode, inner, _max_rows) do
    layout = if numeric?(state, mode), do: @number_layout, else: @date_layout

    values = %{
      show: if(mode.show == :assigned, do: "Assigned", else: "Not assigned"),
      from: mode.from.text,
      to: mode.to.text,
      where: if(mode.where == :inside, do: "Inside range", else: "Outside range")
    }

    # a date or number on the cursor is drawn as the line being typed
    row = field(state, mode)
    editing = if row in [:from, :to], do: [editing: {row, Map.fetch!(mode, row)}], else: []

    Template.render(layout, values, [selected: row] ++ editing) ++
      [[], Box.hint(keys(state, mode), inner)]
  end

  @impl Box
  def keys(_state, _mode),
    do: [
      {"↑↓←→", "Setting", "Move between settings"},
      {"SPACE", "Change", "Change the setting"},
      {"ENTER", "Apply"},
      {"DEL", "Remove"},
      {"ESC", "Cancel"}
    ]

  @impl Box
  def help, do: @help

  @impl Box
  def field(_state, mode), do: Enum.at(@rows, mode.cursor)
end
