defmodule Agenda.Core.Item do
  @moduledoc """
  A free-form piece of text, the basic unit of information in Agenda.

  Items exist independently of categories; assignments live in
  `Agenda.Core.Database` as links. Date fields back the special date
  categories Entry, When and Done.
  """

  @type id :: pos_integer
  @type t :: %__MODULE__{
          id: id,
          text: String.t(),
          note: String.t(),
          entry: Date.t() | nil,
          when: Date.t() | nil,
          done: Date.t() | nil,
          marked: boolean
        }

  defstruct [:id, text: "", note: "", entry: nil, when: nil, done: nil, marked: false]
end
