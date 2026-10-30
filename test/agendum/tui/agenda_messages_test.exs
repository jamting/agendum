# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.AgendaMessagesTest do
  @moduledoc """
  Agendum's messages in Agenda's words (`Agendum.TUI.Messages`), checked
  against Lotus Agenda 2.0's own texts as `tools/agformat/extract_messages.py`
  read them from `AGENDA.RI` into `docs/reference/agenda_messages.json`
  (AGENDA_PARITY, the texts step). A message kept as Agenda's must be
  there word for word; an adapted one names Agenda's original, which must
  be there, and must still fit the control panel's two lines.
  """
  use ExUnit.Case, async: true

  alias Agendum.TUI.Messages

  @reference "docs/reference/agenda_messages.json"

  # Agenda's strings, a "|" (its line break) read as the space it shows as
  # at the end of a screen line, and spaces at the end left off
  setup_all do
    %{"strings" => strings} = @reference |> File.read!() |> JSON.decode!()
    %{agenda: MapSet.new(strings, &(&1 |> String.replace("|", " ") |> String.trim_trailing()))}
  end

  test "a message kept as Agenda's is word for word in Agenda's texts", %{agenda: agenda} do
    for {name, {text, :agenda}} <- Messages.all(),
        do: assert(text in agenda, "#{name}: not Agenda's: #{inspect(text)}")
  end

  test "an adapted message names Agenda's original", %{agenda: agenda} do
    for {name, {_text, {:adapted, original}}} <- Messages.all(),
        do: assert(original in agenda, "#{name}: no such Agenda text: #{inspect(original)}")
  end

  # the control panel's two lines hold about 130 characters at 80 columns
  test "every message fits the control panel" do
    for {name, {text, _}} <- Messages.all(),
        do: assert(String.length(text) <= 130, "#{name} is too long for two lines")
  end
end
