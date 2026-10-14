defmodule Agendum.TUI.Boxes.FieldHelp do
  @moduledoc """
  Help for the highlighted field of a box, shown in the control panel
  while the box is open, as Agenda did (screenshots 130 to 143: "Enter a
  short description of the file. Press F2 to edit."). What a setting
  does, then the keys that change it.

  Each box says which field is highlighted (its `field/2`); the texts are
  here, so they read alike and are checked together: every one fits the
  control panel's two lines at 80 columns. The texts follow Agenda's help
  (its F1 help's SETTING/DESCRIPTION tables), with Agendum's keys. A box
  without help here leaves the control panel as it was. Pure.
  """

  alias Agendum.TUI.{
    Boxes.DatebookBox,
    Boxes.ItemProperties,
    State
  }

  alias Agendum.TUI.CategoryScreens.Properties
  alias Agendum.TUI.Boxes.Box

  # boxes with a module of their own keep their help there (`Agendum.TUI.Boxes.Box`)
  @registered Box.registry()

  # The box types and the module that knows their highlighted field
  @boxes %{
    datebook_props: DatebookBox,
    props: Properties,
    item_props: ItemProperties
  }

  # Help for boxes that are lists: the same whatever is highlighted
  @lists %{
    calendars:
      "Your calendar subscriptions. ENTER reads one now, F sets how often, " <>
        "A how far ahead; INS adds one, DEL removes it.",
    copy_items:
      "Highlight the section to copy the item to and press ENTER; " <>
        "it stays in its other sections.",
    goto: "Highlight the section to go to and press ENTER, or type its first letter.",
    choice_list: "Highlight the choice and press ENTER.",
    viewmgr:
      "To display a view, highlight the view name and press ENTER. " <>
        "Press INS to create a new view.",
    confirm: "Y or N answers. SPACE switches the answer; ENTER accepts the one shown.",
    category_stats:
      "How much of the file uses the category: its items, children, sections, " <>
        "filters, conditions and actions.",
    questions:
      "Pick the categories to assign the item to: SPACE one, TAB all. " <>
        "ENTER assigns them and shows the next item.",
    alarm_list:
      "The items with alarms, and today's alarms that have gone off. " <>
        "DEL removes a past alarm, ALT-A cancels a current one.",
    calendar:
      "Move the highlight to a date and press ENTER. PGUP/PGDN for another month; " <>
        "type a date to go there; F6 adds a time."
  }

  # date format rows: the global Display Format and a date column's
  @help %{
    datebook_props: %{
      date_category: "The date category whose dates place items in the slots. SPACE picks one.",
      end_category:
        "A date category for the end of items that last a while. SPACE picks one, DEL clears it.",
      section_category: "The category at the head of every section. SPACE picks one.",
      period:
        "How long the datebook shows: a day, a week, a month or a quarter. SPACE changes it.",
      interval: "How long each section (slot) is. SPACE for the next choice.",
      start:
        "Where the datebook starts: an hour of the day or a day of the week. SPACE changes it.",
      end: "Where the datebook ends: an hour of the day or a day of the week. SPACE changes it.",
      base:
        "The date the period is taken from, such as \"today\" or \"next week\", " <>
          "read each time the view is shown. SPACE types it.",
      hide_column_heads: "Whether the column heads show above each section. SPACE switches.",
      section_separators: "Whether a line separates the sections. SPACE switches."
    },
    props: %{
      name: "The category's name. F2 (or SPACE) edits it.",
      short_name:
        "A short name for the category, also matched in item text. F2 (or SPACE) edits it.",
      type: "Standard, date or numeric. SPACE changes a standard category's type.",
      exclusive: "Whether an item can be in only one of the category's children. SPACE switches.",
      match_name: "Assign items whose text mentions the category's name. SPACE switches.",
      also_match:
        "Other words and phrases, separated by semicolons, that assign items too. F2 edits.",
      conditions:
        "Assign items to the category when they are in (or not in) other categories. SPACE.",
      also_assign:
        "What happens to items that join the category: other categories, dates, numbers. SPACE.",
      excludes:
        "Categories that may not share items with this one: joining one leaves the other. SPACE.",
      special:
        "An action for items that join the category: mark them done, or discard them. SPACE.",
      advanced: "Press SPACE BAR for how the category gets dates or matches item text.",
      statistics: "Press SPACE BAR to display current statistics for the category.",
      note: "The category's note. SPACE opens it."
    },
    item_props: %{
      text: "The item's text. F2 edits it.",
      note: "The item's note. SPACE (or F2) opens it.",
      stats: "When the item was entered and last changed.",
      prerequisite: "An item this one depends on. SPACE shows it, DEL removes the dependency.",
      dependent: "An item that depends on this one. SPACE shows it, DEL removes the dependency.",
      assigned:
        "A category the item is assigned to. DEL breaks the assignment; F4 " <>
          "changes a date or number.",
      add:
        "Type a category name to assign the item to it. ENTER accepts, INS makes a new one, " <>
          "F3 shows the profile."
    }
  }

  @doc "The help for the highlighted field of the box on top, or nil."
  @spec text(State.t()) :: String.t() | nil
  def text(state) do
    mode = State.mode(state)

    case mode do
      nil ->
        nil

      %{type: type} when is_map_key(@registered, type) ->
        Box.help_text(@registered[type], state, mode)

      %{type: type} when is_map_key(@boxes, type) ->
        get_in(@help, [type, @boxes[type].field(state, mode)])

      %{type: type} ->
        @lists[type]
    end
  end

  @doc "Every help text, for the tests."
  @spec all() :: [String.t()]
  def all,
    do:
      Map.values(@lists) ++
        Enum.flat_map(Map.values(@help), &Map.values/1) ++
        Enum.flat_map(Map.values(@registered), &Box.help_texts/1)

  @doc "The fields that have help, by box type, for the tests."
  @spec fields() :: %{atom => [atom]}
  def fields, do: Map.new(@help, fn {type, texts} -> {type, Map.keys(texts)} end)

  @doc "The box types whose fields have help, with the module that names the field."
  @spec boxes() :: %{atom => module}
  def boxes do
    moved = for {type, box} <- @registered, is_map(box.help()), into: %{}, do: {type, box}
    Map.merge(@boxes, moved)
  end
end
