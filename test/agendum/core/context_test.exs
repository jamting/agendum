defmodule Agendum.Core.ContextTest do
  @moduledoc """
  A context can carry the date rules compiled for its languages and input
  format (`Agendum.Core.Context.prepare/1`), so that reading a date does
  not compile them again: the same readings, faster. Rules made for other
  languages or another input format are never used.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core.{Context, DateLanguage, DateParser, InputFormat}

  @now ~N[2026-10-16 09:00:00]
  @swedish [DateLanguage.Swedish, DateLanguage.English]
  @texts [
    "Call Anna next Friday at 3pm",
    "Möte på fredag kl 15",
    "Lunch with Sarah on 12/11/26",
    "Pay the rent on the 25th of every month",
    "in five working days",
    "Buy honey"
  ]

  defp context(languages, input \\ %InputFormat{}),
    do: %Context{now: @now, languages: languages, input: input}

  test "prepare compiles the rules for the languages, and for them with English after" do
    prepared = Context.prepare(context([DateLanguage.Swedish]))

    assert Keyword.fetch!(Context.parser_opts(prepared, nil), :rules)
    assert Keyword.fetch!(Context.stored_parser_opts(prepared, nil), :rules)
    assert Context.parser_opts(context([DateLanguage.Swedish]), nil)[:rules] == nil
  end

  test "readings are the same with prepared rules as without" do
    for languages <- [[DateLanguage.English], @swedish],
        input <- [%InputFormat{}, %InputFormat{number_order: :dmy, separator: ".", clock: 24}],
        text <- @texts do
      plain = Context.parser_opts(context(languages, input), nil)
      prepared = Context.parser_opts(Context.prepare(context(languages, input)), nil)

      assert DateParser.extract_when(text, @now, prepared) ==
               DateParser.extract_when(text, @now, plain)

      assert DateParser.extract_all(text, @now, prepared) ==
               DateParser.extract_all(text, @now, plain)

      assert DateParser.parse_when(text, @now, prepared) ==
               DateParser.parse_when(text, @now, plain)
    end
  end

  test "rules made for other languages or another input format are not used" do
    prepared = Context.prepare(context([DateLanguage.English]))

    assert Context.parser_opts(%{prepared | languages: @swedish}, nil)[:rules] == nil

    other_input = %{prepared | input: %InputFormat{separator: "."}}
    assert Context.parser_opts(other_input, nil)[:rules] == nil
  end

  test "a date or a time alone as the clock carries no rules" do
    assert Context.parser_opts(~D[2026-10-16], nil)[:rules] == nil
    assert Context.parser_opts(@now, nil)[:rules] == nil
  end
end
