defmodule Agendum.TUI.FilePasswordTest do
  @moduledoc """
  A file's password (R82, ADR 0046), as Agenda's: opening a file with one
  asks for it; File Properties ▸ Set file password sets, changes or
  removes it with Agenda's boxes ("Enter the new password", "Please type
  the new password again"; checked in Agenda 2.0, 2026-10-26).
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Store
  alias Agendum.TUI.{State, Update}

  @moduletag :tmp_dir

  setup %{tmp_dir: dir} do
    {:ok, db} = Agendum.Core.set_password(Agendum.Sample.build(~D[2026-10-26]), "Hoot")
    path = Path.join(dir, "owl.agendum")
    :ok = Store.save(db, path)
    %{state: start(Agendum.Core.new_file()), path: path}
  end

  # the shell's part of opening: load, with the password when given
  defp serve(state, effects) do
    Enum.reduce(effects, state, fn
      {:load, path}, s ->
        Update.Results.loaded(s, path, Store.load_with_stamp(path))

      {:load_password, path, pw}, s ->
        Update.Results.loaded(s, path, Store.load_with_stamp(path, pw))

      _, s ->
        s
    end)
  end

  defp type(state, text),
    do: Enum.reduce(String.graphemes(text), state, &elem(Update.handle(&2, {:char, &1}), 0))

  test "opening asks for the password; a wrong one is said, the right one opens", %{
    state: state,
    path: path
  } do
    state = Update.Results.loaded(state, path, Store.load_with_stamp(path))
    assert screen(state) =~ "Password of owl.agendum:"
    # the keys typed are not shown
    refute screen(type(state, "owl")) =~ "owl:"

    {state, effects} = Update.handle(type(state, "owl"), :enter)
    state = serve(state, effects)
    assert screen(state) =~ "The password you typed is incorrect"

    {state, effects} = Update.handle(type(state, "Hoot"), :enter)
    state = serve(state, effects)
    assert state.path == path
    assert state.db.password == "Hoot"
    refute state.dirty
  end

  describe "File Properties ▸ Set file password" do
    defp props(state),
      do: state |> press([{:f, 10}, "f", "p"]) |> to_setting("Set file password")

    test "a new password, typed twice, hidden", %{state: state} do
      state = press(props(state), " ")
      assert screen(state) =~ "Enter the new password"
      assert screen(state) =~ "Type password and press ENTER."

      state = press(state, ["H", "o", "o", "t"])
      assert screen(state) =~ ~r/Password: +\*\*\*\*/
      # nor logged (ADR 0046)
      assert Agendum.TUI.Update.Prompts.password_prompt?(state)
      refute screen(state) =~ "Hoot"

      state = press(state, [:enter])
      assert screen(state) =~ "Please type the new password again"

      state = press(state, ["H", "o", "o", "t", :enter])
      assert state.db.password == "Hoot"
      assert %{type: :file_props} = State.mode(state)
    end

    test "a second one that differs is Agenda's error, and another try", %{state: state} do
      state = press(props(state), [" ", "H", "o", "o", "t", :enter, "o", "w", "l", :enter])
      assert screen(state) =~ "The second password you typed didn't match the first one."
      state = press(state, " ")
      assert screen(state) =~ "Please type the new password again"
      state = press(state, ["H", "o", "o", "t", :enter])
      assert state.db.password == "Hoot"
    end

    test "a file with one asks for it first; nothing new removes it", %{state: state} do
      {:ok, db} = Agendum.Core.set_password(state.db, "Hoot")
      state = press(props(%{state | db: db}), " ")
      assert screen(state) =~ "Enter the current password"

      wrong = press(state, ["o", "w", "l", :enter])
      assert screen(wrong) =~ "The password you typed is incorrect."

      state = press(state, ["H", "o", "o", "t", :enter, :enter, :enter])
      assert state.db.password == nil
    end
  end

  test "an export of a file with a password says it is plain text", %{state: state} do
    {:ok, db} = Agendum.Core.set_password(state.db, "Hoot")
    state = Update.Results.written(%{state | db: db}, "/wood/owl.json", :ok)
    assert panel(state) =~ "plain text"
  end
end
