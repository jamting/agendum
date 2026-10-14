defmodule Agendum.PreferencesTest do
  @moduledoc "The person's preferences file (ADR 0008): theme, date languages (R40, R14c) and Input format (R41b)."
  use ExUnit.Case, async: true

  alias Agendum.Core.DateLanguage.{English, Swedish}
  alias Agendum.Core.InputFormat
  alias Agendum.Preferences

  @moduletag :tmp_dir

  test "the file lives in the config directory" do
    assert Preferences.path(%{"XDG_CONFIG_HOME" => "/x/config", "HOME" => "/home/me"}) ==
             "/x/config/agendum/preferences"

    assert Preferences.path(%{"HOME" => "/home/me"}) == "/home/me/.config/agendum/preferences"
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

  test "theme and date languages" do
    prefs = %Preferences{theme: :mono, languages: [Swedish, English]}
    text = Preferences.format(prefs)
    assert text =~ "theme = mono\n"
    assert text =~ "lang = swedish\n"
    assert text =~ "fallback = english\n"
    assert Preferences.parse(text) == prefs

    assert Preferences.parse("lang = Swedish\n").languages == [Swedish]
    assert Preferences.parse("theme = pink\nlang = klingon\n") == %Preferences{}
    # a fallback alone has no main language to fall back from
    assert Preferences.parse("fallback = english\n").languages == []
  end

  test "saves and loads; a missing file is the defaults", %{tmp_dir: dir} do
    path = Path.join([dir, "agendum", "preferences"])
    assert Preferences.load(path) == %Preferences{path: path}

    prefs = %Preferences{input: %InputFormat{separator: "-"}}
    assert :ok = Preferences.save(prefs, path)
    assert Preferences.load(path) == %{prefs | path: path}
  end

  test "preferences from before the rename are read, and saved in the new place",
       %{tmp_dir: dir} do
    old = Path.join([dir, "agenda", "preferences"])
    :ok = Preferences.save(%Preferences{theme: :mono}, old)

    path = Path.join([dir, "agendum", "preferences"])
    assert Preferences.load(path) == %Preferences{theme: :mono, path: path}
  end

  test "the name and company for the splash screen, and the last file used" do
    prefs = %Preferences{
      name: "Rabbit",
      company: "Friends and Relations",
      last_file: "/home/rabbit/rabbit.agendum"
    }

    text = Preferences.format(prefs)
    assert text =~ "name = Rabbit\n"
    assert text =~ "last_file = /home/rabbit/rabbit.agendum\n"
    assert Preferences.parse(text) == prefs
    # the login name and where they are kept are not written
    refute Preferences.format(%{prefs | user: "rabbit", path: "/p"}) =~ "user"
  end

  test "the key map is shown unless the person says no" do
    assert Preferences.parse("").key_map
    refute Preferences.format(%Preferences{}) =~ "key_map ="
    text = Preferences.format(%Preferences{key_map: false})
    assert text =~ "key_map = no\n"
    refute Preferences.parse(text).key_map
    assert Preferences.parse("key_map = yes").key_map
  end

  test "Confirm mode is on unless the person says no" do
    assert Preferences.parse("").confirm
    text = Preferences.format(%Preferences{confirm: false})
    assert text =~ "confirm = no\n"
    refute Preferences.parse(text).confirm
  end

  test "the auto-save interval, 0 (off) to 60 minutes" do
    assert Preferences.parse("").auto_save == 0
    text = Preferences.format(%Preferences{auto_save: 10})
    assert text =~ "auto_save = 10\n"
    assert Preferences.parse(text).auto_save == 10
    assert Preferences.parse("auto_save = 61").auto_save == 0
    assert Preferences.parse("auto_save = soon").auto_save == 0
  end

  test "the decimal and thousands separators" do
    prefs = %Preferences{input: %InputFormat{decimal: ",", thousands: " "}}
    text = Preferences.format(prefs)
    assert text =~ "decimal_separator = ,\n"
    assert text =~ "thousands_separator = space\n"
    assert Preferences.parse(text).input == prefs.input
    assert Preferences.parse("decimal_separator = ;").input.decimal == nil
  end
end
