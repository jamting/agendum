defmodule Agendum.TUI.NoteMenuTest do
  @moduledoc """
  The note editor's own F10 menu (R64b, NOTE_EDITOR.md step 2), as
  Agenda's: Import and Export (R64c, step 3), Clear, Return and Quit (File
  comes with external note files).
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Starters.Planner
  alias Agendum.TUI.State

  @today ~D[2026-10-12]

  setup do
    db = Planner.build() |> Planner.with_samples(@today)
    state = start(db, today: @today, height: 25, width: 80)
    # the first item, whose note has two lines
    note = press(state, [:down, {:f, 5}])
    %{note: note, item: State.mode(note).target |> elem(1)}
  end

  defp line(state, n), do: state |> screen() |> String.split("\n") |> Enum.at(n)
  defp types(state), do: Enum.map(state.modes, & &1.type)

  test "F10 opens the note's menu, not the view's", %{note: note} do
    menu = press(note, {:f, 10})
    assert line(menu, 0) =~ ~r/Import +Export +Clear +Return +Quit/
    refute line(menu, 0) =~ "View"
    assert line(menu, 1) =~ "Import a text file into the current note"
    assert types(press(menu, {:f, 10})) == [:note]
  end

  test "Clear asks first; Yes empties the note, which stays open", %{note: note, item: item} do
    asked = press(note, [{:f, 10}, "c"])
    assert screen(asked) =~ "Clear all text from the note?"

    cleared = press(asked, :enter)
    assert types(cleared) == [:note]
    assert State.mode(cleared).edit.lines == [""]

    back = press(cleared, {:f, 5})
    assert back.db.items[item].note == ""
    # one undo puts the text back
    assert press(back, {:ctrl, "z"}).db.items[item].note == note.db.items[item].note
  end

  test "typing before Clear is kept by undoing the Clear", %{note: note, item: item} do
    typed = press(note, "!")
    back = press(typed, [{:f, 10}, "c", :enter, {:f, 5}, {:ctrl, "z"}])
    assert back.db.items[item].note == note.db.items[item].note <> "!"
  end

  test "ESC on the question goes back to the menu, the note as it was", %{note: note} do
    back = press(note, [{:f, 10}, "c", :esc])
    assert types(back) == [:menu, :note]
    assert State.mode(press(back, :esc)).edit == State.mode(note).edit
  end

  test "Return saves and goes back, as F5", %{note: note, item: item} do
    back = press(note, ["!", {:f, 10}, "r"])
    assert back.modes == []
    assert back.db.items[item].note =~ ~r/!$/
  end

  test "Quit saves the note and quits, as ALT-Q", %{note: note, item: item} do
    quit = press(note, ["!", {:f, 10}, "q"])
    refute :note in types(quit)
    assert quit.db.items[item].note =~ ~r/!$/
  end

  test "the key bar names F10 Menu", %{note: note} do
    assert line(note, 24) =~ "F10 Menu"
  end

  describe "Import and Export (R64c)" do
    setup do
      Process.delete(:effects_seen)
      :ok
    end

    test "Import asks for a file; its text goes in at the cursor", %{note: note} do
      asked = press(note, [{:f, 10}, "i"])
      assert screen(asked) =~ "Text file to import into the note:"

      read = press(asked, ["/tmp/in.txt", :enter])
      assert {:read_note_text, "/tmp/in.txt"} in effects()

      done = Agendum.TUI.Update.note_text_read(read, "/tmp/in.txt", {:ok, "one\r\ntwo\r\n"})
      assert Enum.map(done.modes, & &1.type) == [:note]
      edit = State.mode(done).edit
      # CR LF read as LF; the cursor after what came in
      assert Enum.take(edit.lines, -3) == ["Ask Anna about the hosting costs.one", "two", ""]
      assert {edit.row, edit.col} == {length(edit.lines) - 1, 0}
      assert {_kind, "Imported /tmp/in.txt"} = done.message
    end

    test "a file that cannot be read says why, and the note is unchanged", %{note: note} do
      read = press(note, [{:f, 10}, "i", "/tmp/nope.txt", :enter])
      done = Agendum.TUI.Update.note_text_read(read, "/tmp/nope.txt", {:error, :enoent})
      assert {:error, "File not found"} = done.message
      assert State.mode(done).edit == State.mode(note).edit

      binary = Agendum.TUI.Update.note_text_read(read, "/tmp/x.bin", {:ok, <<255, 0, 1>>})
      assert {:error, "Not a text file: /tmp/x.bin"} = binary.message
    end

    test "Export writes the note as a text file", %{note: note} do
      press(note, [{:f, 10}, "e", "/tmp/out.txt", :enter])

      assert {:write_text, "/tmp/out.txt",
              "Scope, milestones and budget.\nAsk Anna about the hosting costs.\n"} in effects()
    end

    test "F3 in the prompt lists text files", %{note: note} do
      listing = press(note, [{:f, 10}, "e", {:f, 3}])
      assert State.mode(listing).type == :select_file
      assert State.mode(listing).extensions == [".txt", ".md"]
    end
  end
end
