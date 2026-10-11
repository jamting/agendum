defmodule Agenda.Preferences do
  @moduledoc """
  The person's preferences, for every file they open (ADR 0008): the
  colour theme (`theme`, R40), the date languages (`lang` and `fallback`,
  R14c) and the Input format (`Agenda.Core.InputFormat`, R41b). Kept in a plain
  text file, one `key = value` per line, in the config directory
  (`$XDG_CONFIG_HOME/agenda/preferences` or
  `~/.config/agenda/preferences`). A setting left out is the date
  language's; unknown lines are ignored.

  `parse/1` and `format/1` are pure; `load/1` and `save/2` touch the disk
  (imperative shell, like `Agenda.Store`).
  """

  alias Agenda.Core.{DateLanguage, InputFormat}
  alias Agenda.TUI.Theme

  @typedoc """
  `theme` nil and `languages` [] mean the defaults (classic, English);
  `path` is where they are kept (nil: not saved), never written in them.
  """
  @type t :: %__MODULE__{
          theme: Theme.name() | nil,
          languages: [DateLanguage.pack()],
          input: InputFormat.t(),
          path: String.t() | nil
        }
  defstruct theme: nil, languages: [], input: %InputFormat{}, path: nil

  @doc "Where the preferences file is, from the environment; nil without a home."
  @spec path(%{String.t() => String.t()}) :: String.t() | nil
  def path(env) do
    case env do
      %{"XDG_CONFIG_HOME" => dir} when dir != "" -> Path.join([dir, "agenda", "preferences"])
      %{"HOME" => home} when home != "" -> Path.join([home, ".config", "agenda", "preferences"])
      _ -> nil
    end
  end

  @doc "Reads preferences, remembering where; a missing or unreadable file gives the defaults."
  @spec load(String.t()) :: t
  def load(path) do
    case File.read(path) do
      {:ok, text} -> %{parse(text) | path: path}
      {:error, _} -> %__MODULE__{path: path}
    end
  end

  @doc "Writes preferences, making the directory if needed."
  @spec save(t, String.t()) :: :ok | {:error, term}
  def save(prefs, path) do
    with :ok <- File.mkdir_p(Path.dirname(path)), do: File.write(path, format(prefs))
  end

  @doc "Preferences from the file's text."
  @spec parse(String.t()) :: t
  def parse(text) do
    pairs =
      for line <- String.split(text, "\n"),
          not String.starts_with?(String.trim_leading(line), "#"),
          [key, value] <- [String.split(line, "=", parts: 2)],
          do: {String.trim(key), String.trim(value)}

    input =
      Enum.reduce(pairs, %InputFormat{}, fn {key, value}, input ->
        case setting(key, value) do
          {:ok, field, value} -> Map.put(input, field, value)
          :error -> input
        end
      end)

    pick = fn key, read ->
      Enum.find_value(pairs, &(elem(&1, 0) == key && ok(read.(elem(&1, 1)))))
    end

    main = pick.("lang", &DateLanguage.find/1)
    fallback = pick.("fallback", &DateLanguage.find/1)

    %__MODULE__{
      theme: pick.("theme", &Theme.parse/1),
      languages: if(main, do: Enum.uniq([main | List.wrap(fallback)]), else: []),
      input: input
    }
  end

  defp ok({:ok, value}), do: value
  defp ok(:error), do: nil

  @doc """
  One Input format setting from its key and text ("number_order", "dmy"),
  as the file and the command line write it.
  """
  @spec setting(String.t(), String.t()) :: {:ok, atom, term} | :error
  def setting("number_order", value) do
    case Enum.find(InputFormat.orders(), &(Atom.to_string(&1) == String.downcase(value))) do
      nil -> :error
      order -> {:ok, :number_order, order}
    end
  end

  def setting("date_separator", value) when value in ["/", "-", ".", ",", ":"],
    do: {:ok, :separator, value}

  def setting("clock", "12"), do: {:ok, :clock, 12}
  def setting("clock", "24"), do: {:ok, :clock, 24}
  def setting(_key, _value), do: :error

  @doc "The file's text."
  @spec format(t) :: String.t()
  def format(%__MODULE__{input: input} = prefs) do
    {main, fallback} =
      case prefs.languages do
        [main, fallback | _] -> {main.name(), fallback.name()}
        [main] -> {main.name(), nil}
        [] -> {nil, nil}
      end

    lines =
      [
        {"theme", prefs.theme && Atom.to_string(prefs.theme)},
        {"lang", main},
        {"fallback", fallback},
        {"number_order", input.number_order && Atom.to_string(input.number_order)},
        {"date_separator", input.separator},
        {"clock", input.clock && Integer.to_string(input.clock)}
      ]
      |> Enum.reject(&(elem(&1, 1) == nil))
      |> Enum.map(fn {key, value} -> "#{key} = #{value}\n" end)

    "# Agenda preferences: yours, for every file. A setting left out is the\n" <>
      "# default: theme classic, lang english, and for dates your language's.\n" <>
      "# theme: #{Enum.join(Theme.names(), " ")}; lang, fallback: " <>
      Enum.map_join(DateLanguage.packs(), " ", & &1.name()) <>
      "\n# number_order: mdy myd dmy dym ydm ymd; date_separator: / - . , :;\n" <>
      "# clock: 12 or 24.\n" <> Enum.join(lines)
  end
end
