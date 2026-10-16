defmodule Agendum.TUI.Command do
  @moduledoc """
  A command a key can run (ADR 0033): data about it, not the code that
  runs it. `id` is what keymaps (and, later, the person's own bindings)
  name; `name` and `summary` are what the command list and "describe
  key" show, and `doc` a longer text for both, saying why one would use
  the command where that is not obvious (nil: the summary says it all).
  `count` says what a count (ALT-digits) does to it: `:none`
  runs it once, `:repeat` runs it up to n times, `:own` hands the count
  to the command (↓ moves n rows at once).

  Pure.
  """

  @enforce_keys [:id, :name, :summary]
  defstruct [:id, :name, :summary, doc: nil, count: :none]

  @type count :: :none | :repeat | :own
  @type t :: %__MODULE__{
          id: atom,
          name: String.t(),
          summary: String.t(),
          doc: String.t() | nil,
          count: count
        }
end
