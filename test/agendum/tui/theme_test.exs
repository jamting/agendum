defmodule Agendum.TUI.ThemeTest do
  @moduledoc "Colour and monochrome themes (R40)."
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.TUI.{Render, Screen, Theme}

  test "every theme defines every style" do
    styles = Theme.styles(:classic)

    for theme <- Theme.names() do
      assert Map.keys(Theme.styles(theme)) == Map.keys(styles), "#{theme} misses styles"
    end
  end

  test "every style the screens use is in the themes" do
    state = start(Agendum.Sample.build(~D[2026-10-08]))

    screens = [
      state,
      press(state, {:f, 10}),
      press(state, {:f, 1}),
      press(state, {:f, 9}),
      press(state, [:down, {:f, 6}]),
      press(state, [:down, {:f, 5}, {:alt_f, 6}]),
      press(state, "new item"),
      press(state, [{:alt_f, 6}, "zebra", :enter])
    ]

    used = for s <- screens, line <- Render.render(s), {style, _} <- line, uniq: true, do: style
    assert used -- Map.keys(Theme.styles(:classic)) == []
  end

  test "every style the boxes and full screens use is in the themes" do
    state = start(Agendum.Sample.build(~D[2026-10-08]))
    screens = [press(state, [{:f, 9}, :down, {:f, 6}]), press(state, [:down, :right, {:f, 3}])]
    used = for s <- screens, line <- Render.render(s), {style, _} <- line, uniq: true, do: style
    assert used -- Map.keys(Theme.styles(:classic)) == []
  end

  test "the classic theme is Agenda's: grey screen, white on red highlight, cyan boxes" do
    sgr = &Theme.sgr(&1, :classic)
    assert sgr.(:item) == "\e[0;30;47m"
    assert sgr.(:cursor) == "\e[0;97;41m"
    assert sgr.(:section) == "\e[0;34;47m"
    assert sgr.(:box) == "\e[0;30;46m"
    assert sgr.(:title) == "\e[0;97;44m"
  end

  test "a terminal taking 24-bit colour gets the VGA colours exactly" do
    assert Theme.depth("truecolor") == :truecolor
    assert Theme.depth("24bit") == :truecolor
    assert Theme.depth(nil) == :ansi16
    assert Theme.sgr(:item, :classic, :truecolor) == "\e[0;38;2;0;0;0;48;2;170;170;170m"
    # themes made of SGR codes stay as they are
    assert Theme.sgr(:item, :mono, :truecolor) == "\e[0m"
  end

  test "the monochrome theme uses no colours" do
    for {style, codes} <- Theme.styles(:mono), code <- String.split(codes, ";") do
      code = String.to_integer(code)
      refute code in 30..49 or code in 90..107, "#{style} uses colour #{code}"
    end
  end

  test "every theme shows the highlighted line, active box titles and the panel" do
    for theme <- Theme.names() do
      t = Theme.styles(theme)
      refute t.row == t.item, "#{theme}: the highlighted line looks like the others"
      refute t.row_cell == t.cell, "#{theme}: the highlighted line's entries"
      refute t.box_title == t.box_title_dim, "#{theme}: dimmed box titles"
      refute t.box_title == t.box, "#{theme}: box titles look like the box"
      refute t.backdrop == t.item, "#{theme}: the screen behind a box does not fade"
      # the two top lines are one panel, whatever they show
      assert t.panel == t.title, "#{theme}: the control panel changes colour"
      assert t.menu_help == t.menu, "#{theme}: the menu's second line"
      refute t.error == t.message, "#{theme}: errors look like messages"
    end
  end

  test "the monochrome theme keeps the highlighted things apart from the rest" do
    mono = Theme.styles(:mono)
    refute mono.cursor == mono.item
    refute mono.menu_selected == mono.menu
    refute mono.box_selected == mono.box
    refute mono.edit_cursor == mono.edit
    refute mono.error == mono.message
  end

  test "a screen is encoded with the chosen theme" do
    line = [{:cursor, "x"}]
    assert IO.iodata_to_binary(Screen.frame(nil, [line], :classic)) =~ "\e[0;97;41mx"

    assert IO.iodata_to_binary(Screen.frame(nil, [line], :classic, :truecolor)) =~
             "\e[0;38;2;255;255;255;48;2;170;0;0mx"

    assert IO.iodata_to_binary(Screen.frame(nil, [line], :mono)) =~ "\e[0;7mx"
  end

  test "the terminal schemes draw their own colours exactly on 24-bit terminals" do
    assert Theme.sgr(:item, :modus_vivendi, :truecolor) == "\e[0;38;2;255;255;255;48;2;0;0;0m"
    assert Theme.sgr(:section, :zenburn, :truecolor) == "\e[0;1;38;2;148;191;243;48;2;63;63;63m"
    # the highlight is the scheme's cursor
    assert Theme.sgr(:cursor, :ayu, :truecolor) == "\e[0;38;2;11;14;20;48;2;230;180;80m"
  end

  test "on 16 colours the schemes use the terminal's own ANSI colours and defaults" do
    # the screen is the terminal's default colours, so it matches its scheme
    assert Theme.sgr(:item, :alabaster) == "\e[0;39;49m"
    assert Theme.sgr(:section, :modus_operandi) == "\e[0;1;34;49m"
    # errors: the screen's colour on the scheme's red
    assert Theme.sgr(:error, :ayu) == "\e[0;1;7;31;49m"
  end

  test "theme names are shown and typed with spaces or dashes" do
    assert Theme.label(:modus_operandi) == "Modus Operandi"
    assert Theme.label(:classic) == "Classic"
    assert Theme.parse("modus-vivendi") == {:ok, :modus_vivendi}
    assert Theme.parse("Modus Operandi") == {:ok, :modus_operandi}
    assert Theme.parse("zenburn") == {:ok, :zenburn}

    for theme <- Theme.names() do
      assert theme |> Theme.label() |> Theme.parse() == {:ok, theme}
    end
  end

  test "theme names are parsed" do
    assert Theme.parse("mono") == {:ok, :mono}
    assert Theme.parse("CLASSIC") == {:ok, :classic}
    assert Theme.parse("borland") == {:ok, :borland}
    # the old blue theme is gone: a preference for it falls back to the default
    assert Theme.parse("blue") == :error
    assert Theme.parse("pink") == :error
  end
