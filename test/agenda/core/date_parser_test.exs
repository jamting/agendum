defmodule Agenda.Core.DateParserTest do
  use ExUnit.Case, async: true

  alias Agenda.Core.DateParser

  # 2026-10-08 is a Thursday
  @today ~D[2026-10-08]

  for {input, expected} <- [
        {"today", ~D[2026-10-08]},
        {"Tomorrow", ~D[2026-10-09]},
        {"yesterday", ~D[2026-10-07]},
        {"friday", ~D[2026-10-09]},
        {"thu", ~D[2026-10-15]},
        {"next tuesday", ~D[2026-10-13]},
        {"next week", ~D[2026-10-15]},
        {"in 3 days", ~D[2026-10-11]},
        {"in 2 weeks", ~D[2026-10-22]},
        {"2026-12-24", ~D[2026-12-24]},
        {"12/24/26", ~D[2026-12-24]},
        {"1/2/2027", ~D[2027-01-02]}
      ] do
    test "parses #{inspect(input)}" do
      assert DateParser.parse(unquote(input), @today) == {:ok, unquote(Macro.escape(expected))}
    end
  end

  test "rejects nonsense and invalid dates" do
    assert DateParser.parse("someday", @today) == :error
    assert DateParser.parse("2026-02-30", @today) == :error
  end
end
