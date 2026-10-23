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

  `zettel` is the number of the item's Zettel id (R73, ADR 0039), spelled
  as a word by `Agendum.Core.Extras.ZettelId` (`bonalaku`); nil until it is given
  one. An item with an id is a zettel.
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
          zettel: non_neg_integer | nil,
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
    zettel: nil,
    done: nil,
    marked: false
  ]

  @doc """
  The rule and base date of an item that recurs, nil for one that does
  not: no rule, no When date, or done (R14a). A done item counts only on
  its own date, as in Agenda, whose F4 leaves the done one a plain date and
  gives the copy the rule; ours keeps the rule stored, so marking it not
  done again brings it back.
  """
  @spec recurring(t) :: {Agendum.Core.Recurrence.t(), Date.t()} | nil
  def recurring(%__MODULE__{
        recurrence: %Agendum.Core.Recurrence{} = rule,
        when: %Date{} = base,
        done: nil
      }),
      do: {rule, base}

  def recurring(%__MODULE__{}), do: nil
end
