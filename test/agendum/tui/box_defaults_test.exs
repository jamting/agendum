defmodule Agendum.TUI.BoxDefaultsTest do
  @moduledoc """
  F8 (DEFAULT) and ALT-F8 (DFLTALL) in settings boxes (User's Guide 2-17;
  checked in Agenda 2.0, 2026-10-24: every settings box has them; F8 put
  Hide done items back to No, ALT-F8 every setting, the view's name kept).
  The default is what something new gets. A setting without one (a name)
  is left as it is. The box applies on ENTER, ESC puts it all back.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers

  alias Agendum.Core.Database
  alias Agendum.Starters.Planner
  alias Agendum.TUI.State

  @today ~D[2026-10-12]

  setup do
    db = Planner.build() |> Planner.with_samples(@today)
    view = Enum.find(Database.views(db), &(&1.name == "Tasks"))
    state = db |> start(today: @today, width: 100, height: 40) |> State.switch_view(view.id)
    %{state: state, view: view.id}
  end

  defp props(state), do: press(state, [{:f, 10}, "v", "p"])

  describe "View Properties" do
    test "F8 puts the highlighted setting back to its default", %{state: state, view: v} do
      changed = state |> props() |> to_setting("Hide done items") |> press(" ")
      assert changed.db.views[v].hide_done
      back = press(changed, {:f, 8})
      refute back.db.views[v].hide_done
      assert screen(back) =~ ~r/Hide done items: +No/
    end

    test "ALT-F8 puts every setting back, the view's name kept", %{state: state, view: v} do
      changed =
        state
        |> props()
        |> to_setting("Hide done items")
        |> press(" ")
        |> to_setting("Hide empty sections")
        |> press(" ")
        |> to_setting("Number items")
        |> press(" ")

      view = changed.db.views[v]
      assert view.hide_done and view.hide_empty and view.number_items

      back = press(changed, {:alt_f, 8})
      view = back.db.views[v]
      refute view.hide_done or view.hide_empty or view.number_items
      assert view.name == "Tasks"
    end

    # silent, as Agenda (the owner's choice, 2026-10-25)
    test "F8 on the name leaves it, without a word", %{state: state, view: v} do
      named = state |> props() |> to_setting("View name") |> press({:f, 8})
      assert named.db.views[v].name == "Tasks"
      assert named.message == nil
    end

    test "ESC puts it back as it was before F8 too", %{state: state} do
      done_on = State.run(state, {:toggle_view_option, state.view_id, :hide_done})
      cancelled = done_on |> props() |> to_setting("Hide done items") |> press([{:f, 8}, :esc])
      assert cancelled.db == done_on.db
    end
  end

  describe "Section Properties" do
    test "F8 on Filter clears the section's filter; ALT-F8 its sort too", %{state: state} do
      filtered =
        state
        |> press({:f, 6})
        |> to_setting("Filter")
        |> press([" ", :ctrl_home, :down, :down, :down, :down, " ", :enter])

      section = fn s -> hd(State.view(s).sections) end
      assert section.(filtered).filter != []
      cleared = press(filtered, {:f, 8})
      assert section.(cleared).filter == []

      sorted = %{
        filtered
        | db:
            Agendum.Core.Facade.Views.set_sort(filtered.db, filtered.view_id, {:section, 0}, [
              %Agendum.Core.View.SortKey{}
            ])
      }

      all = press(sorted, {:alt_f, 8})
      assert section.(all).filter == [] and section.(all).sort == nil
    end
  end

  describe "Customize" do
    test "ALT-F8 gives back a fresh start's preferences", %{state: state} do
      changed =
        state
        |> press([{:f, 10}, "u", "c"])
        |> to_setting("Confirm mode")
        |> press(" ")
        |> to_setting("Sound")
        |> press(" ")
        |> to_setting("Theme")
        |> press(" ")

      refute changed.prefs.confirm or changed.prefs.sound
      refute changed.theme == :classic

      back = press(changed, {:alt_f, 8})
      assert back.prefs.confirm and back.prefs.sound
      assert back.theme == :classic
    end
  end

  describe "Category Properties" do
    test "ALT-F8: a new category's settings, its name kept", %{state: state} do
      # People, a standard category (MAIN, Entry, When, Done come first)
      props = press(state, [{:f, 9}, :down, :down, :down, :down, {:f, 6}])
      id = State.mode(props).cat_id
      assert props.db.categories[id].kind == :standard
      name = props.db.categories[id].name

      changed =
        props
        |> to_setting("Short name")
        |> press([{:f, 2}, "mtg", :enter])
        |> to_setting("Special actions")
        |> press(" ")

      cat = changed.db.categories[id]
      assert cat.short_name == "mtg" and cat.special != nil

      cat = press(changed, {:alt_f, 8}).db.categories[id]
      assert cat.short_name in [nil, ""] and cat.special == nil and cat.match_name
      assert cat.name == name
    end
  end

  describe "File Properties and the Sort box" do
    test "File Properties: ALT-F8 gives back a new file's settings", %{state: state} do
      new = Agendum.Core.new_file()

      changed =
        state
        |> press([{:f, 10}, "f", "p"])
        |> to_setting("Insert new columns in")
        |> press(" ")

      refute changed.db.insert_columns == new.insert_columns
      back = press(changed, {:alt_f, 8})
      assert back.db.insert_columns == new.insert_columns
    end

    test "the Sort box: F8 on Order puts it back; ALT-F8 takes the sort away", %{state: state} do
      sorted =
        state
        |> press([{:f, 10}, "v", "p"])
        |> to_setting("Item sorting")
        |> press(" ")
        |> to_setting("Sort on")
        |> press(" ")
        |> to_setting("Order")
        |> press(" ")

      assert [%{order: :desc}] = State.view(sorted).sort
      assert [%{order: :asc}] = State.view(press(sorted, {:f, 8})).sort
      assert State.view(press(sorted, {:alt_f, 8})).sort == []
    end
  end

  describe "the other settings boxes" do
    defp file_box(state, label),
      do: state |> press([{:f, 10}, "f", "p"]) |> to_setting(label) |> press(" ")

    test "Global Date Settings and Display Format: a new file's", %{state: state} do
      new = Agendum.Core.new_file()

      dates =
        file_box(state, "Global date settings") |> to_setting("Beginning of week") |> press(" ")

      refute dates.db.date_settings == new.date_settings
      assert press(dates, {:alt_f, 8}).db.date_settings == new.date_settings

      display =
        dates
        |> to_setting("Display format")
        |> press(" ")
        |> to_setting("Date separator")
        |> press(" ")

      refute display.db.date_format == new.date_format
      assert press(display, {:alt_f, 8}).db.date_format == new.date_format
    end

    test "Auto-assign settings: a new file's", %{state: state} do
      new = Agendum.Core.new_file()
      auto = file_box(state, "Auto-assign settings") |> to_setting("Ignore accents") |> press(" ")
      refute auto.db.match_settings == new.match_settings
      assert press(auto, {:alt_f, 8}).db.match_settings == new.match_settings
    end

    test "a category's text matching: Global again", %{state: state} do
      box =
        state
        |> press([{:f, 9}, :down, :down, :down, :down, {:f, 6}])
        |> to_setting("Advanced settings")
        |> press(" ")
        |> to_setting("Match on")
        |> press(" ")

      id = State.mode(box).cat_id
      assert box.db.categories[id].match_overrides != %{}
      assert press(box, {:alt_f, 8}).db.categories[id].match_overrides == %{}
    end

    test "a date category's date settings: When's as a new file has them", %{state: state} do
      box =
        state
        |> press([{:f, 9}, :down, :down, {:f, 6}])
        |> to_setting("Advanced settings")
        |> press(" ")

      id = State.mode(box).cat_id
      assert id == box.db.special.when
      changed = box |> to_setting("Assign item date") |> press(" ")
      refute changed.db.categories[id].date_rule == box.db.categories[id].date_rule
      new = Agendum.Core.new_file()

      assert press(changed, {:alt_f, 8}).db.categories[id].date_rule ==
               new.categories[new.special.when].date_rule
    end

    test "the input format: a fresh start's", %{state: state} do
      box =
        state
        |> press([{:f, 10}, "u", "c"])
        |> to_setting("Input format")
        |> press(" ")
        |> to_setting("Input clock")
        |> press(" ")

      refute State.input(box) == %Agendum.Core.InputFormat{}
      assert State.input(press(box, {:alt_f, 8})) == %Agendum.Core.InputFormat{}
    end

    test "Macro Properties: a new macro's run-from places, no key", %{state: state} do
      {:ok, db, id} = Agendum.Core.add_macro(state.db, "Weed")
      db = db |> Agendum.Core.set_macro_keys(id, "x") |> Agendum.Core.attach_macro(id, "{F4}")
      box = Agendum.TUI.Boxes.MacroProps.open(%{state | db: db}, id)
      assert State.mode(box).macro_id == id
      changed = box |> to_setting("Note") |> press(" ")
      refute changed.db.macros[id].run_from.note
      back = press(changed, {:alt_f, 8}).db.macros[id]
      assert back.run_from == %Agendum.Core.Macro{}.run_from
      assert back.key == nil
    end

    test "Datebook settings: a new datebook's", %{state: state} do
      book = Enum.find(Database.views(state.db), & &1.datebook)

      box =
        state
        |> State.switch_view(book.id)
        |> press([{:f, 10}, "v", "p"])
        |> to_setting("Period")
        |> press(" ")

      refute box.db.views[book.id].datebook.period == :week
      back = press(box, {:alt_f, 8}).db.views[book.id].datebook
      assert back.period == :week and back.base == "today"
    end

    test "Item Column Properties: a new item column's", %{state: state} do
      box = state |> press([:down, {:f, 10}, "v", "c", "p"])
      assert %{type: :item_column} = State.mode(box)
      changed = box |> to_setting("Set width") |> press(" ")
      item_column = fn s -> hd(State.view(s).sections).item_column end
      assert item_column.(changed).set == :manual
      assert item_column.(press(changed, {:alt_f, 8})) == %Agendum.Core.View.ItemColumn{}
    end
  end
end
