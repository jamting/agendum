defmodule Agenda.TUI.Render.Managers do
  @moduledoc """
  The full-screen category manager (F9) and view manager (F8). Pure.
  """

  alias Agenda.Core.Database
  alias Agenda.TUI.{CategoryScreens, Draw, State}
  alias Agenda.TUI.Render.Text

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
      Agenda.TUI.CategoryMatchBox.manager_tag(cat.match_overrides),
      cat.note != "" && "♪",
      count && "#{count}"
    ]
    |> Enum.filter(& &1)
    |> case do
      [] -> ""
      tags -> "   " <> Enum.join(tags, " · ")
    end
  end

  @doc "The view manager's lines."
  def view_lines(state, mode) do
    views =
      state.db
      |> Database.views()
      |> Enum.with_index()
      |> Enum.map(fn {v, i} ->
        selected = i == mode.cursor
        current = if v.id == state.view_id, do: "►", else: " "

        name =
          case state.edit do
            %{target: id} when id == v.id -> Draw.input(state.edit.line, 30, :edit)
            _ -> [{if(selected, do: :cursor, else: :item), Draw.pad(v.name, 30)}]
          end

        # * marks a datebook view, as in Agenda's view manager (R47)
        {star, about} =
          case v.datebook do
            nil ->
              {" ",
               "Sections: " <>
                 Enum.map_join(v.sections, ", ", &state.db.categories[&1.category_id].name)}

            d ->
              {"*", "Datebook: #{d.period}, #{state.db.categories[d.section_category].name}"}
          end

        [{:symbol, " #{current}#{star}"}] ++ name ++ [{:dim, "  " <> about}]
      end)

    [[] | views]
  end
end
