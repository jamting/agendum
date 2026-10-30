# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Starters.Planner.Macros do
  @moduledoc """
  The Activities Planner's keystroke macros (R60; screenshots 78-109 in
  `docs/reference/screens/notes.md`), each run from views only, as in
  Agenda. Their keys go through Agendum's menus, which are not Agenda's,
  and Agenda's {ALERT} boxes (command language) are left out:

    * Customize date settings: File ▸ Properties, the file's date
      settings (Agenda: File Properties at Global date settings)
    * Hide/Display done items: View ▸ Properties, Hide done items (END
      goes to View statistics, six ↑ from there reach it, whether or not
      the Order row shows), SPACE switches it, ENTER closes the box
    * Print current view: Print, which asks for the file to print to
      (Agenda asked what to print and opened its Final Print box)

  Left out, as they need the command language: Sort items in view, and
  Create/Update contact list (its Contacts view is in the file instead).
  Pure.
  """

  alias Agendum.Core
  alias Agendum.Core.Database

  # {name, keys in Agenda's notation (`Agendum.TUI.MacroKeys`)}
  @macros [
    {"Customize date settings", "{F10}fp"},
    {"Hide/Display done items", "{F10}vp{END}{UP}{UP}{UP}{UP}{UP}{UP} {ENTER}"},
    {"Print current view", "{F10}p"}
  ]

  @doc "Adds the macros to the Planner `db`."
  @spec add(Database.t()) :: Database.t()
  def add(db) do
    Enum.reduce(@macros, db, fn {name, keys}, db ->
      {:ok, db, id} = Core.add_macro(db, name)

      db
      |> Core.set_macro_keys(id, keys)
      # views only: a new macro also runs from notes and the category manager
      |> Core.set_macro_run_from(id, :note, false)
      |> Core.set_macro_run_from(id, :catmgr, false)
    end)
  end
end
