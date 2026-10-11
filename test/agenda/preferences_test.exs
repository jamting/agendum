defmodule Agenda.PreferencesTest do
  @moduledoc "The person's preferences file (ADR 0008): the Input format for now (R41b)."
  use ExUnit.Case, async: true

  alias Agenda.Core.InputFormat
  alias Agenda.Preferences

  @moduletag :tmp_dir

  test "the file lives in the config directory" do
    assert Preferences.path(%{"XDG_CONFIG_HOME" => "/x/config", "HOME" => "/home/me"}) ==
             "/x/config/agenda/preferences"

    assert Preferences.path(%{"HOME" => "/home/me"}) == "/home/me/.config/agenda/preferences"
    assert Preferences.path(%{}) == nil
  end

  test "is plain text, one setting per line" do
    prefs = %Preferences{input: %InputFormat{number_order: :dmy, separator: ".", clock: 24}}
    text = Preferences.format(prefs)
    assert text =~ "number_order = dmy\n"
    assert text =~ "date_separator = .\n"
    assert text =~ "clock = 24\n"
    assert Preferences.parse(text) == prefs
  end

  test "settings left out are the language's; comments, blanks and unknown lines are ignored" do
    text = "# mine\n\nclock = 12\ncolour = pink\nnumber_order = sideways\n"
    assert Preferences.parse(text) == %Preferences{input: %InputFormat{clock: 12}}
    refute Preferences.format(%Preferences{}) =~ "number_order ="
  end

  test "saves and loads; a missing file is the defaults", %{tmp_dir: dir} do
    path = Path.join([dir, "agenda", "preferences"])
    assert Preferences.load(path) == %Preferences{}

    prefs = %Preferences{input: %InputFormat{separator: "-"}}
    assert :ok = Preferences.save(prefs, path)
    assert Preferences.load(path) == prefs
  end
end
