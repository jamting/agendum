# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.StateSplitTest do
  @moduledoc """
  The TUI state's fields are the file's or the session's (see
  `Agendum.TUI.State`): a new field must be put in one of them.
  """
  use ExUnit.Case, async: true

  alias Agendum.TUI.State

  test "every field is the file's or the session's, never both" do
    fields = %State{} |> Map.from_struct() |> Map.keys() |> MapSet.new()
    file = MapSet.new(State.file_fields())
    session = MapSet.new(State.session_fields())

    assert MapSet.subset?(file, fields), "file_fields names a field State does not have"
    assert MapSet.disjoint?(file, session)
    assert MapSet.union(file, session) == fields
  end

  test "the database is the file's; where the person is, and their undo, the session's" do
    assert :db in State.file_fields()

    assert Enum.all?(
             [:view_id, :cursor, :modes, :edit, :history, :prefs],
             &(&1 in State.session_fields())
           )
  end
end
