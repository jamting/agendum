# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Extras.Publish.Results do
  @moduledoc """
  The shell's answers for the micro-blog (R74): the site's folder read, so
  the preview can show what publishing would change, and the site written
  and uploaded, or why not. Kept beside the extra (the owner's modularity,
  2026-10-27), so `Agendum.TUI.Update.Results` holds only the clone's
  answers. Pure.
  """

  alias Agendum.Core
  alias Agendum.TUI.State
  alias Agendum.TUI.Extras.Publish.Messages
  alias Agendum.TUI.Extras.PublishPreviewBox

  @doc """
  The site's folder read (R74): what publishing would change there is
  shown before anything is written.
  """
  @spec publish_scanned(State.t(), String.t(), list, {:ok, map} | {:error, term}) :: State.t()
  def publish_scanned(state, folder, files, {:ok, scan}) do
    changes = Core.site_changes(files, scan.existing, scan.published)

    if PublishPreviewBox.nothing?(changes) and state.db.blog.upload == :none,
      do: State.info(state, Messages.text(:up_to_date)),
      else: PublishPreviewBox.open(state, folder, files, changes)
  end

  def publish_scanned(state, _folder, _files, {:error, reason}),
    do: State.error(state, Messages.text(:cannot_read_folder, reason))

  @doc """
  The site written and uploaded (R74), or why not; an SFTP server that
  refused the keys asks for a password, with the preview still open.
  """
  @spec published(State.t(), term, :ok | {:error, term}) :: State.t()
  def published(state, changes, :ok) do
    uploaded? = state.db.blog.upload != :none
    summary = PublishPreviewBox.summary(changes)

    # the feeds are written all the same, but a reader cannot follow their
    # links without a Base address, so the message says so
    text =
      if Core.blog_needs_base_url?(state.db),
        do: Messages.text(:published, uploaded?, summary, :needs_base_url),
        else: Messages.text(:published, uploaded?, summary)

    state
    |> pop_publish_preview()
    |> State.info(text)
  end

  # Domain: the upload runs in the background, so the server's question
  # may come while another box covers the preview (the help), or after it
  # was closed (found by the fuzz walk, 2026-10-27). The prompt keeps the
  # preview it asks for, to publish its site again; with none open, there
  # is nothing to try again with.
  def published(state, _changes, {:error, :password}) do
    user = state.db.blog.user
    state = PublishPreviewBox.done(state)

    case Enum.find(state.modes, &match?(%{type: :publish_preview}, &1)) do
      nil ->
        State.error(state, Messages.text(:password_later))

      preview ->
        Agendum.TUI.Update.Prompts.password(
          state,
          Messages.text(:password, user, state.db.blog.target),
          {:sftp_password, preview}
        )
    end
  end

  def published(state, _changes, {:error, reason}),
    do:
      state
      |> pop_publish_preview()
      |> State.error(Messages.text(:not_published, reason))

  # Domain: the result may come while another box (the help) covers the
  # preview; the preview goes then too, or ESC on it would offer to
  # publish again what is already published.
  defp pop_publish_preview(state) do
    case State.mode(state) do
      %{type: :publish_preview} ->
        State.pop(state)

      _ ->
        %{state | modes: Enum.reject(state.modes, &match?(%{type: :publish_preview}, &1))}
    end
  end
end
