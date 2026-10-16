defmodule Agendum.Core.AgFile.ReaderTest do
  @moduledoc """
  The `.AG` reader (R72) reads every file as the reference reader
  `tools/agformat/agdump.py` does: each fixture has its JSON beside it,
  written by agdump.py, and the Elixir reader must give the same.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core.AgFile.Reader

  @dir "test/fixtures/ag"
  @files ~w(ACCOUNT INFOSIFT PEOPLE PLANNER RICH)
  # the owner's own Planner, used for years: on this machine only
  @owners Path.expand("~/Dosbox/APPS/AGENDA/PLANNER.AG")

  for name <- @files do
    test "#{name}.AG reads as agdump.py reads it" do
      {:ok, read} = Reader.read(File.read!(Path.join(@dir, unquote(name) <> ".AG")))
      expected = JSON.decode!(File.read!(Path.join(@dir, unquote(name) <> ".json")))
      assert comparable(read) == expected
    end
  end

  @tag :tmp_dir
  test "the owner's Planner, when it is on this machine", %{tmp_dir: dir} do
    if File.exists?(@owners) do
      out = Path.join(dir, "owner.json")

      {_, 0} =
        System.cmd("python3", ["-I", "tools/agformat/agdump.py", @owners],
          into: File.stream!(out)
        )

      {:ok, read} = Reader.read(File.read!(@owners))
      assert comparable(read) == JSON.decode!(File.read!(out))
    end
  end

  test "anything else is not an Agenda file" do
    assert Reader.read("hello") == {:error, :not_an_agenda_file}
    assert Reader.read("{\"format\": \"agendum-json\"}") == {:error, :not_an_agenda_file}
  end

  test "a file cut short is read as far as it goes, or refused, never a crash" do
    planner = File.read!(Path.join(@dir, "PLANNER.AG"))

    for size <- [1024, 1500, 4096, 20_000, 40_000] do
      result = Reader.read(binary_part(planner, 0, size))
      assert match?({:ok, _}, result) or result == {:error, :not_an_agenda_file}
    end
  end

  test "text is read in the DOS code page" do
    assert Agendum.Core.AgFile.CP437.to_string(<<"R", 0x84, "ksm", 0x94, "rg", 0x86, "s">>) ==
             "Räksmörgås"
  end

  # The reader's maps as agdump.py's JSON: string keys, and without the one
  # thing it adds, how an absolute date was given (agdump.py reads that
  # only for date ranges).
  defp comparable(read) do
    read
    |> update_in([:items], fn items ->
      Enum.map(items, fn item ->
        %{item | assignments: Enum.map(item.assignments, &drop_absolute/1)}
      end)
    end)
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp drop_absolute(%{given_as: %{kind: "absolute"}} = a), do: Map.delete(a, :given_as)
  defp drop_absolute(a), do: a
end
