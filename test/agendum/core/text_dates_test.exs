# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.TextDatesTest do
  @moduledoc """
  When dates read from item text (SPEC R14; Agenda 2.0 User's Guide,
  "Assigning When Dates from the Text of an Item" and "Editing an Item that
  Includes a When Date").
  """
  use ExUnit.Case, async: true

  import Agendum.Fixtures
  alias Agendum.Core

  # 2026-10-08 is a Thursday
  defp item(db, id), do: db.items[id]

  setup do
    db = Core.new_file()
    %{db: db, when_cat: db.special.when}
  end

  test "a date in the text becomes the When date", %{db: db} do
    {db, id} = Core.add_item(db, "Call Toni on August 7", today())
    assert item(db, id).when == ~D[2027-08-07]
    refute item(db, id).when_explicit
  end

  test "the first date in the text is used", %{db: db} do
    {db, id} = Core.add_item(db, "Cheryl arrives tomorrow, leaves next Friday", today())
    assert item(db, id).when == ~D[2026-10-09]
  end

  test "items without a date get none", %{db: db} do
    {db, id} = Core.add_item(db, "Buy stamps", today())
    assert item(db, id).when == nil
  end

  test "editing the date in the text changes the When date (the manual's example)", %{db: db} do
    {db, id} = Core.add_item(db, "Call Marketing Tuesday to arrange demo", today())
    assert item(db, id).when == ~D[2026-10-13]

    db = Core.edit_item(db, id, "Call Marketing Wednesday to arrange demo", today())
    assert item(db, id).when == ~D[2026-10-14]
  end

  test "relative dates are read once: editing other words keeps the date", %{db: db} do
    {db, id} = Core.add_item(db, "Pay rent tomorrow", today())
    later = Date.add(today(), 5)
    db = Core.edit_item(db, id, "Pay the rent tomorrow", later)
    assert item(db, id).when == ~D[2026-10-09]
  end

  test "removing the date from the text clears a When date it gave", %{db: db} do
    {db, id} = Core.add_item(db, "Pay rent tomorrow", today())
    db = Core.edit_item(db, id, "Pay rent", today())
    assert item(db, id).when == nil
  end

  test "an explicit When date overrides the text, and later edits keep it", %{db: db, when_cat: w} do
    {db, id} = Core.add_item(db, "Call Marketing Tuesday", today())
    {:ok, db, :date} = Core.assign_by_name(db, id, w, "2026-12-24", today())
    assert item(db, id).when == ~D[2026-12-24]
    assert item(db, id).when_explicit

    db = Core.edit_item(db, id, "Call Marketing Wednesday", today())
    assert item(db, id).when == ~D[2026-12-24]
  end

  test "clearing the When date hands it back to the text", %{db: db, when_cat: w} do
    {db, id} = Core.add_item(db, "Call Marketing Tuesday", today())
    {:ok, db, :date} = Core.assign_by_name(db, id, w, "friday", today())
    db = Core.remove_from_category(db, id, w)
    assert item(db, id).when == nil
    refute item(db, id).when_explicit

    db = Core.edit_item(db, id, "Call Marketing Wednesday", today())
    assert item(db, id).when == ~D[2026-10-14]
  end

  test "automatic dating can be turned off for a file", %{db: db} do
    db = Core.toggle_auto_date(db)
    refute Core.auto_dating?(db)
    {db, id} = Core.add_item(db, "The News Review, Vol. 2, November 7, 1990", today())
    assert item(db, id).when == nil
  end

  test "recalc dates items that have a date in their text but no When date", %{db: db} do
    db = Core.toggle_auto_date(db)
    {db, id} = Core.add_item(db, "Dentist next Monday", today())
    db = db |> Core.toggle_auto_date() |> Core.reassign_all(today())
    assert item(db, id).when == ~D[2026-10-12]
  end
end
