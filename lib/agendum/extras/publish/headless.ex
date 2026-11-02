# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Extras.Publish.Headless do
  @moduledoc """
  Publishing a file's blog without the screen (R74; plans/archive/PUBLISHER.md step
  7, meeting 2026-11-02-1255, § 12): `mix agendum.publish FILE` and
  `agendum --publish FILE`. It does what Extras ▸ Publish ▸ Publish and
  ENTER on its preview do: the posts get their Zettel ids, the site is made
  from the folder's templates and assets, written into the folder the
  person's Upload settings name (from their preferences, as Agendum reads
  them), and uploaded; then the file is saved with what publishing keeps
  (the posts' addresses, the feeds' folders). `preview: true` only says
  what would change, writing nothing.

  The imperative shell, as `Agendum.Extras.Publish` is. A file with a
  password, and an SFTP server that asks for one, are refused: the screen
  is where a password is asked.
  """

  alias Agendum.{Core, Preferences, Store}
  alias Agendum.Extras.Publish
  alias Agendum.TUI.Extras.Publish.Messages

  @doc """
  Publishes the blog of the file at `file` (a path as typed, the extension
  added as Agendum adds it) with the preferences `prefs`, on `today`.
  Returns the lines to say, or why not.
  """
  @spec run(String.t(), Preferences.t(), Date.t(), keyword) ::
          {:ok, [String.t()]} | {:error, String.t()}
  def run(file, prefs, today, opts \\ []) do
    path = Store.normalize_path(file)
    preview? = Keyword.get(opts, :preview, false)

    with :ok <- extras_on(prefs),
         {:ok, opened, stamp} <- load(path),
         {:ok, upload} <- upload(prefs, path, opened, preview?),
         folder = Publish.folder(path, upload.folder),
         {:ok, db} <- prepare(opened),
         {:ok, inputs} <- Publish.inputs(folder),
         {:ok, files} <- site(db, today, inputs),
         {:ok, scan} <- Publish.scan(folder, files) do
      changes = Core.site_changes(files, scan.existing, scan.published)
      said = Messages.preview(db, today, upload, folder, changes, scan.templates_missing)

      if preview?,
        do: {:ok, said},
        else: publish({opened, db}, {path, stamp}, today, upload, {folder, files, changes}, said)
    end
  end

  # publishing is an extra (R77): with the extras off it is not there
  defp extras_on(%Preferences{extras: true}), do: :ok

  defp extras_on(_prefs),
    do: {:error, "Publishing is one of the extras: turn them on (Utilities ▸ Customize) first"}

  defp load(path) do
    case Store.load_with_stamp(path) do
      {:ok, db, stamp} -> {:ok, db, stamp}
      {:error, :enoent} -> {:error, "There is no #{path}"}
      {:error, :password_required} -> {:error, "#{path} has a password: publish it in Agendum"}
      {:error, {:damaged, problem}} -> {:error, "#{path} is damaged: #{problem}"}
      {:error, reason} -> {:error, "Could not open #{path}: #{inspect(reason)}"}
    end
  end

  # The person's settings for the file. An older file's own (format 46 and
  # before) move to the preferences, as opening it in Agendum moves them
  # (`Agendum.TUI.Extras.UploadBox.move_from_file/1`): the file's next save
  # leaves them out, so they would be lost (not for a preview, which
  # changes nothing).
  defp upload(prefs, path, db, preview?) do
    moved = Core.moved_upload(db)

    cond do
      Preferences.upload?(prefs, path) or moved == nil ->
        {:ok, Preferences.upload(prefs, path)}

      preview? or prefs.path == nil ->
        {:ok, moved}

      true ->
        case Preferences.save(Preferences.put_upload(prefs, path, moved), prefs.path) do
          :ok -> {:ok, moved}
          {:error, why} -> {:error, "Could not keep the upload settings: #{inspect(why)}"}
        end
    end
  end

  defp prepare(%{blog: %{posts: nil}}),
    do: {:error, "The blog has no posts category yet: choose it in Extras ▸ Publish ▸ Site"}

  defp prepare(db) do
    case Core.prepare_publish(db, %{}) do
      {:ok, db, _given} -> {:ok, db}
      {:error, reason} -> {:error, Messages.text(known(reason))}
    end
  end

  # the reasons the Site box words; any other is about the categories
  defp known(reason)
       when reason in [:no_posts_category, :ambiguous, :ingested, :zettels_full, :bad_address],
       do: reason

  defp known(_reason), do: :bad_categories

  defp site(db, today, inputs) do
    case Core.site(db, today, inputs) do
      {:ok, files} -> {:ok, files}
      {:error, error} -> {:error, Messages.site_error(error)}
    end
  end

  # Written, then the file saved with what publishing keeps (the posts'
  # addresses, Zettel ids), as the screen keeps them in the open file
  # before uploading; then uploaded. A failed upload leaves the folder and
  # the file agreeing, and says why.
  defp publish({opened, db}, {path, stamp}, today, upload, {folder, files, changes}, said) do
    published = Core.record_published(db, today)

    with :ok <- Publish.write_site(folder, files, changes),
         :ok <- save(opened, published, path, stamp),
         :ok <- uploaded(upload, folder, files, changes) do
      {:ok, said ++ [done(published, upload, changes)]}
    end
  end

  # as the screen says it, with its warning when the feeds' links cannot
  # be whole addresses
  defp done(db, upload, changes) do
    summary = Messages.summary(changes)
    uploaded? = upload.method != :none

    if Core.blog_needs_base_url?(db),
      do: Messages.text(:published, uploaded?, summary, :needs_base_url),
      else: Messages.text(:published, uploaded?, summary)
  end

  defp uploaded(upload, folder, files, changes) do
    case Publish.upload(upload, folder, files, changes, nil) do
      :ok ->
        :ok

      {:error, :password} ->
        {:error, "Written, not uploaded: the server asks for a password; publish in Agendum"}

      {:error, reason} ->
        {:error, "Written, not uploaded: #{reason}"}
    end
  end

  # saved only when publishing kept something new (a Zettel id, a post's
  # address, a feed's folder): an unchanged file is left as it is, so an
  # Agendum that has it open finds nothing changed on disk
  defp save(opened, opened, _path, _stamp), do: :ok

  defp save(_opened, db, path, stamp) do
    case Store.save(db, path, stamp) do
      {:ok, _stamp} ->
        :ok

      {:error, :changed_on_disk} ->
        {:error, "Written, but #{path} changed meanwhile: not saved, nor uploaded"}

      {:error, reason} ->
        {:error, "Written, but #{path} could not be saved: #{inspect(reason)}"}
    end
  end
end
