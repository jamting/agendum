defmodule Agenda.TUI.SelectFileTest do
  @moduledoc "The Select File box (R51): picking a file from a list instead of typing its name."
  use ExUnit.Case, async: true

  import Agenda.TUIHelpers
  alias Agenda.Store
  alias Agenda.TUI.{State, Update}

  @moduletag :tmp_dir

  setup %{tmp_dir: dir} do
    File.mkdir_p!(Path.join(dir, "Garden"))
    File.write!(Path.join(dir, "Garden/carrots.agendum"), "")
    File.write!(Path.join(dir, "rabbit.agendum"), "")
    File.write!(Path.join(dir, "old.agenda"), "")
    File.write!(Path.join(dir, "notes.txt"), "")
    File.write!(Path.join(dir, "export.json"), "")

    state = start(Agenda.Sample.build(~D[2026-10-08]), width: 100, height: 30)
    %{state: %{state | path: Path.join(dir, "here.agendum")}, dir: dir}
  end

  # the shell's part: reads the folder the box asks for
  defp serve(state) do
    case State.mode(state) do
      %{type: :select_file, entries: :reading, dir: dir} ->
        Update.dir_listed(state, dir, Store.list_dir(dir))

      _ ->
        state
    end
  end

  defp rows(state),
    do: state |> State.mode() |> Agenda.TUI.SelectFile.rows() |> Enum.map(& &1.name)

  test "F3 in File ▸ Retrieve lists the file's folder: up, folders, Agendum files", %{
    state: state,
    dir: dir
  } do
    state = press(state, [{:ctrl, "o"}])
    assert panel(state) =~ "F3 lists files"

    state = state |> press({:f, 3}) |> serve()
    assert %{type: :select_file, dir: ^dir} = State.mode(state)
    assert rows(state) == ["..", "Garden", "old.agenda", "rabbit.agendum"]
    assert screen(state) =~ "Garden/"
  end

  test "ENTER opens a folder, .. goes up; a file goes into the prompt", %{state: state, dir: dir} do
    state = press(state, [{:ctrl, "o"}, {:f, 3}]) |> serve()
    state = state |> press([:down, :enter]) |> serve()
    assert rows(state) == ["..", "carrots.agendum"]

    state = press(state, [:down, :enter])
    assert %{type: :prompt} = State.mode(state)
    assert state.edit.line.text == Path.join([dir, "Garden", "carrots.agendum"])

    # ENTER again retrieves it
    state = press(state, :enter)
    assert [{:load, path} | _] = Enum.reverse(effects())
    assert path == Path.join([dir, "Garden", "carrots.agendum"])
    assert state.modes == []
  end

  test "typing narrows the list; F7 shows dates; ESC leaves the prompt as it was", %{state: state} do
    state = press(state, [{:ctrl, "o"}, "half typed", {:f, 3}]) |> serve()
    state = press(state, "rab")
    assert rows(state) == ["rabbit.agendum"]
    assert screen(state) =~ "Narrowed to: rab"

    state = press(state, [:backspace, :backspace, :backspace, {:f, 7}])
    assert screen(state) =~ ~r/rabbit\.agendum +\d{4}-\d\d-\d\d \d\d:\d\d/

    state = press(state, :esc)
    assert %{type: :prompt} = State.mode(state)
    assert state.edit.line.text == "half typed"
  end

  test "each prompt lists its own kind of file", %{state: state} do
    state = press(state, [{:f, 10}, "f", "t", "i", {:f, 3}]) |> serve()
    assert rows(state) == ["..", "Garden", "export.json"]

    state =
      state |> press([:esc, :esc, :esc, :esc, :esc]) |> press([{:ctrl, "p"}, {:f, 3}]) |> serve()

    assert rows(state) == ["..", "Garden", "notes.txt"]
  end

  test "F3 does nothing in a prompt that is not for a file", %{state: state} do
    state = press(state, [{:f, 10}, "v", "a", {:f, 3}])
    assert %{type: :prompt} = State.mode(state)
  end

  test "a folder that cannot be read says so", %{state: state} do
    state = press(state, [{:ctrl, "o"}, {:ctrl, "u"}, "/nowhere/at/all/x", {:f, 3}]) |> serve()
    assert screen(state) =~ "This folder cannot be read"
  end
end
