# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.DateLanguageTest do
  @moduledoc "Language packs for reading dates (R14c)."
  use ExUnit.Case, async: true

  alias Agendum.Core.DateLanguage
  alias Agendum.Core.DateLanguage.English

  test "packs are found by name, ignoring case" do
    assert DateLanguage.find("English") == {:ok, English}
    assert DateLanguage.find("klingon") == :error
    assert hd(DateLanguage.packs()) == English
  end

  test "alternations try longer words first and let spaces match any whitespace" do
    assert DateLanguage.alt(["mon", "monday"]) == "monday|mon"
    assert Regex.match?(~r/^(?:#{DateLanguage.alt(["i morgon"])})$/u, "i   morgon")
  end

  test "every pack implements the whole behaviour and its words cover its rules" do
    for pack <- DateLanguage.packs() do
      assert is_binary(pack.name())
      assert pack.numeric_order() in [:month_day, :day_month]
      assert pack.clock() in [:agenda, :twenty_four]

      for kind <- ~w(weekdays months numbers ordinals relative periods units intervals edges
                     offsets time_words time_units)a,
          do: assert(is_map(pack.words()[kind]), "#{pack.name()} lacks #{kind}")

      for {_meaning, pattern} <- pack.rules() ++ pack.time_rules(),
          do: assert({:ok, _} = Regex.compile(pattern, "iu"))
    end
  end
end
