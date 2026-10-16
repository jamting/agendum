defmodule Agendum.TUI.DateLanguageTest do
  @moduledoc "Dates typed in Swedish with --lang=swedish (R14c)."
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.Core.Database
  alias Agendum.Core.DateLanguage.{English, Swedish}
  alias Agendum.TUI.{State, Update}

  # Thursday 2026-10-08
  defp start_in(languages),
    do: start(Agendum.Sample.build(~D[2026-10-08]), languages: languages)

  defp item(state, text), do: Enum.find(Database.items(state.db), &(&1.text == text))

  test "dates in item text are read in Swedish" do
    state = press(start_in([Swedish]), ["Ring Anna på fredag kl 14", :enter])
    item = item(state, "Ring Anna på fredag kl 14")
    assert item.when == ~D[2026-10-09]
    assert item.when_time == ~T[14:00:00]
  end

  test "so are dates typed in a When column, the When prompt and date filters" do
    state = start_in([Swedish])

    # When column of the first item
    state = press(state, [:down, :right, "nästa fredag", :enter])
    assert Agendum.TUI.Layout.current_row(state).item.when == ~D[2026-10-16]

    # ALT-F2, the When prompt
    state = press(state, [:left, {:alt_f, 2}, {:ctrl, "u"}, "i övermorgon", :enter])
    assert Agendum.TUI.Layout.current_row(state).item.when == ~D[2026-10-10]

    # a date filter from "måndag" (12th) on
    state = press(state, [{:f, 10}, "v", "f", "When", :enter, :down, "måndag", :enter])
    assert State.view(state).filter != []
    refute screen(state) =~ "Not a date"
  end

  test "English is not read unless it is the fallback" do
    state = press(start_in([Swedish]), ["Call Bob friday", :enter])
    assert item(state, "Call Bob friday").when == nil

    state = press(start_in([Swedish, English]), ["Call Bob friday", :enter])
    assert item(state, "Call Bob friday").when == ~D[2026-10-09]
  end

  test "the languages stay when another file is retrieved" do
    state = start_in([Swedish])
    state = Update.loaded(state, "/tmp/x.agenda", {:ok, Agendum.Core.new_file(), "stamp"})
    assert Agendum.TUI.State.languages(state) == [Swedish]
  end

  # Compiling the date rules is most of the cost of reading a date: the
  # session keeps them compiled for its languages and input format, and
  # hands them to the core in its context.
  test "the session's context carries the date rules compiled for its languages" do
    state = start_in([Swedish])
    opts = Agendum.Core.Context.parser_opts(State.context(state), nil)
    assert opts[:languages] == [Swedish]
    assert opts[:rules]

    # File ▸ Customize changes the languages: the rules follow
    state = State.change_preference(state, &State.put_reader(&1, languages: [English]), & &1)
    opts = Agendum.Core.Context.parser_opts(State.context(state), nil)
    assert opts[:languages] == [English]
    assert opts[:rules]
  end
end
