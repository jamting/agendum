# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Update.Results do
  @moduledoc """
  The shell's answers (meeting 2026-10-26-1524, § 11): after `Agendum.TUI.App`
  has carried out an effect, it hands the result to a function here, which
  returns the new state: a file saved, loaded or imported, a copy written,
  a file moved to the Trash, a folder listed. The extras' answers (a feed
  or calendar read, the blog published) are beside them:
  `Agendum.TUI.Extras.Feeds.Results`, `Agendum.TUI.Extras.Calendars.Results`
  and `Agendum.TUI.Extras.Publish.Results`. Each has a clause per result shape (`:ok`, `{:ok, value}`,
  `{:error, reason}`), so a failure becomes a message, never a crash.

  Moved out of `Agendum.TUI.Update`, which keeps the keys, the clock and the
  dispatch, without any change in behaviour. Pure.
  """

  alias Agendum.Core
  alias Agendum.TUI.{Layout, State, Update}
  alias Agendum.TUI.Update.{Notes, Prompts}

  # --- results of effects -----------------------------------------------------
  #
  # `App` calls these after it has carried out an effect, with its result.
  # Each has a clause per result shape (`:ok`, `{:ok, value}`,
  # `{:error, reason}`), so a failure becomes a message, never a crash.

  @doc "After saving the person's preferences (R41b): only a failure is reported."
  def preferences_saved(state, :ok), do: state

  def preferences_saved(state, {:error, reason}),
    do: State.error(state, "Could not save your preferences: #{inspect(reason)}")

  # Domain: after a good save the database on screen becomes the saved one
  # (`saved.db`), so the file is clean, and what waited for the
  # save goes on (`opts.then`). A failed save changes nothing but the
  # message: the changes are still unsaved, say so, and nothing that
  # waited for them happens (R71): Quit stays, Retrieve opens nothing.
  @doc """
  After the shell saved the file (`{:save, path, opts}`): the result is
  the new stamp, or why it was not saved; a file changed on disk is asked
  about, except by auto-save, which says so and stops (R71).
  """
  @spec saved(State.t(), String.t(), {:ok, Agendum.Store.stamp()} | {:error, term}, map) ::
          State.t()
  # a MakeCopy whose copy could not be written keeps saying so (R82)
  def saved(%{message: {:error, _} = failed} = state, path, {:ok, _} = result, %{
        then: {:copied, _}
      }) do
    %{saved(state, path, result, %{expect: :any, then: nil, auto: false}) | message: failed}
  end

  def saved(state, path, {:ok, stamp}, opts) do
    state = saved_recovery(state)

    %{
      state
      | path: path,
        dirty: false,
        saved: %{db: state.db, stamp: stamp, conflict: false, recovery: nil}
    }
    |> remember(path)
    |> State.info("Saved #{Path.basename(path)}")
    |> after_save(opts.then)
  end

  def saved(state, path, {:error, :changed_on_disk}, %{auto: true}) do
    %{state | saved: %{state.saved | conflict: true}}
    |> State.error(
      "Not auto-saved: #{Path.basename(path)} changed on disk; save it yourself to choose"
    )
  end

  def saved(state, path, {:error, :changed_on_disk}, opts) do
    # `opts.expect` nil: no file was there when this one was read
    what = if opts.expect == nil, do: "already exists", else: "has changed on disk"

    Prompts.ask(
      state,
      "#{Path.basename(path)} #{what} since Agendum read it. Save over it?",
      {:overwrite, path, opts.then}
    )
  end

  def saved(state, _path, {:error, reason}, opts) do
    tail = if opts.then == :quit, do: " (not quitting)", else: ""
    State.error(state, "Could not save: #{inspect(reason)}#{tail}")
  end

  # the changes kept from a crash are in the file now: their recovery
  # file goes (R82b)
  defp saved_recovery(%State{saved: %{recovery: nil}} = state), do: state

  defp saved_recovery(state),
    do: State.effect(state, {:remove_recovery, state.saved.recovery})

  # what waited for the save: quitting keeps the person's place in the
  # file first (R69), as `handle/2` does for a Quit without a save
  defp after_save(state, nil), do: state

  defp after_save(state, :quit),
    do: state |> Agendum.TUI.Places.remember() |> State.effect(:quit)

  defp after_save(state, {:replace_file, command}), do: Prompts.replace_file(state, command)

  # MakeCopy (R82): the copy was written just before; its message is the
  # one to see
  defp after_save(state, {:copied, path}),
    do: State.info(state, "Copied to #{Path.basename(path)}; saved")

  # the file offered when Agendum next starts without one (R52); the shell
  # saves the preferences when this changed them
  defp remember(state, path), do: %{state | prefs: %{state.prefs | last_file: path}}

  @doc """
  The startup prompt's file (R52): opened when it exists; otherwise a new
  file, saved there on the first save.
  """
  def opened(state, path, {:error, :enoent}) do
    state
    |> State.reopen(State.new_file(state), path)
    |> remember(path)
    |> State.info("New file #{Path.basename(path)} (saved there on the first save)")
    |> Layout.settle()
  end

  def opened(state, path, result), do: loaded(state, path, result)

  # `%State{expr | message: ...}` is the struct update syntax with the
  # struct's name: it also checks that `expr` is a `State`. Domain: the new
  # file goes through `arrive/1` too, as at startup, for its alarms (R70).
  def loaded(state, path, {:ok, db, stamp}) do
    %State{
      State.reopen(state, db, path, stamp)
      | message: {:message, "Retrieved #{Path.basename(path)}"}
    }
    |> remember(path)
    |> Layout.settle()
    |> Update.arrive()
  end

  # Retrieve with a name that is not a file yet makes it, after asking
  # (Agenda's way to make a new file; its New File box let one ESC out)
  def loaded(state, path, {:error, :enoent}),
    do: Agendum.TUI.Boxes.NewFileBox.open(state, path)

  # a file with a password (ADR 0046): asked for, and again when wrong, as
  # Agenda said it
  def loaded(state, path, {:error, :password_required}),
    do: Prompts.password(state, "Password of #{Path.basename(path)}:", {:file_password, path})

  def loaded(state, path, {:error, :wrong_password}),
    do:
      Prompts.password(
        state,
        "The password you typed is incorrect. Retype the password of #{Path.basename(path)}:",
        {:file_password, path}
      )

  # a damaged file (SECURITY.md, door 2): refused, and why, as Agenda
  # refused one; the file open stays
  def loaded(state, path, {:error, {:damaged, problem}}),
    do: State.error(state, "#{Path.basename(path)} is damaged and cannot be opened: #{problem}")

  def loaded(state, _path, {:error, _reason}),
    do: State.error(state, Agendum.TUI.Messages.text(:cannot_open))

  @doc """
  After a file was opened, the shell found the changes a crash kept beside
  it (`Agendum.Store.recovery_path/2`, R82b), read here with the time they
  were written: Agendum asks whether to open them. Yes opens them as
  unsaved changes to the file, No moves the recovery file to the Trash, ESC
  leaves it to be asked about next time.
  """
  @spec recovery_found(
          State.t(),
          String.t(),
          {:ok, Agendum.Core.db(), NaiveDateTime.t()} | {:error, term}
        ) :: State.t()
  def recovery_found(state, path, {:ok, db, written}) do
    rpath = Agendum.Store.recovery_path(path)

    when_text =
      Agendum.Core.DateFormat.date_time(
        NaiveDateTime.to_date(written),
        NaiveDateTime.to_time(written),
        state.db.date_format
      )

    Prompts.ask(
      state,
      "#{Path.basename(path)}: changes not saved before a crash (#{when_text}) are in " <>
        "#{Path.basename(rpath)}. Open them?",
      {:recovered, rpath, db},
      help: "Y opens the changes, to save into the file; N moves them to the Trash."
    )
  end

  def recovery_found(state, path, {:error, _reason}),
    do:
      State.error(
        state,
        "#{Path.basename(Agendum.Store.recovery_path(path))} could not be read"
      )

  @doc """
  After the shell read a JSON file to import (R44): the file opens as a
  new, untitled file, to be saved under a name; on an error the open file
  stays.
  """
  def imported(state, path, {:ok, text}) do
    # Domain: one Import for both kinds of file, told apart by what is in
    # them (R72): an Agenda file starts with "T", JSON with "{"
    if Core.agenda_file?(text),
      do: import_ag(state, path, text, nil),
      else: import_json(state, path, text)
  end

  def imported(state, _path, {:error, :enoent}),
    do: State.error(state, Agendum.TUI.Messages.text(:file_not_found))

  def imported(state, _path, {:error, _reason}),
    do: State.error(state, Agendum.TUI.Messages.text(:cannot_open))

  defp import_json(state, path, text) do
    case Core.import_json(text) do
      {:ok, db} ->
        %State{
          State.reopen(state, db, nil)
          | dirty: true,
            saved: %{db: nil, stamp: nil, conflict: false, recovery: nil},
            message: {:message, "Imported #{Path.basename(path)} (save it to keep it)"}
        }
        |> Layout.settle()
        |> Update.arrive()

      {:error, _reason} ->
        State.error(state, Agendum.TUI.Messages.text(:cannot_import))
    end
  end

  @doc """
  Imports a Lotus Agenda file (R72) read from `path`: it opens as a new
  file of the same name with Agendum's extension, beside it, not saved
  yet (a file already there is asked about at the first save, R71), and
  the report of what came over shows. A file with a password asks for it
  (`password` nil: not asked yet), again when it was wrong.
  """
  @spec import_ag(State.t(), String.t(), binary, String.t() | nil) :: State.t()
  def import_ag(state, path, bytes, password) do
    name = Path.basename(path)

    case Core.import_ag(bytes, password: password, clock: State.context(state)) do
      {:ok, db, report} ->
        into = Path.rootname(path) <> Agendum.Store.extension()

        %State{
          State.reopen(state, db, into)
          | dirty: true,
            saved: %{db: nil, stamp: nil, conflict: false, recovery: nil},
            message: {:message, "Imported #{name} as #{Path.basename(into)} (save it to keep it)"}
        }
        |> Layout.settle()
        |> Update.arrive()
        |> Agendum.TUI.Boxes.ImportReportBox.open(path, report)

      {:error, :password_required} ->
        Prompts.password(state, "Password of #{name}:", {:ag_password, path, bytes})

      # as Agenda said it; the prompt has both top lines, so it says it
      {:error, :wrong_password} ->
        Prompts.password(
          state,
          "The password you typed is incorrect. Retype the password of #{name}:",
          {:ag_password, path, bytes}
        )

      {:error, :not_an_agenda_file} ->
        State.error(state, Agendum.TUI.Messages.text(:not_agenda_file))

      {:error, _message} ->
        State.error(state, Agendum.TUI.Messages.text(:cannot_import))
    end
  end

  @doc """
  After the shell read a text file for a note's Import (R64c): its text
  goes in at the note's cursor; an error, or a file that is not text,
  leaves the note as it was.
  """
  @spec note_text_read(State.t(), String.t(), {:ok, binary} | {:error, term}) :: State.t()
  def note_text_read(state, path, {:ok, text}) do
    if String.valid?(text),
      do: state |> Notes.import_text(text) |> State.info("Imported #{path}"),
      else: State.error(state, Agendum.TUI.Messages.text(:cannot_import))
  end

  def note_text_read(state, _path, {:error, :enoent}),
    do: State.error(state, Agendum.TUI.Messages.text(:file_not_found))

  def note_text_read(state, _path, {:error, _reason}),
    do: State.error(state, Agendum.TUI.Messages.text(:cannot_open))

  @doc "The files' descriptions read for the Select File box's F8 (R82)."
  defdelegate descriptions_read(state, dir, descriptions),
    to: Agendum.TUI.Boxes.SelectFile,
    as: :described

  @doc "After the shell backed up the file opened (`{:backup_file, path}`, R82): silent."
  @spec backed_up(State.t(), String.t(), :ok | {:error, term}) :: State.t()
  def backed_up(state, _path, :ok), do: state

  def backed_up(state, path, {:error, reason}),
    do:
      State.error(
        state,
        "Could not back up #{Path.basename(path)}: #{:file.format_error(reason)}"
      )

  @doc "After the shell moved a file to the Trash (`{:trash_file, path}`, R82)."
  @spec trashed(State.t(), String.t(), :ok | {:error, term}) :: State.t()
  def trashed(state, path, :ok), do: State.info(state, "#{Path.basename(path)} is in the Trash")

  def trashed(state, path, {:error, :no_trash}),
    do: State.error(state, "There is no Trash here; #{Path.basename(path)} was kept")

  def trashed(state, path, {:error, reason}),
    do:
      State.error(
        state,
        "Could not move #{Path.basename(path)} to the Trash: #{:file.format_error(reason)}"
      )

  @doc "After the shell wrote a copy or a template (`{:save_copy, path, db}`, R82)."
  @spec copied(State.t(), String.t(), {:ok, term} | {:error, term}) :: State.t()
  def copied(state, path, {:ok, _stamp}),
    do: State.info(state, "Copied to #{Path.basename(path)}")

  def copied(state, _path, {:error, reason}),
    do: State.error(state, "Could not write the copy: #{inspect(reason)}")

  # a file with a password exported as JSON: the JSON is not encrypted
  # (ADR 0046), so the message says so
  def written(%{db: %{password: pw}} = state, path, :ok) when is_binary(pw),
    do: State.info(state, "Wrote #{path} (plain text: the file's password does not protect it)")

  def written(state, path, :ok), do: State.info(state, "Wrote #{path}")

  def written(state, _path, {:error, reason}),
    do: State.error(state, "Could not write: #{inspect(reason)}")

  @doc "A folder read for the Select File box (R51)."
  def dir_listed(state, dir, result), do: Agendum.TUI.Boxes.SelectFile.listed(state, dir, result)
end
