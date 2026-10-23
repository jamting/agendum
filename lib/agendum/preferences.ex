defmodule Agendum.Preferences do
  @moduledoc """
  The person's preferences, for every file they open (ADR 0008): the
  colour theme (`theme`, R40), the date languages (`lang` and `fallback`,
  R14c) and the Input format (`Agendum.Core.InputFormat`, R41b), and where
  they left each file (`Agendum.Preferences.Place`, R69). Kept in a plain
  text file, one `key = value` per line, in the config directory
  (`$XDG_CONFIG_HOME/agendum/preferences` or
  `~/.config/agendum/preferences`; ADR 0019). A setting left out is the date
  language's; unknown lines are ignored.

  `parse/1` and `format/1` are pure; `load/1` and `save/2` touch the disk
  (imperative shell, like `Agendum.Store`).
  """

  alias Agendum.Core.{DateLanguage, InputFormat}
  alias Agendum.Preferences.Place
  alias Agendum.TUI.Terminal.Theme

  @typedoc """
  `theme` nil and `languages` [] mean the defaults (classic, English);
  `name` and `company` are shown on the splash screen, `last_file` is
  offered when Agendum starts without one (R52). `key_map`: whether the
  key bar shows; `confirm`: whether "are you sure?" questions are asked
  (Confirm mode); `auto_save`: minutes without a key before unsaved
  changes are saved, 0 for never (all R54). `sound`: whether Agendum
  makes Agenda's sounds at all, `beep_completion`: whether automatic
  completion beeps (Agenda's Beep on auto-completion; both R76). `extras`:
  whether the extras show, Agendum's own features that Agenda did not have
  (R77, ADR 0043; off unless the person turns it on). `places`: where the person
  left each file, by its path, the file left last first (R69). `path` is where they are
  kept (nil: not saved) and `user` the login name (the splash's name when
  none is set); neither is written in them.
  """
  @type t :: %__MODULE__{
          theme: Theme.name() | nil,
          languages: [DateLanguage.pack()],
          input: InputFormat.t(),
          name: String.t() | nil,
          company: String.t() | nil,
          last_file: String.t() | nil,
          key_map: boolean,
          confirm: boolean,
          auto_save: 0..60,
          sound: boolean,
          beep_completion: boolean,
          extras: boolean,
          places: [{String.t(), Place.t()}],
          path: String.t() | nil,
          user: String.t() | nil
        }
  defstruct theme: nil,
            languages: [],
            input: %InputFormat{},
            name: nil,
            company: nil,
            last_file: nil,
            key_map: true,
            confirm: true,
            auto_save: 0,
            sound: true,
            beep_completion: true,
            extras: false,
            places: [],
            path: nil,
            user: nil

  # how many files' places are kept: the ones used longest ago are forgotten
  @places 50

  @doc "Where the preferences file is, from the environment; nil without a home."
  @spec path(%{String.t() => String.t()}) :: String.t() | nil
  def path(env) do
    case env do
      %{"XDG_CONFIG_HOME" => dir} when dir != "" -> Path.join([dir, "agendum", "preferences"])
      %{"HOME" => home} when home != "" -> Path.join([home, ".config", "agendum", "preferences"])
      _ -> nil
    end
  end

  @doc """
  Reads preferences, remembering where; a missing or unreadable file gives
  the defaults. Without one, the file from before the rename
  (`…/agenda/preferences`) is read, and the next save writes the new one.
  """
  @spec load(String.t()) :: t
  def load(path) do
    case File.read(path) do
      {:ok, text} -> %{parse(text) | path: path}
      {:error, _} -> load_old(path)
    end
  end

  defp load_old(path) do
    old = Path.join([path |> Path.dirname() |> Path.dirname(), "agenda", Path.basename(path)])

    case Path.basename(Path.dirname(path)) == "agendum" && File.read(old) do
      {:ok, text} -> %{parse(text) | path: path}
      _ -> %__MODULE__{path: path}
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

    text = fn key -> pick.(key, &if(&1 == "", do: :error, else: {:ok, &1})) end

    %__MODULE__{
      theme: pick.("theme", &Theme.parse/1),
      languages: if(main, do: Enum.uniq([main | List.wrap(fallback)]), else: []),
      input: input,
      name: text.("name"),
      company: text.("company"),
      last_file: text.("last_file"),
      key_map: pick.("key_map", &yes_no/1) != :no,
      confirm: pick.("confirm", &yes_no/1) != :no,
      auto_save: pick.("auto_save", &minutes/1) || 0,
      sound: pick.("sound", &yes_no/1) != :no,
      beep_completion: pick.("beep_on_completion", &yes_no/1) != :no,
      # off unless the file says yes, where the others are on unless it says no
      extras: pick.("extras", &yes_no/1) == :yes,
      places: places(pairs)
    }
  end

  # every `place` line, in the order written (the file left last first);
  # a second line for the same file is ignored
  defp places(pairs) do
    for({"place", value} <- pairs, {:ok, path, place} <- [Place.parse(value)], do: {path, place})
    |> Enum.uniq_by(&elem(&1, 0))
    |> Enum.take(@places)
  end

  @doc "Where the person left the file at `path` (R69), or nil."
  @spec place(t, String.t() | nil) :: Place.t() | nil
  def place(_prefs, nil), do: nil

  def place(prefs, path) do
    # `List.keyfind/3` finds the first tuple whose element 0 is `path`
    case List.keyfind(prefs.places, path, 0) do
      {^path, place} -> place
      nil -> nil
    end
  end

  @doc """
  Keeps where the person left the file at `path` (R69): it goes first, as
  the file left last, and only the last #{@places} files are kept.
  """
  @spec put_place(t, String.t(), Place.t()) :: t
  def put_place(prefs, path, %Place{} = place) do
    places = [{path, place} | List.keydelete(prefs.places, path, 0)]
    %{prefs | places: Enum.take(places, @places)}
  end

  defp minutes(value) do
    case Integer.parse(value) do
      {n, ""} when n in 0..60 -> {:ok, n}
      _ -> :error
    end
  end

  # :yes or :no (not booleans, which `pick` would take for "not found")
  defp yes_no(value) do
    case String.downcase(value) do
      "yes" -> {:ok, :yes}
      "no" -> {:ok, :no}
      _ -> :error
    end
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

  def setting("decimal_separator", value) when value in [".", ","], do: {:ok, :decimal, value}
  def setting("thousands_separator", "space"), do: {:ok, :thousands, " "}

  def setting("thousands_separator", value) when value in [",", "."],
    do: {:ok, :thousands, value}

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

    # only what differs from the default
    lines =
      ([
         {"theme", prefs.theme && Atom.to_string(prefs.theme)},
         {"lang", main},
         {"fallback", fallback},
         {"number_order", input.number_order && Atom.to_string(input.number_order)},
         {"date_separator", input.separator},
         {"clock", input.clock && Integer.to_string(input.clock)},
         {"decimal_separator", input.decimal},
         {"thousands_separator", if(input.thousands == " ", do: "space", else: input.thousands)},
         {"name", prefs.name},
         {"company", prefs.company},
         {"last_file", prefs.last_file},
         {"key_map", if(prefs.key_map, do: nil, else: "no")},
         {"confirm", if(prefs.confirm, do: nil, else: "no")},
         {"auto_save", if(prefs.auto_save > 0, do: Integer.to_string(prefs.auto_save))},
         {"sound", if(prefs.sound, do: nil, else: "no")},
         {"beep_on_completion", if(prefs.beep_completion, do: nil, else: "no")},
         {"extras", if(prefs.extras, do: "yes")}
       ] ++ Enum.map(prefs.places, fn {path, place} -> {"place", Place.format(path, place)} end))
      |> Enum.reject(&(elem(&1, 1) == nil))
      |> Enum.map(fn {key, value} -> "#{key} = #{value}\n" end)

    "# Wol's Agendum preferences: yours, for every file. A setting left out is the\n" <>
      "# default: theme classic, lang english, and for dates your language's.\n" <>
      "# theme: #{Enum.join(Theme.names(), " ")}; lang, fallback: " <>
      Enum.map_join(DateLanguage.packs(), " ", & &1.name()) <>
      "\n# number_order: mdy myd dmy dym ydm ymd; date_separator: / - . , :;\n" <>
      "# clock: 12 or 24; decimal_separator: . or ,; thousands_separator: , . or space.\n" <>
      "# name, company: shown when Agendum starts;\n" <>
      "# last_file: the file offered then (kept by Agendum); key_map, confirm: yes or no;\n" <>
      "# auto_save: minutes without a key before saving, 1 to 60 (0: never).\n" <>
      "# sound, beep_on_completion: yes or no.\n" <>
      "# extras: yes shows Agendum's extras (blog, feeds, Zettel ids, calendars …).\n" <>
      "# place: where you left a file (kept by Agendum), the file left last first.\n" <>
      Enum.join(lines)
  end
end
