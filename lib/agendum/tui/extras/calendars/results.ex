# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Extras.Calendars.Results do
  @moduledoc """
  The shell's answers for the calendars extra (R45): a calendar read, and
  a calendar read once before subscribing. Kept beside the extra (the
  owner's modularity, 2026-10-27), so `Agendum.TUI.Update.Results` holds
  only the clone's answers. Pure.
  """

  alias Agendum.TUI.State
  alias Agendum.TUI.Extras.Calendars.Messages
  alias Agendum.TUI.Extras.Reads

  @doc """
  After the shell read the calendar `cal_id` at `url`: its events are
  mirrored into the file (one undo step), or the failure is remembered
  (R45).
  """
  @spec calendar_read(State.t(), pos_integer, String.t(), {:ok, list} | {:error, String.t()}) ::
          State.t()
  def calendar_read(state, cal_id, url, result) do
    cal = state.db.calendars[cal_id]
    into = fn state, kind -> into(state, cal, kind, result) end
    Reads.file(state, cal_id, url, cal, into, command(cal_id, result))
  end

  defp command(id, {:ok, events}), do: {:sync_calendar, id, events}
  defp command(id, {:error, message}), do: {:calendar_failed, id, message}

  defp into(state, cal, kind, {:ok, events}) do
    {:ok, state, %{result: counts}} = State.command(state, {:sync_calendar, cal.id, events})
    parts = Reads.counted(counts, added: "new", updated: "changed", removed: "removed")

    cond do
      parts != "" -> State.info(state, Messages.text(:read, cal.name, parts))
      kind == :manual -> State.info(state, Messages.text(:no_changes, cal.name))
      true -> state
    end
  end

  defp into(state, cal, kind, {:error, message}) do
    state = State.run(state, {:calendar_failed, cal.id, message})

    if kind == :manual,
      do: State.error(state, Messages.text(:failed, cal.name, message)),
      else: state
  end

  @doc "A calendar read once before subscribing (R45): its name asked, with its own."
  @spec calendar_probed(State.t(), String.t(), term) :: State.t()
  def calendar_probed(state, url, result),
    do: Agendum.TUI.Extras.CalendarsBox.probed(state, url, result)
end
