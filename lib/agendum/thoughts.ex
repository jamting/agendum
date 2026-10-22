defmodule Agendum.Thoughts do
  @moduledoc """
  The owner's thoughts about Agendum, kept in Agendum itself (meeting
  2026-10-22, § 7b): an inbox of ideas, and the ones to bring up at the
  next panel meeting. Workshop tooling, not part of the program.

  The file is the owner's own, outside git: a category Thoughts with a
  child Next meeting, and a Thoughts view showing Next meeting first.
  Assigning a thought to Next meeting puts it on the meeting's agenda;
  marking it done (F4) once the meeting has handled it takes it off.

  `new_file/0` makes such a file, `read/1` takes the open thoughts out of
  one, and `to_markdown/2` writes them for a session or the `meeting`
  skill to read. `import_docs/3` puts the project's documents into the
  file as Disposable items (meeting 2026-10-22-2, § 5). `mix
  agendum.thoughts` is the shell around them. Pure.
  """

  alias Agendum.Core
  alias Agendum.Core.{Database, Item}
  alias Agendum.Core.View.SortKey

  # The documents' home in the file, and a category for each kind, in the
  # order the Documents view shows them. The import owns all of it: every
  # item under Disposable is deleted and made again at each import.
  @disposable "Disposable"
  @kinds [meeting: "Meetings", adr: "ADRs", roadmap: "Roadmap", summary: "Summaries"]
  @view "Documents"

  @typedoc "One thought: its text, its note, and the day it was written."
  @type thought :: %{text: String.t(), note: String.t(), entry: Date.t() | nil}

  @typedoc "The open thoughts: those for the next meeting, and the rest."
  @type t :: %{next_meeting: [thought], others: [thought]}

  @doc "A new file for thoughts: Thoughts ▸ Next meeting, and a Thoughts view."
  @spec new_file() :: Database.t()
  def new_file do
    db = Core.new_file(view_name: "Thoughts", section_name: "Thoughts")
    thoughts = id(db, "Thoughts")

    # Neither category files an item by the words in its text: a thought
    # that mentions "the next meeting" is not therefore for it. (A new
    # file's first section, Thoughts here, is made that way already.)
    {:ok, db, next} = Core.add_category(db, thoughts, "Next meeting", match_name: false)

    # `hd/1` is the first element of a list: the file's only view
    view = hd(db.view_order)

    # Next meeting first. Hide inherited items: a thought for the meeting
    # is also in Thoughts (its parent), and would otherwise show twice.
    db
    |> Core.add_section(view, next, 0)
    |> Core.toggle_view_option(view, :hide_inherited)
    |> Core.toggle_view_option(view, :hide_done)
  end

  @doc """
  The open (not done) thoughts in `db`, split into those assigned to Next
  meeting and the rest, in the file's item order.
  """
  @spec read(Database.t()) :: {:ok, t} | {:error, :no_thoughts_category}
  def read(db) do
    # `case` matches the list of found ids: exactly one Thoughts category,
    # or none (or two, which cannot tell which is meant)
    case Database.find_categories(db, "Thoughts") do
      [thoughts] -> {:ok, split(db, thoughts)}
      _ -> {:error, :no_thoughts_category}
    end
  end

  defp split(db, thoughts) do
    next = Database.find_categories(db, "Next meeting", thoughts)

    # `Enum.split_with/2` gives two lists: those the function holds for,
    # and the others
    {for_meeting, others} =
      db
      |> Database.items_in(thoughts)
      |> Enum.reject(& &1.done)
      |> Enum.split_with(fn item -> Enum.any?(next, &Database.member?(db, item.id, &1)) end)

    %{next_meeting: Enum.map(for_meeting, &thought/1), others: Enum.map(others, &thought/1)}
  end

  @doc """
  The thoughts as Markdown: a heading per group, a list item per thought
  with its date, its note indented under it. `next_meeting: true` writes
  only the next meeting's.
  """
  @spec to_markdown(t, keyword) :: String.t()
  def to_markdown(thoughts, opts \\ []) do
    groups = [{"For the next meeting", thoughts.next_meeting}]

    groups =
      if opts[:next_meeting], do: groups, else: groups ++ [{"Other thoughts", thoughts.others}]

    # `Enum.map_join/3` maps each element and joins the results with "\n"
    Enum.map_join(groups, "\n", fn {heading, list} -> "## #{heading}\n\n" <> list_text(list) end)
  end

  defp list_text([]), do: "(none)\n"
  defp list_text(list), do: Enum.map_join(list, "", &thought_text/1)

  defp thought_text(%{text: text, note: note, entry: entry}) do
    date = if entry, do: " (#{Date.to_iso8601(entry)})", else: ""

    # each line of the note indented two spaces, under the list item
    note_lines =
      note
      |> String.split("\n", trim: true)
      |> Enum.map_join("", &"  #{&1}\n")

    "- #{text}#{date}\n" <> note_lines
  end

  @typedoc "A document to import: its path in the repository and its text."
  @type doc :: %{path: String.t(), text: String.t()}

  @doc """
  Puts the project's documents into `db` as Disposable items (meeting
  2026-10-22-2, § 5): first every item under Disposable is deleted, then
  each document becomes one item, its title (the first `#` heading) the
  item's text and the whole document its note, in Disposable ▸ its kind
  (Meetings, ADRs, Roadmap, Summaries, made when missing). The item's
  Entry date is the document's own: the meeting's folder, the ADR's status
  line, the summary's file name, else `today` (the roadmap). The person's
  categories file the items further by their text, as typed items; dates
  in a title are not taken as When dates. A Documents view, made the
  first time, shows a section per kind, newest first.

  The Markdown stays the original: nothing done to a Disposable item
  survives the next import. Returns the number of items made.
  """
  @spec import_docs(Database.t(), [doc], Date.t()) :: {:ok, Database.t(), non_neg_integer}
  def import_docs(db, docs, today) do
    {db, home} = category(db, @disposable, db.main_id)

    # `Enum.map_reduce/3` walks a list carrying an accumulator (here the
    # database) and also collects a result per element: the kind's id
    {kinds, db} =
      Enum.map_reduce(@kinds, db, fn {kind, name}, db ->
        {db, id} = category(db, name, home)
        {{kind, id}, db}
      end)

    kinds = Map.new(kinds)

    # the old documents go first, so nothing of the last import is left
    db = db |> Database.items_in(home) |> Enum.reduce(db, &Core.discard_item(&2, &1.id))

    imported = for doc <- docs, kind = kind(doc.path), kind != nil, do: {kind, doc}

    db =
      Enum.reduce(imported, db, fn {kind, doc}, db ->
        add_doc(db, kinds[kind], kind, doc, today)
      end)

    {:ok, documents_view(db, Enum.map(@kinds, fn {kind, _} -> kinds[kind] end)), length(imported)}
  end

  # The category `name` under `parent`, made when missing. It files only
  # what is put in it: a thought that mentions "the roadmap" or "meetings"
  # is not a document.
  defp category(db, name, parent) do
    case Database.find_categories(db, name, parent) do
      [id | _] ->
        {db, id}

      [] ->
        {:ok, db, id} = Core.add_category(db, parent, name, match_name: false)
        {db, id}
    end
  end

  # what kind of document a path is, by its folder (nil: not one we import)
  defp kind("docs/meetings/" <> _), do: :meeting
  defp kind("docs/adr/" <> _), do: :adr
  defp kind("docs/ROADMAP.md"), do: :roadmap
  defp kind("docs/summaries/" <> _), do: :summary
  defp kind(_path), do: nil

  # One document as one item, through the facade as a typed item would go
  # (text matching and conditions file it further). Its date is passed as
  # the clock, so the Entry date stamped is the document's; the When date
  # read from a title such as "Session summary, 2026-10-22" is cleared.
  defp add_doc(db, category, kind, doc, today) do
    date = doc_date(kind, doc, today)
    {db, id} = Core.add_item(db, title(doc), date, section: category)

    db
    |> Core.set_note(id, doc.text, date)
    |> Core.set_date_time(id, db.special.when, nil, nil, date)
  end

  # the first `# ` heading, else the file's name
  defp title(doc) do
    case Regex.run(~r/^# +(.+)$/m, doc.text) do
      [_, heading] -> String.trim(heading)
      nil -> Path.basename(doc.path)
    end
  end

  # Where each kind keeps its date: the meeting's folder
  # (`docs/meetings/2026-10-21-2/`), the summary's file name
  # (`2026-10-22-2311.md`), the first date on the ADR's status line
  defp doc_date(kind, doc, today) when kind in [:meeting, :summary],
    do: first_date(doc.path) || today

  defp doc_date(:adr, doc, today) do
    case Regex.run(~r/^\*\*Status:\*\*.*$/m, doc.text) do
      [line] -> first_date(line) || today
      nil -> today
    end
  end

  defp doc_date(:roadmap, _doc, today), do: today

  defp first_date(text) do
    with [iso] <- Regex.run(~r/\d{4}-\d\d-\d\d/, text),
         {:ok, date} <- Date.from_iso8601(iso) do
      date
    else
      _ -> nil
    end
  end

  # The Documents view, made the first time: a section per kind, newest
  # first by Entry date. Kept as the person leaves it afterwards.
  defp documents_view(db, sections) do
    if Enum.any?(Database.views(db), &(&1.name == @view)) do
      db
    else
      {db, view} = Core.add_view(db, @view, sections)
      Core.set_sort(db, view, :view, [%SortKey{on: {:category, db.special.entry}, order: :desc}])
    end
  end

  defp thought(%Item{} = item), do: %{text: item.text, note: item.note, entry: item.entry}

  defp id(db, name) do
    [id] = Database.find_categories(db, name)
    id
  end
end
