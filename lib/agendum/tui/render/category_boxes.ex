defmodule Agendum.TUI.Render.CategoryBoxes do
  @moduledoc """
  The choice boxes. Pure.
  """

  alias Agendum.TUI.CategoryScreens.Choices

  @doc "The content of a choice box."
  def content(_state, %{type: :choice} = mode, _inner, _max_rows) do
    options = Choices.choice_options(mode)
    [problem, question] = Choices.choice_lines(mode)
    {_, description, _} = Enum.at(options, mode.cursor)

    choices =
      options
      |> Enum.with_index()
      |> Enum.map(fn {{label, _, _}, i} ->
        [{:box, "   "}, {if(i == mode.cursor, do: :box_selected, else: :box), " #{label} "}]
      end)

    [[{:box, " " <> problem}], [], [{:box, " " <> question}]] ++
      choices ++ [[], [{:box, " " <> description}]]
  end
end
