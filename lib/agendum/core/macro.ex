# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Macro do
  @moduledoc """
  A macro kept in the file (SPEC R50; Working with Macros, chapter 1): a
  named series of keystrokes, recorded in Learn mode or typed, that a user
  can play back.

    * `name`: up to 35 characters, unique in the file (case aside)
    * `keys`: the keystrokes in Agenda's notation: text as typed, other keys
      by name in braces (`{F10}vc{ENTER}Hello{AltF2}`); what the names mean
      is the front end's (`Agendum.TUI.MacroKeys`)
    * `key`: the key it is attached to, in the same notation (`{ShfF4}`), or
      nil; pressing it runs the macro instead of the key's own command
    * `run_from`: where it can be run: views, notes, the category manager
      and, for an attached key, everywhere else (boxes, typing)

  A plain struct. Pure.
  """

  @type place :: :view | :note | :catmgr | :elsewhere
  @type t :: %__MODULE__{
          id: pos_integer | nil,
          name: String.t(),
          keys: String.t(),
          key: String.t() | nil,
          run_from: %{place => boolean}
        }
  defstruct [
    :id,
    :name,
    keys: "",
    key: nil,
    run_from: %{view: true, note: true, catmgr: true, elsewhere: false}
  ]

  @doc "The places a macro can be run from, in Agenda's order."
  def places, do: [:view, :note, :catmgr, :elsewhere]

  @doc "The longest name Agenda allows."
  def max_name, do: 35
end
