defmodule Agendum.TUI.HelpCoverageTest do
  @moduledoc """
  Every place and box has its F1 text (R65; meeting 2026-10-22-3, § 5):
  a new kind of mode cannot arrive without saying what F1 shows there.
  """
  use ExUnit.Case, async: true

  alias Agendum.TUI.{Boxes.Box, HelpScreen, Modes}

  # Modes that are neither a place nor a box, and why F1 there shows the
  # general text ("Press c for the commands …"): the help itself, the
  # hidden developer screen, the splash screen (any key ends it), and a
  # prompt, whose question is its own help.
  @general [:help, :devtools, :splash, :prompt]

  # Boxes whose F1 text is made from their title and the highlighted
  # setting's help (`Box.default_about/3`), which is enough for them so
  # far. A new box writes its own `about/2` or joins this list on purpose.
  @default_about_enough [
    Agendum.TUI.Boxes.AbandonBox,
    Agendum.TUI.Boxes.ErrorBox,
    Agendum.TUI.Boxes.NewFileBox,
    Agendum.TUI.Boxes.PasswordBox,
    Agendum.TUI.Boxes.UndiscardBox,
    Agendum.TUI.Boxes.FindTopicBox,
    Agendum.TUI.Boxes.SelectHelpScreenBox,
    Agendum.TUI.Boxes.ActionBox,
    Agendum.TUI.Boxes.AutoAssignBox,
    Agendum.TUI.Boxes.CategoryMatchBox,
    Agendum.TUI.Boxes.CategoryStatsBox,
    Agendum.TUI.Boxes.ChoiceListBox,
    Agendum.TUI.Boxes.ColumnAddBox,
    Agendum.TUI.Boxes.ColumnBox,
    Agendum.TUI.Boxes.CustomizeBox,
    Agendum.TUI.Boxes.DateRuleBox,
    Agendum.TUI.Boxes.DateSettingsBox,
    Agendum.TUI.Boxes.DisplayFormatBox,
    Agendum.TUI.Boxes.ExecuteBox,
    Agendum.TUI.Boxes.FileProperties,
    Agendum.TUI.Boxes.FileStatsBox,
    Agendum.TUI.Boxes.InputFormatBox,
    Agendum.TUI.Boxes.ItemColumnBox,
    Agendum.TUI.Boxes.MacroProps,
    Agendum.TUI.Boxes.NumericFunctionsBox,
    Agendum.TUI.Boxes.RangeFilterBox,
    Agendum.TUI.Boxes.ScheduleBox,
    Agendum.TUI.Boxes.SearchBox,
    Agendum.TUI.Boxes.SetAlarmBox,
    Agendum.TUI.Boxes.SectionBox,
    Agendum.TUI.Boxes.SortBox,
    Agendum.TUI.Boxes.ViewManager,
    Agendum.TUI.Boxes.ViewStatsBox,
    Agendum.TUI.CategoryScreens.Choices,
    Agendum.TUI.CategoryScreens.Properties,
    Agendum.TUI.Typing.NoteSearch
  ]

  test "every kind of mode is a place, a box, or one of the general ones" do
    boxes = Map.keys(Box.registry())

    unknown =
      Enum.reject(Modes.types(), &(&1 in HelpScreen.places() or &1 in boxes or &1 in @general))

    assert unknown == [], "No F1 text for: #{inspect(unknown)}"
  end

  test "every place has a text of its own" do
    for place <- HelpScreen.places() do
      text = HelpScreen.about(%{}, place)
      assert is_binary(text) and String.length(text) > 40, inspect(place)
    end
  end

  test "every box writes its own F1 text, or is listed as needing none" do
    without =
      Box.registry()
      |> Map.values()
      |> Enum.uniq()
      |> Enum.reject(&own_about?/1)
      |> Enum.sort()

    assert without -- @default_about_enough == [],
           "Write about/2 for these boxes, or list them in @default_about_enough"

    assert @default_about_enough -- without == [],
           "These boxes have their own about/2 now: take them off the list"
  end

  # Whether the module defines `about/2` itself, rather than taking the
  # `nil` the `use Box` default gives (`Box.__using__/1`): read from the
  # module's source, as the default is compiled into every box alike.
  defp own_about?(module) do
    source = module.module_info(:compile)[:source] |> to_string() |> File.read!()
    source =~ ~r/^\s*def about\(/m
  end
end
