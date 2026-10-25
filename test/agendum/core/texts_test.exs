defmodule Agendum.Core.TextsTest do
  @moduledoc """
  Unindexed categories (R29b; User's Guide 3-10 to 3-11, 3-23 to 3-26;
  checked in Agenda 2.0, 2026-10-25): a category that gives each item
  assigned to it one text value, such as a phone number or an address. The
  text is not a category: it is not matched, and nothing is assigned from
  it.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.{Database, ViewModel}
  alias Agendum.Core.View.SortKey

  @today ~D[2026-10-08]

  # A file with a People section, an Address column and three items.
  defp file do
    db = Core.new_file()
    {:ok, db, people} = Core.add_category(db, db.main_id, "People")
    {:ok, db, address} = Core.add_category(db, db.main_id, "Address")
    {:ok, db} = Core.make_unindexed(db, address)
    view_id = hd(db.view_order)
    db = Core.set_section_category(db, view_id, 0, people)
    db = Core.add_column(db, view_id, address, {0, 1})

    {db, ids} =
      Enum.reduce(["Jill", "Anna", "Bob"], {db, []}, fn text, {db, ids} ->
        {db, id} = Core.add_item(db, text, @today, section: people)
        {db, ids ++ [id]}
      end)

    %{db: db, address: address, view: view_id, ids: ids}
  end

  describe "text values" do
    test "a text assigns the item to the unindexed category" do
      %{db: db, address: address, ids: [jill | _]} = file()
      {:ok, db} = Core.set_text(db, jill, address, "12 Grant Ave")
      assert Database.text(db, jill, address) == "12 Grant Ave"
      assert Database.member?(db, jill, address)

      db = Core.clear_text(db, jill, address)
      assert Database.text(db, jill, address) == nil
      refute Database.member?(db, jill, address)
    end

    test "an empty text takes the item out" do
      %{db: db, address: address, ids: [jill | _]} = file()
      {:ok, db} = Core.set_text(db, jill, address, "12 Grant Ave")
      {:ok, db} = Core.set_text(db, jill, address, "  ")
      refute Database.member?(db, jill, address)
    end

    test "only unindexed categories take texts" do
      %{db: db, ids: [jill | _]} = file()
      assert Core.set_text(db, jill, db.main_id, "x") == {:error, :not_unindexed}
    end

    test "typing in the column sets the text" do
      %{db: db, address: address, ids: [jill | _]} = file()
      {:ok, db, :text} = Core.assign_by_name(db, jill, address, "12 Grant Ave", @today)
      assert Database.text(db, jill, address) == "12 Grant Ave"
    end

    test "an unindexed category does not match item text, nor its values" do
      %{db: db, address: address} = file()
      {db, id} = Core.add_item(db, "Send the address", @today)
      refute Database.member?(db, id, address)
    end

    test "discarding an item or the category forgets its texts" do
      %{db: db, address: address, ids: [jill, anna | _]} = file()
      {:ok, db} = Core.set_text(db, jill, address, "12 Grant Ave")
      {:ok, db} = Core.set_text(db, anna, address, "1 Main St")

      assert Database.delete_item(db, jill).texts |> Map.keys() == [{anna, address}]
      assert {:ok, %{texts: texts}} = Database.delete_category(db, address)
      assert texts == %{}
    end
  end

  describe "converting a standard category" do
    test "a category without children becomes unindexed" do
      db = Core.new_file()
      {:ok, db, phone} = Core.add_category(db, db.main_id, "Phone")
      {:ok, db} = Core.make_unindexed(db, phone)
      assert db.categories[phone].kind == :unindexed
      refute db.categories[phone].match_name
    end

    test "children become the texts of their items; the category's own items an empty one" do
      db = Core.new_file()
      {:ok, db, city} = Core.add_category(db, db.main_id, "City")
      {:ok, db, lund} = Core.add_category(db, city, "Lund")
      {db, a} = Core.add_item(db, "a", @today)
      {db, b} = Core.add_item(db, "b", @today)
      db = db |> Core.assign(a, lund) |> Core.assign(b, city)

      {:ok, db} = Core.make_unindexed(db, city)

      assert db.categories[city].children == []
      assert Database.text(db, a, city) == "Lund"
      assert Database.text(db, b, city) == ""
    end

    test "categories with grandchildren, and other kinds, cannot be converted" do
      db = Core.new_file()
      {:ok, db, top} = Core.add_category(db, db.main_id, "Top")
      {:ok, db, mid} = Core.add_category(db, top, "Mid")
      {:ok, db, _} = Core.add_category(db, mid, "Low")
      assert Core.make_unindexed(db, top) == {:error, :too_deep}
      assert Core.make_unindexed(db, db.special.when) == {:error, :not_standard}
      assert Core.make_unindexed(db, db.main_id) == {:error, :protected}
    end
  end

  describe "unindexed columns" do
    setup do
      %{db: db, address: address, ids: [jill, anna, _bob]} = f = file()
      {:ok, db} = Core.set_text(db, jill, address, "12 Grant Ave")
      {:ok, db} = Core.set_text(db, anna, address, "1 Main St")
      Map.put(f, :db, db)
    end

    test "cells show the text", %{db: db, view: view} do
      [section] = ViewModel.build(db, db.views[view])
      # the Address column is after the new file's When column
      cells = Enum.map(section.rows, fn row -> {row.item.text, List.last(row.cells)} end)
      assert {"Jill", "12 Grant Ave"} in cells
      assert {"Bob", ""} in cells
    end

    test "items sort by their text", %{db: db, view: view, address: address} do
      db = Core.set_sort(db, view, :view, [%SortKey{on: {:category, address}}])
      [section] = ViewModel.build(db, db.views[view])
      assert Enum.map(section.rows, & &1.item.text) == ["Anna", "Jill", "Bob"]
    end

    test "a column added as unindexed makes its head unindexed" do
      db = Core.new_file()
      {:ok, db, phone} = Core.add_category(db, db.main_id, "Phone")
      view = hd(db.view_order)
      {:ok, db} = Core.add_column_as(db, view, phone, :unindexed, {0, 1})
      assert db.categories[phone].kind == :unindexed
    end
  end

  test "the file keeps them (JSON)" do
    %{db: db, address: address, ids: [jill | _]} = file()
    {:ok, db} = Core.set_text(db, jill, address, "12 Grant Ave")
    {:ok, back} = db |> Agendum.Core.JSONFile.encode() |> Agendum.Core.JSONFile.decode()
    assert Database.text(back, jill, address) == "12 Grant Ave"
    assert back.categories[address].kind == :unindexed
  end
end
