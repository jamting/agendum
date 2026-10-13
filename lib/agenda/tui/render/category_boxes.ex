defmodule Agenda.TUI.Render.CategoryBoxes do
  @moduledoc """
  The boxes listing categories (the picker, an item's assignment profile,
  the marked items' profile), Category Properties and the choice boxes. Pure.
  """

  alias Agenda.Core.Database
  alias Agenda.TUI.{CategoryScreens, Draw, State}
  alias Agenda.TUI.CategoryScreens.{Choices, Properties}
  alias Agenda.TUI.Render.Text

  @doc "The content of one of these boxes, `inner` wide, at most `max_rows` of list."
  def content(state, %{type: type} = mode, inner, max_rows)
      when type in [:picker, :profile, :group_profile] do
    rows = CategoryScreens.rows(state, mode)
    cursor = min(mode.cursor, max(length(rows) - 1, 0))
    top = max(cursor - max_rows + 1, 0)

    list =
      rows
      |> Enum.with_index()
      |> Enum.drop(top)
      |> Enum.take(max_rows)
      |> Enum.map(fn {{id, depth}, i} ->
        style = if i == cursor, do: :box_selected, else: :box
        cat = state.db.categories[id]
        name = String.duplicate("  ", depth) <> cat.name <> Text.ellipsis(state, cat)

        [
          {:box, " " <> profile_marker(state, mode, id) <> " "},
          {style, Draw.pad(name, inner - 6)}
        ]
      end)

    list =
      if list == [], do: [[{:box, "  (no categories yet — press INS to create one)"}]], else: list

    list ++ [[], box_footer(state, mode, inner)]
  end

  def content(_state, %{type: :choice} = mode, _inner, _max_rows) do
    options = Choices.choice_options(mode)
    [problem, question] = Choices.choice_lines(mode)
    {_, description, _} = Enum.at(options, mode.cursor)

    choices =
      options
      |> Enum.with_index()
      |> Enum.map(fn {{label, _, _}, i} ->
        [{:box, "   "}, {if(i == mode.cursor, do: :box_selected, else: :box), " #{label} "}]
      end)

    [[{:box, " " <> problem}], [], [{:box, " " <> question}]] ++
      choices ++ [[], [{:box, " " <> description}]]
  end

  def content(state, %{type: :props} = mode, inner, _max_rows) do
    cat = state.db.categories[mode.cat_id]
    yes_no = fn b -> if b, do: "Yes", else: "No" end

    values = %{
      name: cat.name,
      # an empty value would leave the highlighted row invisible
      short_name: cat.short_name || "(none)",
      type: cat.kind |> Atom.to_string() |> String.capitalize(),
      exclusive: yes_no.(cat.exclusive),
      match_name: yes_no.(cat.match_name),
      also_match: if(cat.also_match == "", do: "(none)", else: cat.also_match),
      special: %{nil => "None", done: "Mark items done", discard: "Discard items"}[cat.special],
      also_assign:
        if(cat.also_assign == [] and cat.actions == [],
          do: "(none)",
          else: Text.actions_text(state, cat)
        ),
      conditions: if(cat.conditions == [], do: "(none)", else: Text.conditions_text(state, cat)),
      excludes:
        if(cat.excludes == [], do: "(none)", else: Text.names_text(state.db, cat.excludes)),
      advanced:
        if(cat.kind == :date,
          do: Agenda.TUI.DateRuleBox.summary(cat.date_rule),
          else: Agenda.TUI.CategoryMatchBox.summary(cat.match_overrides)
        ),
      note: if(cat.note == "", do: "(none)", else: "#{String.length(cat.note)} characters")
    }

    labels = %{
      name: "Category name",
      short_name: "Short name",
      type: "Type",
      exclusive: "Children mutually exclusive",
      match_name: "Assign items mentioning it",
      also_match: "Also match",
      also_assign: "Assignment actions",
      excludes: "Excludes",
      advanced: "Advanced settings",
      special: "Special action",
      conditions: "Assignment conditions",
      note: "Note"
    }

    Properties.props_fields()
    |> Enum.with_index()
    |> Enum.map(fn {prop, i} ->
      label = [{:box, " " <> Draw.pad(labels[prop], 28) <> ": "}]

      value =
        case state.edit do
          %{target: ^prop} -> Draw.input(state.edit.line, inner - 32, :edit)
          _ -> [{if(i == mode.cursor, do: :box_selected, else: :box), values[prop]}]
        end

      label ++ value
    end)
  end

  defp box_footer(state, %{type: :picker} = mode, inner) do
    case state.edit do
      %{target: :new_pick} ->
        [{:box, " New category: "}] ++ Draw.input(state.edit.line, inner - 16, :edit)

      _ when mode.search != "" ->
        [{:box, " Search: " <> mode.search}]

      _ when elem(mode.purpose, 0) == :also_assign ->
        [{:box, " ENTER cycles: + assign · - remove · none (dates, numbers: a box)"}]

      _ when elem(mode.purpose, 0) == :excludes ->
        [{:box, " ENTER toggles: x may not share items"}]

      _ when elem(mode.purpose, 0) in [:condition, :filter, :schedule_filter] ->
        [{:box, " ENTER cycles: + assigned · - not assigned · none"}]

      _ ->
        [{:box, " ENTER selects · INS creates · type to search"}]
    end
  end

  defp box_footer(_state, %{type: :group_profile}, _inner),
    do: [{:box, " N = marked items assigned · SPACE assigns or unassigns all"}]

  defp box_footer(_state, %{type: :profile}, _inner),
    do: [{:box, " * assigned  c by a condition  + via subcategory  SPACE"}]

  defp profile_marker(state, %{type: :group_profile, item_ids: ids}, id) do
    case CategoryScreens.group_count(state.db, ids, id) do
      0 -> " "
      n when n < 10 -> Integer.to_string(n)
      _ -> "+"
    end
  end

  defp profile_marker(state, %{type: :profile, item_id: item_id}, id) do
    db = state.db

    cond do
      Database.date_category?(db, id) ->
        if Database.item_date(db, item_id, id), do: "◊", else: " "

      Database.conditional?(db, item_id, id) ->
        "c"

      Database.explicit?(db, item_id, id) ->
        "*"

      Database.member?(db, item_id, id) ->
        "+"

      true ->
        " "
    end
  end

  defp profile_marker(state, %{type: :picker, purpose: {:filter, scope}}, id) do
    view = State.view(state)

    filter =
      if scope == :view, do: view.filter, else: Enum.at(view.sections, elem(scope, 1)).filter

    case List.keyfind(filter, id, 0) do
      {_, :not_assigned} -> "-"
      {_, _assigned_or_range} -> "+"
      nil -> " "
    end
  end

  defp profile_marker(state, %{type: :picker, purpose: {:condition, cat_id}}, id) do
    case List.keyfind(state.db.categories[cat_id].conditions, id, 0) do
      {_, :not_assigned} -> "-"
      {_, _assigned_or_range} -> "+"
      nil -> " "
    end
  end

  defp profile_marker(state, %{type: :picker, purpose: {:also_assign, cat_id}}, id) do
    cat = state.db.categories[cat_id]

    cond do
      id in cat.also_assign -> "+"
      List.keyfind(cat.actions, id, 0) in [{id, :remove}, {id, :clear}] -> "-"
      List.keymember?(cat.actions, id, 0) -> "="
      true -> " "
    end
  end

  defp profile_marker(state, %{type: :picker, purpose: {:schedule_filter, _}}, id),
    do: Agenda.TUI.ScheduleBox.filter_mark(state, id)

  defp profile_marker(state, %{type: :picker, purpose: {:excludes, cat_id}}, id),
    do: if(id in state.db.categories[cat_id].excludes, do: "x", else: " ")

  defp profile_marker(_state, _mode, _id), do: " "
end
