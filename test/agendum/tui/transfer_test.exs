defmodule Agendum.TUI.TransferTest do
  @moduledoc """
  File ▸ Transfer: writing the whole file as JSON and opening a JSON file
  (R44). The shell reads and writes; these tests check the effects.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core.{InputFormat, JSONFile}
  alias Agendum.TUI.Update

  setup do
    %{state: start(Agendum.Sample.build(~D[2026-10-08]))}
  end

  defp submit(state, keys) do
    state = press(state, keys)
    Update.handle(state, :enter)
  end

  test "Export asks for a name and writes the whole file as JSON", %{state: state} do
    state = press(state, [{:f, 10}, "f", "t", "e"])
    assert screen(state) =~ "Export to JSON file:"
    assert screen(state) =~ "agendum.json"

    {_state, effects} = submit(state, [{:ctrl, "u"} | String.graphemes("~/backup.json")])
    assert [{:write_text, path, text}] = effects
    assert path == Path.expand("~/backup.json")
    assert JSONFile.decode(text) == {:ok, state.db}
  end

  test "the name offered follows the file's name", %{state: state} do
    state = %{state | path: "/work/plans.agenda"}
    assert screen(press(state, [{:f, 10}, "f", "t", "e"])) =~ "/work/plans.json"
  end

  test "Import reads a JSON file and opens it as a new, untitled file", %{state: state} do
    {state, effects} =
      submit(press(state, [{:f, 10}, "f", "t", "i"]), String.graphemes("/tmp/in.json"))

    assert effects == [{:import_json, "/tmp/in.json"}]

    db = Agendum.Core.new_file()
    state = Update.imported(state, "/tmp/in.json", {:ok, JSONFile.encode(db)})
    assert state.db == db
    assert state.path == nil
    assert state.dirty
    assert screen(state) =~ "Imported in.json"
  end

  test "an import that fails says why and keeps the open file", %{state: state} do
    db = state.db

    state =
      Update.imported(state, "/tmp/x.json", {:ok, ~s({"format": "agenda-json", "version": 7})})

    assert state.db == db
    assert screen(state) =~ "Could not import x.json: unsupported version 7"

    state = Update.imported(state, "/tmp/x.json", {:error, :enoent})
    assert screen(state) =~ "File not found"
  end

  test "opening another file keeps the person's session settings", %{state: state} do
    state = %{
      Agendum.TUI.State.put_reader(state, input: %InputFormat{clock: 24})
      | theme: :mono,
        prefs: %Agendum.Preferences{theme: :mono, path: "/prefs"}
    }

    for next <- [
          Update.imported(state, "/x.json", {:ok, JSONFile.encode(state.db)}),
          Update.loaded(state, "/x.agenda", {:ok, state.db, "stamp"})
        ] do
      # only the last file used changes (R52)
      assert {next.theme, Agendum.TUI.State.input(next), %{next.prefs | last_file: nil}} ==
               {state.theme, Agendum.TUI.State.input(state), state.prefs}
    end
  end
end
