defmodule Agendum.Starters.PlannerViewsTest do
  @moduledoc """
  The Activities Planner's views (R60; screenshots 37-73, 110, 127, 143
  in `docs/reference/screens/notes.md`): the sixteen of Agenda's View
  Manager and Contacts, then each drawn in the TUI with the sample data.
  """
  use ExUnit.Case, async: true

  import Agendum.Fixtures, only: [cat: 2]
  import Agendum.TUIHelpers

  alias Agendum.Core.{Database, Datebook, View}
  alias Agendum.Starters.Planner
  alias Agendum.TUI.State

  @today ~D[2026-10-12]

  setup_all do
    %{db: Planner.build(), samples: Planner.build() |> Planner.with_samples(@today)}
  end

  defp view(db, name), do: Enum.find(Database.views(db), &(&1.name == name))
  defp names(db, ids), do: Enum.map(ids, &db.categories[&1].name)
  defp sections(db, name), do: names(db, Enum.map(view(db, name).sections, & &1.category_id))

  # each section's column heads (a note column by its title)
  defp columns(db, name) do
    for s <- view(db, name).sections,
        do: Enum.map(s.columns, &(&1.title || db.categories[&1.category_id].name))
  end

  defp filter(db, name),
    do: Enum.map(view(db, name).filter, fn {id, term} -> {db.categories[id].name, term} end)

  test "the views: Tasks first, where the file opens, then A-Z (shots 40, 41)", %{db: db} do
    assert Enum.map(Database.views(db), & &1.name) == [
             "Tasks",
             "Activities",
             "Calls",
             "Completed This Week",
             "Contacts",
             "Expense Analysis - Type",
             "Expense Entry",
             "Expense Reports",
             "Next Week",
             "Overdue",
             "People",
             "Priorities",
             "Projects",
             "This Month",
             "This Week",
             "Today",
             "Tomorrow"
           ]
  end

  test "Tasks and Activities: columns that differ per section (shots 37, 42, 43)", %{db: db} do
    assert columns(db, "Tasks") == [["Activity", "People", "Project", "When"]]

    assert sections(db, "Activities") ==
             ["Calls", "Follow up", "Ideas", "Issues", "Mail", "Meetings"] ++
               ["Miscellaneous Activity", "Reading"]

    [calls | others] = columns(db, "Activities")
    assert calls == ["People", "Phone #", "When"]
    assert Enum.uniq(others) == [["When"]]
    assert view(db, "Activities").section_sort == :alpha
  end

  test "Phone #: line 1 of the person's note, 14 wide (shot 127)", %{db: db} do
    [section] = view(db, "Calls").sections
    phone = Enum.at(section.columns, 1)
    assert {phone.format, phone.note_line, phone.width} == {:note, 1, 14}
    assert db.categories[phone.category_id].name == "People"
  end

  test "Completed This Week and Overdue: filters on dates (shots 46, 47, 56, 57)", %{db: db} do
    assert [{"Done", {:range, _, _, :inside}}] = filter(db, "Completed This Week")
    assert columns(db, "Completed This Week") == [["Done"]]
    assert [{"When", {:range, _, _, :inside}}] = filter(db, "Overdue")
    assert view(db, "Overdue").hide_done
    assert columns(db, "Overdue") == [["People", "Project", "When"]]
  end

  test "the expense views: Expenses only, lines between sections (shots 48-53)", %{db: db} do
    for name <- ["Expense Analysis - Type", "Expense Reports"] do
      assert filter(db, name) == [{"Expenses", :assigned}]
      assert view(db, name).section_sort == :alpha
    end

    assert sections(db, "Expense Analysis - Type") ==
             ~w(Air Breakfast Dinner Entertainment Lodging Lunch Miscellaneous) ++
               ["No Type", "Transportation"]

    assert sections(db, "Expense Reports") == ["No Purpose", "Sample Trip"]
    assert columns(db, "Expense Entry") == [["Amount", "Report ID", "Type", "When"]]

    for name <- ["Expense Analysis - Type", "Expense Entry", "Expense Reports"],
        do: assert(view(db, name).section_separators, name)
  end

  test "People, Priorities and Projects (shots 58-63)", %{db: db} do
    assert sections(db, "People") == ["Sample Person", "Unassigned"]
    assert filter(db, "People") == [{"Contact List", :not_assigned}]
    assert sections(db, "Priorities") == ["High", "Medium", "Low", "No Priority Assigned"]
    assert List.last(columns(db, "Priorities")) == ["Priority", "When"]
    assert view(db, "Priorities").section_sort == :category
    assert sections(db, "Projects") == ["Miscellaneous Project", "Sample Project"]
    assert Enum.uniq(columns(db, "Projects")) == [["When", "Done"]]
  end

  test "the datebooks (shots 54-55, 66-73)", %{db: db} do
    book = fn name -> view(db, name).datebook end
    assert %Datebook{period: :week, base: "beginning of next week"} = book.("Next Week")
    assert %Datebook{period: :week, base: "beginning of this week"} = book.("This Week")
    assert %Datebook{period: :month, interval: :week} = book.("This Month")

    assert %Datebook{period: :day, interval: 60, start_time: ~T[08:00:00], end_time: ~T[18:00:00]} =
             book.("Today")

    assert book.("Tomorrow").base == "tomorrow"

    for name <- ["Next Week", "This Week", "This Month", "Today", "Tomorrow"] do
      assert book.(name).section_category == cat(db, "Tasks"), name
      assert view(db, name).hide_column_heads and view(db, name).section_separators, name
    end
  end

  test "Contacts, as Agenda's contact list macro made it (shots 81-88, 110)", %{db: db} do
    assert sections(db, "Contacts") == ["Contact List"]
    assert columns(db, "Contacts") == [["People", "Phone #", "Company"]]
    [_people, phone, company] = hd(view(db, "Contacts").sections).columns
    assert {phone.note_line, company.note_line} == {1, 2}
    assert [%View.SortKey{on: {:category, people}, sequence: :alpha}] = view(db, "Contacts").sort
    # the items are blank: their text takes as little room as it can
    assert %{set: :manual, width: 5} = hd(view(db, "Contacts").sections).item_column
    assert db.categories[people].name == "People"
  end

  describe "with the sample data" do
    defp show(db, name) do
      # tall enough for a whole view; Monday 9:00
      state = start(db, today: @today, now: ~N[2026-10-12 09:00:00], width: 120, height: 70)
      state |> State.switch_view(view(db, name).id) |> screen()
    end

    test "every view draws", %{samples: db} do
      for v <- Database.views(db), do: assert(is_binary(show(db, v.name)), v.name)
    end

    test "Overdue shows what is late and not done", %{samples: db} do
      text = show(db, "Overdue")
      assert text =~ "Collect the figures for the annual report"
      refute text =~ "Book the movers"
      refute text =~ "Renew the software licences"
    end

    test "Completed This Week shows this week's done items", %{samples: db} do
      text = show(db, "Completed This Week")
      assert text =~ "Book the movers"
      refute text =~ "Prepare the slides for the Berlin talk"
    end

    test "Today shows the timed calls in their hours", %{samples: db} do
      text = show(db, "Today")
      assert text =~ "Call Anna Berg about the hosting contract"
      assert text =~ "Return Sarah Miller's call"
    end

    test "Contacts shows each person's phone number and company", %{samples: db} do
      text = show(db, "Contacts")
      # near the left margin, as a list: People, Phone #, Company
      assert text =~ ~r/\n    • {1,9}·Anna Berg +·555-0101 +·Nordvik/
      assert text =~ ~r/Sarah Miller +·555-0105/
    end

    test "the expense views total the amounts", %{samples: db} do
      assert show(db, "Expense Reports") =~ "Berlin conference"
      assert show(db, "Expense Entry") =~ "TOTAL"
    end
  end
end
