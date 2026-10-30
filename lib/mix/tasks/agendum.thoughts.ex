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
      mix agendum.thoughts --import-docs    # the project's documents into it

  The file is the owner's own and stays outside git: its place is set in
  the shell, `export AGENDUM_PROJECT_FILE=~/Documents/agendum-project.agendum`.
  `--init` never overwrites a file.

  `--import-docs` (meeting 2026-10-22-2309, § 5) puts the meeting agendas and
  minutes, the ADRs, the roadmap and the session summaries into the file
  as Disposable items (`Agendum.Thoughts.import_docs/3`), replacing those
  of the last import. Agendum must be closed and the file saved first: the
  task cannot see whether Agendum has it open, so it says so and asks
  (`--yes` skips the question). It keeps the file as it was beside it,
  `FILE.bak`, and saves the new one in one go. `--docs DIR` reads the
  documents from another checkout than the current folder.
  """
  use Mix.Task

  alias Agendum.Store
  alias Agendum.Thoughts

  @env "AGENDUM_PROJECT_FILE"

  @impl Mix.Task
  def run(args) do
    {opts, rest} =
      OptionParser.parse!(args,
        strict: [
          init: :boolean,
          next_meeting: :boolean,
          import_docs: :boolean,
          yes: :boolean,
          docs: :string
        ]
      )

    path = path(rest)

    cond do
      opts[:init] -> init(path)
      opts[:import_docs] -> import_docs(path, opts)
      true -> print(path, opts)
    end
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

  defp import_docs(path, opts) do
    shell = Mix.shell()

    shell.info(
      "Agendum must be closed and #{Path.basename(path)} saved before the import: " <>
        "it rewrites the file, and changes Agendum has not saved would be lost."
    )

    # `yes?/2` asks on the terminal; `default: :no` makes ENTER alone a no
    if opts[:yes] || shell.yes?("Import anyway?", default: :no) do
      docs = read_docs(opts[:docs] || File.cwd!())

      # `with` runs each step while its pattern matches; the first that
      # does not falls through to `else`
      with {:ok, db} <- Store.load(path),
           {:ok, db, count} <- Thoughts.import_docs(db, docs, Date.utc_today()),
           {:ok, _} <- File.copy(path, path <> ".bak"),
           :ok <- Store.save(db, path) do
        shell.info("Imported #{count} documents into #{path} (the file as it was: #{path}.bak)")
      else
        {:error, reason} -> Mix.raise("Could not import into #{path}: #{inspect(reason)}")
      end
    else
      shell.info("Nothing imported")
    end
  end

  # The documents, as paths relative to the checkout (what
  # `Thoughts.import_docs/3` sorts by) and their text. The meetings'
  # TEMPLATE.md sits beside the meeting folders, not in one, so the
  # pattern leaves it out.
  defp read_docs(root) do
    ["docs/meetings/*/*.md", "docs/adr/*.md", "docs/ROADMAP.md", "docs/summaries/*.md"]
    |> Enum.flat_map(&Path.wildcard(Path.join(root, &1)))
    |> Enum.map(&%{path: Path.relative_to(&1, root), text: File.read!(&1)})
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
