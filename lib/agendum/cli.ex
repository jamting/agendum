defmodule Agendum.CLI do
  @moduledoc """
  Command-line entry point of Wol's Agendum.

      agendum                   start with a new, untitled file
      agendum FILE              open FILE (created on first save if missing)
      agendum OLD.AG            import a Lotus Agenda file, as OLD.agendum
                                beside it (written on the first save)
      agendum --demo            open the sample file from the patent
      agendum --rabbit          open Rabbit's file from the manual
      agendum --theme NAME      draw with a theme: classic (default), mono,
                                modus-operandi, modus-vivendi, alabaster,
                                zenburn, ayu or borland
      agendum --mono            the same as --theme mono
      agendum --lang NAME       read dates in item text in a language:
                                english (default) or swedish
      agendum --fallback NAME   also read dates in a second language
      agendum --number-order O  how you type dates: mdy, myd, dmy, dym,
                                ydm or ymd (default: the language's)
      agendum --date-separator S  / - . , or : between a date's numbers
      agendum --clock 12|24     how you type times (default: the language's)

  Your preferences (File ▸ Customize, saved in
  ~/.config/agendum/preferences) give the theme, languages and input
  format; these flags override them for this session. Setting the
  NO_COLOR environment variable selects mono unless --theme or your
  preferences name a theme.

  Setting AGENDUM_LOG=1 writes a debug log of each session (keys,
  messages, crashes) to ~/.local/state/agendum/logs, the last five
  sessions kept; AGENDUM_LOG=FOLDER writes it there instead.
  """

  alias Agendum.{Core, Preferences, Sample, Store}
  alias Agendum.Core.{DateLanguage, InputFormat}
  alias Agendum.TUI.{App, DebugLog, Layout, State, Terminal.Theme, Update}

  @type options :: %{
          file: String.t() | nil,
          demo: boolean,
          rabbit: boolean,
          clinic: boolean,
          theme: Theme.name(),
          languages: [DateLanguage.pack()],
          input: InputFormat.t(),
          preferences: String.t() | nil
        }

  # `main/1` is what the escript (the single-file program) calls with the
  # command line; it is the one place where the program starts. Domain: the
  # preferences are read first, because the flags only override them.
  def main(args) do
    env = System.get_env()
    path = Preferences.path(env)
    prefs = if path, do: Preferences.load(path), else: %Preferences{}
    # the splash screen's name when none is set (R52)
    prefs = %{prefs | user: env["USER"]}

    case parse_args(args, env, prefs) do
      :help -> IO.puts(@moduledoc)
      {:ok, options} -> start(options, prefs, DebugLog.start(env, args))
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
          rabbit: :boolean,
          # an Easter egg, not in --help: Christopher Robin's clinic
          clinic: :boolean,
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
    do: %{
      file: List.first(files),
      demo: opts[:demo] == true,
      rabbit: opts[:rabbit] == true,
      clinic: opts[:clinic] == true,
      theme: theme,
      languages: languages
    }

  # `log` is the debug log's path, or nil when it is off
  defp start(options, prefs, log) do
    today = App.local_today()

    # Every way to start ends in the same shape, `{:ok, db, path, stamp}`,
    # with `path` nil for a file that has no name yet (Save then asks for
    # one), and `stamp` nil for a file not on disk yet (R71).
    result =
      cond do
        options.demo -> {:ok, Sample.build(today), nil, nil}
        options.rabbit -> {:ok, Sample.rabbit(today), nil, nil}
        options.clinic -> {:ok, Agendum.Starters.Clinic.build(today), nil, nil}
        options.file -> open(Store.normalize_path(options.file))
        true -> {:ok, Core.new_file(), nil, nil}
      end

    case result do
      # Domain: an Agenda file (R72) is imported as File ▸ Transfer ▸
      # Import does, into an untitled file first; the import gives it its
      # name and shows its report under the splash screen
      {:import, path, bytes} ->
        Core.new_file()
        |> State.new(session(options, prefs, today))
        |> Layout.settle()
        |> Update.imported(path, {:ok, bytes})
        |> Update.start(false)
        |> run_session(log)

      {:ok, db, path, stamp} ->
        # Domain: `State.new/2` sets `saved.db` to the database just read, so
        # the file starts clean; `Update.arrive/1` then rings alarms due while
        # it was closed (R70) without making it dirty; `Update.start/2` puts
        # the splash screen (and, with no file named, the file prompt) on top.
        db
        |> State.new([path: path, stamp: stamp] ++ session(options, prefs, today))
        |> Layout.settle()
        |> Update.arrive()
        |> Update.start(
          options.file == nil and not (options.demo or options.rabbit or options.clinic)
        )
        |> run_session(log)

      {:error, message} ->
        exit_with(message)
    end
  end

  # what `State.new/2` is told about the person and the moment
  defp session(options, prefs, today) do
    [
      today: today,
      now: App.local_now(),
      languages: options.languages,
      input: options.input,
      theme: options.theme,
      prefs: prefs
    ]
  end

  defp run_session(state, log) do
    case run(state, log) do
      :ok -> DebugLog.stop()
      {:error, reason} -> exit_with("Could not start the terminal UI: #{inspect(reason)}")
    end
  end

  # after a crash the terminal is back to normal (App.run/1 restores it),
  # so the log's path can be shown above Elixir's own report
  # A function body can have `catch` (and `rescue`, `after`) without
  # writing `try`. `catch kind, reason` takes any error, exit or throw;
  # `:erlang.raise/3` raises it again unchanged, with its original stacktrace,
  # so the crash report is the real one.
  defp run(state, log) do
    App.run(state)
  catch
    kind, reason ->
      if log, do: IO.puts(:stderr, "Agendum crashed; the debug log is #{log}")
      :erlang.raise(kind, reason, __STACKTRACE__)
  end

  # Domain: a named file that does not exist is not an error: it opens as a
  # new file with that name, written there on the first save.
  # A file that exists but cannot be read stops the program with a message.
  # A Lotus Agenda file (`.AG`, any case) is imported instead (R72).
  defp open(path) do
    cond do
      String.downcase(Path.extname(path)) == ".ag" -> read_agenda(path)
      File.exists?(path) -> open_existing(path)
      true -> {:ok, Core.new_file(), path, nil}
    end
  end

  defp read_agenda(path) do
    case File.read(path) do
      {:ok, bytes} -> {:import, path, bytes}
      {:error, reason} -> {:error, "Could not read #{path}: #{:file.format_error(reason)}"}
    end
  end

  defp open_existing(path) do
    case Store.load_with_stamp(path) do
      {:ok, db, stamp} -> {:ok, db, path, stamp}
      {:error, reason} -> {:error, "Could not open #{path}: #{inspect(reason)}"}
    end
  end

  @spec exit_with(String.t()) :: no_return()
  defp exit_with(message) do
    DebugLog.write("exit: " <> message)
    IO.puts(:stderr, message)
    System.halt(1)
  end
end
