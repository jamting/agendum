defmodule Agenda.Core.Context do
  @moduledoc """
  The outside facts the core needs to read what the user types: the current
  time and the languages dates are written in (SPEC R14c). The core never
  reads the clock or the command line itself; the shell passes them in.

  Wherever the core takes a "clock", it accepts a `Date`, a
  `NaiveDateTime` or a context; a date or time alone means English.
  """

  alias Agenda.Core.DateLanguage

  @type t :: %__MODULE__{now: NaiveDateTime.t(), languages: [DateLanguage.pack()]}
  @type clock :: Date.t() | NaiveDateTime.t() | t

  defstruct [:now, languages: [DateLanguage.English]]

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

  @doc "Options for `Agenda.Core.DateParser`."
  @spec parser_opts(clock | nil) :: keyword
  def parser_opts(clock), do: [languages: languages(clock)]
end
