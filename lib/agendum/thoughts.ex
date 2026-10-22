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
  skill to read. `mix agendum.thoughts` is the shell around them. Pure.
  """

  alias Agendum.Core
  alias Agendum.Core.{Database, Item}

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

  defp thought(%Item{} = item), do: %{text: item.text, note: item.note, entry: item.entry}

  defp id(db, name) do
    [id] = Database.find_categories(db, name)
    id
  end
end
