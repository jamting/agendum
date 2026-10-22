defmodule Agendum.Core.Extras.ZettelId do
  @moduledoc """
  Short, pronounceable, deterministic IDs for Zettelkasten notes.

  This module implements **Quadsyl-24: scrambled four-syllable
  identifiers.** It maps every integer in `0..16_777_215` (a 24-bit space)
  to an 8-letter string such as `"bonalaku"` and back again, one-to-one.

  ## Quadsyl-24 in brief

    * **Space:** 24 bits, `0..16_777_215`.
    * **Format:** exactly 4 syllables = 8 lowercase letters, always
      consonant-vowel (CVCVCVCV).
    * **Alphabet:** 64 syllables, 6 bits each: consonants `bdfgklmnprstv`
      x vowels `aeiou`, minus the excluded syllable `vu`.
    * **Scrambling:** a fixed 24-bit bijection (3 rounds of odd multiply +
      xorshift), so consecutive numbers get unrelated-looking IDs.
    * **Lineage:** inspired by proquints (Wilkerson, 2009, arXiv:0901.4016)
      and Koremutake (shorl.com), with a different alphabet, fixed width
      and added scrambling. Not compatible with either.

  ## Reserved words

  The 267 real English and Swedish words that are valid IDs (`"kategori"`,
  `"lemonade"`, `"kukeliku"`, ...) are reserved. They work in one direction
  only:

    * `decode/1` turns a reserved word into its number, as usual.
    * `encode/1` refuses those numbers with `{:error, :reserved}`.

  So real words never appear as regular note IDs, and each one is free to
  name a special note. This is a policy check in `encode/1`, not a property
  of the encoding: mathematically, every number still has exactly one ID.
  Allocate regular numbers with `next_unreserved/1` to skip them.

  ## How it works

  Encoding has two stages:

    1. **Scramble.** The number is passed through a reversible 24-bit
       mixing function (a bijection on `0..2^24-1`). Consecutive numbers
       such as 1, 2 and 3 therefore get unrelated-looking IDs instead of
       IDs that differ only in their last letter.

    2. **Spell.** The scrambled 24-bit value is split into four 6-bit
       chunks. Each chunk selects one of 64 two-letter syllables: a
       consonant from `bdfgklmnprstv` (13) followed by a vowel from
       `aeiou` (5), minus one excluded syllable (`vu`) to get exactly 64.

  Decoding runs the same steps backwards.

  ## The scrambler

  Three rounds of:

      x = (x * odd_constant) mod 2^24
      x = x XOR (x >>> 12)

  Both steps are invertible:

    * Multiplying by an odd number mod 2^24 is undone by multiplying by its
      modular inverse. Odd numbers are always invertible mod a power of two.
    * `x XOR (x >>> s)` is undone by repeating the shift-and-XOR until all
      24 bits are recovered (see `unxorshift/2`).

  Every one of the 2^24 inputs has been checked to round-trip, so the
  mapping is a bijection: every number has exactly one ID and every
  well-formed ID decodes to exactly one number.

  This is an obfuscation, not encryption. Anyone with this module can
  decode an ID. Its only purpose is to make neighbouring IDs dissimilar.

  ## Stability warning

  IDs depend on the syllable table, the constants and the round count.
  Changing any of them changes every ID, so treat them as frozen once you
  start assigning IDs to notes.

  ## Examples

      iex> Agendum.Core.Extras.ZettelId.encode(1)
      {:ok, "bonalaku"}

      iex> Agendum.Core.Extras.ZettelId.decode("bonalaku")
      {:ok, 1}

      iex> Agendum.Core.Extras.ZettelId.encode(16_777_216)
      {:error, :out_of_range}

      iex> Agendum.Core.Extras.ZettelId.decode("bonalakx")
      {:error, :invalid_id}
  """

  # ---------------------------------------------------------------------------
  # Sample encodings (verified against this module)
  # ---------------------------------------------------------------------------
  #
  #       number  id
  #   ----------  --------
  #            0  babababa
  #            1  bonalaku
  #            2  pigavono
  #            3  pomemaro
  #            4  vosolavo
  #            5  gerokulu
  #            6  nusumabo
  #            7  kitolido
  #            8  lubalipo
  #            9  mibefubi
  #           10  latadora
  #           42  dulabafi
  #          100  rabosalu
  #        1_000  bedaguse
  #       10_000  telegeri
  #       65_535  palamolu
  #      100_000  kemafifa
  #      262_143  palupiko
  #    1_000_000  fukabapu
  #   10_000_000  nedunono
  #   16_777_215  kidenuli

  # ---------------------------------------------------------------------------
  # FUTURE ME: what to do if the 24-bit space runs out (> 16_777_215 notes)
  # ---------------------------------------------------------------------------
  #
  # Rule 1: NEVER change the configuration below. Every existing ID depends
  # on the syllable table, the excluded syllable, the constants, the shift
  # and the round count. Extend, don't modify.
  #
  # Rule 2: the reserved-word list may grow, but only with words whose
  # number is above the current counter, and words in use must never be
  # removed. See the comment above @reserved.
  #
  # A new 30-bit tier would need its own reserved list: search the word
  # lists for 10-letter words made of valid syllables.
  #
  # Recommended: add a 30-bit, 10-letter tier ("Quadsyl-30", or "Pentasyl"
  # if you're strict about the syllable count) and tell tiers apart by LENGTH.
  #
  #   * 8 letters  -> this module as-is, numbers 0..16_777_215
  #   * 10 letters -> five syllables (5 x 6 bits = 30 bits),
  #                   numbers 16_777_216..1_073_741_823 (2^30 - 1)
  #
  #   - Reuse the same 64 syllables (same @syllables, same order).
  #   - Encode n >= 2^24 directly in the 30-bit space. Don't subtract an
  #     offset. Values below 2^24 are simply never issued as 10-letter IDs.
  #     No collisions are possible, because the length always differs.
  #   - decode/1 dispatches on String.length/1: 8 -> old tier, 10 -> new tier.
  #   - The new tier needs its OWN scrambler: @bits 30, mask 2^30 - 1,
  #     shift 15, three new ODD multipliers and their inverses mod 2^30.
  #     Add the same compile-time inverse check as below.
  #   - Verify it's a bijection before use. Exhaustive is 2^30 (~1.07e9)
  #     values; at this module's speed that's roughly half an hour, or
  #     run it in a faster language. Test every value, not a sample.
  #   - That gives 64x the capacity, and every old ID stays valid.
  #
  # Considered and rejected: reversing the letters of an 8-letter ID.
  #
  #   It technically works. A reversed ID is VCVCVCVC ("bonalaku" ->
  #   "ukalanob"), a shape no normal ID can have, so it's a separate
  #   2^24 space with no collisions. But:
  #   - it only doubles capacity (one extra bit), and
  #   - every new ID mirrors an old one (note 1 vs note 16_777_217),
  #     which is easy for a person to confuse.
  #
  # NOT valid: reversing SYLLABLE order ("bo-na-la-ku" -> "kulanabo").
  # That's still CVCVCVCV, i.e. an existing ID, so it WILL collide.
  # ---------------------------------------------------------------------------

  import Bitwise

  # ---------------------------------------------------------------------------
  # Configuration (frozen: changing anything here changes every ID)
  # ---------------------------------------------------------------------------

  # Bit width of the ID space, and the matching mask (2^24 - 1).
  @bits 24
  @mask (1 <<< @bits) - 1

  # Shift used in the xorshift steps: half the width mixes the high
  # and low halves into each other.
  @shift 12

  # Odd multipliers for each round and their inverses mod 2^24.
  # Verified: rem(m * m_inv, 2^24) == 1 for each pair.
  @multipliers [0x9E3779, 0x7F4A7D, 0x5BD1E9]
  @inverses [0xB382C9, 0x1BFED5, 0x7A1659]

  # Letter sets: 13 consonants x 5 vowels = 65 syllables, minus one
  # excluded syllable = exactly 64 (6 bits per syllable).
  #
  # Left out of the consonants on purpose:
  #   c, q, w, x  - ambiguous in Swedish (c = s/k, q = k, w = v) or awkward (x)
  #   z           - sounds like "s" in Swedish
  #   h, j        - removed to get down to 13 consonants; "j" is also
  #                 pronounced differently in Swedish and English
  # "y" is not used as a vowel.
  @consonants ~w(b d f g k l m n p r s t v)
  @vowels ~w(a e i o u)

  # The one syllable dropped to get from 65 to 64. The choice is arbitrary;
  # any single syllable works, but decide before assigning the first ID.
  @excluded ~w(vu)

  # The 64 syllables in index order: "ba", "be", "bi", "bo", "bu", "da", ...
  # Only the index matters to the algorithm, so the set does not have to be
  # a full consonant x vowel grid.
  @syllables for(c <- @consonants, v <- @vowels, do: c <> v) -- @excluded

  # Compile-time lookup tables in both directions.
  @syllable_by_index @syllables |> Enum.with_index() |> Map.new(fn {s, i} -> {i, s} end)
  @index_by_syllable @syllables |> Enum.with_index() |> Map.new()

  # ---------------------------------------------------------------------------
  # Reserved words
  # ---------------------------------------------------------------------------
  #
  # Every real English or Swedish word that happens to be a valid ID, from the
  # Debian word lists (wamerican, wswedish), 8 letters, valid syllables only.
  # Each is paired with the number it decodes to. A test checks every pair.
  #
  # These numbers are never handed out by encode/1, so real words never show
  # up as regular IDs. They are kept for special notes: name the note by its
  # word and store it under decode!(word).
  #
  # Rules for editing this list (see "FUTURE ME" above):
  #   * ADD a word only if its number is above your current counter. A
  #     number the counter has already passed may already be in use.
  #   * NEVER REMOVE a word that a special note uses. Its number would become
  #     encodable again, and a regular note could end up with the same ID.
  # Each entry is {word, number, language(s)}: the language is the word list
  # it was found in (:en American English, :sv Swedish), for reading only.
  @reserved_words_by_language [
    {"makulera", 20_390, :sv},
    {"badinage", 130_871, :en},
    {"levitate", 305_572, :en},
    {"berikade", 337_047, :sv},
    {"validate", 339_325, :en},
    {"relatera", 393_276, :sv},
    {"negative", 403_527, :en},
    {"repetera", 459_175, :sv},
    {"literati", 471_192, :en},
    {"rutabaga", 492_105, :en},
    {"feminina", 501_985, :sv},
    {"redefine", 522_807, :en},
    {"negerade", 558_626, :sv},
    {"generate", 577_884, :en},
    {"denature", 740_338, :en},
    {"populate", 773_580, :en},
    {"timeline", 802_738, :en},
    {"motivate", 810_446, :en},
    {"disunite", 812_083, :en},
    {"volatile", 813_270, :en},
    {"monotona", 820_098, :sv},
    {"filologi", 913_534, :sv},
    {"separate", 917_381, :en},
    {"resoluta", 928_807, :sv},
    {"debutera", 1_062_114, :sv},
    {"dateline", 1_193_811, :en},
    {"doserade", 1_298_005, :sv},
    {"gelatine", 1_323_760, :en},
    {"laminate", 1_325_850, :en},
    {"generade", 1_340_475, :sv},
    {"regerade", 1_374_925, :sv},
    {"militate", 1_476_068, :en},
    {"desolate", 1_660_719, :en},
    {"lonesome", 1_728_453, :en},
    {"filateli", 1_793_106, :sv},
    {"genomila", 1_809_725, :sv},
    {"revidera", 1_996_158, :sv},
    {"befarade", 2_030_767, :sv},
    {"kamerala", 2_054_776, :sv},
    {"navigate", 2_125_299, :en},
    {"liberate", 2_280_315, :en},
    {"beredare", 2_349_378, :sv},
    {"monotone", 2_361_934, :en},
    {"digitala", 2_530_532, :sv},
    {"kurerade", 2_698_940, :sv},
    {"latitude", 2_706_827, :en},
    {"kerosene", 2_716_130, :en},
    {"duperade", 2_757_231, :sv},
    {"lifelike", 2_934_133, :en},
    {"modigare", 2_949_148, :sv},
    {"sedative", 3_004_314, :en},
    {"renegade", 3_010_012, :en},
    # en + sv
    {"superego", 3_015_631},
    {"dikotomi", 3_122_311, :sv},
    {"nosedove", 3_123_606, :en},
    {"raserade", 3_133_957, :sv},
    {"meditate", 3_140_353, :en},
    {"basilika", 3_142_710, :sv},
    {"tabulate", 3_189_166, :en},
    {"keligare", 3_236_540, :sv},
    {"sometime", 3_247_885, :en},
    {"minerade", 3_276_928, :sv},
    {"telefoni", 3_302_494, :sv},
    {"moderata", 3_343_485, :sv},
    {"simulera", 3_372_119, :sv},
    {"tidigare", 3_374_048, :sv},
    {"dikotoma", 3_540_642, :sv},
    {"monotoni", 3_555_701, :sv},
    {"menedare", 3_563_088, :sv},
    {"periferi", 3_604_888, :sv},
    {"fokusera", 3_906_179, :sv},
    {"demolera", 3_972_200, :sv},
    {"legitima", 3_994_728, :sv},
    {"nominate", 4_060_544, :en},
    {"liberala", 4_115_411, :sv},
    {"religisa", 4_220_171, :sv},
    {"figurera", 4_241_714, :sv},
    {"donerade", 4_356_200, :sv},
    {"detonate", 4_402_120, :en},
    {"modulate", 4_496_155, :en},
    {"dirigera", 4_496_804, :sv},
    {"dividera", 4_674_782, :sv},
    {"marinate", 4_715_980, :en},
    {"bevisade", 4_721_160, :sv},
    {"derogate", 4_822_180, :en},
    {"positiva", 4_949_048, :sv},
    {"detonera", 4_972_951, :sv},
    {"soligare", 5_021_183, :sv},
    {"minimera", 5_029_467, :sv},
    {"database", 5_060_693, :en},
    {"paradise", 5_154_166, :en},
    {"solitude", 5_184_067, :en},
    {"punitive", 5_394_112, :en},
    {"referera", 5_405_688, :sv},
    {"saturate", 5_531_004, :en},
    {"tutelage", 5_547_915, :en},
    {"tolerera", 5_603_743, :sv},
    {"beverage", 5_714_446, :en},
    {"relegate", 5_726_857, :en},
    {"topologi", 5_746_803, :sv},
    {"redigera", 5_779_488, :sv},
    {"lifetime", 5_797_847, :en},
    {"beropade", 5_833_138, :sv},
    {"derisive", 5_877_058, :en},
    {"sideline", 5_877_339, :en},
    {"vareviga", 5_921_938, :sv},
    {"fumigate", 5_934_114, :en},
    {"regulate", 5_950_591, :en},
    {"televise", 5_969_690, :en},
    {"tabulera", 6_062_681, :sv},
    {"perifera", 6_091_703, :sv},
    {"pipeline", 6_215_510, :en},
    {"meritera", 6_221_655, :sv},
    {"tiresome", 6_334_266, :en},
    {"motivera", 6_339_193, :sv},
    {"kopulera", 6_465_296, :sv},
    {"salutera", 6_611_055, :sv},
    {"kalasade", 6_647_717, :sv},
    {"relokera", 6_667_721, :sv},
    {"banalare", 6_745_105, :sv},
    {"redovisa", 6_896_940, :sv},
    {"mitigate", 6_934_039, :en},
    {"dominera", 6_960_743, :sv},
    {"fabulera", 7_037_058, :sv},
    {"labilare", 7_046_549, :sv},
    {"federala", 7_265_704, :sv},
    {"voterade", 7_274_106, :sv},
    {"genitive", 7_274_907, :en},
    {"likadana", 7_367_835, :sv},
    {"minimala", 7_411_571, :sv},
    {"melanoma", 7_513_390, :en},
    {"definite", 7_535_101, :en},
    {"venerate", 7_539_760, :en},
    {"raderade", 7_549_737, :sv},
    {"foregone", 7_850_791, :en},
    {"fugitive", 7_869_759, :en},
    {"surefire", 7_931_271, :en},
    {"tolerate", 8_045_168, :en},
    {"relativa", 8_092_080, :sv},
    {"palisade", 8_106_783, :en},
    {"litigate", 8_116_724, :en},
    {"resolute", 8_123_337, :en},
    {"roterade", 8_196_404, :sv},
    {"nominera", 8_214_143, :sv},
    {"panorama", 8_226_960, :en},
    {"navigera", 8_330_195, :sv},
    {"forebode", 8_423_350, :en},
    {"dekorera", 8_442_765, :sv},
    {"delegate", 8_694_320, :en},
    {"generera", 8_731_420, :sv},
    {"titulera", 8_734_712, :sv},
    {"palomino", 8_825_372, :en},
    # en + sv
    {"sabotage", 8_870_510},
    {"bevakade", 8_896_180, :sv},
    {"dominate", 9_004_325, :en},
    {"vegetate", 9_021_395, :en},
    {"gasoline", 9_081_476, :en},
    {"figurine", 9_236_139, :en},
    {"betonade", 9_278_684, :sv},
    {"daterade", 9_294_205, :sv},
    {"kakofoni", 9_433_821, :sv},
    {"ledigare", 9_457_505, :sv},
    {"ponerade", 9_540_571, :sv},
    {"radikala", 9_663_983, :sv},
    {"marinade", 9_705_945, :en},
    {"sodomite", 9_743_540, :en},
    {"serenade", 9_806_467, :en},
    {"roligare", 9_814_198, :sv},
    {"putative", 9_866_025, :en},
    {"kerosine", 9_885_654, :en},
    {"disigare", 10_023_997, :sv},
    {"kurisare", 10_026_073, :sv},
    {"kapitala", 10_065_583, :sv},
    {"girerade", 10_093_814, :sv},
    {"disabuse", 10_156_685, :en},
    {"separera", 10_161_147, :sv},
    {"baseline", 10_243_451, :en},
    {"derivera", 10_284_685, :sv},
    {"meditera", 10_343_471, :sv},
    {"memorera", 10_478_595, :sv},
    {"ruminate", 10_489_049, :en},
    {"renovate", 10_504_564, :en},
    {"moderate", 10_543_733, :en},
    {"forename", 10_685_758, :en},
    {"vidimera", 10_693_968, :sv},
    {"legalese", 10_760_182, :en},
    {"renovera", 10_828_871, :sv},
    {"delikata", 10_831_934, :sv},
    {"leverage", 10_869_696, :en},
    {"feminine", 10_945_107, :en},
    {"separata", 11_364_861, :sv},
    {"datalogi", 11_542_631, :sv},
    {"betalade", 11_566_310, :sv},
    {"karikera", 11_766_515, :sv},
    {"derivata", 11_802_633, :sv},
    {"retirera", 11_876_161, :sv},
    {"demagogi", 11_904_310, :sv},
    {"minibike", 11_938_504, :en},
    {"tudelade", 12_001_244, :sv},
    {"baserade", 12_009_872, :sv},
    {"nematode", 12_110_101, :en},
    {"vemodiga", 12_150_177, :sv},
    {"numerate", 12_186_896, :en},
    {"ligature", 12_187_728, :en},
    {"literate", 12_274_425, :en},
    {"filosofi", 12_358_746, :sv},
    # en + sv
    {"positive", 12_646_671},
    {"debitera", 12_755_742, :sv},
    {"kategori", 12_802_233, :sv},
    {"poserade", 12_824_079, :sv},
    {"sagolika", 12_830_646, :sv},
    {"legitime", 12_941_037, :sv},
    {"resonera", 12_950_457, :sv},
    {"telepati", 12_996_205, :sv},
    {"federate", 13_004_819, :en},
    {"beriberi", 13_269_780, :en},
    {"nosedive", 13_280_518, :en},
    {"befogade", 13_316_768, :sv},
    {"berusade", 13_453_704, :sv},
    {"mutilate", 13_509_882, :en},
    {"lemonade", 13_540_998, :en},
    {"risigare", 13_609_589, :sv},
    {"bifogade", 13_631_569, :sv},
    {"laborera", 13_714_738, :sv},
    {"parerade", 13_723_626, :sv},
    {"leverera", 13_826_733, :sv},
    {"muterade", 13_835_087, :sv},
    {"beramade", 13_892_551, :sv},
    {"verilade", 14_083_696, :sv},
    {"gasolene", 14_181_715, :en},
    {"bevarade", 14_194_618, :sv},
    {"baritone", 14_248_138, :en},
    {"delegera", 14_278_682, :sv},
    {"makaroni", 14_408_194, :sv},
    {"simulate", 14_455_219, :en},
    {"parasite", 14_585_066, :en},
    {"namesake", 14_608_444, :en},
    {"delusive", 14_609_140, :en},
    {"serisare", 14_867_197, :sv},
    {"parabola", 14_876_743, :en},
    {"reparera", 14_941_461, :sv},
    {"lerigare", 15_099_331, :sv},
    {"bevakare", 15_211_175, :sv},
    {"tokigare", 15_217_732, :sv},
    {"negativa", 15_226_666, :sv},
    {"sabotera", 15_251_919, :sv},
    {"paginate", 15_265_465, :en},
    {"maritime", 15_327_982, :en},
    {"kukeliku", 15_369_524, :sv},
    {"pinafore", 15_413_666, :en},
    {"divisive", 15_421_465, :en},
    {"basunera", 15_439_031, :sv},
    {"salivate", 15_472_941, :en},
    {"deponera", 15_474_848, :sv},
    {"girigare", 15_571_720, :sv},
    {"fuselage", 15_644_812, :en},
    {"liberale", 15_754_009, :sv},
    {"lifeline", 15_805_267, :en},
    {"relative", 15_818_644, :en},
    {"resonate", 15_977_896, :en},
    {"semitone", 16_031_527, :en},
    {"gudagoda", 16_073_339, :sv},
    {"noterade", 16_088_753, :sv},
    {"favorite", 16_313_890, :en},
    {"saligare", 16_417_519, :sv},
    {"fireside", 16_595_945, :en},
    {"gudalika", 16_646_312, :sv}
  ]

  # `for` with a tuple pattern takes each entry apart and keeps the pair
  @reserved for {word, n, _language} <- @reserved_words_by_language, do: {word, n}

  @reserved_numbers @reserved |> Enum.map(&elem(&1, 1)) |> MapSet.new()
  @reserved_words @reserved |> Enum.map(&elem(&1, 0)) |> MapSet.new()

  if MapSet.size(@reserved_numbers) != length(@reserved),
    do: raise("reserved numbers must be unique")

  # Sanity checks at compile time.
  if length(@syllables) != 64, do: raise("syllable table must have 64 entries")
  if length(Enum.uniq(@syllables)) != 64, do: raise("syllables must be unique")

  for {m, inv} <- Enum.zip(@multipliers, @inverses) do
    if rem(m * inv, 1 <<< @bits) != 1, do: raise("bad inverse for #{m}")
  end

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @typedoc "An integer in `0..16_777_215`."
  @type id_number :: 0..16_777_215

  @typedoc "An 8-letter ID made of four syllables, e.g. `\"bonalaku\"`."
  @type id :: String.t()

  @doc "The largest number that can be encoded (`16_777_215`)."
  @spec max() :: id_number()
  def max, do: @mask

  @doc """
  Encodes a number into an 8-letter ID.

  Returns:

    * `{:error, :out_of_range}` for anything that isn't an integer in
      `0..16_777_215`.
    * `{:error, :reserved}` if the number's ID is a reserved word (see
      `reserved/0`). Skip it with `next_unreserved/1`.

  Note that `0` encodes to `"babababa"`, because the scrambler maps zero
  to itself. Start your counter at 1 if you don't want that ID.

  ## Examples

      iex> Agendum.Core.Extras.ZettelId.encode(2)
      {:ok, "pigavono"}

      iex> Agendum.Core.Extras.ZettelId.encode(-1)
      {:error, :out_of_range}

      iex> Agendum.Core.Extras.ZettelId.encode(12_802_233)
      {:error, :reserved}
  """
  @spec encode(integer()) :: {:ok, id()} | {:error, :out_of_range | :reserved}
  def encode(n) when is_integer(n) and n >= 0 and n <= @mask do
    if MapSet.member?(@reserved_numbers, n) do
      {:error, :reserved}
    else
      {:ok, n |> scramble() |> spell()}
    end
  end

  def encode(_), do: {:error, :out_of_range}

  @doc """
  Like `encode/1`, but returns the ID directly and raises
  `ArgumentError` if the number is out of range or reserved.

  ## Examples

      iex> Agendum.Core.Extras.ZettelId.encode!(1000)
      "bedaguse"
  """
  @spec encode!(integer()) :: id()
  def encode!(n) do
    case encode(n) do
      {:ok, id} -> id
      {:error, :out_of_range} -> raise ArgumentError, "out of range: #{inspect(n)}"
      {:error, :reserved} -> raise ArgumentError, "reserved: #{inspect(n)}"
    end
  end

  @doc """
  Returns the smallest number `>= n` that `encode/1` accepts, or
  `{:error, :out_of_range}` if there is none left.

  Use it when allocating from your counter, so reserved numbers are
  skipped:

      n = Agendum.Core.Extras.ZettelId.next_unreserved(counter)
      id = Agendum.Core.Extras.ZettelId.encode!(n)
      # store n + 1 as the new counter

  ## Examples

      iex> Agendum.Core.Extras.ZettelId.next_unreserved(5)
      5

      iex> Agendum.Core.Extras.ZettelId.next_unreserved(20_390)
      20_391
  """
  @spec next_unreserved(integer()) :: id_number() | {:error, :out_of_range}
  def next_unreserved(n) when is_integer(n) and n >= 0 and n <= @mask do
    if MapSet.member?(@reserved_numbers, n), do: next_unreserved(n + 1), else: n
  end

  def next_unreserved(_), do: {:error, :out_of_range}

  @doc """
  Returns the reserved words and their numbers, as a list of
  `{word, number}` sorted by number.

  ## Examples

      iex> Agendum.Core.Extras.ZettelId.reserved() |> List.first()
      {"makulera", 20_390}

      iex> {"kategori", 12_802_233} in Agendum.Core.Extras.ZettelId.reserved()
      true
  """
  @spec reserved() :: [{id(), id_number()}]
  def reserved, do: @reserved

  @doc """
  Returns `true` if the ID or number is reserved.

  ## Examples

      iex> Agendum.Core.Extras.ZettelId.reserved?("kukeliku")
      true

      iex> Agendum.Core.Extras.ZettelId.reserved?(15_369_524)
      true

      iex> Agendum.Core.Extras.ZettelId.reserved?("bonalaku")
      false
  """
  @spec reserved?(id() | integer()) :: boolean()
  def reserved?(n) when is_integer(n), do: MapSet.member?(@reserved_numbers, n)

  def reserved?(id) when is_binary(id),
    do: MapSet.member?(@reserved_words, id |> String.trim() |> String.downcase())

  def reserved?(_), do: false

  @doc """
  Decodes an 8-letter ID back into its number.

  Input is case-insensitive and surrounding whitespace is ignored.
  Returns `{:error, :invalid_id}` if the string is not exactly four valid
  syllables.

  Reserved words decode like any other ID. That is how special notes get
  their numbers: `decode!("kategori")` gives `12_802_233`.

  ## Examples

      iex> Agendum.Core.Extras.ZettelId.decode("pigavono")
      {:ok, 2}

      iex> Agendum.Core.Extras.ZettelId.decode("  BEDAGUSE ")
      {:ok, 1000}

      iex> Agendum.Core.Extras.ZettelId.decode("bedagu")
      {:error, :invalid_id}
  """
  @spec decode(String.t()) :: {:ok, id_number()} | {:error, :invalid_id}
  def decode(id) when is_binary(id) do
    case id |> String.trim() |> String.downcase() do
      <<a::binary-size(2), b::binary-size(2), c::binary-size(2), d::binary-size(2)>> ->
        with {:ok, x} <- unspell([a, b, c, d]) do
          {:ok, unscramble(x)}
        end

      _ ->
        {:error, :invalid_id}
    end
  end

  def decode(_), do: {:error, :invalid_id}

  @doc """
  Like `decode/1`, but returns the number directly and raises
  `ArgumentError` if the ID is invalid.

  ## Examples

      iex> Agendum.Core.Extras.ZettelId.decode!("bonalaku")
      1
  """
  @spec decode!(String.t()) :: id_number()
  def decode!(id) do
    case decode(id) do
      {:ok, n} -> n
      {:error, :invalid_id} -> raise ArgumentError, "invalid id: #{inspect(id)}"
    end
  end

  @doc """
  Returns `true` if the string is a well-formed ID.

  ## Examples

      iex> Agendum.Core.Extras.ZettelId.valid?("bonalaku")
      true

      iex> Agendum.Core.Extras.ZettelId.valid?("honalaku")
      false

      iex> Agendum.Core.Extras.ZettelId.valid?("bonalavu")
      false
  """
  @spec valid?(String.t()) :: boolean()
  def valid?(id), do: match?({:ok, _}, decode(id))

  # ---------------------------------------------------------------------------
  # Scrambler: a reversible mixing function on 24-bit integers
  # ---------------------------------------------------------------------------

  @doc """
  Applies the 24-bit bijection. Exposed for testing; `encode/1` calls it.

  Elixir integers have arbitrary precision, so `x * m` never overflows.
  The `band/2` with the mask takes the result mod 2^24.
  """
  @spec scramble(id_number()) :: id_number()
  def scramble(x) do
    Enum.reduce(@multipliers, x, fn m, acc ->
      acc = band(acc * m, @mask)
      bxor(acc, acc >>> @shift)
    end)
  end

  @doc """
  Inverts `scramble/1`: undoes the rounds in reverse order.
  """
  @spec unscramble(id_number()) :: id_number()
  def unscramble(x) do
    @inverses
    |> Enum.reverse()
    |> Enum.reduce(x, fn m_inv, acc ->
      acc = unxorshift(acc, @shift)
      band(acc * m_inv, @mask)
    end)
  end

  # Inverts y = x XOR (x >>> s).
  #
  # The top `s` bits of y equal the top `s` bits of x (nothing was XORed
  # into them). Each pass of `y XOR (guess >>> s)` recovers the next `s`
  # bits, so ceil(bits / s) passes recover all of x.
  defp unxorshift(y, s) do
    passes = div(@bits + s - 1, s)
    Enum.reduce(1..passes, y, fn _, guess -> bxor(y, guess >>> s) end)
  end

  # ---------------------------------------------------------------------------
  # Spelling: 24-bit integer <-> four syllables
  # ---------------------------------------------------------------------------

  # Splits x into four 6-bit chunks, most significant first, and maps each
  # chunk to its syllable.
  defp spell(x) do
    for shift <- [18, 12, 6, 0], into: "" do
      Map.fetch!(@syllable_by_index, band(x >>> shift, 0x3F))
    end
  end

  # Maps four syllables back to their 6-bit indices and reassembles the
  # 24-bit value. Fails if any syllable is not in the table.
  defp unspell(syllables) do
    Enum.reduce_while(syllables, {:ok, 0}, fn syl, {:ok, acc} ->
      case Map.fetch(@index_by_syllable, syl) do
        {:ok, i} -> {:cont, {:ok, acc <<< 6 ||| i}}
        :error -> {:halt, {:error, :invalid_id}}
      end
    end)
  end
end
