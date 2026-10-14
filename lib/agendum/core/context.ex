defmodule Agendum.Core.Context do
  @moduledoc """
  The outside facts the core needs to read what the user types: the current
  time, the languages dates are written in (SPEC R14c) and how the person
  types dates (`Agendum.Core.InputFormat`, R41b). The core never
  reads the clock or the command line itself; the shell passes them in.

  Wherever the core takes a "clock", it accepts a `Date`, a
  `NaiveDateTime` or a context; a date or time alone means English.
  """

  alias Agendum.Core.{DateLanguage, InputFormat}

  @type t :: %__MODULE__{
          now: NaiveDateTime.t(),
          languages: [DateLanguage.pack()],
          input: InputFormat.t()
        }
  @type clock :: Date.t() | NaiveDateTime.t() | t

  defstruct [:now, languages: [DateLanguage.English], input: %InputFormat{}]

  @doc "The current time; a date alone means its midnight."
  @spec now(clock) :: NaiveDateTime.t()
  def now(%__MODULE__{now: now}), do: now
  def now(%NaiveDateTime{} = now), do: now
  def now(%Date{} = today), do: NaiveDateTime.new!(today, ~T[00:00:00])

  @doc "Today's date."
  @spec today(clock) :: Date.t()
  def today(clock), do: clock |> now() |> NaiveDateTime.to_date()

  @doc "The date languages, the main one first."
  @spec languages(clock | nil) :: [DateLanguage.pack()]
  def languages(%__MODULE__{languages: languages}), do: languages
  def languages(_clock), do: [DateLanguage.English]

  @doc "How the person types dates; Agenda's language defaults without a context."
  @spec input(clock | nil) :: InputFormat.t()
  def input(%__MODULE__{input: input}), do: input
  def input(_clock), do: %InputFormat{}

  @doc "How to show and read numbers: the person's separators (R54), or Agenda's."
  @spec number_opts(clock | nil) :: [decimal: String.t(), thousands: String.t()]
  def number_opts(clock), do: clock |> input() |> InputFormat.number_opts()

  @doc """
  Options for `Agendum.Core.DateParser`: the reader's languages and input
  format, and the file's date settings (R14e).
  """
  @spec parser_opts(clock | nil, Agendum.Core.DateSettings.t() | nil) :: keyword
  def parser_opts(clock, settings),
    do: [languages: languages(clock), settings: settings, input: input(clock)]

  @doc """
  Options for reading a date phrase kept in the file (a date filter's
  ends, a datebook's base date), read again each time by whoever opens
  it: as `parser_opts/2`, then English. A file made in English, such as a
  starter file, then works in every language.
  """
  @spec stored_parser_opts(clock | nil, Agendum.Core.DateSettings.t() | nil) :: keyword
  def stored_parser_opts(clock, settings) do
    # Keyword.update!/3 changes one option, keeping the others
    clock
    |> parser_opts(settings)
    |> Keyword.update!(:languages, &Enum.uniq(&1 ++ [DateLanguage.English]))
  end
end
