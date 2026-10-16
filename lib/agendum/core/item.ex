defmodule Agendum.Core.Item do
  @moduledoc """
  A free-form piece of text, the basic unit of information in Agenda.

  Items exist independently of categories; assignments live in
  `Agendum.Core.Database` as links. Date fields back the special date
  categories Entry, When and Done.

  `when_explicit` is true when the user set the When date directly (in a
  When column or with the When command). Such a date overrides any date
  in the text, and edits to the text no longer change it (SPEC R14).
  `when_time` is the time of day on the When date, if one was given (R14b).

  `recurrence` is the rule of a recurring When date ("every Monday",
  `Agendum.Core.Recurrence`, R14a); the When date is then its base date.

  An alarm rings `alarm_minutes` before the When date and time (R38);
  once it has rung, `alarm_rung_at` records when it was due (R70), for
  the list of past alarms.
  """

  @type id :: pos_integer
  @type t :: %__MODULE__{
          id: id,
          text: String.t(),
          note: String.t(),
          entry: Date.t() | nil,
          when: Date.t() | nil,
          done: Date.t() | nil,
          when_time: Time.t() | nil,
          when_explicit: boolean,
          recurrence: Agendum.Core.Recurrence.t() | nil,
          alarm_minutes: 0..60 | nil,
          alarm_rung_at: NaiveDateTime.t() | nil,
          marked: boolean
        }

  defstruct [
    :id,
    text: "",
    note: "",
    entry: nil,
    when: nil,
    when_time: nil,
    when_explicit: false,
    recurrence: nil,
    alarm_minutes: nil,
    alarm_rung_at: nil,
    done: nil,
    marked: false
  ]
end
