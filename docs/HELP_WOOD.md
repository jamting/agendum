# The Hundred Acre Wood in the help

Where the help's written topics (`lib/agendum/tui/help/topics/*.txt`, ADR 0047) touch the Hundred Acre Wood, one row per touch, so the balance can be seen at a glance and a touch found and changed (meeting 2026-10-26-2, § 8). A check keeps the list true: every quoted line here must still be in its topic, word for word (`test/agendum/tui/help_topics_test.exs`).

## The rules

- **Answers first.** The Wood is flavour, not a rule per topic: a touch in an opening line or an example where it comes naturally, left out where it would be forced (the owner, 2026-10-26; meeting 2026-10-22, § 7a).
- **Our own words.** No sentence of Milne's is quoted; characters and places are named, nothing more. No Disney or Shepard pictures.
- **Kindly.** Owl is fond of explaining, never self-centred; no innuendo (the clinic's tone rules).
- **Spread out.** No topic carries more than one or two touches, and no character turns up so often that it grates.

## The touches

| Topic | The words | Who appears |
| --- | --- | --- |
| How to Use Help | "Quick answers about Agendum, wherever you are, as Owl would give them if he were briefer." | Owl |
| Views | "An item can turn up in many views, the way Pooh turns up wherever there is honey." | Pooh |
| Views | "A view called Friends: a section each for Piglet, Rabbit and Eeyore, with what you promised them." | Piglet, Rabbit, Eeyore |
| Enter Items | "Ask Owl how to spell Tuesday", "Three pots of honey by Friday" | Owl |
| Enter Items | "Take Rabbit his umbrella" goes to Rabbit too, if you have a Rabbit. | Rabbit |
| Undiscard an Item | "Changed your mind about something you discarded, as Piglet often does?" | Piglet |
| Categories | "Rabbit can" "be under Friends, under People." … "in Rabbit, it is in Friends and People too." | Rabbit |
| The Category Hierarchy | "like the branches of a tree: Owl's house in the Hundred Acre Wood, as it were." | Owl, the Wood |
| Enter Dates and Times | "Call Kanga next Tuesday" | Kanga |
| Create a Datebook View | "Pooh's would have one slot, marked "Smackerel"." | Pooh |
| Explicit and Conditional Assignments | "Meet with Pooh" in Meetings, edited to "Telephone Pooh", leaves. | Pooh |
| Use Child Categories as Section Heads | "a section each for Piglet, Rabbit and Kanga, under Friends." | Piglet, Rabbit, Kanga |

## By character

| Who | Topics |
| --- | --- |
| Pooh | Views, Create a Datebook View, Explicit and Conditional Assignments |
| Rabbit | Views, Enter Items, Categories, Use Child Categories as Section Heads |
| Piglet | Views, Undiscard an Item, Use Child Categories as Section Heads |
| Owl | How to Use Help, Enter Items, The Category Hierarchy |
| Kanga | Enter Dates and Times, Use Child Categories as Section Heads |
| Eeyore | Views |

Twelve touches in ten of the 108 written topics; the other topics are plain.
