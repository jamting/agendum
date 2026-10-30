# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Fixtures do
  @moduledoc "Helpers for building databases in tests."

  alias Agendum.Core
  alias Agendum.Core.Database

  def today, do: ~D[2026-10-08]

  @doc "Looks up a category id by (unique) name."
  def cat(db, name) do
    case Database.find_categories(db, name) do
      [id] -> id
      other -> raise "expected exactly one category named #{inspect(name)}, got #{inspect(other)}"
    end
  end

  @doc "Builds categories from a nested spec: [{name, opts, children}] or names."
  def with_categories(db, parent \\ nil, spec) do
    parent = parent || db.main_id

    Enum.reduce(spec, db, fn
      name, db when is_binary(name) ->
        {:ok, db, _} = Core.add_category(db, parent, name)
        db

      {name, opts, children}, db ->
        {:ok, db, id} = Core.add_category(db, parent, name, opts)
        with_categories(db, id, children)
    end)
  end

  def item_id(db, text) do
    Enum.find_value(Database.items(db), fn i -> if i.text == text, do: i.id end) ||
      raise "no item #{inspect(text)}"
  end
end
