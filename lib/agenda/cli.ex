defmodule Agenda.CLI do
  @moduledoc """
  Command-line entry point.

      agenda                  start with a new, untitled file
      agenda FILE             open FILE (created on first save if missing)
      agenda --demo           open the sample file from the patent
      agenda --theme NAME     draw with a theme: classic (default) or mono
      agenda --mono           the same as --theme mono

  Setting the NO_COLOR environment variable selects mono unless --theme
  names a theme.
  """

  alias Agenda.{Core, Sample, Store}
  alias Agenda.TUI.{App, Layout, State, Theme}

  @type options :: %{file: String.t() | nil, demo: boolean, theme: Theme.name()}

  def main(args) do
    case parse_args(args, System.get_env()) do
      :help -> IO.puts(@moduledoc)
      {:ok, options} -> start(options)
      {:error, message} -> exit_with(message)
    end
  end

  @doc "The options in `args`, given the environment variables `env`. Pure."
  @spec parse_args([String.t()], %{String.t() => String.t()}) ::
          {:ok, options} | :help | {:error, String.t()}
  def parse_args(args, env) do
    {opts, files, invalid} =
      OptionParser.parse(args,
        strict: [demo: :boolean, help: :boolean, mono: :boolean, theme: :string],
        aliases: [h: :help]
      )

    cond do
      opts[:help] -> :help
      invalid != [] -> {:error, "Unknown option: #{invalid |> hd() |> elem(0)} (try --help)"}
      true -> with {:ok, theme} <- theme(opts, env), do: {:ok, options(opts, files, theme)}
    end
  end

  defp theme(opts, env) do
    cond do
      opts[:theme] ->
        with :error <- Theme.parse(opts[:theme]),
             do:
               {:error, "Unknown theme #{opts[:theme]}; choose #{Enum.join(Theme.names(), ", ")}"}

      opts[:mono] ->
        {:ok, :mono}

      Map.get(env, "NO_COLOR", "") != "" ->
        {:ok, :mono}

      true ->
        {:ok, hd(Theme.names())}
    end
  end

  defp options(opts, files, theme),
    do: %{file: List.first(files), demo: opts[:demo] == true, theme: theme}

  defp start(options) do
    today = App.local_today()

    result =
      cond do
        options.demo -> {:ok, Sample.build(today), nil}
        options.file -> open(Store.normalize_path(options.file))
        true -> {:ok, Core.new_file(), nil}
      end

    case result do
      {:ok, db, path} ->
        state = db |> State.new(path: path, today: today, now: App.local_now()) |> Layout.settle()

        case App.run(state, options.theme) do
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

  defp exit_with(message) do
    IO.puts(:stderr, message)
    System.halt(1)
  end
end
