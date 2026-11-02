# SPDX-License-Identifier: AGPL-3.0-only
defmodule Mix.Tasks.Agendum.Publish do
  @shortdoc "Publishes a file's blog without the screen"
  @moduledoc """
  Publishes the blog of an Agendum file as Extras ▸ Publish ▸ Publish does,
  without the screen (R74; plans/archive/PUBLISHER.md step 7): the site made from
  its folder's templates and assets, written into the folder your Upload
  settings name, and uploaded; then the file saved with what publishing
  keeps. The same as `agendum --publish FILE` in the binary.

      mix agendum.publish FILE             # publish it
      mix agendum.publish FILE --preview   # only say what would change

  Your preferences are read as Agendum reads them (`~/.config/agendum`, or
  under `$XDG_CONFIG_HOME`). A file with a password, and an SFTP server
  that asks for one, are refused: publish those in Agendum. Close the file
  in Agendum first: a file changed meanwhile is not saved over.
  """
  use Mix.Task

  alias Agendum.Extras.Publish.Headless
  alias Agendum.Preferences

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("compile")

    case OptionParser.parse(args, strict: [preview: :boolean]) do
      {opts, [file], []} -> publish(file, opts[:preview] == true)
      _ -> Mix.raise("Usage: mix agendum.publish FILE [--preview]")
    end
  end

  defp publish(file, preview?) do
    env = System.get_env()
    path = Preferences.path(env)
    prefs = if path, do: Preferences.load(path), else: %Preferences{}

    case Headless.run(file, prefs, Agendum.TUI.App.local_today(), preview: preview?) do
      {:ok, lines} -> Enum.each(lines, fn line -> Mix.shell().info(line) end)
      {:error, message} -> Mix.raise(message)
    end
  end
end
