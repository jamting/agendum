defmodule Agendum.TUI.DateColumnsTest do
  @moduledoc """
  A date column's own display format: View ▸ Column ▸ Properties on a date
  column (R41a; User's Guide 6-19 to 6-22).
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core
  alias Agendum.TUI.{History, State}

  # Column Properties of a date column, on Display date and/or time (R55, R41a)
  defp to_show(state),
    do: state |> press([{:f, 10}, "v", "c", "p"]) |> to_setting("Display date and/or time")

  @today ~D[2026-10-08]

  # A Calls section with the columns When and People; the cursor starts on
  # "Call Anna"'s When cell.
  setup do
    db = Core.new_file()
    {:ok, db, calls} = Core.add_category(db, db.main_id, "Calls")
    {:ok, db, people} = Core.add_category(db, db.main_id, "People")
    view = hd(db.view_order)
    db = Core.set_section_category(db, view, 0, calls)
    db = Core.add_column(db, view, people, {0, 1})
    {db, _} = Core.add_item(db, "Call Anna tomorrow at 2pm", @today, section: calls)
    state = db |> start() |> press([:down, :right])
    %{state: state, view: view}
  end

  defp column(state, view), do: hd(Agendum.Core.View.columns(state.db.views[view], 0))

  test "opens a box of the date settings, using the global defaults", %{state: state} do
    state = press(state, [{:f, 10}, "v", "c", "p"])
    assert %{type: :column_props} = State.mode(state)
    text = screen(state)
    assert text =~ ~r/Column head: +When +Category type: +Date/
    assert text =~ "Date Column Properties"
    # Agenda's line under the part's title, not a setting (checked in
    # Agenda 2.0, 2026-10-25)
    assert text =~ ~r/Date Column Properties *│?\n.*\(Global defaults\)/
    refute text =~ "Settings:"
    assert text =~ ~r/Display date and\/or time: +Date time/
    assert text =~ ~r/Date format: +MMDDYY/
    assert text =~ "Formatted Sample"
    assert text =~ "11/13/90 3:25pm"
  end

  test "changing a setting makes them the column's own", %{state: state, view: view} do
    # Display date/time -> Date only, then Date format on to Relative
    state =
      state
      |> to_show()
      |> press(" ")
      |> to_setting("Date format")
      |> press(List.duplicate(" ", 14))

    assert column(state, view).date.show == :date
    assert column(state, view).date.order == :relative
    assert screen(state) =~ "(Local settings)"

    state = press(state, :enter)
    assert state.modes == []
    assert screen(state) =~ ~r/Tomorrow/
    assert state.db.date_format == Core.DateFormat.agenda()
  end

  # Agenda shows only the settings for what the column displays: no clock
  # for Date only, no date format for Time only (checked in Agenda 2.0,
  # 2026-10-25)
  test "the settings shown follow Display date and/or time", %{state: state} do
    both = to_show(state)

    for label <- ["Date format:", "Date separator:", "Clock:", "Show am/pm:", "Time separator:"],
        do: assert(screen(both) =~ label)

    # Date time -> Date only: the time settings go
    date_only = press(both, " ")
    assert screen(date_only) =~ "Date only"

    for label <- ["Clock:", "Show am/pm:", "Time separator:"],
        do: refute(screen(date_only) =~ label)

    assert screen(date_only) =~ "Date separator:"

    # Time date -> Time only: the date format and separator go; the day of
    # week stays, as Agenda's
    time_only = press(date_only, [" ", " "])
    assert screen(time_only) =~ "Time only"
    for label <- ["Date format:", "Date separator:"], do: refute(screen(time_only) =~ label)

    for label <- ["Show day of week:", "Clock:", "Time separator:"],
        do: assert(screen(time_only) =~ label)

    # the cursor reaches only the settings shown
    refute_raise = fn st, label -> assert_raise RuntimeError, fn -> to_setting(st, label) end end
    refute_raise.(date_only, "Clock")
    refute_raise.(time_only, "Date format")
  end

  test "ALT-F8 goes back to the global defaults", %{state: state, view: view} do
    state = state |> to_show() |> press([" ", {:alt_f, 8}])
    assert column(state, view).date == nil
    assert screen(state) =~ "(Global defaults)"
    assert screen(press(state, :esc)) =~ "10/09/26 2:00pm"
  end

  # the box applies on ENTER, as Agenda's (ADR 0030): one step for it all
  test "the whole box is one undo step", %{state: state, view: view} do
    before = column(state, view)
    state = state |> to_show() |> press([" ", " ", :enter])
    assert column(state, view).date.show == :time_date
    state = History.undo(state)
    assert column(state, view) == before
  end

  # F8 and ALT-F8 (User's Guide 2-17): a date column's defaults are the
  # file's, set in File Properties
  test "F8 puts a date setting back to the file's; ALT-F8 to the global defaults",
       %{state: state, view: view} do
    own = state |> to_show() |> press([" ", " "])
    assert column(own, view).date.show == :time_date
    assert column(press(own, {:f, 8}), view).date.show == own.db.date_format.show
    assert column(press(own, {:alt_f, 8}), view).date == nil
  end

  test "the file's format still changes columns using the global defaults", %{state: state} do
    state =
      press(state, [
        {:f, 10},
        "f",
        "p",
        :down,
        :down,
        " ",
        " ",
        :down,
        :down,
        :down,
        " ",
        :enter,
        :enter,
        :enter
      ])

    assert screen(state) =~ "10-09-26 2:00pm"
  end

  test "Column Properties on a standard column has no date part (R55)", %{state: state} do
    state = press(state, [:right, {:f, 10}, "v", "c", "p"])
    assert %{type: :column_props} = State.mode(state)
    refute screen(state) =~ "Date Column Properties"
  end
end
