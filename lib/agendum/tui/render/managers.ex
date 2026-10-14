defmodule Agendum.TUI.Render.Managers do
  @moduledoc """
  The full-screen category manager (F9). Pure.
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
        indent = String.duplicate("   ", depth)

        name =
          case state.edit do
            %{target: {:rename, ^id}} ->
              [{:normal, " " <> indent}] ++ Draw.input(state.edit.line, 30, :edit)

            _ ->
              [
                {:normal, " " <> indent},
                {if(selected, do: :cursor, else: :item), cat.name <> Text.ellipsis(state, cat)}
              ]
          end

        line = name ++ [{:dim, category_tags(state, cat)}]

        case state.edit do
          %{target: {:new, parent, _}} when selected ->
            new_indent = String.duplicate("   ", Database.depth(db, parent) + 1)
            [line, [{:normal, " " <> new_indent}] ++ Draw.input(state.edit.line, 30, :edit)]

          _ ->
            [line]
        end
      end)
      |> Enum.drop(top)

    lines
  end

  defp category_tags(%State{db: db} = state, cat) do
    count =
      if Database.date_field(db, cat.id), do: nil, else: length(Database.items_in(db, cat.id))

    [
      cat.kind == :date && "date",
      cat.exclusive && "exclusive",
      cat.short_name && "aka #{cat.short_name}",
      cat.conditions != [] && "if " <> Text.conditions_text(state, cat),
      (cat.also_assign != [] or cat.actions != []) && "→ " <> Text.actions_text(state, cat),
      cat.excludes != [] && "not with " <> Text.names_text(db, cat.excludes),
      Agendum.TUI.Boxes.CategoryMatchBox.manager_tag(cat.match_overrides),
      cat.note != "" && "♪",
      count && "#{count}"
    ]
    |> Enum.filter(& &1)
    |> case do
      [] -> ""
      tags -> "   " <> Enum.join(tags, " · ")
    end
  end
end
