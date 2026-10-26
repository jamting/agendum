defmodule Agendum.TUI.Boxes.SortBox do
  @moduledoc """
  The Sort box, Agenda's Item Sorting in All Sections (View Properties ▸
  Item sorting) and Item Sorting in Current Section (Section Properties ▸
  Item sorting): how the items of a view (`:view`) or of one section
  (`{:section, index}`) are ordered (SPEC R36; User's Guide 15-13 to
  15-20; checked in Agenda 2.0, 2026-10-25).

  Laid out as Agenda's: Sort new items at the top (shown, not a setting:
  Agendum always sorts as items are entered), then a Primary and a
  Secondary sort key, each with only the settings that apply to what it
  sorts on: Order and Sort n/a's for Item text; also Category, and
  Sequence for a standard category, for Category; also Line number and
  Sequence for Category note. SPACE on Sort on goes None → Item text →
  Category → Category note → None and keeps the category it had; with
  none yet, the category box opens. SPACE (or F3) on Category picks
  another. A section's box says "(View default)" while the section uses
  the view's settings: any change makes them its own, and ALT-F8 goes back
  to the view's. Section heads are sorted in View Properties, as in Agenda.

  ENTER closes the box; ESC closes it and cancels its changes
  (`Agendum.TUI.Boxes.BoxCancel`). Drawn from a layout made for the keys
  (`Agendum.TUI.Boxes.Template`). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done, cancels: true

  alias Agendum.Core.Database
  alias Agendum.Core.View.SortKey
  alias Agendum.TUI.Boxes.{Box, Template}
  alias Agendum.TUI.{CategoryScreens, State}

  # The help for a setting of either key: `then_order` is the secondary
  # key's `order`
  @help %{
    on:
      "What to sort the items on: none, the item text, a category or a category note. " <>
        "SPACE for the next.",
    order: "Sort in ascending or descending order. SPACE switches.",
    na: "Where items with nothing to sort on go: the top or the bottom. SPACE switches.",
    category: "The category whose children (or their notes) the items are sorted by. SPACE.",
    sequence:
      "Sort on the children of the category in their hierarchy order or alphabetically. " <>
        "SPACE switches.",
    line: "Which line of the category note to sort on. Type it (1 to 9), or SPACE for the next."
  }

  @attributes [:on, :order, :na, :category, :sequence, :line]

  # the secondary key's setting names, written out rather than made from
  # text (`String.to_atom/1`, which Credo warns of): `then_order` is the
  # secondary key's `order`
  @then %{
    on: :then_on,
    order: :then_order,
    na: :then_na,
    category: :then_category,
    sequence: :then_sequence,
    line: :then_line
  }

  def open(state, scope), do: State.push(state, %Agendum.TUI.Modes.Sort{scope: scope, cursor: 0})

  @doc "The keys in effect for the scope: the section's own, or `nil` when it uses the view's."
  @spec sort_keys(State.t(), map) :: [SortKey.t()] | nil
  def sort_keys(state, %{scope: :view}), do: State.view(state).sort
  def sort_keys(state, %{scope: {:section, i}}), do: Enum.at(State.view(state).sections, i).sort

  # What the rows show when a section uses the view's keys.
  defp effective(state, mode), do: sort_keys(state, mode) || State.view(state).sort

  # --- the layout -----------------------------------------------------------

  # Agenda's box (checked in Agenda 2.0, 2026-10-25): each key has four
  # rows, blank where a setting does not apply, so the Secondary sort key
  # stays where it is
  defp layout(state, mode) do
    keys = effective(state, mode)
    default? = sort_keys(state, mode) == nil

    """
     Sort new items:   [new_items           ]

    #{key_part(state.db, "Primary sort key", Enum.at(keys, 0), "", default?)}
    #{key_part(state.db, "Secondary sort key", Enum.at(keys, 1), "then_", default?)}
    """
  end

  defp key_part(db, heading, key, prefix, default?) do
    field = fn name, width -> "[" <> String.pad_trailing(prefix <> name, width - 2) <> "]" end
    kind = kind(key)
    heading = if default?, do: String.pad_trailing(heading, 19) <> "(View default)", else: heading
    line = if kind == :note, do: "Line number:" <> field.("line", 11), else: ""

    rows = [
      "   Sort on:    " <> field.("on", 16) <> line,
      kind != :none &&
        "   Order:      " <> field.("order", 16) <> "Sort n/a's: " <> field.("na", 19),
      kind in [:category, :note] && "   Category:   " <> field.("category", 31),
      sequence?(db, key) && "   Sequence:   " <> field.("sequence", 20)
    ]

    # a row that does not apply is a blank line (a space, or the layout
    # would end there)
    Enum.map_join([" " <> heading | rows], "\n", &(&1 || " "))
  end

  defp kind(nil), do: :none
  defp kind(%SortKey{on: :text}), do: :text
  defp kind(%SortKey{on: {:category, _}}), do: :category
  defp kind(%SortKey{on: {:note, _}}), do: :note

  # Sequence orders a category's children: Agenda shows it for a standard
  # category and for any category's notes
  defp sequence?(db, %SortKey{on: {:category, id}}), do: db.categories[id].kind == :standard
  defp sequence?(_db, %SortKey{on: {:note, _}}), do: true
  defp sequence?(_db, _key), do: false

  # the settings in the cursor's order; Sort new items is only shown
  defp fields(state, mode), do: Template.fields(layout(state, mode)) -- [:new_items]

  @impl Box
  def field(state, mode) do
    fields = fields(state, mode)
    Enum.at(fields, min(mode.cursor, length(fields) - 1))
  end

  # :then_order is the secondary key's order: {1, :order}
  defp split(field) do
    case Atom.to_string(field) do
      "then_" <> attribute -> {1, String.to_existing_atom(attribute)}
      _ -> {0, field}
    end
  end

  # --- keys -----------------------------------------------------------------

  # Line number: typed, a digit (Agenda's "type your own choice")
  @impl Box
  def handle(state, mode, {:char, c}) do
    case split(field(state, mode)) do
      {index, :line} when c in ~w(1 2 3 4 5 6 7 8 9) ->
        set_line(state, mode, index, fn _ -> String.to_integer(c) end)

      _ ->
        state
    end
  end

  def handle(state, _mode, _key), do: state

  # the settings box's keys; F3 changes a setting too (on Category it picks
  # one, as Agenda's), ALT-F5, which opened it, is done (R65)
  @impl Box
  def keymap(_mode),
    do:
      Box.settings_keymap(%{
        {:f, 3} => :choose,
        {:f, 6} => :category_props,
        {:alt_f, 5} => :done
      })

  @impl Box
  def commands(_mode),
    do:
      Box.settings_commands([
        {:choose, "Choices", "Change the setting, as SPACE does"},
        {:category_props, "Props", "The field's category's properties"}
      ])

  # ENTER is done (ESC cancels: `Agendum.TUI.Boxes.BoxCancel`)
  @impl Box
  # F6 on a key's Category: that category's properties
  def run(state, mode, :category_props) do
    with {index, :category} <- split(field(state, mode)),
         %SortKey{on: {_on, id}} <- Enum.at(effective(state, mode), index) do
      Box.category_props(state, id)
    else
      _ -> state
    end
  end

  def run(state, mode, id) when id in [:change, :choose] do
    {index, attribute} = split(field(state, mode))
    change(state, mode, index, attribute)
  end

  def run(state, mode, id),
    do: Box.run_settings(state, mode, Template.grid(layout(state, mode), fields(state, mode)), id)

  defp change(state, mode, index, :on) do
    keys = effective(state, mode)

    if index == 1 and keys == [],
      do: State.error(state, "Choose what to sort on first"),
      else: next_on(state, mode, keys, index, Enum.at(keys, index))
  end

  defp change(state, mode, index, :category) do
    purpose =
      if kind(Enum.at(effective(state, mode), index)) == :note,
        do: :sort_note,
        else: :sort_category

    CategoryScreens.open_picker(state, {purpose, mode.scope, index}, nil)
  end

  defp change(state, mode, index, :line), do: set_line(state, mode, index, &(&1 + 1))

  defp change(state, mode, index, attribute) do
    keys = effective(state, mode)
    key = Enum.at(keys, index)

    put(
      state,
      mode,
      List.replace_at(keys, index, Map.update!(key, attribute, &toggle(attribute, &1)))
    )
  end

  # Sort on: None → Item text → Category → Category note → None, keeping the
  # key's other settings and its category (Agenda's: it remembers the
  # category through None and Item text, so the mode keeps it)
  defp next_on(state, mode, keys, index, key) do
    case kind(key) do
      :none ->
        put(state, mode, set_key(keys, index, %SortKey{on: :text}))

      :text ->
        case remembered(mode, index) do
          nil -> CategoryScreens.open_picker(state, {:sort_category, mode.scope, index}, nil)
          id -> put(state, mode, List.replace_at(keys, index, %{key | on: {:category, id}}))
        end

      :category ->
        {:category, id} = key.on
        put(state, mode, List.replace_at(keys, index, %{key | on: {:note, id}}))

      :note ->
        {:note, id} = key.on
        mode = %{mode | remembered: Map.put(mode.remembered || %{}, index, id)}
        state = State.put_mode(state, mode)
        # no primary key means no secondary one either
        put(state, mode, Enum.take(keys, index))
    end
  end

  defp remembered(mode, index), do: (mode.remembered || %{})[index]

  # The line of the category note to sort on (1 or more).
  defp set_line(state, mode, index, fun) do
    keys = effective(state, mode)
    key = Enum.at(keys, index)
    put(state, mode, List.replace_at(keys, index, %{key | line: max(fun.(key.line), 1)}))
  end

  defp toggle(:order, :asc), do: :desc
  defp toggle(:order, :desc), do: :asc
  defp toggle(:na, :bottom), do: :top
  defp toggle(:na, :top), do: :bottom
  defp toggle(:sequence, :hierarchy), do: :alpha
  defp toggle(:sequence, :alpha), do: :hierarchy

  # F8 and ALT-F8 (`Agendum.TUI.Boxes.BoxDefaults`): Sort on back to no sort
  # of the box's own (a section's: the view's, Agenda's "View default",
  # User's Guide 15-20), the secondary key gone, a key's settings a new
  # key's (`SortKey`); a category has none. Each reads the sort as it is
  # when it runs, and touches only a sort the box has of its own
  @impl Box
  def defaults(_state, mode) do
    blank = %SortKey{}
    none = if mode.scope == :view, do: [], else: nil

    settings =
      for {prefix, index} <- [{"", 0}, {"then_", 1}],
          attribute <- [:order, :na, :sequence, :line],
          into: %{} do
        {named(prefix, attribute),
         &key_back(&1, mode, index, attribute, Map.fetch!(blank, attribute))}
      end

    Map.merge(settings, %{
      on: &if(sort_keys(&1, mode) in [nil, []], do: &1, else: put(&1, mode, none)),
      then_on: &then_back(&1, mode)
    })
  end

  defp then_back(state, mode) do
    case sort_keys(state, mode) do
      [first, _ | _] -> put(state, mode, [first])
      _ -> state
    end
  end

  defp key_back(state, mode, index, field, default) do
    keys = sort_keys(state, mode) || []
    key = Enum.at(keys, index)

    if key == nil or Map.fetch!(key, field) == default,
      do: state,
      else: put(state, mode, List.replace_at(keys, index, Map.put(key, field, default)))
  end

  @doc "Sets key `index` to sort on a category's notes (from the category box)."
  def set_note(state, scope, index, cat_id) do
    mode = %{scope: scope}
    keys = effective(state, mode)
    old = Enum.at(keys, index) || %SortKey{}
    put(state, mode, set_key(keys, index, %{old | on: {:note, cat_id}}))
  end

  @doc "Sets key `index` to sort on a category (from the category box)."
  def set_category(state, scope, index, cat_id) do
    mode = %{scope: scope}
    keys = effective(state, mode)
    old = Enum.at(keys, index) || %SortKey{}
    put(state, mode, set_key(keys, index, %{old | on: {:category, cat_id}}))
  end

  defp set_key(keys, index, key) when index < length(keys), do: List.replace_at(keys, index, key)
  defp set_key(keys, _index, key), do: keys ++ [key]

  defp put(state, mode, keys),
    do: State.run(state, {:set_sort, state.view_id, mode.scope, keys})

  # --- drawing ----------------------------------------------------------------

  @impl Box
  def title(_state, %{scope: :view}), do: "Item Sorting in All Sections"

  def title(_state, %{scope: {:section, _}}), do: "Item Sorting in Current Section"

  # as wide as Agenda's, which holds Sort n/a's beside Order
  @impl Box
  def width(state, _mode), do: min(state.width - 8, 66)

  @impl Box
  def content(state, mode, inner, _max_rows) do
    Template.render(layout(state, mode), values(state, mode), selected: field(state, mode)) ++
      [[], Box.hint(keys(state, mode), inner)]
  end

  defp values(state, mode) do
    keys = effective(state, mode)

    Map.merge(
      key_values(state.db, Enum.at(keys, 0), ""),
      key_values(state.db, Enum.at(keys, 1), "then_")
    )
    |> Map.put(:new_items, "When item is entered")
  end

  defp key_values(db, key, prefix) do
    values =
      case key do
        nil ->
          %{on: "None"}

        key ->
          %{
            on: describe(key),
            order: if(key.order == :asc, do: "Ascending", else: "Descending"),
            na: if(key.na == :bottom, do: "Bottom of section", else: "Top of section"),
            category: category_name(db, key),
            sequence:
              if(key.sequence == :hierarchy, do: "Category hierarchy", else: "Alphabetic"),
            line: Integer.to_string(key.line)
          }
      end

    Map.new(values, fn {k, v} -> {named(prefix, k), v} end)
  end

  defp describe(%SortKey{on: :text}), do: "Item text"
  defp describe(%SortKey{on: {:category, _}}), do: "Category"
  defp describe(%SortKey{on: {:note, _}}), do: "Category note"

  defp category_name(db, %SortKey{on: {_, id}}), do: Database.category(db, id).name
  defp category_name(_db, _key), do: ""

  @impl Box
  def keys(_state, _mode),
    do: [
      {"↑↓←→", "Setting", "Move between settings"},
      {"SPACE", "Change", "Change the setting"},
      {"ENTER", "Done"},
      {"ESC", "Cancel"}
    ]

  # the help for every setting of both keys
  @impl Box
  def help do
    for {attribute, text} <- @help, prefix <- ["", "then_"], into: %{} do
      {named(prefix, attribute), text}
    end
  end

  # a setting's name: the first key's is the attribute, the second's its
  # `then_` name
  defp named("", attribute), do: attribute
  defp named("then_", attribute), do: Map.fetch!(@then, attribute)

  # every attribute a key's setting can be: the fields' names without "then_"
  @doc false
  def attributes, do: @attributes
end
