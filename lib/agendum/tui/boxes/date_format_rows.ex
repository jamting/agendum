defmodule Agendum.TUI.Boxes.DateFormatRows do
  @moduledoc """
  The Date Column Properties settings (User's Guide 6-19 to 6-22) as rows
  of a box, in Agenda's order: shared by File Properties (the global
  defaults, R41) and a date column's Column Properties (R41a). Pure.
  """

  alias Agendum.Core.DateFormat

  @rows [:show, :day_of_week, :order, :separator, :clock, :am_pm, :time_separator]

  # the same in File Properties and in a date column's Column Properties
  @help %{
    show: "Choose whether to display date, time, or both. SPACE for the next choice.",
    day_of_week: "Choose whether to show the day of the week with the date. SPACE switches.",
    order: "Choose the order of month, day and year in dates. SPACE for the next choice.",
    separator: "Choose the character between the numbers of a date. SPACE for the next.",
    clock: "Choose a 12-hour or a 24-hour clock for times. SPACE switches.",
    am_pm: "Choose whether a 12-hour time shows am or pm. SPACE switches.",
    time_separator: "Choose the character between hours and minutes. SPACE for the next.",
    time_sep: "Choose the character between hours and minutes. SPACE for the next."
  }

  # Agenda hides the time settings for Date only and the date format for
  # Time only, leaving the rows where they stand (checked in Agenda 2.0,
  # 2026-10-25). `time_sep` is `time_separator`, too long for its field
  @date_both """
   Display date and/or time: [show       ]
   Show day of week:         [day_of_week]  Clock:          [clock   ]
   Date format:              [order      ]  Show am/pm:     [am_pm   ]
   Date separator:           [separator  ]  Time separator: [time_sep]
  """

  @date_only """
   Display date and/or time: [show       ]
   Show day of week:         [day_of_week]
   Date format:              [order      ]
   Date separator:           [separator  ]
  """

  @time_only """
   Display date and/or time: [show       ]
   Show day of week:         [day_of_week]  Clock:          [clock   ]
                                            Show am/pm:     [am_pm   ]
                                            Time separator: [time_sep]
  """

  @doc """
  The settings as Agenda lays them out in a date column's Column
  Properties and in Display Format (`Agendum.TUI.Boxes.Template`): only
  those for what `show` displays.
  """
  @spec layout(DateFormat.show()) :: String.t()
  def layout(:date), do: @date_only
  def layout(:time), do: @time_only
  def layout(_date_and_time), do: @date_both

  @doc "A line across the box, as Agenda draws above the date settings."
  def rule, do: " " <> String.duplicate("─", 70) <> "\n"

  @doc "The formatted sample below the settings, centred as Agenda's."
  def sample(%DateFormat{} = f),
    do: [[], centred("Formatted Sample"), centred(DateFormat.sample(f))]

  defp centred(text) do
    left = String.duplicate(" ", div(70 - String.length(text), 2))
    [{:box, String.pad_trailing(left <> text, 70)}]
  end

  @doc "The settings, top to bottom."
  def rows, do: @rows

  @doc "The help for each setting, in the control panel (`Agendum.TUI.Boxes.FieldHelp`)."
  def help, do: @help

  @doc "The value shown for each setting, by its row."
  def values(%DateFormat{} = f) do
    values = @rows |> Enum.zip(lines(f)) |> Map.new(fn {row, {_, v}} -> {row, v} end)
    Map.put(values, :time_sep, values.time_separator)
  end

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
