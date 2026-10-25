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

  # Every change to the file is a command (`Agendum.Core.run/3`); the TUI
  # calls the rest of Agendum.Core only to read. These are the reads (and
  # `new_file/0`, `import_json/1` and `import_ag/2`, which make a file
  # rather than change one). A new Agendum.Core function must be a command's or be listed
  # here, so a new kind of change cannot skip the command layer.
  @reads ~w(
    agenda_file? alarm_at alarm_list circular_items assignment_reasons auto_dating? browse_keep browse_move browse_start browse_to browsed_view calendars_due completions confirm_mode date_conversion
    date_filters? default_column_width demote_conflicts dependents entry_categories group_alarms
    entry_values exclusive_conflicts export_json import_ag import_json item_assignments
    item_column_fit marked_items match_settings move_conflicts new_file
    numeric_conversion prerequisites promote_conflicts questions read_when
    related_items relocation_conflicts section_calcs shift_filters show_view template view_statistics waiting?
    when_at when_text
    zettel zettels item_by_zettel zettel_links link_targets linked_from
    blog_posts site site_changes feeds_due parse_feed export_opml
  )a

  # Agendum.Core functions a command does: the ones a command calls by its
  # own name (`Command.runs/0`), and those inside the commands written out
  # in `Agendum.Core.Command` (`:own`).
  defp by_command do
    named = for {id, _kinds, how} <- Agendum.Core.Command.runs(), how in [:core, :clock], do: id

    own =
      ~w(add_item edit_item mark_done discard_item move_item execute add_column_as
         ring_alarms clear_old_alarms apply_entry_values)a

    MapSet.new(named ++ own)
  end

  test "every Agendum.Core function is a command's, a read, or run/3" do
    by_command = by_command()

    unknown =
      for {name, arity} <- Agendum.Core.__info__(:functions),
          name != :run,
          name not in by_command,
          name not in @reads,
          uniq: true,
          do: "#{name}/#{arity}"

    assert unknown == [], """
    Agendum.Core functions that are neither a command's nor a read: make
    each a command (Agendum.Core.Command), or list a read in @reads:

      #{Enum.join(unknown, "\n  ")}
    """
  end

  test "the TUI changes the file only through commands", %{calls: calls} do
    violations =
      for {{from, f, a}, {Agendum.Core, name, arity}} <- calls,
          in?(from, "Agendum.TUI"),
          name != :run,
          name not in @reads,
          uniq: true,
          do: "#{inspect(from)}.#{f}/#{a} calls Core.#{name}/#{arity}"

    assert violations == [], """
    The TUI calls a core function that changes the file (send a command
    with State.run/2 instead):

      #{Enum.join(violations, "\n  ")}
    """
  end

  # --- The extras on a shelf of their own (ADR 0044) ----------------------

  # The extras (ADR 0043: the blog and its site, Markdown, feeds, Zettel ids
  # and links, calendar subscriptions) live in namespaces of their own.
  # Faithful code, Agenda's own, does not call them, so the line between the
  # clone and the extras stays where it can be seen. The shelf is the core's
  # extras and the facade's extras area, which Agendum.Core delegates to.
  @shelf ~w(Agendum.Core.Extras Agendum.Core.Facade.Extras)

  # The extras' own homes outside the core: their boxes and the shell
  # modules that fetch and publish for them. They may use the shelf.
  @extras_homes ~w(Agendum.TUI.Extras Agendum.Extras)

  # Faithful modules that must name the extras, because the extras' data are
  # stored fields of the file (`next_zettel`, `feeds`, `blog`, `calendars`;
  # ADR 0044's amendment): the file and its format, the golden file that
  # sets every field, and the checks of a sound file.
  @file_modules [
    Agendum.Core.Database,
    Agendum.Core.JSONFile,
    Agendum.Store,
    Agendum.Starters.Golden,
    Agendum.Core.Invariants
  ]

  # Single faithful functions that reach the extras, each for a reason
  # (owner, 2026-10-23):
  @named_exceptions [
    # a Zettel link ([[abcdefgh]]) in an item's text is blanked out before
    # the text is matched to categories, so a link never assigns an item
    {Agendum.Core.Assign, :levels, 2},
    {Agendum.Core.Assign, :text_matches?, 3},
    # the Zettel id column, a column format stored in a faithful view
    {Agendum.Core.ViewModel, :standard_cell, 6}
  ]

  defp on_shelf?(module), do: Enum.any?(@shelf, &in?(module, &1))

  defp may_use_shelf?({module, f, a}) do
    on_shelf?(module) or Enum.any?(@extras_homes, &in?(module, &1)) or
      module in @file_modules or {module, f, a} in @named_exceptions
  end

  test "faithful code does not call the extras (ADR 0044)", %{calls: calls} do
    violations =
      for {{from, f, a} = caller, {to, name, arity}} <- calls,
          on_shelf?(to),
          # Agendum.Core delegates to the facade's extras area, and only there
          not (from == Agendum.Core and in?(to, "Agendum.Core.Facade.Extras")),
          not may_use_shelf?(caller),
          uniq: true,
          do: "#{inspect(from)}.#{f}/#{a} calls #{inspect(to)}.#{name}/#{arity}"

    assert violations == [], """
    Faithful code calls the extras directly (reach them through the
    facade's extras area; ADR 0044):

      #{Enum.join(violations, "\n  ")}
    """
  end

  # Faithful code reaches the extras' boxes and shell modules only through
  # these doors, each for a reason; every one of them is behind the Extras
  # preference (R77, ADR 0043), so with it off the extras cannot be reached.
  @extras_doors [
    # the menu's extras actions (File ▸ Transfer ▸ Calendars, Publish,
    # Feeds), which `Actions.perform/2` refuses while the extras are off
    {Agendum.TUI.Update.Actions, :do_perform, 3},
    # the shell runs the effects only the extras ask for: reading a feed
    # or a calendar, opening a link, writing and uploading the blog
    {Agendum.TUI.App, :perform, 2},
    # the blog's folder, read for the Publish box, shown in its preview
    {Agendum.TUI.Update, :publish_scanned, 4},
    # the SFTP password, asked for by the preview, sent back to it
    {Agendum.TUI.Update.Prompts, :prompt_action, 3}
  ]

  test "faithful code reaches the extras' boxes only through their doors (R77)", %{
    calls: calls
  } do
    violations =
      for {{from, f, a} = caller, {to, name, arity}} <- calls,
          Enum.any?(@extras_homes, &in?(to, &1)),
          not on_shelf?(from),
          not Enum.any?(@extras_homes, &in?(from, &1)),
          caller not in @extras_doors,
          uniq: true,
          do: "#{inspect(from)}.#{f}/#{a} calls #{inspect(to)}.#{name}/#{arity}"

    assert violations == [], """
    Faithful code opens the extras directly (go through an extras command,
    or list the door with its reason; R77):

      #{Enum.join(violations, "\n  ")}
    """
  end

  test "the extras' list of allowed callers names real modules and functions" do
    {:ok, modules} = :application.get_key(:agendum, :modules)

    for prefix <- @shelf ++ @extras_homes do
      assert Enum.any?(modules, &in?(&1, prefix)), "no module under #{prefix}"
    end

    for module <- @file_modules do
      assert Code.ensure_loaded?(module), "#{inspect(module)} is listed but does not exist"
    end

    for {module, f, a} <- @named_exceptions ++ @extras_doors do
      Code.ensure_loaded!(module)
      # a private function is not exported, so look at the module's own list
      {:ok, {^module, [{:locals, locals}]}} =
        :beam_lib.chunks(:code.which(module), [:locals])

      assert {f, a} in locals or function_exported?(module, f, a),
             "#{inspect(module)}.#{f}/#{a} is a named exception but does not exist"
    end
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
