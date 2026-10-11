defmodule Agenda.CLI do
  @moduledoc """
  Command-line entry point.

      agenda                  start with a new, untitled file
      agenda FILE             open FILE (created on first save if missing)
      agenda --demo           open the sample file from the patent
      agenda --theme NAME     draw with a theme: classic (default), blue or mono
      agenda --mono           the same as --theme mono
      agenda --lang NAME      read dates in item text in a language:
                              english (default) or swedish
      agenda --fallback NAME  also read dates in a second language
      agenda --number-order O how you type dates: mdy, myd, dmy, dym,
                              ydm or ymd (default: the language's)
      agenda --date-separator S  / - . , or : between a date's numbers
      agenda --clock 12|24    how you type times (default: the language's)

  Your preferences (File ▸ Customize, saved in
  ~/.config/agenda/preferences) give the theme, languages and input
  format; these flags override them for this session. Setting the
  NO_COLOR environment variable selects mono unless --theme or your
  preferences name a theme.
  """

  alias Agenda.{Core, Preferences, Sample, Store}
  alias Agenda.Core.{DateLanguage, InputFormat}
  alias Agenda.TUI.{App, Layout, State, Theme}

  @type options :: %{
          file: String.t() | nil,
          demo: boolean,
          theme: Theme.name(),
          languages: [DateLanguage.pack()],
          input: InputFormat.t(),
          preferences: String.t() | nil
        }

  def main(args) do
    env = System.get_env()
    path = Preferences.path(env)
    prefs = if path, do: Preferences.load(path), else: %Preferences{}

    case parse_args(args, env, prefs) do
      :help -> IO.puts(@moduledoc)
      {:ok, options} -> start(options, prefs)
      {:error, message} -> exit_with(message)
    end
  end

  @doc """
  The options in `args`, given the environment variables `env` and the
  person's preferences: a flag wins, then a preference, then NO_COLOR,
  then the default. Pure.
  """
  @spec parse_args([String.t()], %{String.t() => String.t()}, Preferences.t()) ::
          {:ok, options} | :help | {:error, String.t()}
  def parse_args(args, env, prefs \\ %Preferences{}) do
    {opts, files, invalid} =
      OptionParser.parse(args,
        strict: [
          demo: :boolean,
          help: :boolean,
          mono: :boolean,
          theme: :string,
          lang: :string,
          fallback: :string,
          number_order: :string,
          date_separator: :string,
          clock: :string
        ],
        aliases: [h: :help]
      )

    cond do
      opts[:help] ->
        :help

      invalid != [] ->
        {:error, "Unknown option: #{invalid |> hd() |> elem(0)} (try --help)"}

      true ->
        with {:ok, theme} <- theme(opts, env, prefs),
             {:ok, languages} <- languages(opts, prefs),
             {:ok, input} <- input(opts) do
          {:ok,
           opts
           |> options(files, theme, languages)
           |> Map.merge(%{input: struct(prefs.input, input), preferences: Preferences.path(env)})}
        end
    end
  end

  # NO_COLOR gives way to a theme the person chose (no-color.org)
  defp theme(opts, env, prefs) do
    cond do
      opts[:theme] ->
        with :error <- Theme.parse(opts[:theme]),
             do:
               {:error, "Unknown theme #{opts[:theme]}; choose #{Enum.join(Theme.names(), ", ")}"}

      opts[:mono] ->
        {:ok, :mono}

      prefs.theme ->
        {:ok, prefs.theme}

      Map.get(env, "NO_COLOR", "") != "" ->
        {:ok, :mono}

      true ->
        {:ok, hd(Theme.names())}
    end
  end

  # --lang (else the preferred one, else english), then --fallback (else
  # the preferred fallback) (R14c).
  defp languages(opts, prefs) do
    {preferred, preferred_fallback} =
      case prefs.languages do
        [main | rest] -> {main, List.first(rest)}
        [] -> {DateLanguage.English, nil}
      end

    with {:ok, main} <- if(opts[:lang], do: language(opts[:lang]), else: {:ok, preferred}),
         {:ok, fallback} <-
           if(opts[:fallback], do: language(opts[:fallback]), else: {:ok, preferred_fallback}) do
      {:ok, Enum.uniq([main | List.wrap(fallback)])}
    end
  end

  defp language(name) do
    with :error <- DateLanguage.find(name) do
      names = Enum.map_join(DateLanguage.packs(), ", ", & &1.name())
      {:error, "Unknown language #{name}; choose #{names}"}
    end
  end

  # --number-order, --date-separator and --clock (R41b)
  defp input(opts) do
    [number_order: "number_order", date_separator: "date_separator", clock: "clock"]
    |> Enum.filter(fn {flag, _key} -> opts[flag] end)
    |> Enum.reduce_while({:ok, %{}}, fn {flag, key}, {:ok, acc} ->
      case Preferences.setting(key, opts[flag]) do
        {:ok, field, value} -> {:cont, {:ok, Map.put(acc, field, value)}}
        :error -> {:halt, {:error, bad_input(flag, opts[flag])}}
      end
    end)
  end

  defp bad_input(:number_order, value),
    do:
      "Unknown number order #{value}; choose " <>
        Enum.map_join(InputFormat.orders(), ", ", &Atom.to_string/1)

  defp bad_input(:date_separator, value),
    do: "Unknown date separator #{value}; choose #{Enum.join(InputFormat.separators(), " ")}"

  defp bad_input(:clock, value), do: "Unknown clock #{value}; choose 12 or 24"

  defp options(opts, files, theme, languages),
    do: %{file: List.first(files), demo: opts[:demo] == true, theme: theme, languages: languages}

  defp start(options, prefs) do
    today = App.local_today()

    result =
      cond do
        options.demo -> {:ok, Sample.build(today), nil}
        options.file -> open(Store.normalize_path(options.file))
        true -> {:ok, Core.new_file(), nil}
      end

    case result do
      {:ok, db, path} ->
        state =
          db
          |> State.new(
            path: path,
            today: today,
            now: App.local_now(),
            languages: options.languages,
            input: options.input,
            theme: options.theme,
            prefs: prefs
          )
          |> Layout.settle()

        case App.run(state) do
          :ok -> :ok
          {:error, reason} -> exit_with("Could not start the terminal UI: #{inspect(reason)}")
        end

      {:error, message} ->
        exit_with(message)
    end
  end

  defp open(path) do
    if File.exists?(path) do
      case Store.load(path) do
        {:ok, db} -> {:ok, db, path}
        {:error, reason} -> {:error, "Could not open #{path}: #{inspect(reason)}"}
      end
    else
      {:ok, Core.new_file(), path}
    end
  end

  @spec exit_with(String.t()) :: no_return()
  defp exit_with(message) do
    IO.puts(:stderr, message)
    System.halt(1)
  end
end
