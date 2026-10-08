defmodule Agenda.CLI do
  @moduledoc """
  Command-line entry point.

      agenda              start with a new, untitled file
      agenda FILE         open FILE (created on first save if missing)
      agenda --demo       open the sample file from the patent
  """

  alias Agenda.{Core, Sample, Store}
  alias Agenda.TUI.{App, Layout, State}

  def main(args) do
    today = App.local_today()

    result =
      case args do
        ["--demo" | _] -> {:ok, Sample.build(today), nil}
        ["--help" | _] -> :help
        ["-h" | _] -> :help
        [path | _] -> open(Store.normalize_path(path))
        [] -> {:ok, Core.new_file(), nil}
      end

    case result do
      :help ->
        IO.puts(@moduledoc)

      {:ok, db, path} ->
        state = db |> State.new(path: path, today: today) |> Layout.settle()

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

  defp exit_with(message) do
    IO.puts(:stderr, message)
    System.halt(1)
  end
end
