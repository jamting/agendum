defmodule Agendum.Core.Command do
  @moduledoc """
  The command layer (R66, ADR 0036): one named command per user action,
  run by the core.

  A command is data, a tagged tuple such as `{:mark_done, [42, 43]}`. It
  names what it acts on by id, never "the highlighted row", so a front end
  without a cursor (a web page, an agent, a command line) can send it as
  well as the TUI. `run/3` checks the ids, applies the command and returns
  the new database with what changed (`Agendum.Core.Command.Changes`).

  Each command describes itself (`describe/1`): a name and a summary, for
  the help and for a list of commands an agent can call. Commands that
  move the cursor or open a box are the front end's own (ADR 0033); a
  command here is one that changes the database.
  """

  alias Agendum.Core.Database
  alias Agendum.Core.Facade.{Assignments, Items, Views}
  alias Agendum.Core.Command.Changes

  @type id :: Database.id()

  @typedoc """
  Where a new item goes (`{:add_item, text, opts}`), all optional:
  `section:` the category it is filed under (as if typed under that
  section), `after:` the item it follows in the file's order (or `:first`),
  `adjacent:` neighbouring items, nearest first, for an ambiguous automatic
  assignment (R12), `date:` a date category's date and time (a datebook
  slot, R47), and `view_section:` a view and the index of its section, whose
  filters the item is given what they need, so it stays in sight (R28).
  """
  @type add_opts :: [
          section: id | nil,
          after: id | :first | nil,
          adjacent: [id],
          date: {id, Date.t(), Time.t() | nil},
          view_section: {id, non_neg_integer}
        ]

  @typedoc "A command: what to do, and the ids it acts on."
  @type t ::
          {:add_item, String.t(), add_opts}
          | {:edit_item, id, String.t()}
          | {:toggle_mark, id}
          | {:set_marked, [id], boolean}
          | :unmark_all
          | {:toggle_done, id}
          | {:mark_done, [id]}
          | {:discard_items, [id]}

  @typedoc "Why a command was refused; the front end words it."
  @type error ::
          :no_such_item | :no_such_category | :no_such_view | :empty_text | :unknown_command

  # Domain: the list of commands, in the order a help screen shows them:
  # {id, name, summary, the arguments after the id}. Written once, here,
  # so every front end (and an agent's tool list) describes a command in
  # the same words.
  @commands [
    {:add_item, "Add item",
     "Adds an item, filed under a category and by what its text says, as if typed under that section (R21)",
     [:text, :add_opts]},
    {:edit_item, "Edit item",
     "Changes an item's text; it is filed again by what the text now says (R10, R14)",
     [:item, :text]},
    {:toggle_mark, "Mark item", "Marks an item, or unmarks a marked one (R35)", [:item]},
    {:set_marked, "Mark items", "Marks (true) or unmarks (false) a group of items",
     [:items, :boolean]},
    {:unmark_all, "Unmark all", "Unmarks every item in the file", []},
    {:toggle_done, "Done",
     "Marks an item done today, or clears its done date; a recurring item is followed by its next occurrence (R14a)",
     [:item]},
    {:mark_done, "Done (several)",
     "Marks items done today, leaving those already done as they are", [:items]},
    {:discard_items, "Discard items", "Deletes items from the whole file", [:items]}
  ]

  @doc "The ids of every command, in the order a help screen shows them."
  @spec ids() :: [atom]
  # `for {id, _, _, _} <- list` takes each tuple apart and keeps the id; it
  # runs when this module compiles, since `@commands` is a compile-time value.
  def ids, do: for({id, _, _, _} <- @commands, do: id)

  @doc "A command's name, summary and arguments, or nil for an unknown id."
  @spec describe(atom) :: %{id: atom, name: String.t(), summary: String.t(), args: [atom]} | nil
  def describe(id) do
    # `List.keyfind/3` finds the first tuple whose element 0 is `id`.
    case List.keyfind(@commands, id, 0) do
      {id, name, summary, args} ->
        %{id: id, name: name, summary: summary, args: args}

      nil ->
        nil
    end
  end

  @doc """
  Runs a command. The clock is the moment it runs (a date, a date and
  time, or a `Context`), for done dates and the like. Returns the new
  database and what changed, or why the command was refused; a refused
  command changes nothing.
  """
  @spec run(Database.t(), t, Agendum.Core.clock()) ::
          {:ok, Database.t(), Changes.t()} | {:error, error}
  def run(db, command, clock) do
    # `with` as a happy path: each step must match, or its value (an
    # `{:error, reason}`) is returned at once.
    with :ok <- known(command),
         :ok <- check(db, command),
         {:ok, after_, extra} <- apply_command(db, command, clock) do
      # `extra` adds what only the command knows, such as `new:`, the id
      # of the item it made
      {:ok, after_, Map.merge(Changes.between(db, after_), extra)}
    end
  end

  defp known(command) do
    # a command is a bare atom (`:unmark_all`) or a tuple tagged with one
    name = if is_tuple(command), do: elem(command, 0), else: command
    if name in ids(), do: :ok, else: {:error, :unknown_command}
  end

  # The ids a command names must be in this file, each of its kind, and
  # text must not be empty: a front end that sends a stale or made-up id
  # gets a reason, not a crash.
  defp check(db, command) do
    command
    |> refs()
    |> Enum.find_value(:ok, fn ref -> if not exists?(db, ref), do: {:error, missing(ref)} end)
  end

  # What a command refers to: `{:item, id}`, `{:category, id}`,
  # `{:view_section, {view, index}}`, `{:text, text}`.
  defp refs({:add_item, text, opts}) do
    [{:text, text}] ++
      for {key, value} <- opts, value not in [nil, :first], ref = opt_ref(key, value), do: ref
  end

  defp refs({:edit_item, id, text}), do: [{:item, id}, {:text, text}]
  defp refs({:set_marked, ids, _marked}), do: Enum.map(ids, &{:item, &1})
  defp refs({_name, ids}) when is_list(ids), do: Enum.map(ids, &{:item, &1})
  defp refs({_name, id}), do: [{:item, id}]
  defp refs(_command), do: []

  # a `for` filter that is a match (`ref = …`) skips the options that refer
  # to nothing (nil or false)
  defp opt_ref(:section, id), do: {:category, id}
  defp opt_ref(:after, id), do: {:item, id}
  defp opt_ref(:adjacent, ids), do: {:items, ids}
  defp opt_ref(:date, {cat, _date, _time}), do: {:category, cat}
  defp opt_ref(:view_section, view_section), do: {:view_section, view_section}
  defp opt_ref(_key, _value), do: nil

  defp exists?(db, {:item, id}), do: Map.has_key?(db.items, id)
  defp exists?(db, {:items, ids}), do: Enum.all?(ids, &Map.has_key?(db.items, &1))
  defp exists?(db, {:category, id}), do: Map.has_key?(db.categories, id)
  defp exists?(_db, {:text, text}), do: String.trim(text) != ""

  defp exists?(db, {:view_section, {view, index}}) do
    case db.views[view] do
      nil -> false
      view -> index in 0..(length(view.sections) - 1)//1
    end
  end

  defp missing({kind, _}) when kind in [:item, :items], do: :no_such_item
  defp missing({:category, _}), do: :no_such_category
  defp missing({:view_section, _}), do: :no_such_view
  defp missing({:text, _}), do: :empty_text

  # One clause per command: what it does is a call to the area module that
  # has always done it, so the TUI's old calls and a command give the same
  # result. A command made of several steps (done on several items) loops
  # here, in the core, not in a front end. Each returns `{:ok, db, extra}`
  # (`ok/1` when there is nothing extra), so a command that can fail (an
  # `{:error, reason}`) fits in later.
  defp apply_command(db, {:add_item, text, opts}, clock) do
    {db, id} = Items.add_item(db, text, clock, Keyword.delete(opts, :view_section))
    {:ok, in_view_section(db, id, opts[:view_section], clock), %{new: id}}
  end

  defp apply_command(db, {:edit_item, id, text}, clock),
    do: ok(Items.edit_item(db, id, text, clock))

  defp apply_command(db, {:toggle_mark, id}, _clock), do: ok(Items.toggle_mark(db, id))

  defp apply_command(db, {:set_marked, ids, marked}, _clock),
    do: ok(Items.set_marked(db, ids, marked))

  defp apply_command(db, :unmark_all, _clock), do: ok(Items.unmark_all(db))
  defp apply_command(db, {:toggle_done, id}, clock), do: ok(Items.toggle_done(db, id, clock))

  defp apply_command(db, {:mark_done, ids}, clock),
    do: ok(Enum.reduce(ids, db, &Items.mark_done(&2, &1, clock)))

  defp apply_command(db, {:discard_items, ids}, _clock),
    do: ok(Enum.reduce(ids, db, &Items.discard_item(&2, &1)))

  defp ok(db), do: {:ok, db, %{}}

  # A filtered view or section gives a new item what the filters need
  # (R28): the categories they require, and dates and numbers inside their
  # ranges. A special action (R15b) may have discarded the item already.
  defp in_view_section(db, _id, nil, _clock), do: db
  defp in_view_section(db, id, _view_section, _clock) when not is_map_key(db.items, id), do: db

  defp in_view_section(db, id, {view, index}, clock) do
    db =
      db
      |> Views.entry_categories(view, index)
      |> Enum.reduce(db, &Assignments.assign(&2, id, &1, clock))

    Views.apply_entry_values(db, id, Views.entry_values(db, view, index, clock), clock)
  end
end
