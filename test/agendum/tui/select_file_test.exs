# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.SelectFileTest do
  @moduledoc "The Select File box (R51): picking a file from a list instead of typing its name."
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Store
  alias Agendum.TUI.{State, Update}

  @moduletag :tmp_dir

  setup %{tmp_dir: dir} do
    File.mkdir_p!(Path.join(dir, "Garden"))
    File.write!(Path.join(dir, "Garden/carrots.agendum"), "")
    File.write!(Path.join(dir, "rabbit.agendum"), "")
    File.write!(Path.join(dir, "old.agenda"), "")
    File.write!(Path.join(dir, "notes.txt"), "")
    File.write!(Path.join(dir, "export.json"), "")

    state = start(Agendum.Sample.build(~D[2026-10-08]), width: 100, height: 30)
    %{state: %{state | path: Path.join(dir, "here.agendum")}, dir: dir}
  end

  # the shell's part: reads the folder the box asks for
  defp serve(state) do
    case State.mode(state) do
      %{type: :select_file, entries: :reading, dir: dir} ->
        Update.Results.dir_listed(state, dir, Store.list_dir(dir))

      _ ->
        state
    end
  end

  defp rows(state),
    do: state |> State.mode() |> Agendum.TUI.Boxes.SelectFile.rows() |> Enum.map(& &1.name)

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
    assert screen(state) =~ ~r/rabbit\.agendum +\d\d\/\d\d\/\d\d +\d{1,2}:\d\d[ap]m/

    state = press(state, :esc)
    assert %{type: :prompt} = State.mode(state)
    assert state.edit.line.text == "half typed"
  end

  # Agenda's F8 DESCRP (User's Guide 22-4): each file's description (R82)
  test "F8 shows each file's description, read from the files", %{state: state, dir: dir} do
    {:ok, db} = Agendum.Core.set_description(Agendum.Core.new_file(), "Rabbit's garden")
    :ok = Store.save(db, Path.join(dir, "rabbit.agendum"))

    state = press(state, [{:ctrl, "o"}, {:f, 3}]) |> serve()
    {state, effects} = Update.handle(state, {:f, 8})
    assert [{:read_descriptions, ^dir, names}] = effects
    assert "rabbit.agendum" in names

    state = Update.Results.descriptions_read(state, dir, Store.descriptions(dir, names))
    assert screen(state) =~ ~r/rabbit\.agendum +Rabbit's garden/
    # a file that is not an Agendum file has none
    assert Store.descriptions(dir, ["old.agenda"]) == %{"old.agenda" => ""}

    refute screen(press(state, {:f, 8})) =~ "Rabbit's garden"
  end

  test "each prompt lists its own kind of file", %{state: state} do
    state = press(state, [{:f, 10}, "f", "t", "i", {:f, 3}]) |> serve()
    assert rows(state) == ["..", "Garden", "export.json"]

    state =
      state |> press([:esc, :esc, :esc, :esc, :esc]) |> press([{:ctrl, "p"}, {:f, 3}]) |> serve()

    assert rows(state) == ["..", "Garden", "notes.txt"]
  end

  test "the Feeds box's OPML prompts list feed lists (meeting 2026-10-22-2337, § 7)", %{
    state: state,
    dir: dir
  } do
    # the feeds are an extra (R77)
    state = put_in(state.prefs.extras, true)
    File.write!(Path.join(dir, "feeds.opml"), "")
    File.write!(Path.join(dir, "subscriptions.xml"), "")

    # F7 imports a feed list, F8 exports one: both prompts list the same kinds
    for key <- [{:f, 7}, {:f, 8}] do
      state = press(state, [{:f, 10}, "e", "f", key])
      assert panel(state) =~ "F3 lists files"

      state = state |> press({:f, 3}) |> serve()
      assert rows(state) == ["..", "Garden", "feeds.opml", "subscriptions.xml"]
    end
  end

  # there F3 is Agenda's COPY, as anywhere a line is typed (2026-10-25)
  test "F3 in a prompt that is not for a file copies, not lists files", %{state: state} do
    state = press(state, [{:f, 10}, "v", "a", {:f, 3}])
    assert %{type: :what_to_copy, action: :copy} = State.mode(state)
  end

  test "a folder that cannot be read says so", %{state: state} do
    state = press(state, [{:ctrl, "o"}, {:ctrl, "u"}, "/nowhere/at/all/x", {:f, 3}]) |> serve()
    assert screen(state) =~ "This folder cannot be read"
  end
end
