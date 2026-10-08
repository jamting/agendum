defmodule Agenda.Core.Item do
  @moduledoc """
  A free-form piece of text, the basic unit of information in Agenda.

  Items exist independently of categories; assignments live in
  `Agenda.Core.Database` as links. Date fields back the special date
  categories Entry, When and Done.

  `when_explicit` is true when the user set the When date directly (in a
  When column or with the When command). Such a date overrides any date
  in the text, and edits to the text no longer change it (SPEC R14).
  """

  @type id :: pos_integer
  @type t :: %__MODULE__{
          id: id,
          text: String.t(),
          note: String.t(),
          entry: Date.t() | nil,
          when: Date.t() | nil,
          done: Date.t() | nil,
          when_explicit: boolean,
          marked: boolean
        }

  defstruct [
    :id,
    text: "",
    note: "",
    entry: nil,
    when: nil,
    when_explicit: false,
    done: nil,
    marked: false
  ]
end
