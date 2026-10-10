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

  test "unknown options are refused" do
    assert {:error, message} = CLI.parse_args(["--colour"], %{})
    assert message =~ "--colour"
  end
end
