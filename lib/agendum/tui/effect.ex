defmodule Agendum.TUI.Effect do
  @moduledoc """
  Every side effect the pure TUI can ask the shell for: the closed list.

  `Agendum.TUI.Update.handle/2` and `tick/2` return a list of effects, plain
  data such as `{:save, path, opts}`; `Agendum.TUI.App` carries them out and
  hands each result back to a pure function of `Update`. A new kind of
  effect is added here, in `t/0` and `known?/1`, and gets a clause in
  `App.run_effects/2`. An effect `App` still does not know is written to the
  debug log and skipped, not a crash (a `:bell` crashed the shell on
  2026-10-17); the tests (`app_effects_test.exs`, the fuzz walks) check
  that every effect asked for is on this list.
  """

  alias Agendum.Core.Database

  # Domain: the shapes, with what `App` does for each:
  #   :quit                     stop the loop
  #   {:play, keys}             a macro's keys, played before the next key
  #   {:sound, name}            one of Agenda's sounds (R76)
  #   {:save, …} {:load, …} {:open_or_create, …}   the file itself
  #   {:save_copy, path, db}    a copy or template of it (R82)
  #   {:trash_file, path}       another file to the system's Trash (R82)
  #   {:backup_file, path}      the file opened, copied to NAME.agendum.bak (R82)
  #   {:read_descriptions, dir, names}  files' descriptions, for F8 (R82)
  #   {:write_text, …} {:import_json, …} {:read_note_text, …} {:read_opml, …}
  #   {:list_dir, dir}          a folder for the file list
  #   {:save_preferences, …}    the preferences file (R52)
  #   {:fetch_feed, …} {:fetch_calendar, …} {:open_url, …}  the network
  #   {:publish_scan, …} {:publish, …}  the micro-blog (R74)
  @typedoc "A side effect for the shell to carry out."
  @type t ::
          :quit
          | {:play, [term]}
          | {:sound, Agendum.TUI.Sound.name()}
          | {:save, String.t(), save_opts}
          | {:save_copy, String.t(), Database.t()}
          | {:trash_file, String.t()}
          | {:backup_file, String.t()}
          | {:read_descriptions, String.t(), [String.t()]}
          | {:load, String.t()}
          | {:open_or_create, String.t()}
          | {:write_text, String.t(), String.t()}
          | {:import_json, String.t()}
          | {:read_note_text, String.t()}
          | {:read_opml, String.t()}
          | {:list_dir, String.t()}
          | {:save_preferences, String.t(), Agendum.Preferences.t()}
          | {:fetch_feed, Database.id(), String.t()}
          | {:fetch_calendar, Database.id(), String.t()}
          | {:open_url, String.t()}
          | {:publish_scan, String.t(), [{String.t(), String.t()}]}
          | {:publish, String.t(), [{String.t(), String.t()}], map, String.t() | nil}

  @typedoc """
  How a save is made (`Agendum.TUI.State.save/3`): the file it expects on
  disk (R71), what to do once saved, and whether it is an auto-save (R54).
  """
  @type save_opts :: %{expect: term, then: term, auto: boolean}

  @doc """
  Whether `effect` has one of the shapes of `t/0`, so `App` knows it. The
  tests call it on every effect the TUI returns.
  """
  # One clause per shape, as in `t/0`; `is_binary/1` and friends are
  # guards, the only calls allowed after `when`.
  @spec known?(term) :: boolean
  def known?(:quit), do: true
  def known?({:play, keys}) when is_list(keys), do: true
  def known?({:sound, name}) when is_atom(name), do: true
  def known?({:save, path, %{expect: _, then: _, auto: _}}) when is_binary(path), do: true
  def known?({:save_copy, path, %Database{}}) when is_binary(path), do: true

  def known?({tag, path})
      when tag in [
             :load,
             :open_or_create,
             :import_json,
             :read_note_text,
             :read_opml,
             :list_dir,
             :trash_file,
             :backup_file
           ] and
             is_binary(path),
      do: true

  def known?({:write_text, path, _text}) when is_binary(path), do: true
  def known?({:read_descriptions, dir, names}) when is_list(names), do: is_binary(dir)
  def known?({:save_preferences, path, _prefs}) when is_binary(path), do: true

  def known?({tag, id, url}) when tag in [:fetch_feed, :fetch_calendar] and is_binary(url),
    do: is_integer(id)

  def known?({:open_url, url}) when is_binary(url), do: true
  def known?({:publish_scan, folder, files}) when is_list(files), do: is_binary(folder)

  def known?({:publish, folder, files, _changes, _password}) when is_list(files),
    do: is_binary(folder)

  def known?(_), do: false
end
