defmodule Agendum.Core.NumberFormat do
  @moduledoc """
  How a numeric column shows its numbers, and which calculations it shows
  at the bottom of each section (SPEC R29; User's Guide 8-6 to 8-7).

    * `symbol`: nil, "%", "$", "¢", "£" or "¥"; "$", "£" and "¥" go
      before the number, "%" and "¢" after it
    * `decimals`: decimal places shown (2); numbers are rounded for display
      but calculated in full
    * `thousands`: whether to group thousands ("1,234.50")
    * `negative`: `:minus` ("-12.50") or `:parens` ("(12.50)")
    * `calcs`: any of `:count`, `:total`, `:average`, `:minimum`,
      `:maximum`, in that order (default: total)
    * `percent`: Display % of total, a "% tot" column beside the numbers
      with each one's share of its section's total (`percent_of/2`)

  The decimal and thousands characters are personal settings (Agenda's
  Utilities Customize), so they are options here, defaulting to "." and
  ",". Pure.
  """

  @type calc :: :count | :total | :average | :minimum | :maximum
  @type t :: %__MODULE__{
          symbol: String.t() | nil,
          decimals: non_neg_integer,
          thousands: boolean,
          negative: :minus | :parens,
          calcs: [calc],
          percent: boolean
        }
  defstruct symbol: nil,
            decimals: 2,
            thousands: false,
            negative: :minus,
            calcs: [:total],
            percent: false

  @doc """
  A number's share of a total, rounded, as the "% tot" column shows it
  ("12%"); "" for no number or a total of 0.
  """
  @spec percent_of(number | nil, number) :: String.t()
  def percent_of(nil, _total), do: ""
  def percent_of(_value, total) when total == 0, do: ""
  def percent_of(value, total), do: "#{round(value / total * 100)}%"

  @symbols [nil, "$", "%", "¢", "£", "¥"]
  @calcs [:count, :total, :average, :minimum, :maximum]
  @after_number ["%", "¢"]

  @doc "The label or currency symbols, in the order the settings offer them."
  def symbols, do: @symbols

  @doc "Every calculation, in display order."
  def calcs, do: @calcs

  @doc """
  Reads a number as typed: an optional sign or parentheses, a label or
  currency symbol, thousands separators, decimals, or scientific notation
  ("3.22e+12").
  """
  @spec parse(String.t(), keyword) :: {:ok, float} | :error
  def parse(text, opts \\ []) do
    decimal = Keyword.get(opts, :decimal, ".")
    thousands = Keyword.get(opts, :thousands, ",")
    text = String.trim(text)

    {negative, text} =
      case Regex.run(~r/^\((.*)\)$/u, text) do
        [_, inner] -> {true, String.trim(inner)}
        nil -> {false, text}
      end

    text = text |> String.replace(Enum.reject(@symbols, &is_nil/1), "") |> String.trim()
    text = text |> String.replace(thousands, "") |> String.replace(decimal, ".")

    with true <- Regex.match?(~r/^[-+]?(\d+\.?\d*|\.\d+)(e[-+]?\d+)?$/i, text),
         {value, ""} <- Float.parse(normalize(text)) do
      if negative and value >= 0, do: {:ok, -value}, else: {:ok, value * 1.0}
    else
      _ -> :error
    end
  end

  # Float.parse wants digits on both sides of the point: "12." and ".5".
  defp normalize(text) do
    text
    |> String.replace(~r/^([-+]?)\./, "\\g{1}0.")
    |> String.replace(~r/\.(?=$|e)/i, ".0")
  end

  @doc """
  A number as the column shows it. With `width:`, a number that does not
  fit is shown in scientific notation instead.
  """
  @spec format(number, t, keyword) :: String.t()
  def format(value, %__MODULE__{} = f, opts \\ []) do
    text = fixed(value, f, opts)

    case opts[:width] do
      width when is_integer(width) and byte_size(text) > width -> scientific(value)
      _ -> text
    end
  end

  defp fixed(value, f, opts) do
    decimal = Keyword.get(opts, :decimal, ".")
    thousands = Keyword.get(opts, :thousands, ",")
    rounded = Float.round(value * 1.0, f.decimals)
    negative = rounded < 0
    digits = :erlang.float_to_binary(abs(rounded), decimals: f.decimals)

    {whole, fraction} =
      case String.split(digits, ".") do
        [whole, fraction] -> {whole, fraction}
        [whole] -> {whole, nil}
      end

    whole = if f.thousands, do: group(whole, thousands), else: whole
    number = if fraction, do: whole <> decimal <> fraction, else: whole

    number =
      cond do
        f.symbol in @after_number -> number <> f.symbol
        f.symbol -> f.symbol <> number
        true -> number
      end

    cond do
      not negative -> number
      f.negative == :parens -> "(" <> number <> ")"
      true -> "-" <> number
    end
  end

  defp group(digits, separator) do
    digits
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.map_join(separator, &Enum.join/1)
    |> String.reverse()
  end

  defp scientific(value) do
    [mantissa, exponent] =
      value |> Kernel.*(1.0) |> :erlang.float_to_binary(scientific: 2) |> String.split("e")

    {sign, digits} =
      case exponent do
        "-" <> d -> {"-", d}
        "+" <> d -> {"+", d}
        d -> {"+", d}
      end

    mantissa <> "e" <> sign <> String.pad_leading(String.trim_leading(digits, "0"), 2, "0")
  end

  @doc "The result of one calculation over the numbers of a section, or nil."
  @spec calculate(calc, [float]) :: float | nil
  def calculate(:count, values), do: length(values) * 1.0
  def calculate(_calc, []), do: nil
  def calculate(:total, values), do: Enum.sum(values)
  def calculate(:average, values), do: Enum.sum(values) / length(values)
  def calculate(:minimum, values), do: Enum.min(values)
  def calculate(:maximum, values), do: Enum.max(values)

  @doc "A calculation's label, as shown at the bottom of a section."
  @spec label(calc) :: String.t()
  def label(calc), do: calc |> Atom.to_string() |> String.upcase()
end
