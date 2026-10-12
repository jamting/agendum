defmodule Agenda do
  @moduledoc """
  Wol's Agendum, a personal information manager in the spirit of Lotus
  Agenda (1988). The code keeps the `Agenda` namespace for now (ADR 0019).

    * `Agenda.Core` – the facade of the functional core: every change to a
      file goes through it; queries read `Agenda.Core.Database`
    * `Agenda.Core.*` – the pure data and rules behind it
    * `Agenda.TUI.*` – the terminal user interface: `Agenda.TUI.Update`
      handles keys, `Agenda.TUI.Render` draws, `Agenda.TUI.App` runs it
    * `Agenda.CLI`, `Agenda.Store`, `Agenda.Preferences`,
      `Agenda.CalendarFetch` – the shell: the command line, files,
      preferences and downloads

  See the Architecture page for how they fit together.
  """
end
