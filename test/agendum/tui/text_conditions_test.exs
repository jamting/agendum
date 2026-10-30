# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.TextConditionsTest do
  @moduledoc "Also match in Category Properties (R15d) and text matches that break (R15c)."
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core.Database

  setup do
    %{state: start(Agendum.Sample.build(~D[2026-10-08]))}
  end

  defp meetings(state), do: hd(Database.find_categories(state.db, "Meetings"))
  defp item(state, text), do: Enum.find(Database.items(state.db), &(&1.text == text))

  test "Also match is set in Category Properties and pulls items in", %{state: state} do
    # Meetings is the last category
    state =
      state
      |> press([{:f, 9}, :ctrl_end, {:f, 6}])
      |> to_setting("Also match")
      |> press([" ", "meet;(talk to)", :enter])

    assert state.db.categories[meetings(state)].also_match == "meet;(talk to)"
    assert screen(state) =~ ~r/Also match: +meet;\(talk to\)/

    state = press(state, [:enter, :esc, "Talk to Sue about the budget", :enter])
    item = item(state, "Talk to Sue about the budget")
    assert Database.member?(state.db, item.id, meetings(state))

    # editing the text so it no longer matches lets it go (R15c)
    state = press(state, [{:f, 2}, {:ctrl, "u"}, "Email Sue about the budget", :enter])
    refute Database.member?(state.db, item.id, meetings(state))
  end

  test "Item Properties marks text matches as conditional", %{state: state} do
    # "Don't forget to call Anna Lasky…" is assigned to Anna Lasky by its name
    state = press(state, [:down, :down, {:f, 6}])
    assert screen(state) =~ "Anna Lasky (c)"
  end
end
