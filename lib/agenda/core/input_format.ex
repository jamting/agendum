defmodule Agenda.Core.InputFormat do
  @moduledoc """
  How one person types dates and times (SPEC R41b; Agenda's Input Format
  box, User's Guide 7-17):

    * `number_order`: the order of the numbers of a date in calendar
      notation: `:mdy` ("11/12/90" is 12 November), `:myd`, `:dmy`,
      `:dym`, `:ydm` or `:ymd`; a month and day alone keep the order's
      sequence ("12/11" in DMY is 12 November)
    * `separator` (Input date separator): "/", "-", ".", "," or ":"
      between those numbers, and after a month name ("nov.12")
    * `clock` (Input clock): 12 (times without am/pm fall in the twelve
      hours from Morning, Agenda's way) or 24 (as written)

  `nil` means the date language's: its numeric order, "/" and its clock
  (ADR 0009). Agenda saved these in the file; here they belong to the
  person, as their preferences (ADR 0008, 0013), and reach the parser
  through `Agenda.Core.Context`. Pure.
  """

  @type order :: :mdy | :myd | :dmy | :dym | :ydm | :ymd
  @type t :: %__MODULE__{
          number_order: order | nil,
          separator: String.t() | nil,
          clock: 12 | 24 | nil
        }
  defstruct number_order: nil, separator: nil, clock: nil

  @orders [:mdy, :myd, :dmy, :dym, :ydm, :ymd]
  @separators ["/", "-", ".", ",", ":"]

  @doc "Every number order, as Agenda lists them."
  @spec orders() :: [order]
  def orders, do: @orders

  @doc "Every input date separator."
  @spec separators() :: [String.t()]
  def separators, do: @separators

  @doc "The settings with the next (1) or previous (-1) choice for one; nil (Language) comes first."
  @spec cycle(t, :number_order | :separator | :clock, 1 | -1) :: t
  def cycle(f, :number_order, step), do: %{f | number_order: next(@orders, f.number_order, step)}
  def cycle(f, :separator, step), do: %{f | separator: next(@separators, f.separator, step)}
  def cycle(f, :clock, step), do: %{f | clock: next([12, 24], f.clock, step)}

  defp next(list, value, step) do
    list = [nil | list]
    index = Enum.find_index(list, &(&1 == value)) || 0
    Enum.at(list, Integer.mod(index + step, length(list)))
  end

  @doc ~S|A setting as the box shows it: "DMY", or "Language (DMY)" for the language's.|
  @spec label(t, :number_order | :separator | :clock, [module]) :: String.t()
  def label(f, field, languages) do
    case Map.fetch!(f, field) do
      nil -> "Language (#{value_label(field, language_value(field, hd(languages)))})"
      value -> value_label(field, value)
    end
  end

  defp value_label(:number_order, order), do: order |> Atom.to_string() |> String.upcase()
  defp value_label(:separator, separator), do: separator
  defp value_label(:clock, clock), do: "#{clock} hr"

  @doc "What a language gives when the person sets nothing."
  @spec language_value(:number_order | :separator | :clock, module) ::
          order | String.t() | 12 | 24
  def language_value(:number_order, pack),
    do: if(pack.numeric_order() == :day_month, do: :dmy, else: :mdy)

  def language_value(:separator, _pack), do: "/"
  def language_value(:clock, pack), do: if(pack.clock() == :twenty_four, do: 24, else: 12)

  @doc "Whether the person set how dates are written (order or separator)."
  @spec own_dates?(t) :: boolean
  def own_dates?(f), do: f.number_order != nil or f.separator != nil
end
