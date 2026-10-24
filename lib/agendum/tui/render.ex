defmodule Agendum.TUI.Render do
  @moduledoc """
  Turns a `State` into a screen (a list of styled lines). Pure.

  Screen layout, after Agenda 2.0:

      lines 0–1   control panel: the file, indicators and time, and the
                  view (or the manager, note, help) shown; the menu,
                  prompts, questions and messages take it over
      lines 2..   body: the view, or a full-screen manager
      last two    function key bar (R80)

  Each part is drawn by a module of its own under `Agendum.TUI.Render`:
  `ControlPanel`, `View`, `Managers`, `Note`, `Boxes`, `KeyBar` (the help
  screen's pages come from `Agendum.TUI.HelpScreen`);
  `Export` writes a view as plain text.
  """

  alias Agendum.TUI.{Terminal.Draw, State}
  alias Agendum.TUI.Render.{Boxes, ControlPanel, KeyBar, Managers, Note, View}

  @full_screen [:catmgr, :help, :note, :devtools]
  @doc "Whether a mode is drawn as a box over the screen."
  @spec box?(map) :: boolean
  def box?(%{type: type}),
    do: is_map_key(Agendum.TUI.Boxes.Box.registry(), type)

  # A screen is a list of lines; a line is a list of `{style, text}` pieces
  # (`Draw.line()`), such as `[{:normal, " Call Anna"}, {:dim, "Fri"}]`.
  # Styles are names; colours come only when `Terminal.Screen` turns the
  # lines into terminal output with the theme. So a test can compare text,
  # and `Render` knows nothing of colours or the terminal.
  @spec render(State.t()) :: [Draw.line()]
  def render(%State{modes: [%{type: :splash} | _]} = state), do: Agendum.TUI.Splash.render(state)

  def render(%State{width: w} = state) do
    {base, _overlays} = split_modes(state.modes)

    ControlPanel.lines(state, base) ++
      Enum.map(screen_body(state), &Draw.line(&1, w)) ++
      if(state.key_map, do: KeyBar.lines(state), else: [])
  end

  # the body: the full screen (or the view), and the boxes over it
  defp screen_body(state) do
    {base, overlays} = split_modes(state.modes)
    body = painted_body(state, base)
    # behind a box, the screen fades (Agenda greys it out)
    body = if overlays == [], do: body, else: Enum.map(body, &fade/1)

    # each box knows where the one beneath it starts (`Enum.reduce/3` carries
    # the body and that column along)
    # `Enum.reduce/3` is the loop: the accumulator is a tuple of two values,
    # taken apart in the `fn`'s second argument and built again by
    # `Boxes.overlay/6`, which returns `{body, left}`.
    {body, _left} =
      overlays
      |> Enum.with_index()
      |> Enum.reduce({body, nil}, fn {mode, depth}, {body, beneath} ->
        Boxes.overlay(state, mode, depth, depth == length(overlays) - 1, body, beneath)
      end)

    body
  end

  # The body of the full screen (or the view), in its colours. The help is
  # a box over the screen it was opened from, which fades behind it as
  # behind any box (R65c): opening help changes less of what is seen.
  defp painted_body(state, %{type: :help} = help) do
    # what F1 was pressed over, boxes and all
    under = %{state | modes: tl(Enum.drop_while(state.modes, &(&1 != help)))}
    beneath = under |> screen_body() |> Enum.map(&fade/1)
    {inner_w, inner_h} = Agendum.TUI.HelpScreen.size(state)
    {styles, fill} = surface(help)

    content =
      state
      |> Agendum.TUI.HelpScreen.lines(help)
      |> Enum.take(inner_h)
      |> then(&(&1 ++ List.duplicate([], inner_h - length(&1))))
      |> Enum.map(&(&1 |> Draw.paint(styles) |> Draw.line(inner_w, fill)))

    box =
      "Help"
      |> Draw.box(content, inner_w)
      |> Enum.map(&Draw.paint(&1, %{box_frame: :help_frame, box_title: :help_title}))

    top = div(State.body_height(state) - inner_h - 2, 2)
    left = div(state.width - inner_w - 2, 2)

    beneath
    |> Draw.overlay(box, top, left)
    |> Draw.shadow(top, left, inner_h + 2, inner_w + 2)
  end

  defp painted_body(state, base) do
    {styles, fill} = surface(base)
    Enum.map(body(state, base), &(&1 |> Draw.paint(styles) |> Draw.line(state.width, fill)))
  end

  # Everything fades but a note's search match: Search/Replace's question
  # asks about it, so it stays highlighted behind the box.
  defp fade(line) do
    Enum.map(line, fn
      {:note_match, _text} = match -> match
      {_style, text} -> {:backdrop, text}
    end)
  end

  # The colours of a full screen: the category manager is cyan, help
  # yellow on blue (Agenda 2.0); the rest is the view's grey.
  defp surface(%{type: :catmgr}),
    do:
      {%{normal: :catmgr, item: :catmgr, dim: :catmgr_note, section: :catmgr_head, edit: :row},
       :catmgr}

  defp surface(%{type: :help}), do: {%{normal: :help, dim: :help_dim}, :help}
  defp surface(_base), do: {%{}, :normal}

  # The base is the topmost full-screen mode (or the view); boxes above it
  # are drawn on top, bottom-up.
  @doc "The full screen the boxes are drawn over (nil: the view)."
  @spec base([map]) :: map | nil
  def base(modes), do: Enum.find(modes, &(&1.type in @full_screen))

  # Domain: the mode stack drawn from the bottom up. Full screens (the
  # category manager, help, a note) replace the view; boxes above the
  # nearest full screen are drawn over it, each over the one before.
  # `&(&1.type …)` is a short anonymous function; `&1` its argument.
  defp split_modes(modes) do
    {above, rest} = Enum.split_while(modes, &(&1.type not in @full_screen))
    base = List.first(rest)
    {base, above |> Enum.filter(&box?/1) |> Enum.reverse()}
  end

  defp body(state, nil), do: fit(View.lines(state), state)
  defp body(state, %{type: :catmgr} = mode), do: fit(Managers.category_lines(state, mode), state)

  defp body(state, %{type: :devtools} = mode) do
    lines =
      state
      |> Agendum.TUI.DevTools.lines(mode)
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
