defmodule Agenda.TUI.Render.Export do
  @moduledoc """
  The current view as plain text (File Print). Pure.
  """

  alias Agenda.Core.DateFormat
  alias Agenda.TUI.State

  @doc "Plain-text rendering of the whole current view (for File Print)."
  @spec text(State.t()) :: String.t()
  def text(state) do
    view = State.view(state)

    state.db
    |> Agenda.Core.ViewModel.build(view, State.context(state))
    |> Enum.map_join("\n\n", fn section ->
      # each section has its own columns (R55)
      heads = Enum.map(section.columns, &state.db.categories[&1.category_id].name)
      header = Enum.join([section.category.name | heads], " | ")

      items =
        Enum.map(section.rows, fn row ->
          extra =
            row.cells
            |> Enum.zip(heads)
            |> Enum.reject(&(elem(&1, 0) == ""))
            |> Enum.map_join("; ", fn {c, h} -> "#{h}: #{c}" end)

          done =
            if row.item.done,
              do: " (done #{DateFormat.date(row.item.done, state.db.date_format)})",
              else: ""

          "  • " <> row.item.text <> done <> if(extra == "", do: "", else: "  [#{extra}]")
        end)

      calcs =
        Enum.map(section.calcs, fn {calc, cells} ->
          results =
            cells
            |> Enum.zip(heads)
            |> Enum.reject(&(elem(&1, 0) == ""))
            |> Enum.map_join("; ", fn {c, h} -> "#{h}: #{c}" end)

          "  #{Agenda.Core.NumberFormat.label(calc)}  [#{results}]"
        end)

      Enum.join([header | items] ++ calcs, "\n")
    end)
    |> Kernel.<>("\n")
  end
end
