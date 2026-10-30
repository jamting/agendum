# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Command do
  @moduledoc """
  A command a key can run (ADR 0033): data about it, not the code that
  runs it. `id` is what keymaps (and, later, the person's own bindings)
  name; `name` and `summary` are what the command list and "describe
  key" show, and `doc` a longer text for both, saying why one would use
  the command where that is not obvious (nil: the summary says it all).
  `count` says what a count (ALT-digits) does to it: `:none`
  runs it once, `:repeat` runs it up to n times, `:own` hands the count
  to the command (↓ moves n rows at once). `extra`: one of Agendum's
  extras, which Agenda did not have (ADR 0043): hidden, its keys doing
  nothing, while the Extras preference is off (R77). `label`: the short
  label (at most seven characters, Agenda's) the key bar shows in the slot
  of the key bound to it (ADR 0045), or nil when no bar names it.

  Pure.
  """

  @enforce_keys [:id, :name, :summary]
  defstruct [:id, :name, :summary, doc: nil, count: :none, extra: false, label: nil]

  @type count :: :none | :repeat | :own
  @type t :: %__MODULE__{
          id: atom,
          name: String.t(),
          summary: String.t(),
          doc: String.t() | nil,
          count: count,
          extra: boolean,
          label: String.t() | nil
        }
end
