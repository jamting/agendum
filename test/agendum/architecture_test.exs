defmodule Agendum.ArchitectureTest do
  @moduledoc """
  Guards the layering described in docs/DATA_ACCESS.md and CLAUDE.md's
  architecture rules: the TUI may read the database through
  `Agendum.Core.Database` queries, but every change goes through the
  `Agendum.Core` facade; and the core is pure.

  The calls are read from the compiled modules with OTP's `:xref`, so an
  alias, an import or a line split across two cannot hide one. A struct
  update (`%{state.db | …}`) is not a call; it is found in the parsed
  source instead.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core.Database

  # Every call between functions in the compiled app, as
  # {{module, function, arity}, {module, function, arity}}, read once.
  setup_all do
    # :xref is in OTP's tools application, put on the code path by
    # test/test_helper.exs; the escript is unchanged.
    {:ok, xref} =
      :xref.start(xref_mode: :functions, builtins: true, verbose: false, warnings: false)

    ebin = String.to_charlist(Mix.Project.compile_path())
    {:ok, _modules} = :xref.add_directory(xref, ebin, warnings: false, verbose: false)
    {:ok, calls} = :xref.q(xref, ~c"E")
    :xref.stop(xref)
    %{calls: calls}
  end

  defp in?(module, prefix) do
    name = Atom.to_string(module)
    name == "Elixir." <> prefix or String.starts_with?(name, "Elixir." <> prefix <> ".")
  end

  # --- The TUI changes the database only through Agendum.Core -------------

  # A write is any public Database function whose spec returns a database
  # (`t`, alone or in a tuple), so a new one is covered without a list. A
  # function with default arguments shares the spec of its longest form.
  defp writes do
    {:ok, specs} = Code.Typespec.fetch_specs(Database)

    for {{name, arity}, clauses} <- specs,
        {:type, _, :fun, [_args, result]} <- clauses,
        returns_db?(result),
        shorter <- 0..arity,
        function_exported?(Database, name, shorter),
        into: MapSet.new(),
        do: {name, shorter}
  end

  defp returns_db?({:user_type, _, :t, []}), do: true
  defp returns_db?({:type, _, _, args}) when is_list(args), do: Enum.any?(args, &returns_db?/1)
  defp returns_db?(_type), do: false

  test "every public Database function has a spec, so it is known to read or write" do
    {:ok, specs} = Code.Typespec.fetch_specs(Database)

    covered =
      for {{name, arity}, _} <- specs,
          shorter <- 0..arity,
          into: MapSet.new(),
          do: {name, shorter}

    missing =
      for {name, arity} <- Database.__info__(:functions),
          name != :__struct__,
          {name, arity} not in covered,
          do: "#{name}/#{arity}"

    assert missing == [], "add a @spec to Agendum.Core.Database: " <> Enum.join(missing, ", ")
  end

  test "the TUI changes the database only through Agendum.Core", %{calls: calls} do
    writes = writes()

    violations =
      for {{from, f, a}, {Database, name, arity}} <- calls,
          in?(from, "Agendum.TUI"),
          {name, arity} in writes,
          uniq: true,
          do: "#{inspect(from)}.#{f}/#{a} calls Database.#{name}/#{arity}"

    assert violations == [], """
    Direct database writes from the TUI (use or add an Agendum.Core function instead):

      #{Enum.join(violations, "\n  ")}
    """
  end

  test "the TUI updates no database struct by hand" do
    violations =
      for path <- Path.wildcard("lib/agendum/tui/**/*.ex"),
          {line, what} <- db_updates(path),
          do: "#{path}:#{line}: #{what}"

    assert violations == [], """
    The TUI changes a database by hand (use or add an Agendum.Core function instead):

      #{Enum.join(violations, "\n  ")}
    """
  end

  # `%{db | …}`, `%{state.db | …}`, and put_in/update_in on a path through
  # a `.db` field, found by walking the parsed source (`Macro.prewalk/3`).
  defp db_updates(path) do
    {:ok, ast} = path |> File.read!() |> Code.string_to_quoted()

    {_ast, found} =
      Macro.prewalk(ast, [], fn
        {:%{}, meta, [{:|, _, [target, _changes]}]} = node, acc ->
          if db?(target),
            do: {node, [{meta[:line], "%{#{Macro.to_string(target)} | …}"} | acc]},
            else: {node, acc}

        {fun, meta, [target | _]} = node, acc when fun in [:put_in, :update_in, :pop_in] ->
          if through_db?(target),
            do: {node, [{meta[:line], "#{fun}(#{Macro.to_string(target)}, …)"} | acc]},
            else: {node, acc}

        node, acc ->
          {node, acc}
      end)

    Enum.reverse(found)
  end

  # a variable called db, or any `something.db`
  defp db?({:db, _, context}) when is_atom(context), do: true
  defp db?({{:., _, [_struct, :db]}, _, []}), do: true
  defp db?(_), do: false

  # a put_in path whose root passes through a `.db` field
  defp through_db?(target) do
    {_, found} = Macro.prewalk(target, false, fn node, acc -> {node, acc or db?(node)} end)
    found
  end

  # --- The command layer (R66, ADR 0036) -----------------------------------

  # Agendum.Core functions a command does, by name (any arity): the ones
  # a command calls by its own name (`Command.runs/0`), and those inside
  # the commands written out in `Agendum.Core.Command` (`:own`).
  defp by_command do
    named = for {id, _kinds, how} <- Agendum.Core.Command.runs(), how in [:core, :clock], do: id
    own = [:add_item, :edit_item, :mark_done, :discard_item, :move_item, :execute]
    MapSet.new(named ++ own ++ [:ring_alarms, :clear_old_alarms, :apply_entry_values])
  end

  # Commands the TUI does not send yet: the command layer moves them
  # over in batches (ROADMAP), and this list only shrinks.
  @not_yet ~w(
    add_category
    add_column
    add_column_as
    add_condition
    add_datebook_view
    add_macro
    add_section
    add_view
    attach_macro
    calendar_failed
    clear_old_alarms
    cycle_calendar_setting
    cycle_condition
    cycle_filter
    delete_macro
    discard_category
    discard_view
    execute
    find_or_add_category
    fit_column
    make_date
    make_exclusive
    make_numeric
    make_unexclusive
    move_category
    move_column
    move_macro
    move_section
    move_view
    reassign_all
    recheck_conditions
    relocate
    remove_action
    remove_column
    remove_condition
    remove_filter
    remove_section
    rename_category
    rename_macro
    rename_view
    resize_column
    ring_alarms
    set_action
    set_all_sections_collapsed
    set_also_match
    set_column_date_format
    set_column_display
    set_column_format
    set_column_head
    set_column_linked
    set_column_width
    set_confirm_assignments
    set_date_format
    set_date_rule
    set_date_settings
    set_datebook
    set_filters
    set_insert_columns
    set_item_column
    set_item_column_linked
    set_macro_keys
    set_macro_run_from
    set_match_override
    set_match_settings
    set_range_condition
    set_range_filter
    set_section_calcs
    set_section_category
    set_section_collapsed
    set_section_sort
    set_short_name
    set_sort
    set_special_action
    show_items
    show_match
    show_schedule
    sort_children
    sort_macros
    sort_views
    subscribe_calendar
    sync_calendar
    toggle_auto_date
    toggle_exclude
    toggle_match_name
    toggle_section_collapsed
    toggle_view_option
    unsubscribe_calendar
  )a

  test "the TUI sends a command where the core has one", %{calls: calls} do
    by_command = MapSet.difference(by_command(), MapSet.new(@not_yet))

    violations =
      for {{from, f, a}, {Agendum.Core, name, arity}} <- calls,
          in?(from, "Agendum.TUI"),
          name in by_command,
          uniq: true,
          do: "#{inspect(from)}.#{f}/#{a} calls Core.#{name}/#{arity}"

    assert violations == [], """
    The TUI calls a core function that a command does (use State.run/2):

      #{Enum.join(violations, "\n  ")}
    """
  end

  test "every function waiting for its command is still called (else take it off @not_yet)",
       %{calls: calls} do
    called =
      for {{from, _, _}, {Agendum.Core, name, _}} <- calls,
          in?(from, "Agendum.TUI"),
          into: MapSet.new(),
          do: name

    assert Enum.reject(@not_yet, &(&1 in called)) == []
  end

  # How many Agendum.Core functions the TUI still calls directly, reads
  # included. It may only go down: when a step of the command layer moves
  # more actions into commands, lower it to the new count. The command
  # layer is done when only reads are left (ROADMAP, Towards many users).
  @core_calls_at_most 116

  test "the TUI calls no more core functions directly than before", %{calls: calls} do
    used =
      for {{from, _, _}, {Agendum.Core, name, arity}} <- calls,
          in?(from, "Agendum.TUI"),
          uniq: true,
          do: {name, arity}

    count = length(used)

    assert count <= @core_calls_at_most,
           "the TUI now calls #{count} Agendum.Core functions, more than " <>
             "#{@core_calls_at_most}: send a command instead (State.run/2)"

    assert count == @core_calls_at_most,
           "the TUI calls #{count} Agendum.Core functions now: lower " <>
             "@core_calls_at_most to #{count}"
  end

  # --- The core is pure ---------------------------------------------------

  # Modules and functions that reach the outside world: files, the
  # terminal, the environment, processes, the clock, randomness, the
  # network. A whole module is listed as {module, :any}.
  @impure [
    {File, :any},
    {IO, :any},
    {System, :any},
    {Process, :any},
    {Port, :any},
    {Node, :any},
    {Task, :any},
    {Agent, :any},
    {GenServer, :any},
    {Logger, :any},
    {Application, :any},
    {Code, :any},
    {:os, :any},
    {:file, :any},
    {:io, :any},
    {:rand, :any},
    {:random, :any},
    {:crypto, :any},
    {:ets, :any},
    {:persistent_term, :any},
    {:httpc, :any},
    {:calendar, :local_time},
    {:calendar, :universal_time},
    {:calendar, :now_to_local_time},
    {:calendar, :now_to_universal_time},
    {:calendar, :system_time_to_local_time},
    {:calendar, :system_time_to_universal_time},
    {Date, :utc_today},
    {Time, :utc_now},
    {DateTime, :utc_now},
    {DateTime, :now},
    {DateTime, :now!},
    {NaiveDateTime, :utc_now},
    {NaiveDateTime, :local_now},
    {:erlang, :send},
    {:erlang, :spawn},
    {:erlang, :spawn_link},
    {:erlang, :spawn_monitor},
    {:erlang, :spawn_opt},
    {:erlang, :self},
    {:erlang, :now},
    {:erlang, :system_time},
    {:erlang, :monotonic_time},
    {:erlang, :os_time},
    {:erlang, :timestamp},
    {:erlang, :unique_integer},
    {:erlang, :make_ref},
    {:erlang, :put},
    {:erlang, :get}
  ]

  defp impure?(module, function) do
    Enum.any?(@impure, fn {m, f} -> m == module and (f == :any or f == function) end)
  end

  test "the core never reads the clock, the environment or the outside world", %{calls: calls} do
    offenders =
      for {{from, f, a}, {module, name, arity}} <- calls,
          from == Agendum.Core or in?(from, "Agendum.Core"),
          impure?(module, name),
          uniq: true,
          do: "#{inspect(from)}.#{f}/#{a} calls #{inspect(module)}.#{name}/#{arity}"

    assert offenders == [], "impure calls in the core:\n" <> Enum.join(offenders, "\n")
  end

  test "the checks see calls through aliases (they read compiled code)", %{calls: calls} do
    # Agendum.TUI.Update calls the facade through `alias Agendum.Core`;
    # a check that missed aliased calls would find none.
    assert Enum.any?(calls, &match?({{Agendum.TUI.Update, _, _}, {Agendum.Core, _, _}}, &1))
    # and the shell's own impure calls are found where they belong
    assert Enum.any?(calls, &match?({{Agendum.Store, _, _}, {File, _, _}}, &1))
  end
end