end

defmodule Agendum.TUI.LookTest do
  @moduledoc "How screens are drawn after Agenda 2.0's look (SPEC R40)."
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.TUI.Render

  setup do
    %{state: start(Agendum.Sample.build(~D[2026-10-08]), width: 80, height: 25)}
  end

  defp styles_at(state, row, text) do
    line = Enum.at(Render.render(state), row)
    col = line |> Enum.map_join(&elem(&1, 1)) |> :binary.match(text) |> elem(0)
    styles_of(line, col, String.length(text))
  end

  # the styles of the columns col..col+len-1
  defp styles_of(line, col, len) do
    line
    |> Enum.flat_map(fn {style, text} -> List.duplicate(style, String.length(text)) end)
    |> Enum.slice(col, len)
    |> Enum.uniq()
  end

  defp row_of(state, text),
    do:
      state
      |> Render.render()
      |> Enum.find_index(&(Enum.map_join(&1, fn {_, t} -> t end) =~ text))

  test "a box has its title centred in its frame", %{state: state} do
    state = press(state, [:down, {:f, 6}])
    top = Enum.at(Render.render(state), 2 + 1)
    assert {:box_title, " Item properties "} in top

    [{:box_frame, left}, _, {:box_frame, right}] =
      Enum.filter(top, &(elem(&1, 0) in [:box_frame, :box_title]))

    assert abs(String.length(left) - String.length(right)) <= 1
  end

  test "behind a box the screen fades, and the box casts a shadow", %{state: state} do
    state = press(state, [:down, {:f, 6}])
    styles = for line <- Render.render(state), {style, _} <- line, uniq: true, do: style
    assert :backdrop in styles
    assert :shadow in styles
    # nothing of the view keeps its own colours
    refute :item in styles
    refute :cell in styles
  end

  test "the highlighted line is tinted across the screen", %{state: state} do
    state = press(state, [:down, :right])
    row = row_of(state, "Set up meeting")
    assert styles_at(state, row, "Set up meeting") == [:row]
    assert styles_at(state, row, "Medium") == [:row_cell]
    line = Enum.at(Render.render(state), row)
    refute Enum.any?(line, &(elem(&1, 0) in [:normal, :item, :cell, :symbol]))
    other = row_of(state, "Contact Daniel")
    assert styles_at(state, other, "Contact Daniel") == [:item]
  end

  test "the category manager is drawn on its own colour, help in its", %{state: state} do
    catmgr = press(state, {:f, 9})
    assert styles_at(catmgr, row_of(catmgr, "Meetings"), "Meetings") == [:catmgr]
    help = press(state, {:f, 1})
    assert styles_at(help, row_of(help, "AGENDUM KEYS"), "AGENDUM KEYS") == [:help]
  end

  test "the key bar says more when the screen is wide enough", %{state: state} do
    keybar = fn state -> state |> screen() |> String.split("\n") |> List.last() end

    wide = %{state | width: 140}
    assert keybar.(wide) =~ "F6 Properties  F7 Mark  F8 View manager  F9 Category manager"
    assert keybar.(press(wide, {:f, 9})) =~ "INS/CTRL-N Add a category"

    # 80 columns: Agenda's short labels
    assert keybar.(state) =~ "F6 Props F7 Mark F8 VwMgr F9 CatMgr"
  end

  test "a box opened from a box sits a line lower and two columns right", %{state: state} do
    corners = fn state ->
      state
      |> screen()
      |> String.split("\n")
      |> Enum.with_index()
      |> Enum.flat_map(fn {line, row} ->
        case :binary.match(line, "┌") do
          {byte, _} -> [{row, String.length(binary_part(line, 0, byte))}]
          :nomatch -> []
        end
      end)
    end

    props = press(state, [{:f, 9}, :down, :down, :down, :down, {:f, 6}])
    assert [{row, col}] = corners.(props)

    type_box = press(props, [:right, " "])
    assert %{type: :choice} = Agendum.TUI.State.mode(type_box)
    assert [{^row, ^col}, {lower, right}] = corners.(type_box)
    assert {lower, right} == {row + 1, col + 2}
  end

  test "a shadow on a box beneath hides its frame's lines" do
    line = [{:box_frame, "│"}, {:box, " text "}, {:box_frame, "│"}]
    [_, shaded] = Agendum.TUI.Draw.shadow([[], line], 0, 0, 2, 6)
    # the two columns right of a 6-wide box: the last space, and the frame
    assert shaded == [{:box_frame, "│"}, {:box, " text"}, {:shadow, " "}, {:shadow, " "}]
  end

  test "the titles of boxes beneath the active one are dimmed", %{state: state} do
    titles = fn state ->
      for line <- Render.render(state),
          {style, text} <- line,
          style in [:box_title, :box_title_dim],
          # the bottom edge's "Press ENTER when done, ESC to cancel" is not a title
          not String.contains?(text, "ESC"),
          do: {style, String.trim(text)}
    end

    props = press(state, [{:f, 9}, :down, :down, :down, :down, {:f, 6}])
    assert titles.(props) == [{:box_title, "Category properties: Calls"}]

    nested = press(props, [:right, " "])

    assert titles.(nested) == [
             {:box_title_dim, "Category properties: Calls"},
             {:box_title, "Category type: Calls"}
           ]
  end
end
