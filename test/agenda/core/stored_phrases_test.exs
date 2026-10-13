defmodule Agenda.Core.StoredPhrasesTest do
  @moduledoc """
  Date phrases kept in a file (a date filter's ends, a datebook's base
  date) are read again each time, by whoever opens the file. They are read
  in that person's languages and then in English (R14c), so a file made in
  English, such as a starter file, works for someone who reads only
  Swedish, and the person's own phrases still work.
  """
  use ExUnit.Case, async: true

  alias Agenda.Core
  alias Agenda.Core.{Context, Datebook, DateLanguage, DateSettings, ViewModel}

  # Thursday
  @today ~D[2026-10-08]
  @swedish %Context{now: ~N[2026-10-08 09:00:00], languages: [DateLanguage.Swedish]}

  test "a datebook based on an English phrase, read in Swedish" do
    book = %Datebook{period: :week, base: "beginning of next week"}
    assert Datebook.base_date(book, %DateSettings{}, @swedish) == ~D[2026-10-12]
    # and the person's own language still
    assert Datebook.base_date(%{book | base: "igår"}, %DateSettings{}, @swedish) == ~D[2026-10-07]
  end

  test "a filter set in English shows the right items to a Swedish reader" do
    db = Core.new_file()
    view = hd(db.view_order)
    section = hd(db.views[view].sections).category_id
    {db, late} = Core.add_item(db, "late", @today, section: section)
    {db, soon} = Core.add_item(db, "soon", @today, section: section)
    db = Core.set_date(db, late, db.special.when, ~D[2026-10-01])
    db = Core.set_date(db, soon, db.special.when, ~D[2026-10-20])

    {:ok, db} =
      Core.set_range_filter(
        db,
        view,
        :view,
        db.special.when,
        {:assigned, nil, "yesterday", :inside},
        @today
      )

    [section] = ViewModel.build(db, db.views[view], @swedish)
    assert Enum.map(section.rows, & &1.item.text) == ["late"]
  end
end
