defmodule Agendum.Core.AgFile.Convert do
  @moduledoc """
  Turns what `Agendum.Core.AgFile.Reader` read from a Lotus Agenda file
  into an Agendum JSON document (`docs/JSON_FORMAT.md`), which
  `Agendum.Core.JSONFile` then checks and builds (R72). Pure.

  Agenda numbers its items, categories and views from one counter, as
  Agendum does, so they keep their numbers as ids; what Agendum makes
  anew gets ids above them.

  What goes in, and how:

    * categories: the tree from MAIN with names, short names, Also match,
      exclusive children, notes, conditions, actions (assign becomes a
      category link, `also_assign`), Done and Discard special actions,
      text matching settings of their own, and date rules
    * items (not those in the trash): text, note (Agenda ended lines with
      CR), Entry, When (with its time and a recurring rule) and Done
      dates, dates in other date categories, numbers, unindexed
      categories' texts (R29b), alarms; only the
      assignments made by hand are kept (`:assign` in the result), the
      others Agendum works out again by its own rules
    * views: sections, columns (width, number format), sorting, filters
      (relative dates as phrases Agendum reads), the view options, and
      datebook views rebuilt from their period and hours
    * the file's text matching on/off and its date settings

  Every simplification is said in `:notes`, for the import report.
  """

  @weekday_numbers %{
    "Monday" => 1,
    "Tuesday" => 2,
    "Wednesday" => 3,
    "Thursday" => 4,
    "Friday" => 5,
    "Saturday" => 6,
    "Sunday" => 7
  }

  @typedoc """
  The result: the JSON `document`; the assignments made by hand, to be
  made after it is built (`assign`: item id => category ids); the
  categories Agenda had each item in (`agenda`: item id => category ids,
  every way it was assigned), to compare with Agendum's; and `notes`,
  sentences for the report.
  """
  @type t :: %{
          document: map,
          assign: %{pos_integer => [pos_integer]},
          agenda: %{pos_integer => [pos_integer]},
          trashed: non_neg_integer,
          notes: [String.t()]
        }

  @doc "Converts a file read by `Reader.read/1`."
  @spec convert(map) :: t
  def convert(file) do
    # `ctx` is what the parts need to know about each other: every
    # category by id, the special ones, and the next free id.
    cats = flatten(file.categories, nil)
    by_id = Map.new(cats, &{&1.id, &1})

    max_id =
      Enum.max([
        0 | Map.keys(by_id) ++ Enum.map(file.items, & &1.id) ++ Enum.map(file.views, & &1.id)
      ])

    ctx = %{
      by_id: by_id,
      main: file.categories.id,
      next_id: max_id + 1,
      notes: []
    }

    {special, ctx} = special(ctx)
    ctx = Map.put(ctx, :special, special)

    # unindexed categories stay unindexed, their values texts (R29b)
    live = Enum.reject(file.items, & &1.trashed)
    {items, assign, agenda, ctx} = items(live, ctx)
    {views, ctx} = views(file.views, ctx)
    {views, ctx} = if views == [], do: fallback_view(ctx), else: {views, ctx}
    categories = categories(cats, ctx)

    ctx =
      note_once(ctx, file.macros != [], "#{length(file.macros)} macros were not imported (later)")

    %{
      document: %{
        "format" => "agendum-json",
        "version" => 1,
        "next_id" => ctx.next_id,
        "main" => ctx.main,
        "special" => %{"entry" => special.entry, "when" => special.when, "done" => special.done},
        "settings" => settings(file.settings),
        "categories" => categories,
        "items" => items,
        "views" => views
      },
      assign: assign,
      agenda: agenda,
      trashed: length(file.items) - length(live),
      notes: Enum.reverse(ctx.notes)
    }
  end

  # --- categories --------------------------------------------------------------

  # The tree as a list, MAIN first, each with its parent's id.
  defp flatten(cat, parent) do
    children = Map.get(cat, :children, [])

    me =
      cat
      |> Map.delete(:children)
      |> Map.merge(%{parent: parent, children: Enum.map(children, & &1.id)})

    [me | Enum.flat_map(children, &flatten(&1, cat.id))]
  end

  # Entry, When and Done: Agenda's date categories of those names under
  # MAIN; one missing (renamed in Agenda) is made anew.
  defp special(ctx) do
    Enum.reduce([entry: "Entry", when: "When", done: "Done"], {%{}, ctx}, fn {key, name},
                                                                             {acc, ctx} ->
      found =
        Enum.find(ctx.by_id, fn {_id, c} ->
          c.parent == ctx.main and c.type == "date" and
            String.downcase(c.name) == String.downcase(name)
        end)

      case found do
        {id, _} ->
          {Map.put(acc, key, id), ctx}

        nil ->
          id = ctx.next_id
          cat = %{id: id, name: name, type: "date", parent: ctx.main, children: [], settings: %{}}
          main = ctx.by_id[ctx.main]

          ctx = %{
            ctx
            | next_id: id + 1,
              by_id:
                ctx.by_id
                |> Map.put(id, cat)
                |> Map.put(ctx.main, %{main | children: main.children ++ [id]})
          }

          {Map.put(acc, key, id),
           note(ctx, "Agenda's file had no #{name} category; one was made")}
      end
    end)
  end

  defp categories(_cats, ctx) do
    # the order: MAIN, then depth first, as the JSON format wants it
    ctx.by_id |> order(ctx.main) |> Enum.map(&category(ctx.by_id[&1], ctx))
  end

  defp order(by_id, id), do: [id | Enum.flat_map(by_id[id].children, &order(by_id, &1))]

  defp category(cat, ctx) do
    settings = Map.get(cat, :settings, %{})
    set = Map.get(cat, :conditions) || %{conditions: [], actions: []}
    kind = kind(cat.type)

    %{
      "id" => cat.id,
      "name" => cat.name,
      "short_name" => Map.get(cat, :short_name),
      "parent" => cat.parent,
      "children" => cat.children,
      "kind" => kind,
      "exclusive" => kind == "standard" and Map.get(settings, :exclusive_children, false),
      "match_name" => Map.get(settings, :match_name, true),
      "also_match" => cat |> Map.get(:also_match, []) |> Enum.join(";"),
      "also_assign" =>
        for(a <- set.actions, a.assign, known?(ctx, a.category, "standard"), do: a.category),
      "conditions" => for(c <- set.conditions, known?(ctx, c.category), do: criterion(c)),
      "actions" =>
        for(
          a <- set.actions,
          not a.assign,
          known?(ctx, a.category, "standard"),
          do: %{"category" => a.category, "action" => "remove"}
        ),
      "special" => special_action(Map.get(set, :special_action)),
      "date_rule" => if(kind == "date", do: date_rule(settings)),
      "match_overrides" => overrides(settings),
      "note" => cat |> Map.get(:note) |> note_text()
    }
  end

  defp kind("numeric"), do: "numeric"
  defp kind("date"), do: "date"
  defp kind("unindexed"), do: "unindexed"
  defp kind(_standard), do: "standard"

  defp known?(ctx, id, type \\ nil) do
    case ctx.by_id[id] do
      nil -> false
      cat -> type == nil or kind(cat.type) == type
    end
  end

  defp criterion(%{category: id, assigned: true}), do: %{"category" => id, "is" => "assigned"}
  defp criterion(%{category: id}), do: %{"category" => id, "is" => "not_assigned"}

  defp special_action("done"), do: "done"
  defp special_action("discard"), do: "discard"
  defp special_action(_other), do: nil

  @assigns ~w(never entered item_edited note_edited item_or_note_edited assigned
              assigned_or_edited item_text note_text item_or_note_text)
  @agenda_assigns [
    "never",
    "when entered",
    "item text edited",
    "note edited",
    "item or note edited",
    "when assigned",
    "assigned or edited",
    "from item text",
    "from note text",
    "from item or note text"
  ]

  # Agenda's Assign item date choices are Agendum's, in the same order.
  defp date_rule(settings) do
    index = Enum.find_index(@agenda_assigns, &(&1 == Map.get(settings, :assign_item_date))) || 0

    %{
      "assign" => Enum.at(@assigns, index),
      "which" => min(max(Map.get(settings, :which_date_in_text, 1), 1), 10),
      "done_key" => Map.get(settings, :set_from_done_key, false),
      "when_key" => Map.get(settings, :set_from_when_key, false)
    }
  end

  defp overrides(settings) do
    [
      {"enabled", Map.get(settings, :text_matching)},
      {"match_on",
       %{"item text" => "item", "note text" => "note", "item and note" => "both"}[
         Map.get(settings, :match_on)
       ]},
      {"strength", Map.get(settings, :match_strength)},
      {"confirm", Map.get(settings, :confirm)}
    ]
    |> Enum.reject(fn {_key, value} -> value == nil end)
    |> Map.new()
  end

  # A note: its text, with Agenda's CR line ends as LF; a note kept in a
  # file of its own is not read (its name is in the report).
  defp note_text(nil), do: ""
  defp note_text(%{file: _}), do: ""
  defp note_text(text), do: text |> String.replace("\r\n", "\n") |> String.replace("\r", "\n")

  # --- items -------------------------------------------------------------------

  defp items(items, ctx) do
    Enum.reduce(items, {[], %{}, %{}, ctx}, fn item, {out, assign, agenda, ctx} ->
      {json, by_hand, ctx} = item(item, ctx)

      agenda_cats =
        for a <- item.assignments, standard?(ctx, a.category), uniq: true, do: a.category

      {[json | out], Map.put(assign, item.id, by_hand), Map.put(agenda, item.id, agenda_cats),
       ctx}
    end)
    |> then(fn {out, assign, agenda, ctx} -> {Enum.reverse(out), assign, agenda, ctx} end)
  end

  defp standard?(ctx, id) do
    case ctx.by_id[id] do
      %{type: type} when type in ["standard"] -> id != ctx.main
      _ -> false
    end
  end

  defp item(item, ctx) do
    sp = ctx.special
    by_cat = Map.new(item.assignments, &{&1.category, &1})
    when_a = by_cat[sp.when]

    {recurrence, ctx} = recurrence(when_a, item, ctx)
    {{alarm, alarm_category}, ctx} = alarm(item, ctx)

    ctx =
      if match?(%{file: _}, item.note),
        do:
          note(ctx, "\"#{item.text}\": its note is in the file #{item.note.file}, not imported"),
        else: ctx

    # by hand: explicit assignments to standard categories; a text in an
    # unindexed category is by hand too (R29b)
    by_hand =
      for a <- item.assignments, a.how == "explicit", standard?(ctx, a.category), do: a.category

    texts =
      for a <- item.assignments,
          match?(%{type: "unindexed"}, ctx.by_id[a.category]),
          is_binary(Map.get(a, :value)),
          do: %{"category" => a.category, "value" => a.value}

    unindexed = for t <- texts, do: t["category"]

    json = %{
      "id" => item.id,
      "text" => item.text,
      "note" => note_text(item.note),
      "entry" => date_of(by_cat[sp.entry]),
      "when" => date_of(when_a),
      "when_time" => time_of(when_a),
      "when_explicit" => match?(%{how: "explicit"}, when_a),
      "done" => date_of(by_cat[sp.done]),
      "recurrence" => recurrence,
      "alarm_minutes" => alarm,
      "alarm_category" => alarm_category,
      "dates" =>
        for(
          a <- item.assignments,
          a.category not in [sp.entry, sp.when, sp.done],
          match?(%{type: "date"}, ctx.by_id[a.category]),
          date_of(a) != nil,
          do: %{
            "category" => a.category,
            "date" => date_of(a),
            "time" => time_of(a),
            "explicit" => a.how == "explicit"
          }
        ),
      "numbers" =>
        for(
          a <- item.assignments,
          match?(%{type: "numeric"}, ctx.by_id[a.category]),
          is_float(Map.get(a, :value)),
          do: %{"category" => a.category, "value" => a.value}
        ),
      "texts" => texts
    }

    {json, by_hand ++ unindexed, ctx}
  end

  defp date_of(%{value: "" <> moment}), do: String.slice(moment, 0, 10)
  defp date_of(_assignment), do: nil

  # The time, when one was given: an absolute date says so in its flag, a
  # relative or recurring one keeps it in its expression.
  defp time_of(%{value: "" <> moment, given_as: %{kind: "absolute", time_given: true}}),
    do: String.slice(moment, 11, 5) <> ":00"

  defp time_of(%{given_as: %{time: time}}), do: time <> ":00"
  defp time_of(_assignment), do: nil

  defp recurrence(%{given_as: %{kind: "recurring"} = g} = a, item, ctx) do
    every = max(Map.get(g, :interval, 1), 1)
    day = a.value |> String.slice(8, 2) |> String.to_integer()

    rule =
      case g.unit do
        "weekday" ->
          %{
            "every" => every,
            "unit" => "week",
            "weekday" => @weekday_numbers[Map.get(g, :weekday)]
          }

        "days" ->
          %{"every" => every, "unit" => "day"}

        "working days" ->
          %{"every" => every, "unit" => "day"}

        "weeks" ->
          %{"every" => every, "unit" => "week"}

        "fortnights" ->
          %{"every" => 2 * every, "unit" => "week"}

        "months" ->
          %{"every" => every, "unit" => "month", "day" => day}

        "quarters" ->
          %{"every" => 3 * every, "unit" => "month", "day" => day}

        "years" ->
          %{"every" => every, "unit" => "year"}

        _ ->
          nil
      end

    if rule,
      do: {rule, ctx},
      else:
        {nil, note(ctx, "\"#{item.text}\": its recurring date (#{g.unit}) is kept as one date")}
  end

  defp recurrence(_when, _item, ctx), do: {nil, ctx}

  # An alarm rings before its date category's date, When by default (R38):
  # the minutes, and the category when it is another than When.
  defp alarm(%{alarm: %{date_category: cat, minutes_before: minutes}}, ctx) do
    category = if cat == ctx.special.when, do: nil, else: cat
    {{min(max(minutes, 0), 60), category}, ctx}
  end

  defp alarm(_item, ctx), do: {{nil, nil}, ctx}

  # --- views -------------------------------------------------------------------

  defp views(views, ctx) do
    Enum.map_reduce(views, ctx, &view/2)
  end

  defp view(v, ctx) do
    {filter, ctx} = criteria(v.filter, v.name, ctx)

    {sections, ctx} =
      if Map.has_key?(v, :datebook),
        do: {[], ctx},
        else: Enum.map_reduce(v.sections, ctx, &section(&1, v.name, &2))

    {datebook, ctx} = datebook(v, ctx)

    json = %{
      "id" => v.id,
      "name" => v.name,
      "sections" => sections,
      "hide_done" => v.hide_done,
      "hide_empty" => v.hide_empty_sections,
      "hide_inherited" => v.hide_inherited,
      "hide_dependent" => v.hide_dependent,
      "hide_column_heads" => v.hide_column_heads,
      "section_separators" => v.section_separators,
      "number_items" => v.number_items,
      "filter" => filter,
      "sort" => sort_keys(v.sort, ctx),
      "section_sort" =>
        %{"category order" => "category", "alphabetic" => "alpha", "numeric" => "numeric"}[
          v.section_sorting
        ] ||
          "none",
      "datebook" => datebook,
      # a datebook's columns are the view's (R55), from its first slot
      "columns" => if(datebook, do: columns(List.first(v.sections), ctx), else: [])
    }

    {json, ctx}
  end

  defp section(s, view_name, ctx) do
    {filter, ctx} = criteria(Map.get(s, :filter, []), view_name, ctx)
    category = if known?(ctx, s.category), do: s.category, else: ctx.main

    json = %{
      "category" => category,
      "filter" => filter,
      "sort" => if(Map.has_key?(s, :sort), do: sort_keys(s.sort, ctx)),
      "columns" => columns(s, ctx)
    }

    {json, ctx}
  end

  defp columns(nil, _ctx), do: []

  defp columns(s, ctx) do
    for c <- s.columns, known?(ctx, c.category) do
      base = %{"category" => c.category, "width" => max(c.width, 1)}

      case c do
        %{number_format: n} ->
          Map.put(base, "number", %{
            "symbol" => %{"%" => "%", "$" => "$"}[n.label],
            "decimals" => n.decimals,
            "thousands" => n.thousands_separator,
            "negative" => if(n.negative_parentheses, do: "parens", else: "minus"),
            "percent" => n.percent_of_total
          })

        _ ->
          base
      end
    end
  end

  defp sort_keys(keys, ctx) do
    for k <- keys, on <- [sort_on(k, ctx)], on != nil do
      %{
        "on" => on,
        "order" => if(k.descending, do: "desc", else: "asc"),
        "na" => if(k[:"n/a first"], do: "top", else: "bottom"),
        "sequence" => if(Map.get(k, :sequence) == "alphabetic", do: "alpha", else: "hierarchy")
      }
    end
  end

  defp sort_on(%{on: "item text"}, _ctx), do: "text"

  defp sort_on(%{on: "category", category: id}, ctx),
    do: if(known?(ctx, id), do: %{"category" => id})

  defp sort_on(%{on: "category note", category: id}, ctx),
    do: if(known?(ctx, id), do: %{"note" => id})

  defp sort_on(_key, _ctx), do: nil

  # Filter elements; a date range keeps Agenda's relative dates as the
  # phrases Agendum reads ("yesterday", "end of this week").
  defp criteria(elements, view_name, ctx) do
    Enum.flat_map_reduce(elements, ctx, fn e, ctx ->
      cond do
        not known?(ctx, e.category) ->
          {[], ctx}

        Map.has_key?(e, :range) ->
          {from, ctx} = bound(e.range, :start, view_name, ctx)
          {to, ctx} = bound(e.range, :end, view_name, ctx)

          {[
             %{
               "category" => e.category,
               "from" => from,
               "to" => to,
               "outside" => not e.inside_range
             }
           ], ctx}

        true ->
          {[criterion(%{category: e.category, assigned: e.assigned})], ctx}
      end
    end)
  end

  defp bound(range, side, view_name, ctx) do
    case {Map.get(range, side), Map.get(range, :"#{side}_given_as")} do
      {nil, _} ->
        {nil, ctx}

      {moment, given} ->
        case phrase(given) do
          nil ->
            date = String.slice(moment, 0, 10)
            {date, note(ctx, "View #{view_name}: a date in its filter is kept as #{date}")}

          words ->
            {words, ctx}
        end
    end
  end

  @doc """
  A relative date as Agenda stored it (the reader's `given_as`) in words
  Agendum reads, or nil when there are none for it: count 0 is this unit,
  1 the next and -1 the last; a position is its beginning or end.
  """
  @spec phrase(map | nil) :: String.t() | nil
  def phrase(%{kind: "absolute"}), do: nil

  def phrase(%{kind: "relative", unit: "days", count: n}), do: days(n)

  def phrase(%{kind: "relative", unit: unit, count: n} = g)
      when unit in ["weeks", "months", "quarters", "years"] do
    noun =
      %{"weeks" => "week", "months" => "month", "quarters" => "quarter", "years" => "year"}[unit]

    which = %{0 => "this", 1 => "next", -1 => "last"}[n]

    case {which, Map.get(g, :position)} do
      {nil, _} -> nil
      {which, "beginning"} -> "beginning of #{which} #{noun}"
      {which, "end"} -> "end of #{which} #{noun}"
      {which, _} -> "#{which} #{noun}"
    end
  end

  def phrase(_given), do: nil

  defp days(0), do: "today"
  defp days(1), do: "tomorrow"
  defp days(-1), do: "yesterday"
  defp days(n) when n > 1, do: "in #{n} days"
  defp days(n), do: "#{-n} days ago"

  # A datebook view: the period, the hours of a day or the days of a week;
  # the date it starts from is not read from Agenda's file yet, so it is
  # today.
  defp datebook(%{datebook: d} = v, ctx) do
    section =
      case v.sections do
        [s | _] -> if known?(ctx, s.category), do: s.category, else: ctx.special.when
        [] -> ctx.special.when
      end

    json = %{
      "date_category" => ctx.special.when,
      "section_category" => section,
      "period" => d.period,
      "base" => "today"
    }

    json =
      if d.period == "day",
        do: Map.merge(json, %{"start_time" => hour(d.from), "end_time" => hour(d.to)}),
        else:
          Map.merge(json, %{
            "start_day" => @weekday_numbers[d.from],
            "end_day" => @weekday_numbers[d.to]
          })

    {json,
     note_once(ctx, true, "Datebook views start from today; set another date in View Properties")}
  end

  defp datebook(_view, ctx), do: {nil, ctx}

  defp hour(text) do
    [h | _] = String.split(text, ":")

    h
    |> String.to_integer()
    |> min(23)
    |> Integer.to_string()
    |> String.pad_leading(2, "0")
    |> Kernel.<>(":00:00")
  end

  defp fallback_view(ctx) do
    id = ctx.next_id
    view = %{"id" => id, "name" => "Main", "sections" => [%{"category" => ctx.main}]}
    {[view], %{ctx | next_id: id + 1}}
  end

  # --- settings ----------------------------------------------------------------

  defp settings(s) do
    [first, last] = s.week

    # The file's own global date format (header word 0x182) is not decoded
    # yet: the file gets Agenda's default, which most files kept (R41).
    format = Agendum.Core.DateFormat.agenda()

    %{
      "match_settings" => %{"enabled" => s.text_matching},
      "date_format" => %{
        "order" => Atom.to_string(format.order),
        "separator" => format.separator,
        "clock" => format.clock
      },
      "date_settings" => %{
        "week_start" => @weekday_numbers[first] || 7,
        "week_end" => @weekday_numbers[last] || 6,
        "month_alone" => if(s.month_alone_means == "last day", do: "last", else: "first"),
        "morning" => hour(s.morning),
        "afternoon" => hour(s.afternoon),
        "evening" => hour(s.evening)
      }
    }
  end

  # --- notes for the report ----------------------------------------------------

  defp note(ctx, text), do: %{ctx | notes: [text | ctx.notes]}

  defp note_once(ctx, true, text), do: if(text in ctx.notes, do: ctx, else: note(ctx, text))
  defp note_once(ctx, false, _text), do: ctx
end
