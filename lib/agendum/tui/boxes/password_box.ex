# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Boxes.PasswordBox do
  @moduledoc """
  Agenda's small password boxes (File Properties ▸ Set file password; R82,
  ADR 0046; checked in Agenda 2.0, 2026-10-26): one field, "Password:",
  typed hidden (a star a character), under a title saying what to type:

    * "Enter the current password", when the file has one: a wrong one is
      Agenda's error, "The password you typed is incorrect."
    * "Enter the new password" (nothing removes the password)
    * "Please type the new password again": a different one is Agenda's
      error, and the box stays for another try (ESC starts over)

  ENTER takes what is typed, ESC goes back. Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :accept

  alias Agendum.TUI.Boxes.{Box, ErrorBox}
  alias Agendum.TUI.State
  alias Agendum.TUI.Typing.LineEdit

  @titles %{
    current: "Enter the current password",
    new: "Enter the new password",
    again: "Please type the new password again"
  }

  @doc "Opens the first box: the current password when there is one, else the new one."
  def open(state) do
    if state.db.password,
      do: push(state, :current),
      else: push(state, :new)
  end

  defp push(state, step, first \\ nil),
    do:
      State.push(state, %Agendum.TUI.Modes.PasswordBox{
        step: step,
        first: first,
        line: LineEdit.new("")
      })

  @impl Box
  # a box that types gets every key: ENTER takes the password, ESC goes
  # back, the others type it
  def handle(state, mode, :enter), do: run(state, mode, :accept)
  def handle(state, mode, :esc), do: run(state, mode, :close)

  def handle(state, mode, key) do
    case LineEdit.handle(mode.line, key) do
      {:ok, line} -> State.put_mode(state, %{mode | line: line})
      :unhandled -> state
    end
  end

  @impl Box
  def typing?(_state, _mode), do: true

  # R65
  @impl Box
  def keymap(_mode), do: %{:enter => :accept, :esc => :close}

  @impl Box
  def commands(_mode),
    do: [{:accept, "Accept", "Take the password"}, {:close, "Cancel", "Go back"}]

  @impl Box
  def run(state, _mode, :close), do: State.pop(state)
  def run(state, mode, :accept), do: accept(state, mode, mode.line.text)

  defp accept(state, %{step: :current}, typed) do
    if typed == state.db.password,
      do: state |> State.pop() |> push(:new),
      else: state |> State.pop() |> ErrorBox.open("The password you typed is incorrect.")
  end

  defp accept(state, %{step: :new}, typed), do: state |> State.pop() |> push(:again, typed)

  # the same twice: set (an empty one removes it); else Agenda's error
  # over this box, cleared for another try
  defp accept(state, %{step: :again, first: first} = mode, typed) do
    if typed == first do
      case State.command(State.pop(state), {:set_password, typed}) do
        {:ok, state, _} ->
          state

        {:error, :too_long} ->
          ErrorBox.open(State.pop(state), "A password has at most 12 characters.")
      end
    else
      state
      |> State.put_mode(%{mode | line: LineEdit.new("")})
      |> ErrorBox.open(
        "The second password you typed didn't match the first one. " <>
          "Retype the second password entry or press ESC to start over."
      )
    end
  end

  @impl Box
  def title(_state, mode), do: @titles[mode.step]

  @impl Box
  def width(state, _mode), do: min(state.width - 8, 42)

  @impl Box
  def content(_state, mode, _inner, _max_rows) do
    stars = String.duplicate("*", String.length(mode.line.text))
    [[], [{:box, "  Password:  "}, {:box_selected, stars <> " "}], []]
  end

  @impl Box
  def keys(_state, _mode), do: [{"ENTER", "Accept"}, {"ESC", "Cancel"}]

  # Agenda's words on the top line
  @impl Box
  def help, do: "Type password and press ENTER."
end
