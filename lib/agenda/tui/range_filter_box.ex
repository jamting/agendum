defmodule Agenda.TUI.RangeFilterBox do
  @moduledoc """
  The Date Filter and Numeric Filter boxes (SPEC R28a; User's Guide 11-6
  and 11-11), opened when a date or numeric category is chosen in the
  filter box of a view or section.

  Rows: Show items (Assigned / Not assigned), Start date and End date (or
  Minimum and Maximum value; blank means open), and Items should be
  (Inside / Outside range). ↑↓ or TAB move; SPACE or ←→ change a choice;
  typing goes into the dates or numbers. ENTER applies the filter, ESC
  cancels, DEL on a choice row removes the category from the filter. The
  rules are `Agenda.Core.RangeFilter`. Pure.
  """

  alias Agenda.Core
  alias Agenda.TUI.{LineEdit, State, Update}

  @rows [:show, :from, :to, :where]
  def rows, do: @rows

  def open(state, scope, cat_id) do
    {show, from, to, where} =
      case List.keyfind(filter(state, scope), cat_id, 0) do
        {_, :not_assigned} -> {:not_assigned, "", "", :inside}
        {_, {:range, from, to, where}} -> {:assigned, text(from), text(to), where}
        _ -> {:assigned, "", "", :inside}
      end

    State.push(state, %{
      type: :range_filter,
      scope: scope,
      cat_id: cat_id,
      show: show,
      from: LineEdit.new(from),
      to: LineEdit.new(to),
      where: where,
      cursor: 0
    })
  end

  defp filter(state, :view), do: State.view(state).filter
  defp filter(state, {:section, i}), do: Enum.at(State.view(state).sections, i).filter

  defp text(nil), do: ""
  defp text(number) when is_number(number), do: Update.number_text(number)
  defp text(date_expression), do: date_expression

  @doc "Whether the box filters a numeric category (else a date category)."
  def numeric?(state, mode), do: state.db.categories[mode.cat_id].kind == :numeric

  def handle(state, mode, key) do
    row = Enum.at(@rows, mode.cursor)

    case key do
      :esc ->
        State.pop(state)

      :enter ->
        apply_filter(state, mode)

      k when k in [:down, :tab] ->
        State.put_mode(state, %{mode | cursor: min(mode.cursor + 1, length(@rows) - 1)})

      k when k in [:up, :shift_tab] ->
        State.put_mode(state, %{mode | cursor: max(mode.cursor - 1, 0)})

      k when row in [:from, :to] ->
        case LineEdit.handle(Map.fetch!(mode, row), k) do
          {:ok, line} -> State.put_mode(state, Map.put(mode, row, line))
          :unhandled -> state
        end

      :delete ->
        db = Core.remove_filter(state.db, state.view_id, mode.scope, mode.cat_id)
        state |> State.pop() |> State.change_db(db)

      k when k in [{:char, " "}, :left, :right] ->
        State.put_mode(state, toggle(mode, row))

      _ ->
        state
    end
  end

  defp toggle(mode, :show),
    do: %{mode | show: if(mode.show == :assigned, do: :not_assigned, else: :assigned)}

  defp toggle(mode, :where),
    do: %{mode | where: if(mode.where == :inside, do: :outside, else: :inside)}

  defp apply_filter(state, mode) do
    settings = {mode.show, mode.from.text, mode.to.text, mode.where}

    case Core.set_range_filter(
           state.db,
           state.view_id,
           mode.scope,
           mode.cat_id,
           settings,
           State.context(state)
         ) do
      {:ok, db} ->
        state |> State.pop() |> State.change_db(db)

      {:error, :invalid_date} ->
        State.error(
          state,
          "Not a date: #{bad(mode, &Core.DateParser.parse(&1, state.today, Core.Context.parser_opts(State.context(state))))}"
        )

      {:error, :not_a_number} ->
        State.error(state, "Not a number: #{bad(mode, &Core.NumberFormat.parse/1)}")
    end
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
end
