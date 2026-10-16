defmodule Agendum.Core.Context do
  @moduledoc """
  The outside facts the core needs to read what the user types: the current
  time, the languages dates are written in (SPEC R14c) and how the person
  types dates (`Agendum.Core.InputFormat`, R41b). The core never
  reads the clock or the command line itself; the shell passes them in.

  Wherever the core takes a "clock", it accepts a `Date`, a
  `NaiveDateTime` or a context; a date or time alone means English.

  A context can also carry the date rules compiled for its languages and
  input format (`prepare/1`): compiling them is most of the cost of
  reading a date, and the core cannot keep them anywhere else (it has no
  processes). They are kept by the languages and input format they were
  made for, so a context whose languages or input format changed since
  simply compiles again.
  """

  alias Agendum.Core.{DateLanguage, DateParser, InputFormat}

  # `now` is nil in a context kept without the time (a shell's reader,
  # `Agendum.TUI.State`), which gets it before it is used as a clock
  @type t :: %__MODULE__{
          now: NaiveDateTime.t() | nil,
          languages: [DateLanguage.pack()],
          input: InputFormat.t(),
          rules: %{optional({[DateLanguage.pack()], InputFormat.t()}) => DateParser.rules()}
        }
  @type clock :: Date.t() | NaiveDateTime.t() | t

  defstruct [:now, languages: [DateLanguage.English], input: %InputFormat{}, rules: %{}]

  @doc """
  Compiles the date rules for the context's languages, and for them with
  English after (`stored_parser_opts/2`), for its input format. A shell
  keeps the result while the languages and input format stay the same.
  """
  @spec prepare(t) :: t
  def prepare(%__MODULE__{languages: languages, input: input} = context) do
    rules =
      for langs <- Enum.uniq([languages, stored_languages(languages)]),
          into: %{},
          do: {{langs, input}, DateParser.compile_rules(langs, input)}

    %{context | rules: rules}
  end

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
  def parser_opts(clock, settings), do: opts(clock, languages(clock), settings)

  @doc """
  Options for reading a date phrase kept in the file (a date filter's
  ends, a datebook's base date), read again each time by whoever opens
  it: as `parser_opts/2`, then English. A file made in English, such as a
  starter file, then works in every language.
  """
  @spec stored_parser_opts(clock | nil, Agendum.Core.DateSettings.t() | nil) :: keyword
  def stored_parser_opts(clock, settings),
    do: opts(clock, stored_languages(languages(clock)), settings)

  defp stored_languages(languages), do: Enum.uniq(languages ++ [DateLanguage.English])

  # The parser's options for `languages`, with their compiled rules when
  # the context has them for these languages and its input format.
  defp opts(clock, languages, settings) do
    input = input(clock)

    rules =
      case clock do
        %__MODULE__{rules: rules} -> Map.get(rules, {languages, input})
        _date_or_time -> nil
      end

    [languages: languages, settings: settings, input: input, rules: rules]
  end
end
