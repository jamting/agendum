defmodule Agenda.CLITest do
  @moduledoc "Command-line arguments (R40)."
  use ExUnit.Case, async: true

  alias Agenda.CLI

  test "a file, the demo and help" do
    assert {:ok, %{file: "my.agenda", demo: false, theme: :classic}} =
             CLI.parse_args(["my.agenda"], %{})

    assert {:ok, %{file: nil, demo: true}} = CLI.parse_args(["--demo"], %{})
    assert :help = CLI.parse_args(["--help"], %{})
    assert :help = CLI.parse_args(["-h"], %{})
  end

  test "the theme comes from --theme or --mono" do
    assert {:ok, %{theme: :mono}} = CLI.parse_args(["--theme", "mono", "f"], %{})
    assert {:ok, %{theme: :mono, file: "f"}} = CLI.parse_args(["f", "--mono"], %{})
    assert {:error, message} = CLI.parse_args(["--theme", "pink"], %{})
    assert message =~ "classic, mono"
  end

  test "NO_COLOR forces monochrome unless a theme is given" do
    assert {:ok, %{theme: :mono}} = CLI.parse_args([], %{"NO_COLOR" => "1"})
    assert {:ok, %{theme: :classic}} = CLI.parse_args([], %{"NO_COLOR" => ""})

    assert {:ok, %{theme: :classic}} =
             CLI.parse_args(["--theme", "classic"], %{"NO_COLOR" => "1"})
  end

  test "the date language and a fallback language (R14c)" do
    alias Agenda.Core.DateLanguage.{English, Swedish}

    assert {:ok, %{languages: [English]}} = CLI.parse_args([], %{})
    assert {:ok, %{languages: [Swedish]}} = CLI.parse_args(["--lang=swedish"], %{})

    assert {:ok, %{languages: [Swedish, English], file: "f"}} =
             CLI.parse_args(["--lang", "Swedish", "--fallback=english", "f"], %{})

    # the same language twice counts once
    assert {:ok, %{languages: [English]}} = CLI.parse_args(["--fallback=english"], %{})

    assert {:error, message} = CLI.parse_args(["--lang=klingon"], %{})
    assert message =~ "english, swedish"
    assert {:error, _} = CLI.parse_args(["--fallback=klingon"], %{})
  end

  test "unknown options are refused" do
    assert {:error, message} = CLI.parse_args(["--colour"], %{})
    assert message =~ "--colour"
  end

  test "the input format for this session (R41b)" do
    assert {:ok, %{input: input}} =
             CLI.parse_args(["--number-order=dmy", "--date-separator", ".", "--clock=24"], %{})

    assert input == %{number_order: :dmy, separator: ".", clock: 24}
    assert {:ok, %{input: %{}}} = CLI.parse_args([], %{})
    assert {:error, message} = CLI.parse_args(["--number-order=xyz"], %{})
    assert message =~ "mdy, myd, dmy, dym, ydm, ymd"
    assert {:error, _} = CLI.parse_args(["--clock=13"], %{})
    assert {:error, _} = CLI.parse_args(["--date-separator=x"], %{})
  end

  test "the preferences file comes from the environment" do
    assert {:ok, %{preferences: "/h/.config/agenda/preferences"}} =
             CLI.parse_args([], %{"HOME" => "/h"})
  end
end
