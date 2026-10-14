defmodule Agendum.TUI.Boxes.DateFormatRows do
  @moduledoc """
  The Date Column Properties settings (User's Guide 6-19 to 6-22) as rows
  of a box, in Agenda's order: shared by File Properties (the global
  defaults, R41) and a date column's Column Properties (R41a). Pure.
  """

  alias Agendum.Core.DateFormat

  @rows [:show, :day_of_week, :order, :separator, :clock, :am_pm, :time_separator]

  # the same in File Properties and in a date column's Column Properties,
  # whose Settings switches between the global defaults and its own
  @help %{
    settings:
      "Global defaults uses the file's date format; any change gives the column its own. " <>
        "SPACE goes back to the global defaults.",
    show: "Choose whether to display date, time, or both. SPACE for the next choice.",
    day_of_week: "Choose whether to show the day of the week with the date. SPACE switches.",
    order: "Choose the order of month, day and year in dates. SPACE for the next choice.",
    separator: "Choose the character between the numbers of a date. SPACE for the next.",
    clock: "Choose a 12-hour or a 24-hour clock for times. SPACE switches.",
    am_pm: "Choose whether a 12-hour time shows am or pm. SPACE switches.",
    time_separator: "Choose the character between hours and minutes. SPACE for the next.",
    time_sep: "Choose the character between hours and minutes. SPACE for the next."
  }

  @doc "The settings, top to bottom."
  def rows, do: @rows

  @doc "The help for each setting, in the control panel (`Agendum.TUI.Boxes.FieldHelp`)."
  def help, do: @help

  @doc "The value shown for each setting, by its row."
  def values(%DateFormat{} = f),
    do: @rows |> Enum.zip(lines(f)) |> Map.new(fn {row, {_, v}} -> {row, v} end)

  # `{label, value}` for each row, in the rows' order
  defp lines(%DateFormat{} = f) do
    yes_no = &if(&1, do: "Yes", else: "No")

    [
      {"Display date/time", DateFormat.show_label(f.show)},
      {"Show day of week", yes_no.(f.day_of_week)},
      {"Date format", DateFormat.label(f.order)},
      {"Date separator", if(f.separator == " ", do: "(space)", else: f.separator)},
      {"Clock", "#{f.clock} hr"},
      {"Show am/pm", yes_no.(f.am_pm)},
      {"Time separator", f.time_separator}
    ]
  end
end
