defmodule Agendum.TUI.Messages do
  @moduledoc """
  Lotus Agenda's own messages, for the situations where Agendum meets the
  same thing (AGENDA_PARITY, the texts step; the owner's choice,
  2026-10-25: Agenda's words, adapted). They come from Agenda 2.0's
  `AGENDA.RI` (`docs/reference/agenda_messages.json`, two spaces after a
  full stop as there); `test/agendum/tui/agenda_messages_test.exs` checks
  each against it.

  A message is `:agenda`, Agenda's words as they are, or `{:adapted,
  original}`: Agenda's words with what Agendum does otherwise left out
  (ALT-C's calendar, the trash, unindexed categories, DOS and network
  advice), "Agenda" as "Agendum" where it names the program, and cut to a
  sentence or two where the whole would not fit the control panel's two
  lines. Pure.
  """

  @messages %{
    not_on_item:
      {"The highlight isn't on an item.  Highlight the item you want and repeat the command.",
       :agenda},
    not_on_category:
      {"The highlight isn't on a category.  Highlight the category you want and repeat the command.",
       :agenda},
    bad_date:
      {"The date you entered isn't valid.  Type a valid date.",
       {:adapted,
        "The date you entered isn't valid.  Type a valid date or press ALT-C to pick a date from the calendar."}},
    bad_number: {"The number you entered isn't valid.  Retype a number.", :agenda},
    bad_time: {"The time you entered isn't valid.  Type a valid time.", :agenda},
    macro_not_here:
      {"You can't run this macro in this part of Agendum.",
       {:adapted,
        "You can't run this macro in this part of Agenda.  Macros can be limited to any one or more of these parts of Agenda: views, category manager, and notes.  You can check these limits by displaying the macro properties for the current macro."}},
    category_name:
      {"The name of the category must contain at least one character (other than a space).  Type a valid category name.",
       {:adapted,
        "The name of the category must contain at least one character (other than a space) and can't begin with a semicolon.  Type a valid category name."}},
    cannot_convert:
      {"You can't convert the MAIN category or a category with grandchildren to numeric, date, or unindexed.",
       :agenda},
    no_sections:
      {"Every view must have at least one section.  Type a category name or press F3 to pick an existing category for the section head.",
       :agenda},
    cannot_change_type:
      {"You can't change the category type of date and numeric categories.",
       {:adapted,
        "You can't change the category type of date, numeric, and unindexed categories."}},
    view_needs_section:
      {"Every view must have at least one section.  Type a category name or press F3 to pick an existing category for the section head.",
       :agenda},
    macro_key_reserved:
      {"You can't attach a macro to any of these keys: ALT-Z, ALT-F3, or ALT-F1. Choose a different key.",
       :agenda},
    macro_one_key:
      {"You can't attach a macro to more than one key.  Enter a single key for the macro attachment.",
       :agenda},
    file_not_found:
      {"The file you requested doesn't exist.  Check the name you typed for errors and make sure you specified the correct directory.",
       :agenda},
    not_agenda_file:
      {"Agendum can't retrieve this file.  It is either not an Agenda file, or it is too damaged to open.",
       {:adapted,
        "Agenda can't retrieve this file.  It is either not an Agenda file, or it is too damaged to open."}},
    cannot_import:
      {"Agendum can't import the file you requested.",
       {:adapted,
        "Agenda can't import the file you requested.  Either the file is damaged, or it contains control characters that Agenda can't accept."}},
    cannot_open:
      {"Agendum couldn't open the file.",
       {:adapted,
        "Agenda couldn't open the file.  Try exiting to the system to see if the file is damaged.  If the file is on a network drive, the drive may be read-only, so you'll have to use a different drive."}},
    needs_date: {"You must provide a date for the item.", :agenda},
    make_dependent:
      {"To make an item dependent, you must first highlight the prerequisite item(s) and mark them by pressing F7.",
       :agenda},
    depends_on_itself: {"An item can't be dependent on itself.", :agenda},
    no_matches:
      {"Agendum couldn't find any matches for the text you entered.",
       {:adapted, "Agenda couldn't find any matches for the text you entered."}},
    no_more_matches: {"No matching text found", :agenda},
    no_macro_to_restart: {"There is no macro to restart.", :agenda},
    select_date_category: {"You must select a date category.", :agenda},
    item_column_stays: {"You can't remove the item column from the section.", :agenda},
    discarded_by_action:
      {"You assigned the current item to a category with a special action that discarded the item when you made the assignment.",
       {:adapted,
        "You assigned the current item to a category with a special action that discarded the item when you made the assignment.  You can recover the item from the trash (unless you have set Empty trash to When item is discarded)."}},
    datebook_change: {"You can't make this change in a datebook view.", :agenda},
    discard_main: {"You can't discard the MAIN category from the file.", :agenda},
    discard_date_category:
      {"You can't discard the Done, Entry, or When date categories.", :agenda},
    section_head_name:
      {"The name of the section head must contain at least one character (other than a space).",
       {:adapted,
        "The name of the section head must contain at least one character (other than a space).  Type a valid category name or press F3 to choose an existing category."}}
  }

  @doc "Every message: `{text, :agenda | {:adapted, Agenda's original}}`, by name."
  def all, do: @messages

  @doc "The message's text."
  @spec text(atom) :: String.t()
  def text(name), do: @messages |> Map.fetch!(name) |> elem(0)

  @doc """
  Why a category cannot be discarded, as Agenda says it: MAIN, or one of
  the date categories Entry, When and Done.
  """
  def cannot_discard(db, id),
    do: if(id == db.main_id, do: text(:discard_main), else: text(:discard_date_category))

  @doc """
  Why an ingested category (R75a) cannot be changed here, and where it can:
  its feed's or calendar's box; `id` nil when it is not known which.
  """
  @spec ingested(Agendum.Core.Database.t(), integer | nil) :: String.t()
  def ingested(db, id) do
    by_calendar = id != nil and Enum.any?(db.calendars, fn {_, c} -> c.category_id == id end)

    parent =
      id != nil and
        Enum.any?(db.feeds, fn {_, f} -> db.categories[f.category_id].parent_id == id end)

    name = if id, do: db.categories[id].name <> " is", else: "That category is"

    cond do
      parent ->
        "#{db.categories[id].name} holds your feeds: rename or remove one in File ▸ Transfer ▸ Feeds"

      by_calendar ->
        "#{name} filled by its calendar: rename or remove it in File ▸ Transfer ▸ Calendars"

      true ->
        "#{name} filled by a feed: rename or remove it in File ▸ Transfer ▸ Feeds"
    end
  end
end
