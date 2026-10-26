defmodule Agendum.TUI.Boxes.ImportReportBox do
  @moduledoc """
  The report after a Lotus Agenda file was imported (R72): what came over
  (items, categories, views), what was left out or simplified, and the
  items Agendum's own rules file differently from Agenda (+ categories
  Agendum added, − those it did not keep). ↑ ↓ PGUP PGDN scroll it;
  CTRL-P writes it to a text file beside the Agenda file, as CTRL-P
  prints a view; ENTER or ESC closes it. Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :return

  alias Agendum.TUI.Boxes.Box
  alias Agendum.TUI.State
  alias Agendum.TUI.Terminal.Draw

  @doc """
  Opens the report of importing `source` (the Agenda file's path) as the
  file now open.
  """
  @spec open(State.t(), String.t(), Agendum.Core.AgFile.report()) :: State.t()
  def open(state, source, report),
    do: State.push(state, %Agendum.TUI.Modes.AgImport{source: source, report: report, top: 0})

  @doc """
  The report as lines of text, for the box and for the file CTRL-P
  writes; `into` is the name of the Agendum file it became.
  """
  @spec text(String.t(), String.t() | nil, Agendum.Core.AgFile.report()) :: [String.t()]
  def text(source, into, report) do
    counts =
      Enum.join(
        [
          Draw.count(report.items, "item"),
          Draw.count(report.categories, "category", "categories"),
          Draw.count(report.views, "view")
        ],
        ", "
      )

    trashed =
      if report.trashed > 0,
        do: ["#{Draw.count(report.trashed, "discarded item")} in the trash, as in Agenda"],
        else: []

    notes =
      case report.notes do
        [] -> []
        notes -> ["", "Left out or changed:" | Enum.map(notes, &("  • " <> &1))]
      end

    differences =
      case report.differences do
        [] ->
          ["", "Every item is in the categories it was in in Agenda."]

        list ->
          [
            "",
            "Filed differently by Agendum's rules (#{length(list)}):"
            | Enum.map(list, &difference/1)
          ]
      end

    ["#{Path.basename(source)} came over as #{into || "a new file"} (not saved yet):", counts] ++
      trashed ++ notes ++ differences
  end

  defp difference(d) do
    plus = Enum.map(d.only_agendum, &("+" <> &1))
    minus = Enum.map(d.only_agenda, &("−" <> &1))
    "  • #{String.replace(d.text, "\n", " ")}: #{Enum.join(plus ++ minus, " ")}"
  end

  @doc "Where CTRL-P writes the report: beside the Agenda file."
  @spec report_path(String.t()) :: String.t()
  def report_path(source), do: Path.rootname(source) <> "-import.txt"

  @impl Box
  def about(_state, _mode) do
    """
    What came over from the Agenda file: its items, categories and views,
    what was left out or simplified, and the items Agendum's own text
    matching, conditions and actions file differently from Agenda (+ a
    category Agendum added, − one it did not keep). Assignments you made
    by hand in Agenda are all kept.

    ↑ ↓ PGUP PGDN scroll; CTRL-P writes the report to a text file beside
    the Agenda file; ENTER or ESC closes it. The file is not saved yet:
    save it (CTRL-S) to keep it.
    """
  end

  # the scrolling keys: one line, or a page of the room the box has
  @impl Box
  def handle(state, mode, key) do
    step =
      case key do
        :up -> -1
        :down -> 1
        :pgup -> -page(state)
        :pgdn -> page(state)
        _ -> 0
      end

    last = max(length(wrapped(state, mode, width(state, mode))) - page(state), 0)
    State.put_mode(state, %{mode | top: min(max(mode.top + step, 0), last)})
  end

  defp page(state), do: max(state.height - 8, 3)

  # R65
  @impl Box
  def keymap(_mode), do: %{:enter => :close, :esc => :close, {:ctrl, "p"} => :write}

  @impl Box
  def commands(_mode) do
    [
      {:close, "Return", "Close the report"},
      {:write, "Write", "Write the report to a text file"}
    ]
  end

  @impl Box
  def run(state, _mode, :close), do: State.pop(state)

  def run(state, mode, :write) do
    text = Enum.join(lines(state, mode), "\n") <> "\n"
    State.effect(state, {:write_text, report_path(mode.source), text})
  end

  @impl Box
  def title(_state, _mode), do: "Imported from Agenda"

  @impl Box
  def width(state, _mode), do: min(state.width - 8, 72)

  defp lines(state, mode),
    do: text(mode.source, state.path && Path.basename(state.path), mode.report)

  # the lines as the box shows them, wrapped to its width
  defp wrapped(state, mode, inner) do
    state
    |> lines(mode)
    |> Enum.flat_map(fn
      "" -> [""]
      line -> Draw.wrap(line, max(inner - 2, 10))
    end)
  end

  @impl Box
  def content(state, mode, inner, max_rows) do
    wrapped = wrapped(state, mode, inner)
    room = max(max_rows, 3)
    shown = wrapped |> Enum.drop(mode.top) |> Enum.take(room)
    below = length(wrapped) - mode.top - length(shown)

    rows = Enum.map(shown, &[{:box, " " <> &1}])

    if below > 0,
      do: Enum.drop(rows, -1) ++ [[{:dim, " … #{below} more lines: ↓ PGDN"}]],
      else: rows
  end

  @impl Box
  def keys(_state, _mode), do: [{"↑↓", "Scroll"}, {"CTRL-P", "Write"}, {"ENTER/ESC", "Return"}]

  @impl Box
  def help,
    do: "What came over from the Agenda file. CTRL-P writes this report to a text file."
end
