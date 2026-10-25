defmodule Agendum.Core.TemplateTest do
  @moduledoc """
  File ▸ Transfer ▸ Template (R82; User's Guide 23-26): the file's
  structure without its items: the category hierarchy, views, macros,
  conditions and actions, and the file's settings.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core
  alias Agendum.Core.{Database, Invariants}

  test "a template keeps the structure and drops every item" do
    db = Agendum.Starters.Golden.build()
    template = Core.template(db)

    assert Database.items(template) == []
    assert template.categories == db.categories
    assert template.view_order == db.view_order
    assert template.macros == db.macros
    assert {template.date_format, template.date_settings} == {db.date_format, db.date_settings}
    assert template.numbers == %{} and template.texts == %{} and template.dates == %{}
    assert template.suggestions == %{}
    assert Invariants.violations(template) == []

    # a Show View listing items lists none
    refute Enum.any?(Map.values(template.views), &match?(%{match: {:items, _}}, &1))
  end
end
