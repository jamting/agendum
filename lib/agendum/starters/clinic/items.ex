defmodule Agendum.Starters.Clinic.Items do
  @moduledoc """
  The clinic's items (`Agendum.Starters.Clinic`): treatment plans, the
  sessions of the last fortnight and the next, progress notes, calls,
  paperwork, reading, ideas, and what was paid in kind.

  Every date is a number of days from `today`. Item texts hold no date or
  number words, so reading them sets no When (the dates are given here);
  a client's name in a text assigns the item to the client. Pure.
  """

  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.Starters.Clinic

  # {text, section, details}. Details, all optional:
  #   in:    more categories to assign, by name
  #   when:  days from today, or {days, ~T[time]}
  #   done:  done this many days ago
  #   fee:   a number in Fee (which files it under Fees)
  #   note:  the item's note
  @plans [
    {"Treatment plan for Pooh", "Treatment plans",
     in:
       ["Honey use disorder", "ADHD, inattentive type"] ++
         ["Motivational interviewing", "CBT", "High"],
     note: """
     Presenting problem: honey. Fourteen pots a week at intake, "and a little something at eleven".

     Goals
     1. Seven pots a week by the end of the season.
     2. One smackerel at eleven, not three.
     3. Notice the urge before the pot is open ("humming it out": urge surfing, in his words).

     Interventions: motivational interviewing; a honey diary; CBT on the thought "it would be a pity to waste it".
     Measure: pots counted together each Monday (alone, he counts the same pot twice).
     Safety plan: no visits to Rabbit before lunch. Doorways are a known risk.
     """},
    {"Treatment plan for Piglet", "Treatment plans",
     in: ["Generalized anxiety", "Exposure therapy", "CBT", "Medium"],
     note: """
     Exposure hierarchy (how frightening, 0-10)
     1. Say the word Heffalump aloud: 3. Done.
     2. Look at a drawing of a Heffalump: 5. Done.
     3. Stand by the Heffalump Trap: 7. Done, at the second attempt (fell in at the first).
     4. A walk on a blustery day: 8. Booked.
     5. A night at home without checking for Woozles: 9.

     Coping card, in his own words: "It is hard to be brave, when you're only a Very Small Animal. But it can be done."
     """},
    {"Treatment plan for Eeyore", "Treatment plans",
     in: ["Dysthymia", "Housing problems", "Behavioural activation", "CBT", "Medium"],
     note: """
     Goals
     1. One pleasant activity a day. Thistles do not count ("they're only food").
     2. Visit one friend a week without being asked.
     3. A house that stays where he built it.

     Thought record: "Nobody tells me. Nobody keeps me informed." Evidence for and against, every session.
     Mood, weekly: he rates everything 2 out of 10. We look at the decimals.
     Housing: Pooh and Piglet once "found" his house of sticks and built it again on the other side of the Wood. Agree with them where it lives.
     """},
    {"Treatment plan for Owl", "Treatment plans",
     in: ["Reading difficulty", "Housing problems", "Literacy support", "CBT", "Medium"],
     note: """
     Owl (who writes it WOL) is very bright, and has hidden a reading difficulty for years behind long words. Nobody noticed: the 2000 paper is right about this one.

     Goals
     1. Say "I don't know" once a session, without a lecture after it.
     2. Literacy tutoring every week (referral sent).
     3. The encyclopaedia as audiobooks.

     Housing: his house blew down in the storm. Now at The Wolery, which was Piglet's house; Piglet moved in with Pooh. Check on both.
     """},
    {"Treatment plan for Rabbit", "Treatment plans",
     in: ["Need for control", "CBT", "Group therapy", "Medium"],
     note: """
     The paper calls it a narcissistic personality disorder. I disagree: Rabbit is not self-loving, he is Organized, and needs others to be Organized too, often against their will. Need for control (provisional).

     Goals
     1. Let one plan go wrong without fixing it.
     2. Ask before organizing a friend.
     3. Fewer Notices.

     Homework: a day of Nothing, as Pooh does it. Rabbit has put it in his own Agendum file, with a priority, a reminder and three sub-tasks. We'll talk about that.
     """},
    {"Treatment plan for Tigger", "Treatment plans",
     in: ["ADHD, hyperactive-impulsive type", "CBT", "Mindfulness", "Medium"],
     note: """
     Goals
     1. Stop, think, then bounce.
     2. No climbing trees with Roo until both of them can get down.
     3. New foods one at a time, with someone there. History: honey, haycorns, thistles; then Extract of Malt, which is Roo's.

     Bounce budget: twenty bounces a session, then a walk. Currently about a hundred and forty.
     """},
    {"Treatment plan for Kanga and Roo", "Treatment plans",
     in: ["Parenting stress", "No diagnosis", "Parent coaching", "Play therapy", "Medium"],
     note: """
     Kanga: a worried mother, and a very capable one.
     Goal: Roo goes into the Wood with Tigger for an hour, with a whistle. Kanga watches from the window for the first ten minutes only.

     Roo: no diagnosis. The bouncing is his age. Play therapy so that he has an hour that is his.
     Extract of Malt is Roo's strengthening medicine; Tigger now has most of it. Discuss with both.
     """}
  ]

  @sessions [
    # --- today ---
    {"Session with Piglet: the blustery walk", "To Do",
     in: ["Exposure therapy", "Walk in the Wood", "High"],
     when: {0, ~T[09:00:00]},
     fee: 60.0,
     note: "Step four of the hierarchy. Bring a scarf for him, and the coping card."},
    {"Home visit to Eeyore: activity schedule", "To Do",
     in: ["Behavioural activation", "Home visit", "Medium"],
     when: {0, ~T[10:00:00]},
     fee: 60.0,
     note:
       "He would not come in: \"Nobody would notice if I didn't.\" I would. Bring the schedule and a thistle."},
    {"Session with Pooh: the honey diary", "To Do",
     in: ["Motivational interviewing", "Consulting room", "High"],
     when: {0, ~T[11:30:00]},
     fee: 60.0,
     note:
       "Not at eleven: at eleven it is time for a little something, and he is unavailable. Moved, with a snack plan."},
    {"Session with Owl: practising I don't know", "To Do",
     in: ["CBT", "Consulting room", "Medium"], when: {0, ~T[13:00:00]}, fee: 60.0},
    {"Family session with Kanga, Roo and Tigger", "To Do",
     in: ["Parent coaching", "Consulting room", "High"],
     when: {0, ~T[14:30:00]},
     fee: 90.0,
     note: "Agenda: the tree. Who climbed it, who could not get down, and who telephoned whom."},
    {"Session with Rabbit", "To Do",
     in: ["CBT", "Consulting room", "Medium"],
     when: {0, ~T[16:00:00]},
     fee: 60.0,
     note: "Rabbit sent an agenda for the session. And an agenda for discussing the agenda."},

    # --- the last fortnight, done ---
    {"Session with Pooh: urge surfing", "To Do",
     in: ["Motivational interviewing", "Consulting room"],
     when: -7,
     done: 7,
     fee: 60.0,
     note: "Hummed through two urges. The third one won. Still: two."},
    {"Session with Piglet: the Heffalump Trap", "To Do",
     in: ["Exposure therapy", "Walk in the Wood"],
     when: -6,
     done: 6,
     fee: 60.0,
     note:
       "Fell into the trap at step three, and climbed out by himself. Framed as evidence of courage. He agreed, eventually."},
    {"Session with Eeyore: thought record", "To Do",
     in: ["CBT", "Home visit"], when: -5, done: 5, fee: 60.0},
    {"Session with Tigger: stop, think, bounce", "To Do",
     in: ["CBT", "Consulting room"],
     when: -4,
     done: 4,
     fee: 60.0,
     note:
       "A hundred and forty bounces. The bookshelf is down; so is volume three of Owl's encyclopaedia."},
    {"Rabbit cancelled: organizing a search for Small", "To Do",
     in: ["Admin"],
     when: -3,
     done: 3,
     note: "Small was found. He had been on Pooh's back the whole time."},
    {"Session with Owl: reading assessment", "To Do",
     in: ["Literacy support", "Consulting room"], when: -8, done: 8, fee: 60.0},
    {"Session with Kanga: letting go, a little", "To Do",
     in: ["Parent coaching", "Consulting room"], when: -9, done: 9, fee: 60.0},
    {"Play session with Roo", "To Do",
     in: ["Play therapy", "Consulting room"],
     when: -9,
     done: 9,
     fee: 45.0,
     note: "Drew a picture of himself swimming. Asked me to look at it. I looked at it."},
    {"Session with Rabbit: the plan that went wrong", "To Do",
     in: ["CBT", "Consulting room"], when: -10, done: 10, fee: 60.0},

    # --- the days ahead ---
    {"Group therapy: the Expotition to the North Pole, revisited", "To Do",
     in:
       ["Group therapy", "Consulting room", "Medium"] ++
         ["Pooh", "Piglet", "Eeyore", "Owl", "Rabbit", "Tigger", "Kanga", "Roo"],
     when: {2, ~T[14:00:00]},
     fee: 30.0,
     note: "A process group. Rabbit wants to lead it. Rabbit will not lead it."},
    {"Session booked by a Mr. Sanders", "To Do",
     in: ["Consulting room", "Low"],
     when: {3, ~T[11:30:00]},
     note:
       "Who is Mr. Sanders? Pooh lives under the name of Sanders. Ask him before anything else."},
    {"Mindfulness on the bridge: Poohsticks", "To Do",
     in: ["Mindfulness", "Walk in the Wood", "Pooh", "Piglet", "Eeyore", "Low"],
     when: {4, ~T[10:00:00]},
     fee: 30.0,
     note: "Eeyore may float under the bridge again. Do not count it as a win, whatever he says."},
    {"Session with Pooh: the doorway plan", "To Do",
     in: ["CBT", "Consulting room", "High"], when: {7, ~T[11:30:00]}, fee: 60.0},
    {"Session with Piglet: a night without checking", "To Do",
     in: ["Exposure therapy", "Consulting room", "Medium"], when: {7, ~T[09:00:00]}, fee: 60.0},
    {"Session with Owl and the literacy tutor", "To Do",
     in: ["Literacy support", "Consulting room", "Medium"], when: {8, ~T[13:00:00]}, fee: 60.0},
    {"Session with Eeyore: a visit, unasked", "To Do",
     in: ["Behavioural activation", "Home visit", "Medium"],
     when: {8, ~T[10:00:00]},
     fee: 60.0,
     note: "The goal is that he visits someone. Not that I visit him. We'll see."},
    {"Session with Tigger: the bounce budget", "To Do",
     in: ["CBT", "Walk in the Wood", "Medium"],
     when: {9, ~T[15:00:00]},
     fee: 60.0,
     note: "Outside, this time. The bookshelf is still being glued."}
  ]

  # progress notes: what a session showed, filed under how it is going
  @progress [
    {"Pooh counted his pots: fewer than at intake", "Improving",
     in: ["Write-ups"],
     when: -1,
     note:
       "He said nine. Counted together: eleven. He did not count the empty ones as \"really pots\". Fourteen at intake, so: progress."},
    {"Pooh stuck in Rabbit's front door again", "Setback",
     in: ["Write-ups"],
     when: -11,
     note:
       "A week of Sustaining Books read aloud until he was thin enough. Rabbit used his legs as a towel-horse, and asks whether this counts as a session. It does not."},
    {"Piglet said Heffalump at a normal volume", "Improving", in: ["Write-ups"], when: -13},
    {"Piglet climbed out of the trap by himself", "Improving", in: ["Write-ups"], when: -6},
    {"Eeyore said: thanks for noticing me", "Holding steady",
     in: ["Write-ups"],
     when: -5,
     note:
       "The first time in eleven sessions. Noted as progress. He objected to its being noted, which I have also noted."},
    {"Eeyore's mood: a little up, if you look at the decimals", "Holding steady",
     in: ["Write-ups"], when: -2, note: "Two out of ten, as always. But 2.3, from 2.1."},
    {"Owl wrote Eeyore's birthday message himself", "Improving",
     in: ["Write-ups"],
     when: -12,
     note:
       "It read HIPY PAPY BTHUTHDTH THUTHDA BTHUTHDY. Eeyore was pleased anyway. Then Owl asked for help with the next one, and that is the progress."},
    {"Owl explained the word Expotition for a whole session", "Setback",
     in: ["Write-ups"],
     when: -8,
     note: "Instead of the reading exercise. Gently back to the plan next time."},
    {"Rabbit put up a Notice about not putting up Notices", "Setback",
     in: ["Write-ups"], when: -3},
    {"Rabbit let the search for Small be organized by Piglet", "Improving",
     in: ["Write-ups"],
     when: -3,
     note: "He watched. He did not correct. Afterwards he lay down for a while."},
    {"Tigger got down from the tree without help", "Improving",
     in: ["Write-ups"], when: -1, note: "Roo stayed up. Kanga telephoned. See the family session."},
    {"Tigger tried thistles again, to be sure", "Setback", in: ["Write-ups"], when: -6},
    {"Kanga let Roo go to the Wood for forty minutes", "Improving",
     in: ["Write-ups"],
     when: -4,
     note: "She watched from the window for twenty, not ten. Still: forty minutes."}
  ]

  @tasks [
    # --- overdue ---
    {"Call Kanga back about the tree", "To Do",
     in: ["Calls", "High"], when: -1, note: "Two messages. The second only said: \"The TREE.\""},
    {"Write up the incident with the bookshelf for Tigger's file", "To Do",
     in: ["Write-ups", "Medium"], when: -2},
    {"Collect Pooh's honey diary", "To Do",
     in: ["Admin", "Medium"],
     when: -2,
     note: "Last time the pages were stuck together. Ask for it in a plastic sleeve."},
    {"Send the letter about Eeyore's housing to the Hundred Acre Board", "To Do",
     in: ["Admin", "High"], when: -3},

    # --- calls ---
    {"Return Rabbit's messages and read the Notice on the door", "To Do",
     in: ["Calls", "Medium"], when: 0},
    {"Call Owl's literacy tutor to confirm the lessons", "To Do",
     in: ["Calls", "Medium"], when: 1},
    {"Ring the Hundred Acre Board about the clinic's licence", "To Do",
     in: ["Calls", "Admin", "Low"], when: 5},
    {"Call Piglet before the blustery walk", "To Do",
     in: ["Calls", "Medium"],
     when: -1,
     done: 1,
     note: "He asked whether a blustery day could be a less blustery one. No."},

    # --- paperwork ---
    {"Write the session notes", "To Do", in: ["Write-ups", "Medium"], when: 1},
    {"Send the invoices", "To Do", in: ["Admin", "Medium"], when: 3},
    {"Renew the clinic's insurance, with a clause for climbing trees", "To Do",
     in: ["Admin", "Low"], when: 9, note: "For Tigger. And for Roo, who follows Tigger."},
    {"Fix the sign on the door, and politely decline Owl's offer to write it", "To Do",
     in: ["Admin", "Low"],
     note:
       "The sign on Owl's own door reads PLES RING IF AN RNSER IS REQIRD. Very kind of him to offer."},
    {"Back up the Agendum file", "To Do", in: ["Admin", "Low"], when: 0},
    {"Move the honey pots out of the waiting room", "To Do",
     in: ["Admin", "High"], when: -8, done: 8, note: "Pooh's own idea, to his credit."},
    {"Buy more tissues for the waiting room", "To Do",
     in: ["Admin", "Low"],
     when: -2,
     done: 2,
     note: "Piglet uses them for worry. Eeyore for effect."},
    {"Glue volume three of Owl's encyclopaedia", "To Do", in: ["Admin", "Low"], when: 2},

    # --- referrals ---
    {"Refer Owl to literacy support", "To Do", in: ["Referrals", "High"], when: -12, done: 12},
    {"Ask the beekeeper whether Pooh may visit the hives, eating nothing", "To Do",
     in: ["Referrals", "Ideas", "Low"],
     note: "Exposure with response prevention. Ask the bees too."},

    # --- reading ---
    {"Read Shea and colleagues: Pathology in the Hundred Acre Wood", "To Do",
     in: ["Reading", "Medium"],
     note: """
     CMAJ 2000; 163(12):1557-1559. In docs/reference/1557.full.pdf.

     Tongue in cheek, and wrong about several of my clients: Rabbit is not a narcissist (just Organized), Roo is fine, and Kanga is doing a fine job.
     Right about Owl's reading, which nobody noticed for years.
     They end: "It is unfortunate that an Expotition was never Organdized to a Child Development Clinic." One was, in the end. This one.
     """},
    {"Read up on motivational interviewing for bears", "To Do", in: ["Reading", "Low"]},
    {"Read The Tao of Pooh, which Pooh recommends and has not read", "To Do",
     in: ["Reading", "Low"]},

    # --- ideas ---
    {"A group for the Friends-and-Relations of Rabbit", "To Do",
     in: ["Ideas", "Group therapy", "Low"],
     note: "Alexander Beetle asked to join. So did Small, if anyone can find him."},
    {"An hour of Nothing, for everyone", "To Do",
     in: ["Ideas", "Mindfulness", "Low"],
     note: "\"What I like doing best is Nothing.\" Pooh says it is evidence-based."},
    {"Honey-free afternoons at the clinic", "To Do", in: ["Ideas", "Low"]}
  ]

  # paid in kind: under Billing, with what came instead of money
  @in_kind [
    {"Pooh paid in honey", "Paid in kind",
     when: -7, note: "Two pots. One was eaten in the waiting room, before the session."},
    {"Rabbit paid in carrots", "Paid in kind",
     when: -10, note: "Sorted by length, with a list of them."},
    {"Piglet paid in haycorns", "Paid in kind", when: -6, note: "He apologised for each one."},
    {"Eeyore paid in thistles", "Paid in kind",
     when: -5, note: "\"The best ones,\" he said. They were not, and he knew it."}
  ]

  @doc "Adds the clinic's items to `db`, dated from `today`."
  @spec add(Database.t(), Date.t()) :: Database.t()
  def add(db, today) do
    (@plans ++ sessions() ++ @progress ++ @tasks ++ @in_kind)
    |> Enum.with_index()
    |> Enum.reduce(db, fn {{text, section, details}, index}, db ->
      add_item(db, today, text, section, details, index)
    end)
  end

  # a session is in Sessions (a cancelled one, filed under Admin, is not)
  defp sessions do
    for {text, section, details} <- @sessions do
      if "Admin" in details[:in],
        do: {text, section, details},
        else: {text, section, Keyword.update!(details, :in, &["Sessions" | &1])}
    end
  end

  defp add_item(db, today, text, section, details, index) do
    days = details |> Keyword.get(:when) |> days()
    # written a little before it was due (or before today), varied by its
    # place in the list so that the Entry dates differ
    entered = Date.add(today, min(days || 0, 0) - 1 - rem(index, 5))
    {db, item} = Core.add_item(db, text, entered, section: Clinic.id(db, section))

    db =
      Enum.reduce(
        Keyword.get(details, :in, []),
        db,
        &Core.assign(&2, item, Clinic.id(&2, &1), today)
      )

    db
    |> set_when(item, Keyword.get(details, :when), today)
    |> set_fee(item, Keyword.get(details, :fee), today)
    |> set_note(item, Keyword.get(details, :note), today)
    |> set_done(item, Keyword.get(details, :done), today)
  end

  # `days/1` and the `set_*` helpers have a clause for "not given" (nil)
  # that leaves the database as it is
  defp days({days, %Time{}}), do: days
  defp days(days), do: days

  defp set_when(db, _item, nil, _today), do: db

  defp set_when(db, item, {days, time}, today),
    do: Core.set_date_time(db, item, db.special.when, Date.add(today, days), time, today)

  defp set_when(db, item, days, today),
    do: Core.set_date(db, item, db.special.when, Date.add(today, days), today)

  defp set_fee(db, _item, nil, _today), do: db

  defp set_fee(db, item, fee, today) do
    {:ok, db} = Core.set_number(db, item, Clinic.id(db, "Fee"), fee, today)
    db
  end

  defp set_note(db, _item, nil, _today), do: db
  # (a heredoc ends with a newline; the note does not need it)
  defp set_note(db, item, note, today), do: Core.set_note(db, item, String.trim(note), today)

  # marked done on the day it was done, as if F4 were pressed then
  defp set_done(db, _item, nil, _today), do: db

  defp set_done(db, item, days_ago, today),
    do: Core.toggle_done(db, item, Date.add(today, -days_ago))
end
