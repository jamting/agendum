defmodule Agenda.Core.JSONFile do
  @moduledoc """
  A whole Agenda file as JSON (SPEC R44, ADR 0010): readable, diff-friendly
  and complete, so that `decode(encode(db)) == {:ok, db}`.

  The document is an envelope, `{"format": "agenda-json", "version": 1, …}`,
  with the file's settings, its categories in hierarchy order, its items in
  file order (each with its assignments, dates, numbers, dependencies and
  suggestions) and its views in view-manager order. Enumerations are
  lowercase strings ("standard", "item_text"), dates and times ISO 8601;
  every object lists its keys in a fixed order. `docs/JSON_FORMAT.md`
  describes the schema.

  Reading is strict about what it cannot trust (unknown values, references
  to ids that do not exist) and lenient about what it can: a missing field
  takes its default. Pure: the shell reads and writes the file.
  """

  alias Agenda.Core.{
    Category,
    Database,
    DateFormat,
    DateRule,
    DateSettings,
    Item,
    Links,
    NumberFormat,
    Recurrence,
    Search,
    TextMatch,
    View
  }

  alias Agenda.Core.View.{Column, Section, SortKey}

  @format "agenda-json"
  @version 1

  # --- field specs of the flat settings structs -----------------------------------
  #
  # {field, type}: :int, :float, :string, :bool, :date, :time, :datetime,
  # {:enum, atoms}, {:or, [types]}, {:list, type}, {:nullable, type}

  defp spec(DateFormat) do
    [
      order: {:enum, DateFormat.orders()},
      separator: :string,
      clock: :int,
      day_of_week: :bool,
      show: {:enum, DateFormat.shows()},
      am_pm: :bool,
      time_separator: :string
    ]
  end

  defp spec(DateSettings) do
    [
      week_start: :int,
      week_end: :int,
      quarter_start: :int,
      year_start: :int,
      month_alone: {:or, [{:enum, [:first, :last]}, :int]},
      morning: :time,
      afternoon: :time,
      evening: :time
    ]
  end

  defp spec(TextMatch) do
    [
      enabled: :bool,
      match_on: {:enum, [:item, :note, :both]},
      strength: {:enum, [:exact, :partial, :minimal]},
      enclosed_by: {:enum, TextMatch.enclosers()},
      ignore_suffixes: :bool,
      ignore_accents: :bool
    ]
  end

  defp spec(DateRule) do
    [assign: {:enum, DateRule.assigns()}, which: :int, done_key: :bool, when_key: :bool]
  end

  defp spec(NumberFormat) do
    [
      symbol: {:nullable, :string},
      decimals: :int,
      thousands: :bool,
      negative: {:enum, [:minus, :parens]},
      calcs: {:list, {:enum, NumberFormat.calcs()}}
    ]
  end

  defp spec(Recurrence) do
    [
      every: :int,
      unit: {:enum, [:day, :week, :month, :year]},
      weekday: {:nullable, :int},
      day: {:nullable, :int}
    ]
  end

  defp spec(Search),
    do: [text: :string, on: {:enum, [:item, :note, :both]}, ignore_case: :bool]

  @confirm [:never, :always, :sometimes]
  @overrides [
    enabled: :bool,
    match_on: {:enum, [:item, :note, :both]},
    strength: {:enum, [:exact, :partial, :minimal]},
    confirm: {:enum, @confirm},
    ignore_suffixes: :bool,
    ignore_accents: :bool
  ]

  # ================================================================================
  # Encoding
  # ================================================================================

  @doc "The file as pretty-printed JSON."
  @spec encode(Database.t()) :: String.t()
  def encode(%Database{} = db), do: db |> document() |> pretty(0) |> IO.iodata_to_binary()

  defp document(db) do
    rel = by_item(db)

    obj(
      format: @format,
      version: @version,
      next_id: db.next_id,
      main: db.main_id,
      special: obj(entry: db.special.entry, when: db.special.when, done: db.special.done),
      settings:
        obj(
          date_format: struct_obj(db.date_format),
          date_settings: struct_obj(db.date_settings),
          match_settings: struct_obj(db.match_settings),
          confirm_assignments: Atom.to_string(db.confirm_assignments)
        ),
      categories: Enum.map(category_order(db), &category(db.categories[&1])),
      items: Enum.map(db.item_order, &item(db, rel, db.items[&1])),
      views: Enum.map(db.view_order, &view(db.views[&1]))
    )
  end

  # the item-and-category relations, grouped by item, each sorted
  defp by_item(db) do
    group = fn pairs -> Enum.group_by(Enum.sort(pairs), &elem(elem(&1, 0), 0)) end

    %{
      conditional: Enum.group_by(Enum.sort(db.conditional), &elem(&1, 0), &elem(&1, 1)),
      dates: group.(db.dates),
      numbers: group.(db.numbers)
    }
  end

  # MAIN's tree in hierarchy order, then anything outside it by id
  defp category_order(db) do
    tree = Database.subtree(db, db.main_id)
    tree ++ (db.categories |> Map.keys() |> Enum.sort() |> Enum.reject(&(&1 in tree)))
  end

  defp category(%Category{} = c) do
    obj(
      id: c.id,
      name: c.name,
      short_name: c.short_name,
      parent: c.parent_id,
      children: c.children,
      kind: Atom.to_string(c.kind),
      exclusive: c.exclusive,
      match_name: c.match_name,
      also_match: c.also_match,
      also_assign: c.also_assign,
      excludes: c.excludes,
      conditions: Enum.map(c.conditions, &criterion/1),
      actions: Enum.map(c.actions, &action/1),
      special: c.special && Atom.to_string(c.special),
      date_rule: c.date_rule && struct_obj(c.date_rule),
      match_overrides: overrides(c.match_overrides),
      note: c.note
    )
  end

  defp overrides(map) do
    {:obj,
     for(
       {field, type} <- @overrides,
       Map.has_key?(map, field),
       do: {Atom.to_string(field), value(map[field], type)}
     )}
  end

  defp criterion({cat, :assigned}), do: obj(category: cat, is: "assigned")
  defp criterion({cat, :not_assigned}), do: obj(category: cat, is: "not_assigned")

  defp criterion({cat, {:range, from, to, side}}),
    do: obj(category: cat, from: from, to: to, outside: side == :outside)

  defp action({cat, :remove}), do: obj(category: cat, action: "remove")
  defp action({cat, :clear}), do: obj(category: cat, action: "clear")
  defp action({cat, {:set, value}}), do: obj(category: cat, action: "set", value: value)

  defp item(db, rel, %Item{} = i) do
    obj(
      id: i.id,
      text: i.text,
      note: i.note,
      entry: date(i.entry),
      when: date(i.when),
      when_time: time(i.when_time),
      when_explicit: i.when_explicit,
      done: date(i.done),
      recurrence: i.recurrence && struct_obj(i.recurrence),
      alarm_minutes: i.alarm_minutes,
      alarm_rung_at: i.alarm_rung_at && NaiveDateTime.to_iso8601(i.alarm_rung_at),
      marked: i.marked,
      categories: db.links |> Links.rights(i.id) |> Enum.sort(),
      conditional: Map.get(rel.conditional, i.id, []),
      dates:
        for(
          {{_, cat}, {d, t, explicit}} <- Map.get(rel.dates, i.id, []),
          do: obj(category: cat, date: date(d), time: time(t), explicit: explicit)
        ),
      numbers:
        for({{_, cat}, n} <- Map.get(rel.numbers, i.id, []), do: obj(category: cat, value: n)),
      depends_on: db.dependencies |> Links.rights(i.id) |> Enum.sort(),
      suggested: Map.get(db.suggestions, i.id, [])
    )
  end

  defp view(%View{} = v) do
    obj(
      id: v.id,
      name: v.name,
      sections:
        Enum.map(
          v.sections,
          &obj(
            category: &1.category_id,
            collapsed: &1.collapsed,
            filter: Enum.map(&1.filter, fn c -> criterion(c) end),
            sort: &1.sort && Enum.map(&1.sort, fn k -> sort_key(k) end)
          )
        ),
      columns:
        Enum.map(
          v.columns,
          &obj(
            category: &1.category_id,
            width: &1.width,
            number: struct_obj(&1.number),
            date: &1.date && struct_obj(&1.date)
          )
        ),
      hide_done: v.hide_done,
      hide_empty: v.hide_empty,
      hide_inherited: v.hide_inherited,
      hide_dependent: v.hide_dependent,
      filter: Enum.map(v.filter, &criterion/1),
      sort: Enum.map(v.sort, &sort_key/1),
      match: match(v.match),
      section_sort: Atom.to_string(v.section_sort),
      section_order: Atom.to_string(v.section_order)
    )
  end

  defp sort_key(%SortKey{} = k) do
    on =
      case k.on do
        :text -> "text"
        {:category, id} -> obj(category: id)
        {:note, id} -> obj(note: id)
      end

    obj(
      on: on,
      order: Atom.to_string(k.order),
      na: Atom.to_string(k.na),
      sequence: Atom.to_string(k.sequence),
      line: k.line
    )
  end

  defp match(nil), do: nil
  defp match({:items, ids}), do: obj(items: ids)
  defp match(%Search{} = s), do: obj(search: struct_obj(s))

  defp struct_obj(%module{} = s),
    do:
      {:obj,
       for(
         {field, type} <- spec(module),
         do: {Atom.to_string(field), value(Map.fetch!(s, field), type)}
       )}

  defp value(nil, _type), do: nil
  defp value(v, {:enum, _}), do: Atom.to_string(v)
  defp value(v, {:or, _types}) when is_atom(v), do: Atom.to_string(v)
  defp value(v, {:list, type}), do: Enum.map(v, &value(&1, type))
  defp value(v, {:nullable, type}), do: value(v, type)
  defp value(v, :time), do: time(v)
  defp value(v, _type), do: v

  defp date(nil), do: nil
  defp date(%Date{} = d), do: Date.to_iso8601(d)
  defp time(nil), do: nil
  defp time(%Time{} = t), do: Time.to_iso8601(t)

  # an object with its keys in this order
  defp obj(pairs), do: {:obj, Enum.map(pairs, fn {k, v} -> {Atom.to_string(k), v} end)}

  # --- pretty printing, keeping key order ------------------------------------------

  defp pretty({:obj, []}, _level), do: "{}"

  defp pretty({:obj, pairs}, level) do
    inner = indent(level + 1)

    fields =
      Enum.map(pairs, fn {k, v} -> [inner, JSON.encode!(k), ": ", pretty(v, level + 1)] end)

    ["{\n", Enum.intersperse(fields, ",\n"), "\n", indent(level), "}"]
  end

  defp pretty([], _level), do: "[]"

  defp pretty(list, level) when is_list(list) do
    if Enum.all?(list, &(not is_list(&1) and not is_tuple(&1))) do
      ["[", list |> Enum.map(&JSON.encode!/1) |> Enum.intersperse(", "), "]"]
    else
      inner = indent(level + 1)
      items = Enum.map(list, &[inner, pretty(&1, level + 1)])
      ["[\n", Enum.intersperse(items, ",\n"), "\n", indent(level), "]"]
    end
  end

  defp pretty(scalar, _level), do: JSON.encode!(scalar)

  defp indent(level), do: String.duplicate("  ", level)

  # ================================================================================
  # Decoding
  # ================================================================================

  @doc """
  Reads a file from JSON. Errors say what is wrong and where
  ("categories[3].kind: unknown value \\"cheese\\"").
  """
  @spec decode(String.t()) :: {:ok, Database.t()} | {:error, String.t()}
  def decode(text) do
    case JSON.decode(text) do
      {:ok, %{"format" => @format, "version" => @version} = doc} ->
        build(doc)

      {:ok, %{"format" => @format, "version" => v}} ->
        {:error, "unsupported version #{inspect(v)}"}

      {:ok, _} ->
        {:error, "not an Agenda JSON file"}

      {:error, _} ->
        {:error, "not valid JSON"}
    end
  end

  defp build(doc) do
    db = database(doc)

    case check(db) do
      :ok -> {:ok, db}
      {:error, message} -> {:error, message}
    end
  catch
    {:bad, path, message} -> {:error, "#{path}: #{message}"}
  end

  defp database(doc) do
    categories = list(doc, "categories", "categories", &read_category/2)
    items = list(doc, "items", "items", &read_item/2)
    views = list(doc, "views", "views", &read_view/2)
    settings = field(doc, "settings", %{}, "settings")
    special = field(doc, "special", %{}, "special")

    %Database{
      next_id: req(doc, "next_id", :int, "next_id"),
      main_id: req(doc, "main", :int, "main"),
      special: %{
        entry: req(special, "entry", :int, "special.entry"),
        when: req(special, "when", :int, "special.when"),
        done: req(special, "done", :int, "special.done")
      },
      date_format: read_struct(settings, "date_format", DateFormat, "settings.date_format"),
      date_settings:
        read_struct(settings, "date_settings", DateSettings, "settings.date_settings"),
      match_settings:
        read_struct(settings, "match_settings", TextMatch, "settings.match_settings"),
      confirm_assignments:
        opt(settings, "confirm_assignments", {:enum, @confirm}, :never, "settings"),
      categories: Map.new(categories, &{&1.id, &1}),
      items: Map.new(items, fn {item, _} -> {item.id, item} end),
      item_order: Enum.map(items, fn {item, _} -> item.id end),
      views: Map.new(views, &{&1.id, &1}),
      view_order: Enum.map(views, & &1.id)
    }
    |> put_item_relations(items)
  end

  defp put_item_relations(db, items) do
    Enum.reduce(items, db, fn {item, rel}, db ->
      id = item.id

      %{
        db
        | links: Enum.reduce(rel.categories, db.links, &Links.link(&2, id, &1)),
          dependencies: Enum.reduce(rel.depends_on, db.dependencies, &Links.link(&2, id, &1)),
          conditional: Enum.reduce(rel.conditional, db.conditional, &MapSet.put(&2, {id, &1})),
          dates: Enum.reduce(rel.dates, db.dates, fn {c, v}, acc -> Map.put(acc, {id, c}, v) end),
          numbers:
            Enum.reduce(rel.numbers, db.numbers, fn {c, v}, acc -> Map.put(acc, {id, c}, v) end),
          suggestions:
            if(rel.suggested == [],
              do: db.suggestions,
              else: Map.put(db.suggestions, id, rel.suggested)
            )
      }
    end)
  end

  defp read_category(c, path) do
    %Category{
      id: req(c, "id", :int, path),
      name: req(c, "name", :string, path),
      short_name: opt(c, "short_name", {:nullable, :string}, nil, path),
      parent_id: opt(c, "parent", {:nullable, :int}, nil, path),
      children: opt(c, "children", {:list, :int}, [], path),
      kind: opt(c, "kind", {:enum, [:standard, :date, :numeric]}, :standard, path),
      exclusive: opt(c, "exclusive", :bool, false, path),
      match_name: opt(c, "match_name", :bool, true, path),
      also_match: opt(c, "also_match", :string, "", path),
      also_assign: opt(c, "also_assign", {:list, :int}, [], path),
      excludes: opt(c, "excludes", {:list, :int}, [], path),
      conditions: list(c, "conditions", path <> ".conditions", &read_criterion/2),
      actions: list(c, "actions", path <> ".actions", &read_action/2),
      special: opt(c, "special", {:nullable, {:enum, [:done, :discard]}}, nil, path),
      date_rule:
        case c["date_rule"] do
          nil -> nil
          _ -> read_struct(c, "date_rule", DateRule, path <> ".date_rule")
        end,
      match_overrides: read_overrides(field(c, "match_overrides", %{}, path), path),
      note: opt(c, "note", :string, "", path)
    }
  end

  defp read_overrides(map, path) do
    for {field, type} <- @overrides, Map.has_key?(map, Atom.to_string(field)), into: %{} do
      {field, convert(map[Atom.to_string(field)], type, "#{path}.match_overrides.#{field}")}
    end
  end

  defp read_criterion(c, path) do
    cat = req(c, "category", :int, path)

    case c do
      %{"is" => "assigned"} ->
        {cat, :assigned}

      %{"is" => "not_assigned"} ->
        {cat, :not_assigned}

      %{"is" => other} ->
        bad(path <> ".is", "unknown value #{inspect(other)}")

      _ ->
        bound = {:nullable, {:or, [:string, :float]}}
        side = if opt(c, "outside", :bool, false, path), do: :outside, else: :inside
        {cat, {:range, opt(c, "from", bound, nil, path), opt(c, "to", bound, nil, path), side}}
    end
  end

  defp read_action(a, path) do
    cat = req(a, "category", :int, path)

    case req(a, "action", {:enum, [:remove, :clear, :set]}, path) do
      :set -> {cat, {:set, req(a, "value", {:or, [:string, :float]}, path)}}
      action -> {cat, action}
    end
  end

  defp read_item(i, path) do
    item = %Item{
      id: req(i, "id", :int, path),
      text: opt(i, "text", :string, "", path),
      note: opt(i, "note", :string, "", path),
      entry: opt(i, "entry", {:nullable, :date}, nil, path),
      when: opt(i, "when", {:nullable, :date}, nil, path),
      when_time: opt(i, "when_time", {:nullable, :time}, nil, path),
      when_explicit: opt(i, "when_explicit", :bool, false, path),
      done: opt(i, "done", {:nullable, :date}, nil, path),
      recurrence:
        case i["recurrence"] do
          nil -> nil
          _ -> read_struct(i, "recurrence", Recurrence, path <> ".recurrence")
        end,
      alarm_minutes: opt(i, "alarm_minutes", {:nullable, :int}, nil, path),
      alarm_rung_at: opt(i, "alarm_rung_at", {:nullable, :datetime}, nil, path),
      marked: opt(i, "marked", :bool, false, path)
    }

    relations = %{
      categories: opt(i, "categories", {:list, :int}, [], path),
      conditional: opt(i, "conditional", {:list, :int}, [], path),
      depends_on: opt(i, "depends_on", {:list, :int}, [], path),
      suggested: opt(i, "suggested", {:list, :int}, [], path),
      dates:
        list(i, "dates", path <> ".dates", fn d, p ->
          {req(d, "category", :int, p),
           {req(d, "date", :date, p), opt(d, "time", {:nullable, :time}, nil, p),
            opt(d, "explicit", :bool, false, p)}}
        end),
      numbers:
        list(i, "numbers", path <> ".numbers", fn n, p ->
          {req(n, "category", :int, p), req(n, "value", :float, p)}
        end)
    }

    {item, relations}
  end

  defp read_view(v, path) do
    %View{
      id: req(v, "id", :int, path),
      name: req(v, "name", :string, path),
      sections: list(v, "sections", path <> ".sections", &read_section/2),
      columns: list(v, "columns", path <> ".columns", &read_column/2),
      hide_done: opt(v, "hide_done", :bool, false, path),
      hide_empty: opt(v, "hide_empty", :bool, false, path),
      hide_inherited: opt(v, "hide_inherited", :bool, false, path),
      hide_dependent: opt(v, "hide_dependent", :bool, false, path),
      filter: list(v, "filter", path <> ".filter", &read_criterion/2),
      sort: list(v, "sort", path <> ".sort", &read_sort_key/2),
      match: read_match(v["match"], path <> ".match"),
      section_sort:
        opt(v, "section_sort", {:enum, [:none, :category, :alpha, :numeric]}, :none, path),
      section_order: opt(v, "section_order", {:enum, [:asc, :desc]}, :asc, path)
    }
  end

  defp read_section(s, path) do
    %Section{
      category_id: req(s, "category", :int, path),
      collapsed: opt(s, "collapsed", :bool, false, path),
      filter: list(s, "filter", path <> ".filter", &read_criterion/2),
      sort:
        case s["sort"] do
          nil -> nil
          _ -> list(s, "sort", path <> ".sort", &read_sort_key/2)
        end
    }
  end

  defp read_column(c, path) do
    %Column{
      category_id: req(c, "category", :int, path),
      width: opt(c, "width", :int, 12, path),
      number: read_struct(c, "number", NumberFormat, path <> ".number"),
      date:
        case c["date"] do
          nil -> nil
          _ -> read_struct(c, "date", DateFormat, path <> ".date")
        end
    }
  end

  defp read_sort_key(k, path) do
    on =
      case k["on"] do
        nil -> :text
        "text" -> :text
        %{"category" => id} when is_integer(id) -> {:category, id}
        %{"note" => id} when is_integer(id) -> {:note, id}
        other -> bad(path <> ".on", "unknown value #{inspect(other)}")
      end

    %SortKey{
      on: on,
      order: opt(k, "order", {:enum, [:asc, :desc]}, :asc, path),
      na: opt(k, "na", {:enum, [:bottom, :top]}, :bottom, path),
      sequence: opt(k, "sequence", {:enum, [:hierarchy, :alpha]}, :hierarchy, path),
      line: opt(k, "line", :int, 1, path)
    }
  end

  defp read_match(nil, _path), do: nil

  defp read_match(%{"items" => ids} = m, path) when is_list(ids),
    do: {:items, req(m, "items", {:list, :int}, path)}

  defp read_match(%{"search" => _} = m, path),
    do: read_struct(m, "search", Search, path <> ".search")

  defp read_match(other, path), do: bad(path, "unknown value #{inspect(other)}")

  # --- reading helpers ---------------------------------------------------------------

  defp read_struct(map, key, module, path) do
    fields = field(map, key, %{}, path)
    defaults = struct(module)

    values =
      for {name, type} <- spec(module),
          do: {name, opt(fields, Atom.to_string(name), type, Map.fetch!(defaults, name), path)}

    struct(module, values)
  end

  defp field(map, key, default, path) do
    case Map.get(map, key) do
      nil -> default
      %{} = value -> value
      _ -> bad("#{path}.#{key}", "should be an object")
    end
  end

  defp list(map, key, path, read) do
    case Map.get(map, key) do
      nil ->
        []

      values when is_list(values) ->
        values
        |> Enum.with_index()
        |> Enum.map(fn
          {%{} = value, i} -> read.(value, "#{path}[#{i}]")
          {_, i} -> bad("#{path}[#{i}]", "should be an object")
        end)

      _ ->
        bad(path, "should be a list")
    end
  end

  defp req(map, key, type, path) do
    case Map.fetch(map, key) do
      {:ok, value} when value != nil -> convert(value, type, "#{path}.#{key}")
      _ -> bad("#{path}.#{key}", "is missing")
    end
  end

  defp opt(map, key, type, default, path) do
    case Map.fetch(map, key) do
      {:ok, value} -> convert(value, type, "#{path}.#{key}")
      :error -> default
    end
  end

  defp convert(nil, {:nullable, _}, _path), do: nil
  defp convert(value, {:nullable, type}, path), do: convert(value, type, path)
  defp convert(value, :int, _path) when is_integer(value), do: value
  defp convert(value, :float, _path) when is_float(value), do: value
  defp convert(value, :float, _path) when is_integer(value), do: value * 1.0
  defp convert(value, :string, _path) when is_binary(value), do: value
  defp convert(value, :bool, _path) when is_boolean(value), do: value

  defp convert(value, {:enum, atoms}, path) when is_binary(value) do
    Enum.find(atoms, &(Atom.to_string(&1) == value)) ||
      bad(path, "unknown value #{inspect(value)}")
  end

  defp convert(value, {:or, types}, path) do
    Enum.find_value(types, fn type ->
      try do
        {:ok, convert(value, type, path)}
      catch
        {:bad, _, _} -> nil
      end
    end)
    |> case do
      {:ok, v} -> v
      nil -> bad(path, "unexpected value #{inspect(value)}")
    end
  end

  defp convert(value, {:list, type}, path) when is_list(value),
    do: value |> Enum.with_index() |> Enum.map(fn {v, i} -> convert(v, type, "#{path}[#{i}]") end)

  defp convert(value, :date, path) when is_binary(value),
    do: parsed(Date.from_iso8601(value), path, value)

  defp convert(value, :time, path) when is_binary(value),
    do: parsed(Time.from_iso8601(value), path, value)

  defp convert(value, :datetime, path) when is_binary(value),
    do: parsed(NaiveDateTime.from_iso8601(value), path, value)

  defp convert(value, type, path),
    do: bad(path, "expected #{type_name(type)}, got #{inspect(value)}")

  defp parsed({:ok, value}, _path, _text), do: value
  defp parsed({:error, _}, path, text), do: bad(path, "not ISO 8601: #{inspect(text)}")

  defp type_name({:enum, _}), do: "a string"
  defp type_name({:list, _}), do: "a list"
  defp type_name(type) when is_atom(type), do: Atom.to_string(type)
  defp type_name(_type), do: "a value"

  @spec bad(String.t(), String.t()) :: no_return()
  defp bad(path, message), do: throw({:bad, path, message})

  # --- references --------------------------------------------------------------------

  # Every id a file refers to must exist, and ids must be below next_id.
  defp check(db) do
    cats = db.categories
    items = db.items

    problems =
      [
        {Map.has_key?(cats, db.main_id), "main category #{db.main_id} does not exist"},
        {Enum.all?(Map.values(db.special), &(cats[&1] && cats[&1].kind == :date)),
         "special categories must be date categories"},
        {db.views != %{}, "a file needs at least one view"},
        {Enum.all?(Map.keys(cats) ++ Map.keys(items) ++ Map.keys(db.views), &(&1 < db.next_id)),
         "next_id must be above every id"},
        {length(Enum.uniq(Map.keys(cats) ++ Map.keys(items) ++ Map.keys(db.views))) ==
           map_size(cats) + map_size(items) + map_size(db.views), "ids must be unique"}
      ] ++
        Enum.flat_map(Map.values(cats), &category_refs(&1, cats, items)) ++
        Enum.flat_map(Map.keys(items), &item_refs(db, &1)) ++
        relation_refs(db) ++
        Enum.flat_map(Map.values(db.views), &view_refs(&1, cats, items))

    case Enum.find(problems, &(not elem(&1, 0))) do
      nil -> :ok
      {_, message} -> {:error, message}
    end
  end

  defp category_refs(c, cats, _items) do
    ref = &Map.has_key?(cats, &1)

    [
      {c.parent_id == nil or (ref.(c.parent_id) and c.id in cats[c.parent_id].children),
       "category #{c.id}: parent #{inspect(c.parent_id)} does not list it"},
      {Enum.all?(c.children, &(ref.(&1) and cats[&1].parent_id == c.id)),
       "category #{c.id}: children do not exist or have another parent"},
      {Enum.all?(c.also_assign ++ c.excludes, ref),
       "category #{c.id}: also_assign or excludes refer to a missing category"},
      {Enum.all?(c.conditions ++ c.actions, &ref.(elem(&1, 0))),
       "category #{c.id}: a condition or action refers to a missing category"}
    ]
  end

  defp item_refs(db, id) do
    cats = Links.rights(db.links, id)

    [
      {Enum.all?(cats, &Map.has_key?(db.categories, &1)),
       "item #{id}: assigned to a missing category"},
      {Enum.all?(Links.rights(db.dependencies, id), &Map.has_key?(db.items, &1)),
       "item #{id}: depends on a missing item"},
      {Enum.all?(Map.get(db.suggestions, id, []), &Map.has_key?(db.categories, &1)),
       "item #{id}: a suggestion refers to a missing category"}
    ]
  end

  defp relation_refs(db) do
    keys = Map.keys(db.dates) ++ Map.keys(db.numbers) ++ MapSet.to_list(db.conditional)

    [
      {Enum.all?(keys, fn {_item, cat} -> Map.has_key?(db.categories, cat) end),
       "a date, number or conditional assignment refers to a missing category"}
    ]
  end

  defp view_refs(v, cats, items) do
    ref = &Map.has_key?(cats, &1)

    ids =
      Enum.map(v.sections, & &1.category_id) ++
        Enum.map(v.columns, & &1.category_id) ++
        Enum.map(v.filter ++ Enum.flat_map(v.sections, & &1.filter), &elem(&1, 0))

    matched =
      case v.match do
        {:items, ids} -> Enum.all?(ids, &Map.has_key?(items, &1))
        _ -> true
      end

    [{Enum.all?(ids, ref) and matched, "view #{v.id}: refers to a missing category or item"}]
  end
end
