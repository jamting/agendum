defmodule Agendum.HostileFilesTest do
  @moduledoc """
  Every file in `test/fixtures/hostile/` (made by its `make.exs`) read
  through its parser (ROADMAP, Sharpen the saw: a collection of hostile
  files): each must answer as the parser's `@spec` says within a time
  budget, never crash and never hang. The folder says which parser:
  `markdown/`, `ical/`, `feed/`, `ag/`, `json/`, `dates/` (one typed date a
  line). A bug of this kind found later adds its file there.
  """
  use ExUnit.Case, async: true

  alias Agendum.Bounded
  alias Agendum.Core
  alias Agendum.Core.{DateLanguage, DateParser}
  alias Agendum.Core.Extras.{FeedParser, ICal, Markdown}

  @dir "test/fixtures/hostile"
  @now ~N[2026-10-26 23:30:00]
  @budget 3_000

  # One test for each file, made when the module compiles: `for` runs
  # then, and each `test` inside it becomes a test of its own, named after
  # the file. `@external_resource` recompiles the module when a file is
  # added or changed.
  for path <- Path.wildcard("#{@dir}/*/*"), Path.extname(path) != ".exs" do
    @external_resource path
    @path path
    test "#{Path.relative_to(path, @dir)} is read or refused, at once" do
      check(Path.dirname(Path.relative_to(@path, @dir)), File.read!(@path), @path)
    end
  end

  defp check("markdown", text, path) do
    html = Bounded.value!(fn -> Markdown.to_html(text, %{"202610261200" => 1}) end, path, @budget)
    assert is_binary(html)
    # what a note says is text: no tag of its own reaches the page
    refute html =~ "<script"
    refute html =~ "<img src=x"
    refute html =~ ~s(href="javascript:)
  end

  defp check("ical", text, path) do
    case Bounded.value!(fn -> ICal.parse(text) end, path, @budget) do
      {:ok, events} ->
        db = Core.new_file()
        {:ok, db, cal} = Core.subscribe_calendar(db, "Work", "https://w.example/w.ics")

        assert {:ok, _db, _counts} =
                 Bounded.value!(
                   fn -> Core.sync_calendar(db, cal, events, @now) end,
                   path,
                   @budget
                 )

      {:error, :not_ical} ->
        :ok
    end
  end

  defp check("feed", text, path) do
    case Bounded.value!(fn -> FeedParser.parse(text) end, path, @budget) do
      {:ok, %{entries: entries}} ->
        # HTML in a feed becomes plain text
        refute Enum.any?(entries, &(&1.summary =~ "<script" or &1.title =~ "<script"))
        db = Core.new_file()
        {:ok, db, feed} = Core.subscribe_feed(db, "News", "https://n.example/feed")

        assert {:ok, _db, _counts} =
                 Bounded.value!(fn -> Core.sync_feed(db, feed, entries, @now) end, path, @budget)

      {:error, :not_a_feed} ->
        :ok
    end
  end

  defp check("ag", bytes, path) do
    case Bounded.value!(fn -> Core.import_ag(bytes, clock: @now) end, path, @budget) do
      {:ok, %Core.Database{}, _report} -> :ok
      {:error, _reason} -> :ok
    end
  end

  defp check("json", text, path) do
    case Bounded.value!(fn -> Core.import_json(text) end, path, @budget) do
      {:ok, %Core.Database{}} -> :ok
      {:error, message} -> assert is_binary(message)
    end
  end

  defp check("dates", text, path) do
    opts = [languages: [DateLanguage.English, DateLanguage.Swedish]]

    for line <- String.split(text, "\n") do
      case Bounded.value!(
             fn -> DateParser.parse_recurring(line, @now, opts) end,
             {path, line},
             @budget
           ) do
        {:ok, %Date{}, _time, _rule} -> :ok
        :error -> :ok
      end

      case Bounded.value!(
             fn -> DateParser.extract_recurring(line, @now, opts) end,
             {path, line},
             @budget
           ) do
        {:ok, %Date{}, _time, _rule, rest} -> assert is_binary(rest)
        :none -> :ok
      end
    end
  end
end
