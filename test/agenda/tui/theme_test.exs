defmodule Agenda.TUI.ThemeTest do
  @moduledoc "Colour and monochrome themes (R40)."
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.TUI.{Render, Screen, Theme}

  test "every theme defines every style" do
    styles = Theme.styles(:classic)

    for theme <- Theme.names() do
      assert Map.keys(Theme.styles(theme)) == Map.keys(styles), "#{theme} misses styles"
    end
  end

  test "every style the screens use is in the themes" do
    state = start(Agenda.Sample.build(~D[2026-10-08]))

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
    state = start(Agenda.Sample.build(~D[2026-10-08]))
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
    assert IO.iodata_to_binary(Screen.frame(nil, [line], :blue)) =~ "\e[0;30;47mx"

    assert IO.iodata_to_binary(Screen.frame(nil, [line], :classic, :truecolor)) =~
             "\e[0;38;2;255;255;255;48;2;170;0;0mx"

    assert IO.iodata_to_binary(Screen.frame(nil, [line], :mono)) =~ "\e[0;7mx"
  end

  test "theme names are parsed" do
    assert Theme.parse("mono") == {:ok, :mono}
    assert Theme.parse("CLASSIC") == {:ok, :classic}
    assert Theme.parse("blue") == {:ok, :blue}
    assert Theme.parse("pink") == :error
  end
end

defmodule Agenda.TUI.LookTest do
  @moduledoc "How screens are drawn after Agenda 2.0's look (SPEC R40)."
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.TUI.Render

  setup do
    %{state: start(Agenda.Sample.build(~D[2026-10-08]), width: 80, height: 25)}
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
    assert styles_at(help, row_of(help, "AGENDA KEYS"), "AGENDA KEYS") == [:help]
  end

  test "the key bar says more when the screen is wide enough", %{state: state} do
    keybar = fn state -> state |> screen() |> String.split("\n") |> List.last() end

    wide = %{state | width: 140}
    assert keybar.(wide) =~ "F6 Properties  F7 Mark  F8 View manager  F9 Category manager"
    assert keybar.(press(wide, {:f, 9})) =~ "INS/CTRL-N Add a category"

    # 80 columns: Agenda's short labels
    assert keybar.(state) =~ "F6 Props F7 Mark F8 VwMgr F9 CatMgr"
  end
end
