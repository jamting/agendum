# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Extras.Reads do
  @moduledoc """
  A feed's or a calendar's read, come back from the shell (R75, R45): what
  the two extras share in taking it. Only a read this file asked for, of
  the address it still has, is filed; the filing goes into the snapshot of
  a settings box open meanwhile too, and is one undo step. Each extra says
  what was filed in its own words (`Agendum.TUI.Extras.Feeds.Results`,
  `Agendum.TUI.Extras.Calendars.Results`). Pure.
  """

  alias Agendum.TUI.{History, Layout, State}

  @doc """
  Files the read of subscription `id` at `url`: `into` takes the state
  (the wait for it ended) and how the read was asked for (`:manual` or
  `:auto`), and files it, saying what it did; `command` is the same
  filing as a core command, for the snapshots of open boxes.
  """
  @spec file(State.t(), pos_integer, String.t(), map | nil, (State.t(), atom -> State.t()), tuple) ::
          State.t()
  def file(state, id, url, subscription, into, command) do
    # Elixir: the clause's `state` is a new binding, the state without the
    # wait; it is the one returned when the answer is dropped too
    case answered(state, id, url) do
      {:ok, kind, state} ->
        if current?(subscription, url) do
          next = state |> into.(kind) |> into_snapshots(command)
          next = %{History.record(state, next) | dirty: next.db != next.saved.db}
          if next.modes == [], do: Layout.settle(next), else: next
        else
          state
        end

      :not_asked ->
        state
    end
  end

  @doc ~S'What a read changed, in words: "2 new, 1 changed" ("" for nothing).'
  @spec counted(map, keyword) :: String.t()
  def counted(counts, words) do
    words
    |> Enum.filter(fn {key, _} -> counts[key] > 0 end)
    |> Enum.map_join(", ", fn {key, word} -> "#{counts[key]} #{word}" end)
  end

  # Domain: only a read this file asked for, of the address it asked for.
  # A read started for another file, open before, comes back with no
  # `fetching` entry here (code review 2026-10-26: it was filed into
  # whatever file shared the id), or, when this file reads a feed or
  # calendar of the same id too (every file counts its ids from one), with
  # another address (the fuzz walk, 2026-10-27). It is left out, and this
  # file's own read is still waited for. An answer this file asked for
  # always ends the wait, filed or not (`current?/2`).
  defp answered(state, id, url) do
    case state.fetching do
      %{^id => {kind, ^url}} -> {:ok, kind, %{state | fetching: Map.delete(state.fetching, id)}}
      _ -> :not_asked
    end
  end

  # Domain: the feed or calendar may have gone while it was read (DEL, an
  # undo) or have another address now; the answer is then dropped, and
  # the next read asks for the address it has (the richer fuzz walks,
  # 2026-10-27: it was waited for ever, "reading…" and WRKG).
  defp current?(subscription, url), do: subscription != nil and subscription.url == url

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
end
