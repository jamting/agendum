defmodule Agendum.Core.Extras.ZettelIdTest do
  use ExUnit.Case, async: true
  alias Agendum.Core.Extras.ZettelId
  doctest ZettelId

  test "known values (matches the reference implementation)" do
    assert ZettelId.encode!(0) == "babababa"
    assert ZettelId.encode!(1) == "bonalaku"
    assert ZettelId.encode!(65_535) == "palamolu"
    assert ZettelId.encode!(262_143) == "palupiko"
    assert ZettelId.encode!(16_777_215) == "kidenuli"
  end

  test "rejects out-of-range and non-integer input" do
    for bad <- [-1, 16_777_216, 1.0, "1", nil] do
      assert ZettelId.encode(bad) == {:error, :out_of_range}
    end
  end

  test "rejects malformed ids" do
    for bad <- [
          "",
          "bonalak",
          "bonalakuba",
          "honalaku",
          "zonalaku",
          "bonalavu",
          "bona-laku",
          "bonalak4",
          123
        ] do
      assert ZettelId.decode(bad) == {:error, :invalid_id}
    end
  end

  # Full check of all 2^24 values; takes some seconds.
  # Excluded by default (see test_helper.exs). Run with: mix test --include exhaustive
  @tag :exhaustive
  @tag timeout: :infinity
  test "scramble is a bijection and every id round-trips" do
    max = ZettelId.max()

    for n <- 0..max do
      x = ZettelId.scramble(n)
      assert x in 0..max
      assert ZettelId.unscramble(x) == n
    end
  end

  test "round-trips a sample of the space" do
    for n <- Enum.take_random(0..ZettelId.max(), 20_000), not ZettelId.reserved?(n) do
      assert n |> ZettelId.encode!() |> ZettelId.decode!() == n
    end
  end

  describe "reserved words" do
    test "every reserved word decodes to its listed number" do
      for {word, n} <- ZettelId.reserved() do
        assert ZettelId.decode(word) == {:ok, n}, "#{word} should decode to #{n}"
        assert ZettelId.reserved?(word)
        assert ZettelId.reserved?(n)
      end
    end

    test "reserved numbers are refused by encode" do
      for {_word, n} <- ZettelId.reserved() do
        assert ZettelId.encode(n) == {:error, :reserved}
        assert_raise ArgumentError, fn -> ZettelId.encode!(n) end
      end
    end

    test "reserved list is sorted by number and has no duplicates" do
      numbers = Enum.map(ZettelId.reserved(), &elem(&1, 1))
      assert numbers == Enum.sort(numbers)
      assert numbers == Enum.uniq(numbers)
    end

    test "next_unreserved skips reserved numbers and never returns one" do
      for {_word, n} <- ZettelId.reserved() do
        m = ZettelId.next_unreserved(n)
        assert m > n
        refute ZettelId.reserved?(m)
        assert {:ok, _} = ZettelId.encode(m)
      end

      assert ZettelId.next_unreserved(ZettelId.max() + 1) == {:error, :out_of_range}
    end
  end
end
