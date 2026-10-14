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
    Boxes.ActionBox,
    Boxes.ColumnAddBox,
    Boxes.ColumnBox,
    Boxes.DatebookBox,
    Boxes.ItemColumnBox,
    Boxes.ItemProperties,
    Boxes.NumericFunctionsBox,
    Boxes.RangeFilterBox,
    Boxes.SearchBox,
    Boxes.SectionBox,
    Boxes.SortBox,
    State
  }

  alias Agendum.TUI.CategoryScreens.Properties
  alias Agendum.TUI.Boxes.Box

  # boxes with a module of their own keep their help there (`Agendum.TUI.Boxes.Box`)
  @registered Box.registry()

  # The box types and the module that knows their highlighted field
  @boxes %{
    datebook_props: DatebookBox,
    sort: SortBox,
    search_box: SearchBox,
    section_props: SectionBox,
    column_props: ColumnBox,
    column_add: ColumnAddBox,
    item_column: ItemColumnBox,
    numeric_functions: NumericFunctionsBox,
    range_filter: RangeFilterBox,
    action_box: ActionBox,
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
    sort: %{
      on: "What to sort the items on: item text, a category, or a category note. SPACE.",
      order: "Sort in ascending or descending order. SPACE switches.",
      na: "Where items with nothing to sort on go: the top or the bottom. SPACE switches.",
      sequence:
        "Sort on the children of the category in their hierarchy order or alphabetically. " <>
          "SPACE switches.",
      line: "Which line of the category note to sort on. Type it (1 to 9).",
      then_on: "What to sort items on when they are equal so far. SPACE changes it.",
      then_order: "Sort the second key in ascending or descending order. SPACE switches.",
      sections:
        "How to order the sections: none, by category order, alphabetic or numeric. SPACE.",
      section_order: "Sort the sections in ascending or descending order. SPACE switches."
    },
    search_box: %{
      text: "Type the text to search for. Pat* finds Pat and Patty. ENTER searches.",
      on: "Choose whether to search the item text, the note, or both. SPACE changes it.",
      direction: "Search forward, backward, or from the beginning of the view. SPACE changes it.",
      ignore_case: "Whether capital and small letters match alike. SPACE switches."
    },
    section_props: %{
      head:
        "Type a new or existing category name, or press F3 to pick one. " <>
          "F6 shows the category's properties.",
      sorting: "Press SPACE BAR to choose how the items in this section are sorted.",
      statistics: "Press SPACE BAR to see how many items the section shows.",
      numeric:
        "Press SPACE BAR to choose the calculations (total, average…) " <>
          "of the section's numeric columns.",
      filter: "Show only items in (or not in) some categories. Press SPACE BAR to choose them.",
      columns:
        "The section's columns. INS adds one, DEL removes it from this section, " <>
          "ALT-↑ ↓ moves it."
    },
    column_props:
      Map.merge(Agendum.TUI.Boxes.DateFormatRows.help(), %{
        head: "Press F3 to pick a category or type a new one.",
        type:
          "The type of the column's category: standard, date or numeric. " <>
            "Change it in the category's properties.",
        width: "The width of the column, in characters. Type it.",
        linked:
          "Whether the column changes with the same column in other sections. SPACE switches.",
        format:
          "How the column shows categories: name only, parent:category, ancestor, star, " <>
            "yes/no or a note line. SPACE changes it.",
        note_line: "Which line of the category note the column shows. Type it.",
        title: "Type the column's title.",
        symbol: "The label or currency symbol shown with numbers. SPACE for the next one.",
        decimals: "How many decimal places numbers show. Type it, or SPACE for one more.",
        thousands: "Whether numbers show a separator between thousands. SPACE switches.",
        negative: "How negative numbers show: with a minus sign or in parentheses. SPACE.",
        percent:
          "Whether a column with each number's percent of the total shows beside it. SPACE.",
        count: "Whether the section shows how many items have a number. SPACE switches.",
        total: "Whether the section shows the total of the column. SPACE switches.",
        average: "Whether the section shows the average of the column. SPACE switches.",
        minimum: "Whether the section shows the smallest number in the column. SPACE switches.",
        maximum: "Whether the section shows the largest number in the column. SPACE switches."
      }),
    column_add: %{
      head: "Type the name of a new or existing category, or press F3 to pick one.",
      type:
        "The type of the column's category: standard, date or numeric. " <>
          "SPACE changes it for a new head.",
      width: "The width of the column, in characters. Type it.",
      format:
        "How the column shows categories: name only, parent:category, ancestor, star, " <>
          "yes/no or a note line. SPACE changes it.",
      note_line: "Which line of the category note the column shows. Type it.",
      title: "Type the column's title.",
      position: "Add the column right or left of the highlighted one. SPACE switches.",
      insert_in: "Add the column to all sections in the view, or only this one. SPACE switches."
    },
    item_column: %{
      head: "The category at the head of the section. F3 or SPACE picks another.",
      set: "Set the width of the item text automatically, or by hand. SPACE switches.",
      width: "The width of the item text, in characters. Type it.",
      minimum: "The narrowest the item text may become. Type it.",
      linked:
        "Whether the item column changes with the item columns of other sections. SPACE switches."
    },
    numeric_functions: %{
      count: "Show how many items have a number, in every numeric column. SPACE switches.",
      total: "Show the total of every numeric column. SPACE switches.",
      average: "Show the average of every numeric column. SPACE switches.",
      minimum: "Show the smallest number of every numeric column. SPACE switches.",
      maximum: "Show the largest number of every numeric column. SPACE switches."
    },
    range_filter: %{
      show: "Choose items assigned to the category, or items not assigned. SPACE switches.",
      from: "Type the start of the range: a date or a number. Leave it blank for no start.",
      to: "Type the end of the range: a date or a number. Leave it blank for no end.",
      where:
        "Choose items inside the range or outside it. SPACE switches. " <>
          "ENTER applies, DEL removes the category."
    },
    action_box: %{
      what: "Choose whether the action gives items a date or a number, or removes it. SPACE.",
      value:
        "Type the date (\"tomorrow\", read when the action runs) or the number. " <>
          "ENTER applies, DEL removes the action."
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
