defmodule Agendum.Starters.Clinic do
  @moduledoc """
  An Easter egg, and a showcase: the file of Christopher Robin, grown up
  and a psychotherapist, who runs a small private clinic for his old
  friends from the Hundred Acre Wood (still the age they are in the
  books). The diagnoses follow, with the clinic's own disagreements, the
  tongue-in-cheek paper by Shea et al., "Pathology in the Hundred Acre
  Wood: a neurodevelopmental perspective on A.A. Milne", CMAJ 2000;
  163(12):1557 (`docs/reference/1557.full.pdf`).

  The file is caught mid-work: sessions today and this week, treatment
  plans, progress notes (some clients improving, some not), calls,
  overdue paperwork, fees and what was paid in kind. It shows Agendum at
  work: a client's name in an item assigns it to the client (Wol and
  Winnie count too), exclusive categories (Progress, Priority, Location),
  a catch-all made by conditions (Sessions without a client), a numeric
  Fee whose action files the item under Fees, views with columns,
  filters, date ranges and totals, and datebooks.

  `agendum --clinic` opens it (not in `--help`: an Easter egg), and `mix
  agendum.starters --clinic` writes it to a file. Every date is counted
  from `today`, so it is always mid-week at the clinic. Pure.
  """

  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.Starters.Clinic

  @doc "The clinic's file, its dates counted from `today`."
  @spec build(Date.t()) :: Database.t()
  def build(today) do
    Core.new_file(view_name: "To Do", section_name: "To Do")
    |> categories()
    |> Clinic.Items.add(today)
    |> Clinic.Views.add()
    |> macros()
  end

  # --- categories ---

  # {name, options, children}, options as `Core.add_category/4` takes them.
  # Only the clients' names assign items by text (a name in an item's text
  # files it under that client); every other category has
  # `match_name: false`, so that "honey" or "walk" in a text assigns nothing.
  @off [match_name: false]

  @tree [
    {"Clients", @off,
     [
       {"Pooh", [], []},
       {"Piglet", [], []},
       {"Eeyore", [], []},
       {"Owl", [], []},
       {"Rabbit", [], []},
       {"Tigger", [], []},
       {"Kanga", [], []},
       {"Roo", [], []}
     ]},
    {"Treatment plans", @off, []},
    {"Diagnosis", @off,
     [
       {"Honey use disorder", @off, []},
       {"ADHD, inattentive type", @off, []},
       {"ADHD, hyperactive-impulsive type", @off, []},
       {"Generalized anxiety", @off, []},
       {"Dysthymia", @off, []},
       {"Reading difficulty", @off, []},
       {"Need for control", @off, []},
       {"Parenting stress", @off, []},
       {"Housing problems", @off, []},
       {"No diagnosis", @off, []}
     ]},
    {"Treatment", @off,
     [
       {"Motivational interviewing", [short_name: "MI"] ++ @off, []},
       {"CBT", @off, []},
       {"Exposure therapy", @off, []},
       {"Behavioural activation", @off, []},
       {"Literacy support", @off, []},
       {"Parent coaching", @off, []},
       {"Play therapy", @off, []},
       {"Group therapy", @off, []},
       {"Mindfulness", @off, []}
     ]},
    {"Activity", @off,
     [
       {"Sessions", @off, []},
       {"Calls", @off, []},
       {"Write-ups", @off, []},
       {"Admin", @off, []},
       {"Referrals", @off, []},
       {"Reading", @off, []},
       {"Ideas", @off, []}
     ]},
    {"No client", @off, []},
    {"Progress", [exclusive: true] ++ @off,
     [
       {"Improving", @off, []},
       {"Holding steady", @off, []},
       {"Setback", @off, []}
     ]},
    {"Priority", [exclusive: true] ++ @off,
     [{"High", @off, []}, {"Medium", @off, []}, {"Low", @off, []}]},
    {"Location", [exclusive: true] ++ @off,
     [
       {"Consulting room", @off, []},
       {"Home visit", @off, []},
       {"Walk in the Wood", @off, []}
     ]},
    {"Billing", @off, [{"Fees", @off, []}, {"Paid in kind", @off, []}]},
    {"Fee", [kind: :numeric] ++ @off, []}
  ]

  # Other words for a client in an item's text (`;` between them, a phrase
  # in quotes): Owl spells his name WOL, and Pooh is also Winnie and
  # Edward Bear.
  @also_match [
    {"Pooh", ~s(Winnie;"Edward Bear")},
    {"Owl", "Wol"},
    {"Tigger", "Tiggers"}
  ]

  # The clients' notes: the intake summary a therapist keeps on file.
  @client_notes [
    {"Pooh",
     "Winnie-the-Pooh (also Edward Bear). Lives under the name of Sanders.\n" <>
       "Referred by: himself, after getting stuck in Rabbit's front door.\n" <>
       "Presenting problem: honey. 'A little something' at eleven, and at other times.\n" <>
       "Strengths: kind, loyal, writes hums. Very Little Brain, he says; I disagree."},
    {"Piglet",
     "A Very Small Animal. Lives in a beech tree (Trespassers W).\n" <>
       "Presenting problem: worry, about Heffalumps, Woozles, wind and floods.\n" <>
       "Strengths: brave when it matters, and he knows it now."},
    {"Eeyore",
     "Lives in the gloomy place by the stream, in a house of sticks that moves.\n" <>
       "Presenting problem: low mood, for as long as anyone remembers.\n" <>
       "Tail: re-attached (by me, as a boy), with a nail. Holding."},
    {"Owl",
     "Writes his name WOL. Lives at The Wolery since his house blew down.\n" <>
       "Presenting problem: a reading difficulty, hidden for years behind long words.\n" <>
       "Strengths: very bright, generous with advice (sometimes too generous)."},
    {"Rabbit",
     "Lives in the burrow by the sandy bank. Many Friends-and-Relations.\n" <>
       "Presenting problem: needs things Organized; others less so.\n" <>
       "Strengths: gets things done. Has his own Agendum file (see agendum --rabbit)."},
    {"Tigger",
     "Lives with Kanga and Roo. Bouncy.\n" <>
       "Presenting problem: acts first, thinks later (if at all). Climbs trees he cannot get down.\n" <>
       "Likes: Extract of Malt, it turns out."},
    {"Kanga",
     "Mother of Roo. Also looks after Tigger.\n" <>
       "Presenting problem: worry about Roo; finds it hard to let him out of the pocket.\n" <>
       "Pays for Roo's and Tigger's sessions. Always on time."},
    {"Roo",
     "Small. Kanga's son.\n" <>
       "Presenting problem: none, really. Here with his mother.\n" <>
       "Would like everyone to Look At Him Swimming."}
  ]

  # Sessions without a client are filed here: a catch-all made by
  # conditions, as the Planner's Unassigned (all of them must hold).
  @conditions [{"No client", [{"Sessions", :assigned}, {"Clients", :not_assigned}]}]

  defp categories(db) do
    db = add_tree(db, db.main_id, @tree)

    db =
      for {name, conditions} <- @conditions, {target, kind} <- conditions, reduce: db do
        db ->
          {:ok, db} = Core.add_condition(db, id(db, name), id(db, target), kind)
          db
      end

    db =
      Enum.reduce(@also_match, db, fn {name, text}, db ->
        {:ok, db} = Core.set_also_match(db, id(db, name), text)
        db
      end)

    # an item with a fee is filed under Fees, for the Billing view
    {:ok, db} = Core.set_action(db, id(db, "Fee"), id(db, "Fees"), :assign)

    Enum.reduce(@client_notes, db, fn {name, note}, db ->
      Core.set_category_note(db, id(db, name), note)
    end)
  end

  defp add_tree(db, parent, specs) do
    Enum.reduce(specs, db, fn {name, opts, children}, db ->
      {:ok, db, id} = Core.add_category(db, parent, name, opts)
      add_tree(db, id, children)
    end)
  end

  # --- macros ---

  # {name, keys in Agenda's notation}: one, from views only
  @macros [{"Hide/Display done items", "{F10}vhd"}]

  defp macros(db) do
    Enum.reduce(@macros, db, fn {name, keys}, db ->
      {:ok, db, id} = Core.add_macro(db, name)

      db
      |> Core.set_macro_keys(id, keys)
      |> Core.set_macro_run_from(id, :note, false)
      |> Core.set_macro_run_from(id, :catmgr, false)
    end)
  end

  @doc false
  # the clinic's names are unique, so a name is enough to find one
  @spec id(Database.t(), String.t()) :: pos_integer
  def id(db, name) do
    [id] = Database.find_categories(db, name)
    id
  end
end
