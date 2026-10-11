defmodule Agenda.TUI.DevTools do
  @moduledoc """
  The hidden developer screen (ESC ? or ALT-?, from anywhere but while
  typing): what the program knows right now, for debugging. The program
  and the versions it was built with, the file (format version and
  counts), the session (time, languages, input format, theme,
  preferences, terminal size), the screen (view, cursor, the mode stack,
  top first) and undo depth.

  It also tests keys: every key but ESC is shown as decoded
  (`Agenda.TUI.Keys`), before any alias or global command, and does
  nothing else; ↑↓ PGUP PGDN also scroll. ESC closes it. Not in the
  menus or the F1 help. Pure.
  """

  alias Agenda.Core.{DateFormat, Links}
  alias Agenda.TUI.State

  @version Mix.Project.config()[:version]
  @built_with "#{System.version()} / OTP #{System.otp_release()}"

  def open(state), do: State.push(state, %{type: :devtools, top: 0, key: nil})

  def handle(state, _mode, :esc), do: State.pop(state)

  def handle(state, mode, key) do
    # the body starts with a heading and a blank line
    page = max(State.body_height(state), 1)
    last = max(length(lines(state, mode)) - page, 0)

    top =
      case key do
        :up -> mode.top - 1
        :down -> mode.top + 1
        :pgup -> mode.top - page
        :pgdn -> mode.top + page
        _ -> mode.top
      end

    State.put_mode(state, %{mode | top: top |> min(last) |> max(0), key: key})
  end

  @doc "The screen's lines: a heading (a string) or `{label, value}`."
  @spec lines(State.t(), map) :: [String.t() | {String.t(), String.t()}]
  def lines(state, mode) do
    db = state.db
    kinds = db.categories |> Map.values() |> Enum.frequencies_by(& &1.kind)
    view = State.view(state)

    [
      "Keys",
      {"Last key", if(mode.key, do: inspect(mode.key), else: "(press a key; ESC closes)")},
      "",
      "Screen",
      {"View", "#{view.name} (##{view.id}, #{length(db.view_order)} views in order)"},
      {"Cursor", "row #{state.cursor}, column #{state.col}, scroll #{state.scroll}"},
      {"Cursor key", inspect(state.cursor_key)},
      {"Modes", Enum.map_join(state.modes, " > ", &Atom.to_string(&1.type))},
      {"Edit", if(state.edit, do: inspect(state.edit.target), else: "(none)")},
      {"Undo / redo", "#{length(state.undo)} / #{length(state.redo)}"},
      "",
      "Session",
      {"Now", DateFormat.datetime(state.now, %DateFormat{})},
      {"Languages", Enum.map_join(state.languages, ", ", & &1.name())},
      {"Input format", input(state.input)},
      {"Theme", Atom.to_string(state.theme)},
      {"Preferences", state.prefs.path || "(none)"},
      {"Terminal", "#{state.width}×#{state.height}"},
      {"Key map", if(state.key_map, do: "shown", else: "hidden")},
      "",
      "File",
      {"Path", state.path || "(untitled)"},
      {"Saved", if(state.dirty, do: "no, changed", else: "yes")},
      {"File format", "version #{Agenda.Store.format_version()}"},
      {"Items", "#{map_size(db.items)} (#{Enum.count(Map.values(db.items), & &1.done)} done)"},
      {"Categories",
       "#{map_size(db.categories)} (#{kinds[:standard] || 0} standard, #{kinds[:date] || 0} date, " <>
         "#{kinds[:numeric] || 0} numeric)"},
      {"Views", Integer.to_string(map_size(db.views))},
      {"Assignments", Integer.to_string(Links.size(db.links))},
      {"Dependencies", Integer.to_string(Links.size(db.dependencies))},
      {"Dates, numbers", "#{map_size(db.dates)} user dates, #{map_size(db.numbers)} numbers"},
      {"Next id", Integer.to_string(db.next_id)},
      "",
      "Program",
      {"Wol's Agendum", @version},
      {"Elixir / OTP", @built_with <> " (built with)"}
    ]
  end

  defp input(input) do
    [number_order: input.number_order, separator: input.separator, clock: input.clock]
    |> Enum.map_join(", ", fn {k, v} -> "#{k} #{v || "language's"}" end)
  end
end
