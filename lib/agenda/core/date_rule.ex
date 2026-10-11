defmodule Agenda.Core.DateRule do
  @moduledoc """
  How a date category gets dates (SPEC R6b; Agenda's Advanced settings,
  User's Guide 7-5 to 7-8):

    * `assign` (Assign item date): `:never`; from the clock when the item
      is entered (`:entered`), also each time its text is edited
      (`:item_edited`), its note is edited (`:note_edited`), either
      (`:item_or_note_edited`), it is assigned to another category
      (`:assigned`), or assigned or edited (`:assigned_or_edited`); or
      from a date in the item text (`:item_text`), the note
      (`:note_text`) or the item text and else the note
      (`:item_or_note_text`)
    * `which` (Which one): the nth date in the text, 1–10
    * `done_key`, `when_key`: F4 (DONE) or ALT-F2 (WHEN) sets this date too

  Entry, When and Done have Agenda's defaults (`builtin/1`); a date
  category the user makes starts with Never. Pure.
  """

  @type assign ::
          :never
          | :entered
          | :item_edited
          | :note_edited
          | :item_or_note_edited
          | :assigned
          | :assigned_or_edited
          | :item_text
          | :note_text
          | :item_or_note_text
  @type event :: :entered | :item_edited | :note_edited | :assigned
  @type t :: %__MODULE__{assign: assign, which: 1..10, done_key: boolean, when_key: boolean}

  defstruct assign: :never, which: 1, done_key: false, when_key: false

  @assigns [
    :never,
    :entered,
    :item_edited,
    :note_edited,
    :item_or_note_edited,
    :assigned,
    :assigned_or_edited,
    :item_text,
    :note_text,
    :item_or_note_text
  ]

  @labels %{
    never: "Never",
    entered: "When item is entered",
    item_edited: "When item text is edited",
    note_edited: "When note text is edited",
    item_or_note_edited: "When item or note text is edited",
    assigned: "When item is assigned",
    assigned_or_edited: "When item is assigned or edited",
    item_text: "From the item text",
    note_text: "From the note text",
    item_or_note_text: "From the item or note text"
  }

  # the events that set a date from the clock, for each choice
  @events %{
    entered: [:entered],
    item_edited: [:entered, :item_edited],
    note_edited: [:note_edited],
    item_or_note_edited: [:entered, :item_edited, :note_edited],
    assigned: [:entered, :assigned],
    assigned_or_edited: [:entered, :item_edited, :assigned]
  }

  @doc "Agenda's rule for a built-in date category."
  @spec builtin(:entry | :when | :done) :: t
  def builtin(:entry), do: %__MODULE__{assign: :entered}
  def builtin(:when), do: %__MODULE__{assign: :item_text, when_key: true}
  def builtin(:done), do: %__MODULE__{assign: :never, done_key: true}

  @doc "Every choice for Assign item date, in Agenda's order."
  @spec assigns() :: [assign]
  def assigns, do: @assigns

  @doc "A choice's name as Agenda's box shows it."
  @spec label(assign) :: String.t()
  def label(assign), do: Map.fetch!(@labels, assign)

  @doc "The texts a rule reads dates from, in order, or [] for a clock rule."
  @spec sources(t | nil) :: [:item | :note]
  def sources(%__MODULE__{assign: :item_text}), do: [:item]
  def sources(%__MODULE__{assign: :note_text}), do: [:note]
  def sources(%__MODULE__{assign: :item_or_note_text}), do: [:item, :note]
  def sources(_rule), do: []

  @doc "Whether one of `events` sets the date from the clock."
  @spec stamps?(t | nil, [event]) :: boolean
  def stamps?(%__MODULE__{assign: assign}, events),
    do: Enum.any?(Map.get(@events, assign, []), &(&1 in events))

  def stamps?(nil, _events), do: false

  @doc "The rule with the next (step 1) or previous (-1) choice for one setting."
  @spec cycle(t, :assign | :which | :done_key | :when_key, 1 | -1) :: t
  def cycle(rule, :assign, step), do: %{rule | assign: next(@assigns, rule.assign, step)}
  def cycle(rule, :which, step), do: %{rule | which: Integer.mod(rule.which - 1 + step, 10) + 1}

  def cycle(rule, key, _step) when key in [:done_key, :when_key],
    do: Map.update!(rule, key, &(not &1))

  defp next(list, value, step) do
    index = Enum.find_index(list, &(&1 == value)) || 0
    Enum.at(list, Integer.mod(index + step, length(list)))
  end
end
