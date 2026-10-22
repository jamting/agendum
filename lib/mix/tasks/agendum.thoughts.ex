defmodule Mix.Tasks.Agendum.Thoughts do
  @shortdoc "Prints the owner's thoughts from their project file"
  @moduledoc """
  Prints the open thoughts in the owner's project file as Markdown
  (`Agendum.Thoughts`), for a session or the `meeting` skill to read. It
  only reads the file; the owner changes it in Agendum.

      mix agendum.thoughts                  # the file in $AGENDUM_PROJECT_FILE
      mix agendum.thoughts PATH             # another file
      mix agendum.thoughts --next-meeting   # only those for the next meeting
      mix agendum.thoughts --init PATH      # make a new file for thoughts

  The file is the owner's own and stays outside git: its place is set in
  the shell, `export AGENDUM_PROJECT_FILE=~/Documents/agendum-project.agendum`.
  `--init` never overwrites a file.
  """
  use Mix.Task

  alias Agendum.Store
  alias Agendum.Thoughts

  @env "AGENDUM_PROJECT_FILE"

  @impl Mix.Task
  def run(args) do
    {opts, rest} = OptionParser.parse!(args, strict: [init: :boolean, next_meeting: :boolean])
    path = path(rest)

    if opts[:init], do: init(path), else: print(path, opts)
  end

  defp init(path) do
    if File.exists?(path), do: Mix.raise("#{path} exists already; --init never overwrites a file")

    case Store.save(Thoughts.new_file(), path) do
      :ok -> Mix.shell().info("Wrote #{path}")
      {:error, reason} -> Mix.raise("Could not write #{path}: #{inspect(reason)}")
    end
  end

  defp print(path, opts) do
    with {:ok, db} <- Store.load(path),
         {:ok, thoughts} <- Thoughts.read(db) do
      Mix.shell().info(Thoughts.to_markdown(thoughts, next_meeting: opts[:next_meeting]))
    else
      {:error, :no_thoughts_category} ->
        Mix.raise("#{path} has no Thoughts category (mix agendum.thoughts --init makes a file)")

      {:error, reason} ->
        Mix.raise("Could not read #{path}: #{inspect(reason)}")
    end
  end

  # the path given, else the environment's; `~` is the home folder
  defp path([path]), do: Path.expand(path)

  defp path([]) do
    case System.get_env(@env) do
      nil -> Mix.raise("Name the file, or set #{@env} to it (mix help agendum.thoughts)")
      path -> Path.expand(path)
    end
  end

  defp path(_), do: Mix.raise("One file at a time (mix help agendum.thoughts)")
end
