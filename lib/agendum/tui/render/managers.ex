defmodule Agendum.TUI.Render.Managers do
  @moduledoc """
  The full-screen category manager (F9), drawn as Agenda's: the names,
  indented by level, with Agenda's marks before them and brackets for
  exclusive families; no counts or tags (Agenda shows conditions and
  actions only with Customize's Display cond/act info). Pure.
  """

  alias Agendum.Core.Database
  alias Agendum.TUI.{CategoryScreens, Terminal.Draw, State}
  alias Agendum.TUI.Render.Text

  @doc "The category manager's lines, scrolled to the highlight."
  def category_lines(state, mode) do
    rows = CategoryScreens.rows(state, mode)
    visible = State.body_height(state)
    top = max(mode.cursor - visible + 1, 0)
    db = state.db

    lines =
      rows
      |> Enum.with_index()
      |> Enum.flat_map(fn {{id, depth}, i} ->
        cat = db.categories[id]
        selected = i == mode.cursor
        # Agenda's row (checked in Agenda 2.0, 2026-10-25): two columns a
        # level, a mark, the family's bracket, then the name
        lead = [
          {:normal, Draw.spaces(2 * depth)},
          {:symbol, mark(cat)},
          {:symbol, bracket(db, cat)}
        ]

        # a name is typed in the control panel, as Agenda's (checked in
        # Agenda 2.0, 2026-10-25): the list shows the name as it is, and a
        # new category as a blank highlighted row
        new? = match?(%{target: {:new, _, _}}, state.edit)
        style = if selected and not new?, do: :cursor, else: :item
        name = lead ++ [{style, cat.name <> Text.ellipsis(state, cat)}]

        case state.edit do
          %{target: {:new, parent, _}} when selected ->
            new_lead = Draw.spaces(2 * (Database.depth(db, parent) + 1) + 2)
            [name, [{:normal, new_lead}, {:cursor, Draw.spaces(8)}]]

          _ ->
            [name]
        end
      end)
      |> Enum.drop(top)

    lines
  end

  # Agenda's mark two left of the name: ♪ a note, ☼ a date category, # a
  # numeric one (the screen shows ☼ where Agenda's help writes *), ⌂ an
  # unindexed one (R29b; Agenda's mark on the View line, unchecked here)
  defp mark(%{note: note}) when note != "", do: "♪"
  defp mark(%{kind: :date}), do: "☼"
  defp mark(%{kind: :numeric}), do: "#"
  defp mark(%{kind: :unindexed}), do: "⌂"
  defp mark(_cat), do: " "

  # ┌ ├ └ just before the children of an exclusive family, [ for a lone
  # child, as Agenda draws them
  defp bracket(db, %{parent_id: parent} = cat) when parent != nil do
    case db.categories[parent] do
      %{exclusive: true, children: [_only]} ->
        "["

      %{exclusive: true, children: [first | _] = children} ->
        family_bracket(cat.id, first, List.last(children))

      _ ->
        " "
    end
  end

  defp bracket(_db, _cat), do: " "

  defp family_bracket(id, id, _last), do: "┌"
  defp family_bracket(id, _first, id), do: "└"
  defp family_bracket(_id, _first, _last), do: "├"
end
