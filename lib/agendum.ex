defmodule Agendum do
  @moduledoc """
  Wol's Agendum, a personal information manager in the spirit of Lotus
  Agenda (1988). The code keeps the `Agenda` namespace for now (ADR 0019).

    * `Agendum.Core` – the facade of the functional core: every change to a
      file goes through it; queries read `Agendum.Core.Database`
    * `Agendum.Core.*` – the pure data and rules behind it
    * `Agendum.TUI.*` – the terminal user interface: `Agendum.TUI.Update`
      handles keys, `Agendum.TUI.Render` draws, `Agendum.TUI.App` runs it
    * `Agendum.CLI`, `Agendum.Store`, `Agendum.Preferences`,
      `Agendum.CalendarFetch` – the shell: the command line, files,
      preferences and downloads

  See the Architecture page for how they fit together.
  """
end
