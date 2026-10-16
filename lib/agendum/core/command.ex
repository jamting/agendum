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

  alias Agendum.Core.{Database, Facade.Items}
  alias Agendum.Core.Command.Changes

  @type id :: Database.id()

  @typedoc "A command: what to do, and the ids it acts on."
  @type t ::
          {:toggle_mark, id}
          | {:set_marked, [id], boolean}
          | :unmark_all
          | {:toggle_done, id}
          | {:mark_done, [id]}
          | {:discard_items, [id]}

  @typedoc "Why a command was refused; the front end words it."
  @type error :: :no_such_item | :unknown_command

  # Domain: the list of commands, in the order a help screen shows them:
  # {id, name, summary, the arguments after the id}. Written once, here,
  # so every front end (and an agent's tool list) describes a command in
  # the same words.
  @commands [
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
         {:ok, after_} <- apply_command(db, command, clock) do
      {:ok, after_, Changes.between(db, after_)}
    end
  end

  defp known(command) do
    # a command is a bare atom (`:unmark_all`) or a tuple tagged with one
    name = if is_tuple(command), do: elem(command, 0), else: command
    if name in ids(), do: :ok, else: {:error, :unknown_command}
  end

  # The ids a command names must be items of this file: a front end that
  # sends a stale or made-up id gets a reason, not a crash.
  defp check(db, command) do
    if Enum.all?(item_ids(command), &Map.has_key?(db.items, &1)),
      do: :ok,
      else: {:error, :no_such_item}
  end

  defp item_ids({:set_marked, ids, _marked}), do: ids
  defp item_ids({_name, ids}) when is_list(ids), do: ids
  defp item_ids({_name, id}), do: [id]
  defp item_ids(_command), do: []

  # One clause per command: what it does is a call to the area module that
  # has always done it, so the TUI's old calls and a command give the same
  # result. A command made of several steps (done on several items) loops
  # here, in the core, not in a front end. Each returns `{:ok, db}`, so a
  # command that can fail (an `{:error, reason}`) fits in later.
  defp apply_command(db, {:toggle_mark, id}, _clock), do: {:ok, Items.toggle_mark(db, id)}

  defp apply_command(db, {:set_marked, ids, marked}, _clock),
    do: {:ok, Items.set_marked(db, ids, marked)}

  defp apply_command(db, :unmark_all, _clock), do: {:ok, Items.unmark_all(db)}
  defp apply_command(db, {:toggle_done, id}, clock), do: {:ok, Items.toggle_done(db, id, clock)}

  defp apply_command(db, {:mark_done, ids}, clock),
    do: {:ok, Enum.reduce(ids, db, &Items.mark_done(&2, &1, clock))}

  defp apply_command(db, {:discard_items, ids}, _clock),
    do: {:ok, Enum.reduce(ids, db, &Items.discard_item(&2, &1))}
end
