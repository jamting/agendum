defmodule Agenda.Store do
  @moduledoc """
  Saving and loading Agendum files (imperative shell). A file is
  `.agendum`; a name typed without an extension also finds a `.agenda`
  file from before the rename. Inside, the tag stays `:agenda`, so every
  file ever saved still loads.

  A file is the database serialized with `:erlang.term_to_binary/1`,
  wrapped in a versioned envelope so the format can evolve.

  Versions: 1 (initial); 2 adds `Item.when_explicit` and
  `Database.auto_date` (R14); 3 adds `Category.conditions` and
  `Database.conditional` (R15); 4 adds view and section `filter` and
  `sort` (R28, R36); 5 adds the view `match` of the Show View (R37); 6
  adds `Item.when_time`, `alarm_minutes` and `alarm_rung_at` (R14b, R38);
  7 adds `Database.date_format` (R41); 8 adds `Database.numbers` and
  `View.Column.number` (R29); 9 adds `Item.recurrence` (R14a); 10 adds
  `Database.dependencies` and `View.hide_dependent` (R43); 11 adds
  `Category.also_match` (R15d); 12 adds `Category.actions` and
  `Category.special` (R15b); 13 adds `Database.confirm_assignments` and
  `Database.suggestions` (R16); 14 adds `Database.date_settings` (R14e);
  15 replaces `Database.auto_date` with `Database.when_from` (R14f); 16
  adds `Category.excludes` (R9); 17 adds `Database.dates`, the dates of
  date categories the user made (R6a); 18 adds `Category.date_rule` (R6b),
  replacing `Database.when_from` with When's rule, and marks dates set by
  hand in `Database.dates`; 19 adds `Database.match_settings` (R16a); 20 adds
  `Category.match_overrides` (R16b); 21 adds `View.Column.date` and the
  `DateFormat` fields `show`, `am_pm` and `time_separator` (R41a); 22 adds
  `Database.calendars`, calendar subscriptions (R45); 23 adds
  `View.datebook` (R47); 24 adds `Database.macros` and `macro_order` (R50);
  25 moves a standard view's columns into its sections and adds
  `View.Column.linked` (R55); 26 adds `Database.insert_columns` (R55); 27
  replaces `View.Column.linked` with `link`, each column one of its own (R55);
  28 adds `View.Section.item_column` (R55); 29 adds its `position`;
  30 adds `NumberFormat.percent` (Display % of total); 31 adds
  `View.Column.format`, `note_line` and `title` (standard column formats);
  32 adds `View.hide_column_heads` (R57).
  Older versions are upgraded on load by filling new struct fields with
  their defaults.
  """

  alias Agenda.Core.Database

  @format_version 32
  @extension ".agendum"
  # files from before the program was called Wol's Agendum (ADR 0019)
  @old_extension ".agenda"

  def extension, do: @extension

  @doc "The file format version this program writes."
  def format_version, do: @format_version

  @spec save(Database.t(), Path.t()) :: :ok | {:error, term}
  def save(%Database{} = db, path) do
    binary = :erlang.term_to_binary({:agenda, @format_version, db}, [:compressed])
    tmp = path <> ".tmp"

    with :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- File.write(tmp, binary) do
      File.rename(tmp, path)
    end
  end

  @spec load(Path.t()) :: {:ok, Database.t()} | {:error, term}
  def load(path) do
    with {:ok, binary} <- File.read(path) do
      # `:safe` decoding refuses unknown atoms, and struct field names only
      # exist once their modules are loaded (modules load lazily).
      ensure_modules_loaded()

      try do
        case :erlang.binary_to_term(binary, [:safe]) do
          {:agenda, version, %{__struct__: Database} = db} when version in 1..@format_version ->
            {:ok, upgrade(db)}

          {:agenda, version, _} ->
            {:error, {:unsupported_version, version}}

          _ ->
            {:error, :not_an_agenda_file}
        end
      rescue
        ArgumentError -> {:error, :not_an_agenda_file}
      end
    end
  end

  @doc """
  Brings a database from any older format version up to date: every struct
  is rebuilt so fields added since it was saved get their defaults, and
  fields since removed are dropped. An old file's struct may have fields
  `Database` no longer has, so it is matched as a plain map.
  """
  @spec upgrade(map) :: Database.t()
  def upgrade(%{__struct__: Database} = db) do
    alias Agenda.Core.{Category, View}

    fields = Map.from_struct(db)

    # before 15 a file that did not read dates had auto_date: false; from
    # 15 to 17, when_from said where When dates came from
    when_assign =
      case fields do
        %{auto_date: false} -> :never
        %{when_from: :never} -> :never
        %{when_from: :note} -> :note_text
        %{when_from: :item_or_note} -> :item_or_note_text
        _ -> :item_text
      end

    db = struct(Database, fields)
    db = %{db | dates: Map.new(db.dates, &upgrade_date/1)}

    db = %{
      db
      | match_settings: struct(Agenda.Core.TextMatch, Map.from_struct(db.match_settings))
    }

    db = %{db | date_format: struct(Agenda.Core.DateFormat, Map.from_struct(db.date_format))}

    db = %{
      db
      | date_settings: struct(Agenda.Core.DateSettings, Map.from_struct(db.date_settings))
    }

    %{
      db
      | items: Map.new(db.items, fn {id, i} -> {id, upgrade_item(i)} end),
        categories:
          Map.new(db.categories, fn {id, c} ->
            {id, upgrade_category(db, struct(Category, Map.from_struct(c)), when_assign)}
          end),
        views: Map.new(db.views, fn {id, v} -> {id, upgrade_view(v)} end),
        macros:
          Map.new(db.macros, fn {id, m} -> {id, struct(Agenda.Core.Macro, Map.from_struct(m))} end),
        calendars:
          Map.new(db.calendars, fn {id, c} ->
            c = struct(Agenda.Core.Calendar, Map.from_struct(c))
            # events read before ends were (format 23 and earlier) have none
            {id,
             %{
               c
               | events: Map.new(c.events, fn {uid, s} -> {uid, Map.put_new(s, :ends, nil)} end)
             }}
          end)
    }
  end

  # Date categories get a date rule: Agenda's for Entry, When (with the
  # file's old setting) and Done, Never for the user's (R6b).
  defp upgrade_category(db, %{kind: :date, date_rule: nil} = cat, when_assign) do
    rule =
      case Enum.find(db.special, fn {_key, id} -> id == cat.id end) do
        {:when, _} -> %{Agenda.Core.DateRule.builtin(:when) | assign: when_assign}
        {key, _} -> Agenda.Core.DateRule.builtin(key)
        nil -> %Agenda.Core.DateRule{}
      end

    %{cat | date_rule: rule}
  end

  defp upgrade_category(_db, %{date_rule: %_{} = rule} = cat, _when_assign),
    do: %{cat | date_rule: struct(Agenda.Core.DateRule, Map.from_struct(rule))}

  defp upgrade_category(_db, cat, _when_assign), do: cat

  # dates of user date categories: {date, time} before 18
  defp upgrade_date({key, {date, time}}), do: {key, {date, time, true}}
  defp upgrade_date(entry), do: entry

  defp upgrade_item(item) do
    item = struct(Agenda.Core.Item, Map.from_struct(item))

    case item.recurrence do
      nil -> item
      rule -> %{item | recurrence: struct(Agenda.Core.Recurrence, Map.from_struct(rule))}
    end
  end

  defp upgrade_view(view) do
    alias Agenda.Core.View
    view = struct(View, Map.from_struct(view))
    # 25 and 26 marked columns `linked`, read before the structs drop it
    linked = old_linked(view.sections)

    # before 25 a standard view's columns were the view's, in every section
    %{
      view
      | sections: Enum.map(view.sections, &upgrade_section/1),
        columns: Enum.map(view.columns, &upgrade_column/1),
        sort: upgrade_keys(view.sort),
        datebook: view.datebook && struct(Agenda.Core.Datebook, Map.from_struct(view.datebook))
    }
    |> then(fn view -> if linked, do: View.link_by_head(view, linked), else: view end)
    |> View.columns_into_sections()
  end

  # The places of the columns marked `linked: true`, or nil when the file
  # has no such marks (before 25, or from 27 on).
  defp old_linked(sections) do
    places =
      for {section, s} <- Enum.with_index(sections),
          {column, i} <- Enum.with_index(Map.get(section, :columns, [])),
          Map.has_key?(column, :linked),
          do: {{s, i}, column.linked}

    if places != [],
      do: for({place, true} <- places, into: MapSet.new(), do: place)
  end

  defp upgrade_section(section) do
    section = struct(Agenda.Core.View.Section, Map.from_struct(section))

    %{
      section
      | sort: upgrade_keys(section.sort),
        columns: Enum.map(section.columns, &upgrade_column/1),
        item_column: struct(Agenda.Core.View.ItemColumn, Map.from_struct(section.item_column))
    }
  end

  # Sort keys gain fields too (`line`, R36).
  defp upgrade_keys(nil), do: nil

  defp upgrade_keys(keys),
    do: Enum.map(keys, &struct(Agenda.Core.View.SortKey, Map.from_struct(&1)))

  defp upgrade_column(column) do
    column = struct(Agenda.Core.View.Column, Map.from_struct(column))

    %{
      column
      | number: struct(Agenda.Core.NumberFormat, Map.from_struct(column.number)),
        date: column.date && struct(Agenda.Core.DateFormat, Map.from_struct(column.date))
    }
  end

  defp ensure_modules_loaded do
    {:ok, modules} = :application.get_key(:agenda, :modules)
    Enum.each(modules, &Code.ensure_loaded/1)
  end

  @doc """
  A folder's contents for the Select File box: its folders, then its files,
  each by name, with when it was last changed (local time); hidden ones
  (starting with a dot) are left out.
  """
  @spec list_dir(Path.t()) ::
          {:ok, [%{name: String.t(), dir?: boolean, modified: NaiveDateTime.t()}]}
          | {:error, String.t()}
  def list_dir(dir) do
    case File.ls(dir) do
      {:ok, names} ->
        entries =
          for name <- names,
              not String.starts_with?(name, "."),
              {:ok, stat} <- [File.stat(Path.join(dir, name), time: :local)] do
            %{
              name: name,
              dir?: stat.type == :directory,
              modified: NaiveDateTime.from_erl!(stat.mtime)
            }
          end

        {:ok, Enum.sort_by(entries, &{not &1.dir?, String.downcase(&1.name)})}

      {:error, reason} ->
        {:error, :file.format_error(reason) |> to_string()}
    end
  end

  @doc "Adds the default extension when the path has none."
  @spec normalize_path(String.t()) :: String.t()
  def normalize_path(path) do
    path = Path.expand(String.trim(path))

    cond do
      Path.extname(path) != "" ->
        path

      not File.exists?(path <> @extension) and File.exists?(path <> @old_extension) ->
        path <> @old_extension

      true ->
        path <> @extension
    end
  end
end
