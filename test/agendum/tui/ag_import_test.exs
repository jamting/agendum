defmodule Agendum.TUI.AgImportTest do
  @moduledoc """
  Importing a Lotus Agenda file in the TUI (R72): File ▸ Transfer ▸ Import
  takes an `.AG` as well as JSON; it opens as a new file beside it, not
  saved yet, with a report box; a file with a password asks for it,
  hidden as it is typed.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.TUI.{State, Update}

  @rich File.read!("test/fixtures/ag/RICH.AG")
  @ux File.read!("test/fixtures/ag/UX.AG")

  defp started,
    do: start(Agendum.Core.new_file(), now: ~N[2026-10-16 10:00:00], width: 100, height: 30)

  defp import(state, path, bytes), do: Update.imported(state, path, {:ok, bytes})

  test "Import asks for a JSON or an Agenda file" do
    assert screen(press(started(), [{:f, 10}, "f", "t", "i"])) =~
             "JSON or Agenda (.AG) file to import"
  end

  test "an Agenda file opens as a new file beside it, not saved yet, with its report" do
    state = import(started(), "/home/rabbit/RICH.AG", @rich)
    assert state.path == "/home/rabbit/RICH.agendum"
    assert state.dirty
    assert state.saved.stamp == nil
    assert map_size(state.db.items) == 5

    text = screen(state)
    assert text =~ "Imported from Agenda"
    assert text =~ "RICH.AG came over as RICH.agendum (not saved yet)"
    assert text =~ "5 items"
    assert text =~ "discarded item"
    assert text =~ "Filed differently"
    assert text =~ "+Anna"
  end

  test "ENTER or ESC closes the report; the file's view is there" do
    state = import(started(), "/home/rabbit/RICH.AG", @rich)

    for key <- [:enter, :esc] do
      closed = press(state, key)
      refute screen(closed) =~ "Imported from Agenda"
      assert screen(closed) =~ "Imported RICH.AG as RICH.agendum" or State.mode(closed) == nil
    end
  end

  test "CTRL-P writes the report beside the Agenda file" do
    state = import(started(), "/home/rabbit/RICH.AG", @rich)
    {_state, effects} = Update.handle(state, {:ctrl, "p"})
    assert [{:write_text, "/home/rabbit/RICH-import.txt", text}] = effects
    assert text =~ "RICH.AG came over as RICH.agendum"
  end

  test "the first save expects no file there yet" do
    state = import(started(), "/home/rabbit/RICH.AG", @rich) |> press(:esc)
    {_state, effects} = Update.handle(state, {:ctrl, "s"})
    assert [{:save, "/home/rabbit/RICH.agendum", %{expect: nil}}] = effects
  end

  describe "a file with a password" do
    test "asks for it, shows stars, and imports with it" do
      state = import(started(), "/home/rabbit/UX.AG", @ux)
      assert screen(state) =~ "Password of UX.AG:"
      typed = press(state, "hoot")
      assert screen(typed) =~ "****"
      refute screen(typed) =~ "hoot"
      assert Agendum.TUI.Update.Prompts.password_prompt?(typed)

      done = press(typed, :enter)
      assert done.path == "/home/rabbit/UX.agendum"
      assert screen(done) =~ "Imported from Agenda"
    end

    test "a wrong one says so and asks again" do
      state = import(started(), "/home/rabbit/UX.AG", @ux) |> press(["owl", :enter])
      assert screen(state) =~ "The password you typed is incorrect"
      assert screen(state) =~ "Retype the password of UX.AG:"
      assert state.path == nil
    end

    test "ESC gives up; the open file stays" do
      state = import(started(), "/home/rabbit/UX.AG", @ux) |> press(:esc)
      assert State.mode(state) == nil
      assert state.path == nil
    end
  end

  test "a file that is neither says so" do
    state = import(started(), "/home/rabbit/x.json", "hello")
    assert screen(state) =~ "Could not import x.json"
  end
end
