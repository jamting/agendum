# Quadsyl-24

**Scrambled four-syllable identifiers for Zettelkasten notes**

Quadsyl-24 turns a number between 0 and 16,777,215 into an 8-letter, pronounceable ID such as `bonalaku`, and turns it back again. It is implemented by the Elixir module `Agendum.Core.Extras.ZettelId` (`lib/agendum/core/extras/zettel_id.ex`), and Agendum gives its zettels these ids (ADR 0039).

## Contents

1. [Format](#format)
2. [How encoding works](#how-encoding-works)
3. [Reserved words](#reserved-words)
4. [Using it](#using-it)
5. [Sample encodings](#sample-encodings)
6. [Funny IDs below 10,000](#funny-ids-below-10000)
7. [Funny IDs from 10,000 to 100,000](#funny-ids-from-10000-to-100000)
8. [Real-word IDs](#real-word-ids)
9. [Rules and future extension](#rules-and-future-extension)
10. [Background and prior art](#background-and-prior-art)
11. [Appendix: all 267 reserved words](#appendix-all-267-reserved-words)

## Format

| Property | Value |
|---|---|
| Number range | 0 – 16,777,215 (24 bits) |
| ID length | always 8 lowercase letters |
| Structure | 4 syllables, each consonant + vowel: CVCVCVCV |
| Bits per syllable | 6 (64 syllables) |
| Consonants (13) | `b d f g k l m n p r s t v` |
| Vowels (5) | `a e i o u` |
| Excluded syllable | `vu` (13 × 5 = 65, minus one = 64) |
| Case | decoding ignores case and surrounding whitespace |

The 64 syllables, in index order (index 0 first):

```
ba be bi bo bu  da de di do du  fa fe fi fo fu  ga ge gi go gu
ka ke ki ko ku  la le li lo lu  ma me mi mo mu  na ne ni no nu
pa pe pi po pu  ra re ri ro ru  sa se si so su  ta te ti to tu
va ve vi vo
```

### Why these letters

| Left out | Reason |
|---|---|
| `c`, `q`, `w` | Ambiguous in Swedish: `c` sounds like s or k, `q` like k, `w` like v. |
| `x` | Awkward at the start of a syllable. |
| `z` | Sounds like `s` in Swedish. |
| `h`, `j` | Removed to get down to 13 consonants; `j` is also pronounced differently in Swedish and English. |
| `y` as a vowel | Pronounced inconsistently by English speakers. |

## How encoding works

Encoding has two stages. Decoding runs them backwards.

**1. Scramble.** The number goes through a reversible mixing function on 24-bit integers, three rounds of:

```
x = (x * odd_constant) mod 2^24
x = x XOR (x >> 12)
```

Multiplying by an odd number mod 2^24 is undone by multiplying by its modular inverse, and `x XOR (x >> 12)` is undone by repeating the shift-and-XOR. Every one of the 2^24 inputs has been tested to round-trip, so the function is a bijection: each number has exactly one ID and each ID exactly one number.

| Round | Multiplier | Inverse mod 2^24 |
|---|---|---|
| 1 | `0x9E3779` | `0xB382C9` |
| 2 | `0x7F4A7D` | `0x1BFED5` |
| 3 | `0x5BD1E9` | `0x7A1659` |

The point of scrambling is that consecutive numbers get unrelated IDs. Without it, 1, 2 and 3 would be `babababe`, `babababi` and `babababo`, differing only in the last letter. With it they are `bonalaku`, `pigavono` and `pomemaro`.

This is obfuscation, not encryption. Anyone with the code can decode any ID.

**2. Spell.** The scrambled value is split into four 6-bit chunks, most significant first. Each chunk picks one syllable from the table above. Example for the number 1, which scrambles to 931,416:

```
scrambled 931,416:  000011  100011  011001  011000
chunk index:             3      35      25      24
syllable:               bo      na      la      ku   ->  "bonalaku"
```

### Edge case: zero

The scrambler maps 0 to itself, so 0 encodes to `babababa`. Start the counter at 1 if you don't want that ID.

## Reserved words

267 of the 16,777,216 IDs are real English or Swedish words, found by searching the Debian word lists `wamerican` and `wswedish` for 8-letter words made only of valid syllables. These are **reserved**:

* **Word → number** works as usual: `decode!("kategori")` returns `12_802_233`.
* **Number → word** is refused: `encode(12_802_233)` returns `{:error, :reserved}`.

This has two effects. Real words never appear as regular note IDs, so a note can't accidentally be called `melanoma`. And every word is free to name a special note, such as an index or a start page: store the note under the word's number.

Reserving is a check in `encode/1`, not a property of the encoding. Mathematically, every number still has exactly one ID.

The smallest reserved number is 20,390 (`makulera`), so reservation has no effect on the first 20,389 notes.

## Using it

| Function | Returns |
|---|---|
| `encode(n)` | `{:ok, id}`, `{:error, :out_of_range}` or `{:error, :reserved}` |
| `encode!(n)` | the ID, or raises `ArgumentError` |
| `decode(id)` | `{:ok, n}` or `{:error, :invalid_id}` |
| `decode!(id)` | the number, or raises `ArgumentError` |
| `valid?(id)` | `true` if the string is a well-formed ID |
| `next_unreserved(n)` | smallest number ≥ `n` that `encode/1` accepts |
| `reserved()` | all `{word, number}` pairs, sorted by number |
| `reserved?(id_or_number)` | `true` for a reserved word or its number |
| `max()` | `16_777_215` |

Allocating a regular ID from the shared counter:

```elixir
alias Agendum.Core.Extras.ZettelId

n = ZettelId.next_unreserved(counter)
id = ZettelId.encode!(n)
# store n + 1 as the new counter
```

Giving a special note a word:

```elixir
n = ZettelId.decode!("kategori")   # 12_802_233
```

## Sample encodings

| Number | ID |
|---:|---|
| 0 | `babababa` |
| 1 | `bonalaku` |
| 2 | `pigavono` |
| 3 | `pomemaro` |
| 4 | `vosolavo` |
| 5 | `gerokulu` |
| 6 | `nusumabo` |
| 7 | `kitolido` |
| 8 | `lubalipo` |
| 9 | `mibefubi` |
| 10 | `latadora` |
| 42 | `dulabafi` |
| 100 | `rabosalu` |
| 1,000 | `bedaguse` |
| 10,000 | `telegeri` |
| 65,535 | `palamolu` |
| 100,000 | `kemafifa` |
| 262,143 | `palupiko` |
| 1,000,000 | `fukabapu` |
| 10,000,000 | `nedunono` |
| 16,777,215 | `kidenuli` |

## Funny IDs below 10,000

Found by searching IDs 1 to 10,000 against English and Swedish dictionaries, a hand-picked word list and repeating syllable patterns. Funniness is subjective.

| Number | ID | Why |
|---:|---|---|
| 921 | `fulafuna` | *ful* = ugly in Swedish |
| 1,121 | `gofigogo` | goofy go-go |
| 1,206 | `nanofika` | a very small coffee break |
| 1,699 | `fisasava` | *fisa* = to fart in Swedish |
| 3,062 | `nininide` | sounds like a stammered "nineteen" |
| 3,178 | `gigapede` | a very large centipede |
| 3,381 | `badaboge` | almost "badaboom" |
| 4,053 | `kobegone` | "Kobe, begone!" |
| 4,671 | `tikiloki` | Norse god at a tiki bar |
| 5,556 | `gagagapa` | Lady Gaga's dad |
| 5,928 | `mikitiki` | sounds like a children's song |
| 6,309 | `galibido` | contains "libido" |
| 6,416 | `popoteto` | sounds like "potato" |
| 6,657 | `mesomeso` | repeats itself (ABAB) |
| 6,838 | `rakimono` | contains "kimono" |
| 7,925 | `lolulolu` | repeats itself (ABAB) |
| 8,182 | `seminute` | half a minute? |
| 8,213 | `denudedi` | contains "denude" and "nude" |
| 8,620 | `kamumumu` | the noise a cow makes when it can't decide |
| 9,311 | `sotototo` | Toto, twice over |
| 9,618 | `pagodagu` | contains "pagoda" |

None of these are reserved; they are ordinary IDs that happen to sound funny. The scrambler spreads IDs evenly, so there are equally many funny ones above 10,000.

## Funny IDs from 10,000 to 100,000

Found the same way as the ones below 10,000, this time also looking for words of six letters and for syllables repeated three or four times. Reserved numbers were skipped.

| Number | ID | Why |
|---:|---|---|
| 10,369 | `likukuku` | a cuckoo clock striking |
| 10,876 | `fugugugu` | fugu, the poisonous pufferfish, in triplicate |
| 12,819 | `kakadunu` | *kakadu* = cockatoo in Swedish |
| 13,162 | `bananapu` | contains "banana" |
| 14,630 | `mufedora` | a hat for a cow |
| 20,938 | `robotise` | an actual English word, and good advice for a zettelkasten with AI agents |
| 24,643 | `gotototo` | "Go, Toto!" (Toto returns from `sotototo`) |
| 25,963 | `nemonemo` | finding Nemo twice |
| 30,392 | `natatata` | a fanfare, or a very small machine gun |
| 33,731 | `fakiraka` | a fakir with a rake |
| 46,121 | `kukikuki` | sounds like a cookie jar being rattled |
| 48,692 | `panamado` | "Panama, darling" |
| 57,890 | `gogodisu` | *godis* = sweets in Swedish |
| 59,191 | `morotulu` | *morot* = carrot in Swedish |
| 63,544 | `kubodega` | a corner shop run by a cow |
| 70,662 | `fopotato` | an actual "potato", after the near-miss `popoteto` at 6,416 |
| 75,921 | `fifififi` | a giant who forgot the "fum" |
| 79,101 | `fugigolo` | contains "gigolo" |
| 86,299 | `boniboni` | sounds like a candy brand |
| 86,547 | `komakoma` | *koma* = coma in Swedish, twice: a very deep sleep |
| 95,133 | `sudokume` | "Sudoku me!" |
| 98,159 | `gogigolo` | "Go, gigolo!" |
| 98,834 | `gopinata` | "Go, piñata!" (said by someone holding a stick) |

Repeated syllables show up much more often in this range: 87 IDs have patterns like ABAB (`nemonemo`), AABB (`pepepapa`), AAAB (`fifififi`) or ABBB (`likukuku`), against 10 below 10,000. That's roughly what you'd expect, since the range holds nine times as many IDs.

## Real-word IDs

A selection of the 267 reserved words. The full list is in the [appendix](#appendix-all-267-reserved-words).

| Number | ID | Language | Meaning |
|---:|---|---|---|
| 20,390 | `makulera` | sv | to void, cancel |
| 130,871 | `badinage` | en | playful banter |
| 305,572 | `levitate` | en | |
| 471,192 | `literati` | en | |
| 492,105 | `rutabaga` | en | swede (the vegetable) |
| 802,738 | `timeline` | en | |
| 1,728,453 | `lonesome` | en | |
| 3,015,631 | `superego` | en, sv | |
| 3,302,494 | `telefoni` | sv | telephony |
| 3,374,048 | `tidigare` | sv | earlier |
| 5,060,693 | `database` | en | |
| 5,154,166 | `paradise` | en | |
| 5,184,067 | `solitude` | en | |
| 5,714,446 | `beverage` | en | |
| 5,797,847 | `lifetime` | en | |
| 6,215,510 | `pipeline` | en | |
| 6,334,266 | `tiresome` | en | |
| 8,226,960 | `panorama` | en | |
| 8,825,372 | `palomino` | en | a golden-coated horse |
| 8,870,510 | `sabotage` | en, sv | |
| 9,081,476 | `gasoline` | en | |
| 9,433,821 | `kakofoni` | sv | cacophony |
| 9,705,945 | `marinade` | en | |
| 9,806,467 | `serenade` | en | |
| 9,814,198 | `roligare` | sv | funnier |
| 12,358,746 | `filosofi` | sv | philosophy |
| 12,802,233 | `kategori` | sv | category |
| 12,996,205 | `telepati` | sv | telepathy |
| 13,269,780 | `beriberi` | en | the only true ABAB word in either dictionary |
| 13,540,998 | `lemonade` | en | |
| 14,248,138 | `baritone` | en | |
| 14,408,194 | `makaroni` | sv | macaroni |
| 14,585,066 | `parasite` | en | |
| 14,608,444 | `namesake` | en | |
| 15,369,524 | `kukeliku` | sv | cock-a-doodle-doo |
| 15,805,267 | `lifeline` | en | |
| 16,313,890 | `favorite` | en | |
| 16,646,312 | `gudalika` | sv | godlike |

The word lists are the standard Debian ones, so slang and rare words are missing. Many of the Swedish hits are verb forms ending in `-era` or `-ade`.

## Rules and future extension

**Never change the configuration.** Every existing ID depends on the syllable table, the excluded syllable, the multipliers, the shift and the round count. Changing any of them changes every ID.

**The reserved list may grow, carefully.**

* Add a word only if its number is above the current counter. A number the counter has passed may already belong to a note.
* Never remove a word that a special note uses. Its number would become available to the counter, and a regular note could get the same ID.

**If the 24-bit space runs out**, add a 10-letter tier rather than changing this one:

* 8 letters: Quadsyl-24 as is, numbers 0 – 16,777,215.
* 10 letters: five syllables, 30 bits, numbers 16,777,216 – 1,073,741,823. Call it Quadsyl-30, or Pentasyl if you want the name to match the syllable count.
* Reuse the same 64 syllables. Encode numbers ≥ 2^24 directly in the 30-bit space, without an offset; the length difference prevents collisions.
* `decode/1` picks the tier from the string length.
* The new tier needs its own scrambler (30 bits, shift 15, three new odd multipliers and their inverses mod 2^30), an exhaustive bijection test over all 2^30 values, and its own reserved list of 10-letter words.
* That gives 64 times the capacity, and every old ID stays valid.

**Considered and rejected: reversing letters.** Reversing an ID's letters (`bonalaku` → `ukalanob`) gives the shape VCVCVCVC, which no normal ID has, so it would double the space without collisions. But it only adds one bit, and every new ID would mirror an old one, which is easy to confuse. Reversing *syllable* order (`kulanabo`) is not an option at all: that is a normal ID and would collide.

## Background and prior art

Quadsyl-24 builds on earlier schemes for turning numbers or binary data into strings people can read, say and remember. These are the four it draws on.

### Proquint

*Daniel Shawcross Wilkerson, 2009.* Paper: [arXiv:0901.4016](https://arxiv.org/abs/0901.4016). Formalized as the IETF Internet-Draft `draft-rayner-proquint`.

* Encodes data in **16-bit blocks**, each spelled as five letters in the pattern **CVCVC**.
* Consonants `bdfghjklmnprstvz` carry 4 bits each, vowels `aiou` carry 2 bits each.
* Blocks are joined with hyphens. Example: the IP address `127.0.0.1` is `lusab-babad`.
* Fixed length per block, no scrambling: consecutive numbers differ only in the last letters.

### Koremutake

*Shorl.com.* Based on Sean B. Palmer's idea of "memorable random strings". Original description: [shorl.com/koremutake.php](http://shorl.com/koremutake.php).

* **128 syllables**, each carrying **7 bits**. 90 have two letters (`ba` … `vy`), 38 have three (`bra` … `tre`).
* Variable length, with no padding and no checksum. Small numbers give short strings.
* Example: `10610353957` encodes to `koremutake`, the scheme's own name.
* Because syllables are 2 or 3 letters, neighbouring numbers can have different string lengths.

### Urbit @p and @q

*Urbit.* Reference library: [urbit-ob](https://github.com/urbit/urbit-ob) (JavaScript), with Haskell and Go ports.

* **3-letter syllables**, each carrying **8 bits**, from separate prefix and suffix tables. Written with a leading `~` and joined with hyphens.
* **@p** names Urbit identities. For values above 16 bits it **obfuscates** the number before encoding, so similar numbers get dissimilar names.
* **@q** encodes arbitrary data **without** obfuscation.
* Examples: `0` is `~zod`, `15663360` is `~nidsut-tomdun`.

### Mnemonicode

*Oren Tirosh, 2000.* Maintained copy: [singpolyma/mnemonicode](https://github.com/singpolyma/mnemonicode).

* Encodes **32 bits as 3 words** from a list of **1,626 words**.
* The words were chosen to be easy to understand over the phone and recognizable internationally. No word is a prefix of another.
* Encodes bytes, not integers. There is no standard rule for turning a number into bytes, so results depend on the implementation.
* Example (from the JavaScript port's documentation): `438871` is `judo-fluid-jet`.

### Comparison

The same number, 107,945, in each scheme. Mnemonicode uses minimal big-endian bytes.

| Scheme | Unit | Bits per unit | 107,945 | Scrambled |
|---|---|---|---|---|
| Proquint | CVCVC block | 16 | `babad-pikon` | no |
| Koremutake | 2–3-letter syllable | 7 | `dasoky` | no |
| Urbit @p | 3-letter syllable | 8 | `~mogsyt-mapryc` | above 16 bits |
| Urbit @q | 3-letter syllable | 8 | `~doznec-pinfyl` | no |
| Mnemonicode | word | ~10.7 | `divide-helena-rio` | no |
| **Quadsyl-24** | 2-letter syllable | 6 | `mimodode` | yes, full 24 bits |

### What Quadsyl-24 takes from each

* **From proquint:** strict consonant-vowel structure, fixed length.
* **From Koremutake:** two-letter syllables as the unit.
* **From Urbit @p:** scrambling, so neighbouring numbers look unrelated.
* **From Mnemonicode:** choosing the alphabet for how it sounds, here for Swedish and English speakers.

It is not compatible with any of them.

## Appendix: all 267 reserved words

The list's home is the code (`@reserved` in `lib/agendum/core/extras/zettel_id.ex`, and `Agendum.Core.Extras.ZettelId.reserved/0`); this copy is for reading.

Sorted by number. Language: `en` = in the American English list, `sv` = in the Swedish list.

| Number | ID | Language |
|---:|---|---|
| 20,390 | `makulera` | sv |
| 130,871 | `badinage` | en |
| 305,572 | `levitate` | en |
| 337,047 | `berikade` | sv |
| 339,325 | `validate` | en |
| 393,276 | `relatera` | sv |
| 403,527 | `negative` | en |
| 459,175 | `repetera` | sv |
| 471,192 | `literati` | en |
| 492,105 | `rutabaga` | en |
| 501,985 | `feminina` | sv |
| 522,807 | `redefine` | en |
| 558,626 | `negerade` | sv |
| 577,884 | `generate` | en |
| 740,338 | `denature` | en |
| 773,580 | `populate` | en |
| 802,738 | `timeline` | en |
| 810,446 | `motivate` | en |
| 812,083 | `disunite` | en |
| 813,270 | `volatile` | en |
| 820,098 | `monotona` | sv |
| 913,534 | `filologi` | sv |
| 917,381 | `separate` | en |
| 928,807 | `resoluta` | sv |
| 1,062,114 | `debutera` | sv |
| 1,193,811 | `dateline` | en |
| 1,298,005 | `doserade` | sv |
| 1,323,760 | `gelatine` | en |
| 1,325,850 | `laminate` | en |
| 1,340,475 | `generade` | sv |
| 1,374,925 | `regerade` | sv |
| 1,476,068 | `militate` | en |
| 1,660,719 | `desolate` | en |
| 1,728,453 | `lonesome` | en |
| 1,793,106 | `filateli` | sv |
| 1,809,725 | `genomila` | sv |
| 1,996,158 | `revidera` | sv |
| 2,030,767 | `befarade` | sv |
| 2,054,776 | `kamerala` | sv |
| 2,125,299 | `navigate` | en |
| 2,280,315 | `liberate` | en |
| 2,349,378 | `beredare` | sv |
| 2,361,934 | `monotone` | en |
| 2,530,532 | `digitala` | sv |
| 2,698,940 | `kurerade` | sv |
| 2,706,827 | `latitude` | en |
| 2,716,130 | `kerosene` | en |
| 2,757,231 | `duperade` | sv |
| 2,934,133 | `lifelike` | en |
| 2,949,148 | `modigare` | sv |
| 3,004,314 | `sedative` | en |
| 3,010,012 | `renegade` | en |
| 3,015,631 | `superego` | en, sv |
| 3,122,311 | `dikotomi` | sv |
| 3,123,606 | `nosedove` | en |
| 3,133,957 | `raserade` | sv |
| 3,140,353 | `meditate` | en |
| 3,142,710 | `basilika` | sv |
| 3,189,166 | `tabulate` | en |
| 3,236,540 | `keligare` | sv |
| 3,247,885 | `sometime` | en |
| 3,276,928 | `minerade` | sv |
| 3,302,494 | `telefoni` | sv |
| 3,343,485 | `moderata` | sv |
| 3,372,119 | `simulera` | sv |
| 3,374,048 | `tidigare` | sv |
| 3,540,642 | `dikotoma` | sv |
| 3,555,701 | `monotoni` | sv |
| 3,563,088 | `menedare` | sv |
| 3,604,888 | `periferi` | sv |
| 3,906,179 | `fokusera` | sv |
| 3,972,200 | `demolera` | sv |
| 3,994,728 | `legitima` | sv |
| 4,060,544 | `nominate` | en |
| 4,115,411 | `liberala` | sv |
| 4,220,171 | `religisa` | sv |
| 4,241,714 | `figurera` | sv |
| 4,356,200 | `donerade` | sv |
| 4,402,120 | `detonate` | en |
| 4,496,155 | `modulate` | en |
| 4,496,804 | `dirigera` | sv |
| 4,674,782 | `dividera` | sv |
| 4,715,980 | `marinate` | en |
| 4,721,160 | `bevisade` | sv |
| 4,822,180 | `derogate` | en |
| 4,949,048 | `positiva` | sv |
| 4,972,951 | `detonera` | sv |
| 5,021,183 | `soligare` | sv |
| 5,029,467 | `minimera` | sv |
| 5,060,693 | `database` | en |
| 5,154,166 | `paradise` | en |
| 5,184,067 | `solitude` | en |
| 5,394,112 | `punitive` | en |
| 5,405,688 | `referera` | sv |
| 5,531,004 | `saturate` | en |
| 5,547,915 | `tutelage` | en |
| 5,603,743 | `tolerera` | sv |
| 5,714,446 | `beverage` | en |
| 5,726,857 | `relegate` | en |
| 5,746,803 | `topologi` | sv |
| 5,779,488 | `redigera` | sv |
| 5,797,847 | `lifetime` | en |
| 5,833,138 | `beropade` | sv |
| 5,877,058 | `derisive` | en |
| 5,877,339 | `sideline` | en |
| 5,921,938 | `vareviga` | sv |
| 5,934,114 | `fumigate` | en |
| 5,950,591 | `regulate` | en |
| 5,969,690 | `televise` | en |
| 6,062,681 | `tabulera` | sv |
| 6,091,703 | `perifera` | sv |
| 6,215,510 | `pipeline` | en |
| 6,221,655 | `meritera` | sv |
| 6,334,266 | `tiresome` | en |
| 6,339,193 | `motivera` | sv |
| 6,465,296 | `kopulera` | sv |
| 6,611,055 | `salutera` | sv |
| 6,647,717 | `kalasade` | sv |
| 6,667,721 | `relokera` | sv |
| 6,745,105 | `banalare` | sv |
| 6,896,940 | `redovisa` | sv |
| 6,934,039 | `mitigate` | en |
| 6,960,743 | `dominera` | sv |
| 7,037,058 | `fabulera` | sv |
| 7,046,549 | `labilare` | sv |
| 7,265,704 | `federala` | sv |
| 7,274,106 | `voterade` | sv |
| 7,274,907 | `genitive` | en |
| 7,367,835 | `likadana` | sv |
| 7,411,571 | `minimala` | sv |
| 7,513,390 | `melanoma` | en |
| 7,535,101 | `definite` | en |
| 7,539,760 | `venerate` | en |
| 7,549,737 | `raderade` | sv |
| 7,850,791 | `foregone` | en |
| 7,869,759 | `fugitive` | en |
| 7,931,271 | `surefire` | en |
| 8,045,168 | `tolerate` | en |
| 8,092,080 | `relativa` | sv |
| 8,106,783 | `palisade` | en |
| 8,116,724 | `litigate` | en |
| 8,123,337 | `resolute` | en |
| 8,196,404 | `roterade` | sv |
| 8,214,143 | `nominera` | sv |
| 8,226,960 | `panorama` | en |
| 8,330,195 | `navigera` | sv |
| 8,423,350 | `forebode` | en |
| 8,442,765 | `dekorera` | sv |
| 8,694,320 | `delegate` | en |
| 8,731,420 | `generera` | sv |
| 8,734,712 | `titulera` | sv |
| 8,825,372 | `palomino` | en |
| 8,870,510 | `sabotage` | en, sv |
| 8,896,180 | `bevakade` | sv |
| 9,004,325 | `dominate` | en |
| 9,021,395 | `vegetate` | en |
| 9,081,476 | `gasoline` | en |
| 9,236,139 | `figurine` | en |
| 9,278,684 | `betonade` | sv |
| 9,294,205 | `daterade` | sv |
| 9,433,821 | `kakofoni` | sv |
| 9,457,505 | `ledigare` | sv |
| 9,540,571 | `ponerade` | sv |
| 9,663,983 | `radikala` | sv |
| 9,705,945 | `marinade` | en |
| 9,743,540 | `sodomite` | en |
| 9,806,467 | `serenade` | en |
| 9,814,198 | `roligare` | sv |
| 9,866,025 | `putative` | en |
| 9,885,654 | `kerosine` | en |
| 10,023,997 | `disigare` | sv |
| 10,026,073 | `kurisare` | sv |
| 10,065,583 | `kapitala` | sv |
| 10,093,814 | `girerade` | sv |
| 10,156,685 | `disabuse` | en |
| 10,161,147 | `separera` | sv |
| 10,243,451 | `baseline` | en |
| 10,284,685 | `derivera` | sv |
| 10,343,471 | `meditera` | sv |
| 10,478,595 | `memorera` | sv |
| 10,489,049 | `ruminate` | en |
| 10,504,564 | `renovate` | en |
| 10,543,733 | `moderate` | en |
| 10,685,758 | `forename` | en |
| 10,693,968 | `vidimera` | sv |
| 10,760,182 | `legalese` | en |
| 10,828,871 | `renovera` | sv |
| 10,831,934 | `delikata` | sv |
| 10,869,696 | `leverage` | en |
| 10,945,107 | `feminine` | en |
| 11,364,861 | `separata` | sv |
| 11,542,631 | `datalogi` | sv |
| 11,566,310 | `betalade` | sv |
| 11,766,515 | `karikera` | sv |
| 11,802,633 | `derivata` | sv |
| 11,876,161 | `retirera` | sv |
| 11,904,310 | `demagogi` | sv |
| 11,938,504 | `minibike` | en |
| 12,001,244 | `tudelade` | sv |
| 12,009,872 | `baserade` | sv |
| 12,110,101 | `nematode` | en |
| 12,150,177 | `vemodiga` | sv |
| 12,186,896 | `numerate` | en |
| 12,187,728 | `ligature` | en |
| 12,274,425 | `literate` | en |
| 12,358,746 | `filosofi` | sv |
| 12,646,671 | `positive` | en, sv |
| 12,755,742 | `debitera` | sv |
| 12,802,233 | `kategori` | sv |
| 12,824,079 | `poserade` | sv |
| 12,830,646 | `sagolika` | sv |
| 12,941,037 | `legitime` | sv |
| 12,950,457 | `resonera` | sv |
| 12,996,205 | `telepati` | sv |
| 13,004,819 | `federate` | en |
| 13,269,780 | `beriberi` | en |
| 13,280,518 | `nosedive` | en |
| 13,316,768 | `befogade` | sv |
| 13,453,704 | `berusade` | sv |
| 13,509,882 | `mutilate` | en |
| 13,540,998 | `lemonade` | en |
| 13,609,589 | `risigare` | sv |
| 13,631,569 | `bifogade` | sv |
| 13,714,738 | `laborera` | sv |
| 13,723,626 | `parerade` | sv |
| 13,826,733 | `leverera` | sv |
| 13,835,087 | `muterade` | sv |
| 13,892,551 | `beramade` | sv |
| 14,083,696 | `verilade` | sv |
| 14,181,715 | `gasolene` | en |
| 14,194,618 | `bevarade` | sv |
| 14,248,138 | `baritone` | en |
| 14,278,682 | `delegera` | sv |
| 14,408,194 | `makaroni` | sv |
| 14,455,219 | `simulate` | en |
| 14,585,066 | `parasite` | en |
| 14,608,444 | `namesake` | en |
| 14,609,140 | `delusive` | en |
| 14,867,197 | `serisare` | sv |
| 14,876,743 | `parabola` | en |
| 14,941,461 | `reparera` | sv |
| 15,099,331 | `lerigare` | sv |
| 15,211,175 | `bevakare` | sv |
| 15,217,732 | `tokigare` | sv |
| 15,226,666 | `negativa` | sv |
| 15,251,919 | `sabotera` | sv |
| 15,265,465 | `paginate` | en |
| 15,327,982 | `maritime` | en |
| 15,369,524 | `kukeliku` | sv |
| 15,413,666 | `pinafore` | en |
| 15,421,465 | `divisive` | en |
| 15,439,031 | `basunera` | sv |
| 15,472,941 | `salivate` | en |
| 15,474,848 | `deponera` | sv |
| 15,571,720 | `girigare` | sv |
| 15,644,812 | `fuselage` | en |
| 15,754,009 | `liberale` | sv |
| 15,805,267 | `lifeline` | en |
| 15,818,644 | `relative` | en |
| 15,977,896 | `resonate` | en |
| 16,031,527 | `semitone` | en |
| 16,073,339 | `gudagoda` | sv |
| 16,088,753 | `noterade` | sv |
| 16,313,890 | `favorite` | en |
| 16,417,519 | `saligare` | sv |
| 16,595,945 | `fireside` | en |
| 16,646,312 | `gudalika` | sv |
