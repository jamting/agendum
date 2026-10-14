defmodule Agendum.TUI.DateFormatRows do
  @moduledoc """
  The Date Column Properties settings (User's Guide 6-19 to 6-22) as rows
  of a box, in Agenda's order: shared by File Properties (the global
  defaults, R41) and a date column's Column Properties (R41a). Pure.
  """

  alias Agendum.Core.DateFormat

  @rows [:show, :day_of_week, :order, :separator, :clock, :am_pm, :time_separator]

  @doc "The settings, top to bottom."
  def rows, do: @rows

  @doc "`{label, value}` for each row."
  def lines(%DateFormat{} = f) do
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
