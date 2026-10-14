defmodule Agenda.TUI.RangeFilterBox do
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
  rules are `Agenda.Core.RangeFilter`. Pure.
  """

  import Agenda.TUI.BoxNav, only: [is_move: 1]
  alias Agenda.TUI.BoxNav

  alias Agenda.Core
  alias Agenda.TUI.{LineEdit, State}
  alias Agenda.TUI.Update.Editing

  @rows [:show, :from, :to, :where]
  def rows, do: @rows

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

    State.push(state, %{
      type: :range_filter,
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

  def handle(state, mode, key) do
    row = Enum.at(@rows, mode.cursor)

    case key do
      :esc ->
        State.pop(state)

      :enter ->
        apply_filter(state, mode)

      # on a date or number, ← → HOME END move in it; ↑ ↓ TAB still move between settings
      k when is_move(k) and (row not in [:from, :to] or k in [:up, :down, :tab, :shift_tab]) ->
        BoxNav.move(state, mode, BoxNav.column(@rows), k)

      k when row in [:from, :to] ->
        case LineEdit.handle(Map.fetch!(mode, row), k) do
          {:ok, line} -> State.put_mode(state, Map.put(mode, row, line))
          :unhandled -> state
        end

      :delete ->
        state |> State.pop() |> State.change_db(remove(state, mode))

      {:char, " "} ->
        State.put_mode(state, toggle(mode, row))

      _ ->
        state
    end
  end

  defp toggle(mode, :show),
    do: %{mode | show: if(mode.show == :assigned, do: :not_assigned, else: :assigned)}

  defp toggle(mode, :where),
    do: %{mode | where: if(mode.where == :inside, do: :outside, else: :inside)}

  defp remove(state, %{purpose: {:filter, scope}, cat_id: cat_id}),
    do: Core.remove_filter(state.db, state.view_id, scope, cat_id)

  defp remove(state, %{purpose: {:condition, owner}, cat_id: cat_id}),
    do: Core.remove_condition(state.db, owner, cat_id)

  defp apply_filter(state, mode) do
    case set(state, mode) do
      {:ok, db} ->
        state |> State.pop() |> State.change_db(db)

      {:error, :invalid_date} ->
        State.error(state, "Not a date: #{bad(mode, &parse_date(&1, state))}")

      {:error, :not_a_number} ->
        opts = State.number_opts(state)
        State.error(state, "Not a number: #{bad(mode, &Core.NumberFormat.parse(&1, opts))}")

      {:error, :self} ->
        State.error(state, "A category cannot depend on itself")
    end
  end

  defp parse_date(text, state),
    do:
      Core.DateParser.parse(
        text,
        state.today,
        Core.Context.parser_opts(State.context(state), state.db.date_settings)
      )

  defp set(state, %{purpose: {:filter, scope}} = mode) do
    settings = {mode.show, mode.from.text, mode.to.text, mode.where}

    Core.set_range_filter(
      state.db,
      state.view_id,
      scope,
      mode.cat_id,
      settings,
      State.context(state)
    )
  end

  # A condition with Not assigned: items without a date (or number).
  defp set(state, %{purpose: {:condition, owner}, show: :not_assigned} = mode) do
    db = Core.remove_condition(state.db, owner, mode.cat_id)
    Core.add_condition(db, owner, mode.cat_id, :not_assigned)
  end

  defp set(state, %{purpose: {:condition, owner}} = mode) do
    range = {mode.from.text, mode.to.text, mode.where}
    Core.set_range_condition(state.db, owner, mode.cat_id, range, State.context(state))
  end

  # The first non-blank bound that does not read.
  defp bad(mode, parse) do
    [mode.from.text, mode.to.text]
    |> Enum.map(&String.trim/1)
    |> Enum.find(&(&1 != "" and parse.(&1) == :error))
  end

  @doc "`{label, value}` for each row; text rows give their `LineEdit`."
  def lines(state, mode) do
    numeric = numeric?(state, mode)

    [
      {"Show items", if(mode.show == :assigned, do: "Assigned", else: "Not assigned")},
      {if(numeric, do: "Minimum value", else: "Start date"), {:line, mode.from}},
      {if(numeric, do: "Maximum value", else: "End date"), {:line, mode.to}},
      {"Items should be", if(mode.where == :inside, do: "Inside range", else: "Outside range")}
    ]
  end

  @doc "The highlighted field, for its help in the control panel (`Agenda.TUI.FieldHelp`)."
  def field(_state, mode), do: Enum.at(@rows, mode.cursor)
end
