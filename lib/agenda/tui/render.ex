defmodule Agenda.TUI.Render do
  @moduledoc """
  Turns a `State` into a screen (a list of styled lines). Pure.

  Screen layout, after Agenda 2.0:

      lines 0–1   control panel: the file, indicators and time, and the
                  view (or the manager, note, help) shown; the menu,
                  prompts, questions and messages take it over
      lines 2..   body: the view, or a full-screen manager
      last line   function key bar

  Each part is drawn by a module of its own under `Agenda.TUI.Render`:
  `ControlPanel`, `View`, `Managers`, `Note`, `Help`, `Boxes` and
  `CategoryBoxes`, `KeyBar`; `Export` writes a view as plain text.
  """

  alias Agenda.TUI.{Draw, State}
  alias Agenda.TUI.Render.{Boxes, ControlPanel, Help, KeyBar, Managers, Note, View}

  @full_screen [:catmgr, :viewmgr, :help, :note, :devtools]
  @boxes [
    :picker,
    :calendar,
    :datebook_props,
    :schedule,
    :macros,
    :macro_props,
    :select_file,
    :profile,
    :props,
    :choice,
    :item_props,
    :group_profile,
    :scope,
    :sort,
    :search_box,
    :note_search,
    :file_props,
    :date_settings,
    :display_format,
    :input_format,
    :customize,
    :calendars,
    :date_rule,
    :category_match,
    :auto_assign,
    :goto,
    :range_filter,
    :action_box,
    :execute,
    :questions,
    :column_props,
    :column_add,
    :item_column,
    :section_props,
    :numeric_functions,
    :copy_items,
    :alarm_list,
    :choice_list,
    :category_stats
  ]

  @doc "Whether a mode is drawn as a box over the screen."
  @spec box?(map) :: boolean
  def box?(%{type: type}), do: type in @boxes

  @spec render(State.t()) :: [Draw.line()]
  def render(%State{modes: [%{type: :splash} | _]} = state), do: Agenda.TUI.Splash.render(state)

  def render(%State{width: w} = state) do
    {base, overlays} = split_modes(state.modes)
    {styles, fill} = surface(base)
    body = Enum.map(body(state, base), &(&1 |> Draw.paint(styles) |> Draw.line(w, fill)))
    # behind a box, the screen fades (Agenda greys it out)
    body = if overlays == [], do: body, else: Enum.map(body, &Draw.paint(&1, :backdrop))

    # each box knows where the one beneath it starts (`Enum.reduce/3` carries
    # the body and that column along)
    {body, _left} =
      overlays
      |> Enum.with_index()
      |> Enum.reduce({body, nil}, fn {mode, depth}, {body, beneath} ->
        Boxes.overlay(state, mode, depth, depth == length(overlays) - 1, body, beneath)
      end)

    ControlPanel.lines(state, base) ++
      Enum.map(body, &Draw.line(&1, w)) ++
      if(state.key_map, do: [KeyBar.line(state)], else: [])
  end

  # The colours of a full screen: the category manager is cyan, help
  # yellow on blue (Agenda 2.0); the rest is the view's grey.
  defp surface(%{type: :catmgr}),
    do:
      {%{normal: :catmgr, item: :catmgr, dim: :catmgr_note, section: :catmgr_head, edit: :row},
       :catmgr}

  defp surface(%{type: :help}), do: {%{normal: :help}, :help}
  defp surface(_base), do: {%{}, :normal}

  # The base is the topmost full-screen mode (or the view); boxes above it
  # are drawn on top, bottom-up.
  defp split_modes(modes) do
    {above, rest} = Enum.split_while(modes, &(&1.type not in @full_screen))
    base = List.first(rest)
    {base, above |> Enum.filter(&(&1.type in @boxes)) |> Enum.reverse()}
  end

  defp body(state, nil), do: fit(View.lines(state), state)
  defp body(state, %{type: :catmgr} = mode), do: fit(Managers.category_lines(state, mode), state)
  defp body(state, %{type: :viewmgr} = mode), do: fit(Managers.view_lines(state, mode), state)
  defp body(state, %{type: :help} = mode), do: fit(Enum.drop(Help.lines(), mode.top), state)

  defp body(state, %{type: :devtools} = mode) do
    lines =
      state
      |> Agenda.TUI.DevTools.lines(mode)
      |> Enum.map(fn
        "" -> []
        {label, value} -> [{:normal, " " <> Draw.pad(label, 16) <> ": " <> value}]
        heading -> [{:section, " " <> heading}]
      end)

    fit(Enum.drop(lines, mode.top), state)
  end

  defp body(state, %{type: :note} = mode), do: fit(Note.lines(state, mode), state)

  defp fit(lines, state) do
    h = State.body_height(state)
    lines = Enum.take(lines, h)
    lines ++ List.duplicate([], h - length(lines))
  end
end
