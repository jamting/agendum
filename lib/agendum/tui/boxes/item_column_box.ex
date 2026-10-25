defmodule Agendum.TUI.Boxes.ItemColumnBox do
  @moduledoc """
  The Item Column Properties box (View ▸ Column ▸ Properties with the
  highlight on the item text; User's Guide 3-18 to 3-19, Help "Item
  Column Properties Box"): the section's item column (R55).

    * Section head: F3 or SPACE picks another category for the section.
    * Width: the item text's width now; typing one sets it by hand (Set
      width becomes Manually), as Agenda's (checked in Agenda 2.0,
      2026-10-25).
    * Set width: Automatically (as wide as the columns leave) or Manually.
      Manually starts at the width the item text has at that moment.
    * Minimum width (Automatically only): typed.
    * Link with other sections: a linked item column changes with the
      other linked ones; No makes it change alone, Yes takes their
      settings again.

  Each change applies at once and is one undo step, as in Column Properties.
  ENTER closes the box; ESC closes it and cancels its changes
  (`Agendum.TUI.Boxes.BoxCancel`). Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done, indicator: "PROPS", cancels: true

  alias Agendum.TUI.Boxes.{Box}

  alias Agendum.Core.View
  alias Agendum.Core.View.ItemColumn
  alias Agendum.TUI.{CategoryScreens, Boxes.FieldTyping, State, Boxes.Template}

  @layout """
   Section head:             [head              ]
   Width:                    [width ]
   Set width:                [set          ]
   Minimum width:            [minimum ]
   Link with other sections: [linked]
  """

  @help %{
    head: "The category at the head of the section. F3 or SPACE picks another.",
    set: "Set the width of the item text automatically, or by hand. SPACE switches.",
    width: "The width of the item text, in characters. Typing one sets it by hand.",
    minimum: "The narrowest the item text may become. Type it.",
    linked:
      "Whether the item column changes with the item columns of other sections. SPACE switches."
  }

  @doc "Opens the box for the item column of section `sidx`."
  def open(state, sidx),
    do: State.push(state, %Agendum.TUI.Modes.ItemColumn{sidx: sidx, cursor: 0})

  defp item_column(state, mode), do: Enum.at(State.view(state).sections, mode.sidx).item_column

  # Minimum width shows only while the width is automatic, so the cursor
  # goes through the fields shown
  defp fields(state, mode) do
    fields = Template.fields(@layout)
    if item_column(state, mode).set == :auto, do: fields, else: List.delete(fields, :minimum)
  end

  @impl Box
  def field(state, mode), do: Enum.at(fields(state, mode), mode.cursor)

  @impl Box
  def handle(state, mode, key) do
    if FieldTyping.typing?(mode),
      do: FieldTyping.key(state, mode, key, &typed/3),
      else: typing_key(state, mode, key)
  end

  # the settings box's keys, and F3 on Head picks its category (R65)
  @impl Box
  def keymap(_mode), do: Box.settings_keymap(%{{:f, 3} => :pick_head})

  @impl Box
  def commands(_mode),
    do: Box.settings_commands([{:pick_head, "Pick head", "Choose the head's category"}])

  @impl Box
  def run(state, mode, :change), do: change(state, mode, field(state, mode), 1)

  def run(state, mode, :pick_head),
    do: if(field(state, mode) == :head, do: pick_head(state, mode), else: state)

  def run(state, mode, id),
    do: Box.run_settings(state, mode, Template.grid(@layout, fields(state, mode)), id)

  # a typed width (the item text's room is at least 1, at most the screen's)
  defp typed(state, field, text) do
    mode = State.mode(state)

    case FieldTyping.number(text, 1, 500) do
      # a width typed sets it by hand, as Agenda's
      {:ok, n} when field == :width -> set(state, mode, set: :manual, width: n)
      {:ok, n} -> set(state, mode, [{field, n}])
      :error -> State.error(state, "Type a width, a number")
    end
  end

  # a digit in Width or Minimum starts typing a number
  defp typing_key(state, mode, {:char, c}) do
    field = field(state, mode)
    if field in [:width, :minimum], do: type_number(state, mode, field, c), else: state
  end

  defp typing_key(state, _mode, _key), do: state

  defp type_number(state, mode, field, c) do
    if FieldTyping.digit?(c), do: FieldTyping.start(state, mode, field, c), else: state
  end

  defp pick_head(state, mode),
    do: CategoryScreens.open_picker(state, {:change_section, mode.sidx}, nil)

  defp change(state, mode, :head, _step), do: pick_head(state, mode)

  # Manually starts at the width the item text has now, so nothing moves
  defp change(state, mode, :set, _step) do
    case item_column(state, mode) do
      %{set: :auto} -> set(state, mode, set: :manual, width: shown_width(state, mode))
      %{set: :manual} -> set(state, mode, set: :auto)
    end
  end

  # SPACE on Width widens it by one, by hand
  defp change(state, mode, :width, step),
    do: set(state, mode, set: :manual, width: width_now(state, mode) + step)

  defp change(state, mode, :minimum, step),
    do: set(state, mode, minimum: item_column(state, mode).minimum + step)

  defp change(state, mode, :linked, _step) do
    linked = not item_column(state, mode).linked
    State.run(state, {:set_item_column_linked, state.view_id, mode.sidx, linked})
  end

  defp set(state, mode, changes),
    do: State.run(state, {:set_item_column, state.view_id, mode.sidx, changes})

  # the width the item text has: its own when set by hand
  defp width_now(state, mode) do
    case item_column(state, mode) do
      %{set: :manual, width: width} -> width
      _auto -> shown_width(state, mode)
    end
  end

  defp shown_width(state, mode) do
    view = State.view(state)
    ItemColumn.text_width(item_column(state, mode), View.columns(view, mode.sidx), state.width)
  end

  # --- drawing ---

  @impl Box
  def title(_state, _mode), do: "Item Column Properties"

  # as wide as Column Properties, which it stands for on the item text
  @impl Box
  def width(state, _mode), do: min(state.width - 8, 72)

  @impl Box
  def content(state, mode, inner, _max_rows) do
    items = item_column(state, mode)
    section = Enum.at(State.view(state).sections, mode.sidx)

    values = %{
      head: state.db.categories[section.category_id].name,
      set: if(items.set == :auto, do: "Automatically", else: "Manually"),
      # nil leaves the row out (`Template.render/3`)
      width: Integer.to_string(width_now(state, mode)),
      minimum: if(items.set == :auto, do: Integer.to_string(items.minimum)),
      linked: if(items.linked, do: "Yes", else: "No")
    }

    opts = [selected: field(state, mode)] ++ FieldTyping.editing(mode)
    Template.render(@layout, values, opts) ++ [[], Box.hint(keys(state, mode), inner)]
  end

  @impl Box
  def keys(_state, _mode),
    do: Box.settings_keys([{"type", "Width", "a width"}, {"F3", "Choices", "Pick the head"}])

  @impl Box
  def help, do: @help

  # F8 and ALT-F8 (`Agendum.TUI.Boxes.BoxDefaults`): a new section's item
  # column (`ItemColumn`); the section head has none
  @impl Box
  def defaults(_state, mode) do
    new = %ItemColumn{}

    sizes =
      Map.new([:set, :width, :minimum], fn field ->
        {field,
         fn state ->
           default = Map.fetch!(new, field)

           if Map.fetch!(item_column(state, mode), field) == default,
             do: state,
             else: set(state, mode, [{field, default}])
         end}
      end)

    Map.put(sizes, :linked, fn state ->
      if item_column(state, mode).linked == new.linked,
        do: state,
        else: State.run(state, {:set_item_column_linked, state.view_id, mode.sidx, new.linked})
    end)
  end
end
