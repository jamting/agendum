defmodule Agenda.TUI.ActionBox do
  @moduledoc """
  The Date Action and Numeric Action boxes (SPEC R15b; User's Guide 21-4 to
  21-7), opened when a date or numeric category is chosen in a category's
  Assignment actions. Rows: what to do (set a date or number, or clear it)
  and the date or value. ↑↓ move; SPACE or ←→ change the choice; typing
  goes into the value. ENTER applies, DEL removes the action, ESC cancels.
  Pure.
  """

  alias Agenda.Core
  alias Agenda.TUI.{LineEdit, State, Update}

  @rows [:what, :value]
  def rows, do: @rows

  def open(state, owner, target) do
    {clear, value} =
      case List.keyfind(state.db.categories[owner].actions, target, 0) do
        {_, :clear} ->
          {true, ""}

        {_, {:set, value}} when is_number(value) ->
          {false, Update.number_text(value, State.number_opts(state))}

        {_, {:set, value}} ->
          {false, value}

        nil ->
          {false, ""}
      end

    State.push(state, %{
      type: :action_box,
      owner: owner,
      target: target,
      clear: clear,
      line: LineEdit.new(value),
      cursor: 0
    })
  end

  @doc "Whether the action is on a numeric category (else a date category)."
  def numeric?(state, mode), do: state.db.categories[mode.target].kind == :numeric

  def handle(state, mode, key) do
    row = Enum.at(@rows, mode.cursor)

    case key do
      :esc ->
        State.pop(state)

      :enter ->
        apply_action(state, mode)

      k when k in [:down, :tab] ->
        State.put_mode(state, %{mode | cursor: 1})

      k when k in [:up, :shift_tab] ->
        State.put_mode(state, %{mode | cursor: 0})

      k when row == :value ->
        case LineEdit.handle(mode.line, k) do
          {:ok, line} -> State.put_mode(state, %{mode | line: line})
          :unhandled -> state
        end

      :delete ->
        state
        |> State.pop()
        |> State.change_db(Core.remove_action(state.db, mode.owner, mode.target))

      k when k in [{:char, " "}, :left, :right] ->
        State.put_mode(state, %{mode | clear: not mode.clear})

      _ ->
        state
    end
  end

  defp apply_action(state, mode) do
    action = if mode.clear, do: :clear, else: {:set, mode.line.text}

    case Core.set_action(state.db, mode.owner, mode.target, action, State.context(state)) do
      {:ok, db} ->
        state |> State.pop() |> State.change_db(db)

      {:error, :invalid_date} ->
        State.error(state, "Not a date: #{String.trim(mode.line.text)}")

      {:error, :not_a_number} ->
        State.error(state, "Not a number: #{String.trim(mode.line.text)}")

      {:error, :self} ->
        State.error(state, "A category cannot act on itself")
    end
  end

  @doc "`{label, value}` for each row; the value row gives its `LineEdit`."
  def lines(state, mode) do
    name = state.db.categories[mode.target].name
    noun = if numeric?(state, mode), do: "value", else: "date"

    [
      {"Action",
       if(mode.clear, do: "Remove the #{noun} in #{name}", else: "Give items a #{noun}")},
      {if(numeric?(state, mode), do: "With value", else: "With date"), {:line, mode.line}}
    ]
  end
end
