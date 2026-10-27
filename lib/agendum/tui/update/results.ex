defmodule Agendum.TUI.Update.Results do
  @moduledoc """
  The shell's answers (meeting 2026-10-26-4, § 11): after `Agendum.TUI.App`
  has carried out an effect, it hands the result to a function here, which
  returns the new state: a calendar or feed read (R45, R75), a file saved,
  loaded or imported, a copy written, a file moved to the Trash, the blog
  published. Each has a clause per result shape (`:ok`, `{:ok, value}`,
  `{:error, reason}`), so a failure becomes a message, never a crash.

  Moved out of `Agendum.TUI.Update`, which keeps the keys, the clock and the
  dispatch, without any change in behaviour. Pure.
  """

  alias Agendum.Core
  alias Agendum.TUI.{History, Layout, State, Update}
  alias Agendum.TUI.Update.{Notes, Prompts}

  @doc """
  After the shell read the calendar `cal_id` at `url`: its events are
  mirrored into the file (one undo step), or the failure is remembered
  (R45).
  """
  def calendar_read(state, cal_id, url, result) do
    cal = state.db.calendars[cal_id]

    if asked?(state, cal, url) do
      {kind, fetching} = Map.pop(state.fetching, cal_id)
      state = %{state | fetching: fetching}
      next = read_into(state, cal, kind, result)
      next = into_snapshots(next, read_command(:calendar, cal_id, result))
      next = %{History.record(state, next) | dirty: next.db != next.saved.db}
      if next.modes == [], do: Layout.settle(next), else: next
    else
      state
    end
  end

  # Domain: only a read this file asked for, of the address it has now. A
  # read started for another file, open before, comes back with no
  # `fetching` entry here (code review 2026-10-26: it was filed into
  # whatever file shared the id), or, when this file reads a feed or
  # calendar of the same id too (every file counts its ids from one), with
  # another address (the fuzz walk, 2026-10-27). It is left out, and this
  # file's own read is still waited for.
  defp asked?(state, subscription, url),
    do:
      subscription != nil and subscription.url == url and
        Map.has_key?(state.fetching, subscription.id)

  defp read_into(state, cal, kind, {:ok, events}) do
    {:ok, state, %{result: counts}} = State.command(state, {:sync_calendar, cal.id, events})

    parts =
      [added: "new", updated: "changed", removed: "removed"]
      |> Enum.filter(fn {key, _} -> counts[key] > 0 end)
      |> Enum.map_join(", ", fn {key, word} -> "#{counts[key]} #{word}" end)

    cond do
      parts != "" ->
        State.info(state, Agendum.TUI.Extras.Calendars.Messages.text(:read, cal.name, parts))

      kind == :manual ->
        State.info(state, Agendum.TUI.Extras.Calendars.Messages.text(:no_changes, cal.name))

      true ->
        state
    end
  end

  defp read_into(state, cal, kind, {:error, message}) do
    state = State.run(state, {:calendar_failed, cal.id, message})

    if kind == :manual,
      do:
        State.error(state, Agendum.TUI.Extras.Calendars.Messages.text(:failed, cal.name, message)),
      else: state
  end

  @doc """
  After the shell read the feed `feed_id` at `url`: its entries are filed
  into the file (R75), or why not.
  """
  def feed_read(state, feed_id, url, result) do
    feed = state.db.feeds[feed_id]

    if asked?(state, feed, url) do
      {kind, fetching} = Map.pop(state.fetching, feed_id)
      state = %{state | fetching: fetching}
      next = feed_into(state, feed, kind, result)
      next = into_snapshots(next, read_command(:feed, feed_id, result))
      next = %{History.record(state, next) | dirty: next.db != next.saved.db}
      if next.modes == [], do: Layout.settle(next), else: next
    else
      state
    end
  end

  # Domain: a read is not a change made in a settings box that happens to
  # be open (the Properties box, F6, opened while it was under way): it
  # goes into the box's snapshot too, so ESC, putting the file back as it
  # was when the box opened, keeps it (the review of 2026-10-27)
  defp into_snapshots(state, command) do
    clock = State.context(state)

    modes =
      Enum.map(state.modes, fn
        %{opened: %{db: db} = opened} = mode ->
          case Agendum.Core.run(db, command, clock) do
            {:ok, db, _} -> %{mode | opened: %{opened | db: db}}
            {:error, _} -> mode
          end

        mode ->
          mode
      end)

    %{state | modes: modes}
  end

  defp read_command(:feed, id, {:ok, entries}), do: {:sync_feed, id, entries}
  defp read_command(:feed, id, {:error, message}), do: {:feed_failed, id, message}
  defp read_command(:calendar, id, {:ok, events}), do: {:sync_calendar, id, events}
  defp read_command(:calendar, id, {:error, message}), do: {:calendar_failed, id, message}

  defp feed_into(state, feed, kind, {:ok, entries}) do
    {:ok, state, %{result: counts}} = State.command(state, {:sync_feed, feed.id, entries})

    parts =
      [added: "new", updated: "changed", faded: "faded"]
      |> Enum.filter(fn {key, _} -> counts[key] > 0 end)
      |> Enum.map_join(", ", fn {key, word} -> "#{counts[key]} #{word}" end)

    cond do
      parts != "" ->
        State.info(state, Agendum.TUI.Extras.Feeds.Messages.text(:read, feed.name, parts))

      kind == :manual ->
        State.info(state, Agendum.TUI.Extras.Feeds.Messages.text(:nothing_new, feed.name))

      true ->
        state
    end
  end

  defp feed_into(state, feed, kind, {:error, message}) do
    state = State.run(state, {:feed_failed, feed.id, message})

    if kind == :manual,
      do: State.error(state, Agendum.TUI.Extras.Feeds.Messages.text(:failed, feed.name, message)),
      else: state
  end

  @doc "After the browser was asked to open a link (R75)."
  def url_opened(state, url, :ok), do: State.info(state, "Opened #{url}")

  def url_opened(state, _url, {:error, reason}),
    do: State.error(state, "Could not open it: #{reason}")

  @doc "A feed read once before subscribing (R75): its name asked, with its title."
  def feed_probed(state, url, result),
    do: Agendum.TUI.Extras.FeedsBox.probed(state, url, result)

  @doc "A calendar read once before subscribing (R45): its name asked, with its own."
  def calendar_probed(state, url, result),
    do: Agendum.TUI.Extras.CalendarsBox.probed(state, url, result)

  @doc "A feed list read for OPML import (R75): each feed not in the file yet is subscribed."
  def opml_read(state, path, {:ok, text}) do
    case State.command(state, {:import_opml, text}) do
      {:ok, state, %{result: []}} ->
        State.info(
          state,
          Agendum.TUI.Extras.Feeds.Messages.text(:no_new_feeds, Path.basename(path))
        )

      {:ok, state, %{result: ids}} ->
        state = Enum.reduce(ids, state, &Update.fetch_feed(&2, &1, :auto))

        State.info(
          state,
          Agendum.TUI.Extras.Feeds.Messages.text(
            :opml_subscribed,
            Path.basename(path),
            length(ids)
          )
        )

      {:error, :not_opml} ->
        State.error(state, Agendum.TUI.Extras.Feeds.Messages.text(:not_opml, Path.basename(path)))
    end
  end

  def opml_read(state, _path, {:error, :enoent}),
    do: State.error(state, Agendum.TUI.Messages.text(:file_not_found))

  def opml_read(state, _path, {:error, _reason}),
    do: State.error(state, Agendum.TUI.Messages.text(:cannot_open))

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

  @doc """
  The site's folder read (R74): what publishing would change there is
  shown before anything is written.
  """
  def publish_scanned(state, folder, files, {:ok, scan}) do
    changes = Core.site_changes(files, scan.existing, scan.published)

    if Agendum.TUI.Extras.PublishPreviewBox.nothing?(changes) and state.db.blog.upload == :none,
      do: State.info(state, Agendum.TUI.Extras.Publish.Messages.text(:up_to_date)),
      else: Agendum.TUI.Extras.PublishPreviewBox.open(state, folder, files, changes)
  end

  def publish_scanned(state, _folder, _files, {:error, reason}),
    do: State.error(state, Agendum.TUI.Extras.Publish.Messages.text(:cannot_read_folder, reason))

  @doc """
  The site written and uploaded (R74), or why not; an SFTP server that
  refused the keys asks for a password, with the preview still open.
  """
  def published(state, changes, :ok) do
    preview = Agendum.TUI.Extras.PublishPreviewBox
    uploaded? = state.db.blog.upload != :none

    state
    |> pop_publish_preview()
    |> State.info(
      Agendum.TUI.Extras.Publish.Messages.text(:published, uploaded?, preview.summary(changes))
    )
  end

  # Domain: the upload runs in the background, so the server's question
  # may come while another box covers the preview (the help), or after it
  # was closed (found by the fuzz walk, 2026-10-27). The prompt keeps the
  # preview it asks for, to publish its site again; with none open, there
  # is nothing to try again with.
  def published(state, _changes, {:error, :password}) do
    user = state.db.blog.user

    case Enum.find(state.modes, &match?(%{type: :publish_preview}, &1)) do
      nil ->
        State.error(state, Agendum.TUI.Extras.Publish.Messages.text(:password_later))

      preview ->
        Prompts.password(
          state,
          Agendum.TUI.Extras.Publish.Messages.text(:password, user, state.db.blog.target),
          {:sftp_password, preview}
        )
    end
  end

  def published(state, _changes, {:error, reason}),
    do:
      state
      |> pop_publish_preview()
      |> State.error(Agendum.TUI.Extras.Publish.Messages.text(:not_published, reason))

  defp pop_publish_preview(state) do
    case State.mode(state) do
      %{type: :publish_preview} -> State.pop(state)
      _ -> state
    end
  end

  @doc "A folder read for the Select File box (R51)."
  def dir_listed(state, dir, result), do: Agendum.TUI.Boxes.SelectFile.listed(state, dir, result)
end
