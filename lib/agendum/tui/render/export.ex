defmodule Agendum.TUI.Render.Export do
  @moduledoc """
  The current view as plain text (File Print). Pure.
  """

  alias Agendum.Core.DateFormat
  alias Agendum.TUI.State

  @doc "Plain-text rendering of the whole current view (for File Print)."
  @spec text(State.t()) :: String.t()
  def text(state) do
    view = State.view(state)

    state.db
    |> Agendum.Core.ViewModel.build(view, State.context(state))
    |> Enum.map_join("\n\n", fn section ->
      # each section has its own columns (R55)
      # a Category note column's title stands in for its head's name (R56)
      heads =
        Enum.map(section.columns, fn
          %{format: :note, title: title} when is_binary(title) -> title
          column -> state.db.categories[column.category_id].name
        end)

      header = Enum.join([section.category.name | heads], " | ")

      items =
        Enum.map(section.rows, fn row ->
          # a number's "% tot" (R29) goes after it in brackets
          extra =
            row.cells
            |> Enum.zip_with(row.percents, fn
              cell, p when p in [nil, ""] -> cell
              cell, p -> "#{cell} (#{p})"
            end)
            |> Enum.zip(heads)
            |> Enum.reject(&(elem(&1, 0) == ""))
            |> Enum.map_join("; ", fn {c, h} -> "#{h}: #{c}" end)

          done =
            if row.item.done,
              do: " (done #{DateFormat.date(row.item.done, state.db.date_format)})",
              else: ""

          # Number items (R79): printed too, as Agenda printed them
          number = if row.number, do: "#{row.number} ", else: ""

          "  • " <>
            number <> row.item.text <> done <> if(extra == "", do: "", else: "  [#{extra}]")
        end)

      calcs =
        Enum.map(section.calcs, fn {calc, cells} ->
          results =
            cells
            |> Enum.zip(heads)
            |> Enum.reject(&(elem(&1, 0) == ""))
            |> Enum.map_join("; ", fn {c, h} -> "#{h}: #{c}" end)

          "  #{Agendum.Core.NumberFormat.label(calc)}  [#{results}]"
        end)

      Enum.join([header | items] ++ calcs, "\n")
    end)
    |> Kernel.<>("\n")
  end
end
