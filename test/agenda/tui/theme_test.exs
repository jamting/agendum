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
    assert IO.iodata_to_binary(Screen.frame(nil, [line], :classic)) =~ "\e[0;30;47mx"
    assert IO.iodata_to_binary(Screen.frame(nil, [line], :mono)) =~ "\e[0;7mx"
  end

  test "theme names are parsed" do
    assert Theme.parse("mono") == {:ok, :mono}
    assert Theme.parse("CLASSIC") == {:ok, :classic}
    assert Theme.parse("pink") == :error
  end
end
