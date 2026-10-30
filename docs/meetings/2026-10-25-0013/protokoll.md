# Minutes of the panel meeting, 2026-10-25-0013

**Place:** Owl's house, the Hundred Acre Wood
**Present:** the owner (chair); Old Mitch Lilypad, David the Squirrel, Dr. Russell, Little Marie-Who-Folds, Claude (Owl's cousin); Eeyore, guest; Owl, host
**Secretary:** Claude · **Approvers:** David the Squirrel and Eeyore
**Agenda:** [dagordning.md](dagordning.md) · **At commit:** `786c13a`

*A windy night, the second meeting of the day, called at short notice and running past midnight. Owl had hung a new portrait over the umbrella stand for the occasion, of himself, rather large. Eeyore arrived last, sat on the stairs where Mitch's papers usually go, and said that he supposed nobody had asked him to come because they wanted to hear what he thought. The panel's voices are lenses in the spirit of the people named, written by Claude, not their words; Eeyore is the Hundred Acre Wood's own. The minutes were made with the `meeting` skill.*

## § 1 Opening of the meeting

Owl opened the meeting, thanked everyone for coming out in such weather, and introduced the guest.

## § 2 Election of a chair, a secretary and two approvers

The owner was elected chair and Claude secretary. David the Squirrel and Eeyore were elected to approve the minutes.

## § 3 Adoption of the agenda

The agenda was adopted as it stood, with one item raised by the owner during the session (§ 5). Mitch, David, Russell and Marie were invited, and Eeyore as the owner's guest, a true AI sceptic.

## § 4 The previous minutes

| Decision (2026-10-24) | Status | Evidence |
| --- | --- | --- |
| § 5.1 ALT-K cycles the ALT, CTRL and SHIFT bars | Done; the letter in the last column dropped after the owner tried it | v0.25.0, `d846527`, `28dbb72` |
| § 5.2 CTRL-F keys decoded; the Mac's checked | Done: CTRL-F4, F9 and F10 get through on the owner's Mac | v0.24.1, `d8b32c3` |
| § 5.3 Every key bar made from the keymaps (ADR 0045) | Done, tested against Agenda's 16 bars | v0.24.2, `02c3249` |

## § 5 Wol in the machine: where the plan stands, and what to add to it

**Background.** `docs/plans/WOL-IN-THE-MACHINE.md` describes a language-model agent living inside the person's file, written on 2026-10-13 and still marked "an idea, not a plan yet", with six principles and five open questions. Since then the command layer it names as its tools is done, the item levels give it its memory (context items), and it is frozen with the extras until the clone is declared done. The owner wants to discuss it, and perhaps add to the document at the end.

**Discussion.** The secretary presented the plan and what had changed since it was written; the golden tasks of principle 6 do not exist yet, and none of the open questions is answered.

**Eeyore** raised five objections: that suggestions slowly make the person's categories the model's own; that a model is right often enough to be trusted and wrong often enough to matter, where Agenda's text matching is dull but predictable; that "private by default" is a promise rather than a property; that a vendor may change the model and Wol behave differently with nothing changed in the file; and that nobody had said how anyone would know Wol helped. **Mitch** found the objections fair and observed that Agenda worked because the person could always see and override the rule; if Wol keeps that, it is Agenda's idea grown up. **David** put trust first: one silent wrong filing costs more than a hundred right ones save, principle 1 is the plan's most important line, and Agendum must be fully usable with Wol switched off for good. **Russell** welcomed help at the point of performance but warned against a queue of suggestions to sift: Wol should propose rarely, at a natural moment, and be quiet when unsure. **Marie** asked that the frozen plan keep its place, gaining principles and answers rather than features, and noticed it had no list of what Wol will not do. **Claude** noted that Agendum is unusually ready (the command table, one undo step per action, the Questions box), that the missing golden tasks are the strongest point, and that a model whose answers go through the core's commands and Questions can make worse proposals but cannot change the file behind the person's back.

The chair asked that all five suggestions be added, calling them very good inputs, and added three thoughts of their own: a concern for privacy, and a wish to explore a local language model doing "small things", categorising first; a level for each assignment (me, rule, language model); and summaries such as this week's timebox or the ten Hacker News items the chair is interested in. The chair asked whether such a local model can learn over time. The panel answered that categorising suits a small local model, running through a local server with no new dependency, so that nothing leaves the machine; that the level fits Agenda's own ladder (the person beats a rule, R11), with Wol below the rule; that bounded summaries end and should be ordinary views; and that a local model learns not by changing its weights but from the person's own accept and refuse decisions and filing, kept as context items the person can inspect. *Eeyore said that if it learns from him, it will be his fault when it is wrong; Claude said yes, in a way one can inspect.*

**Decided:**

1. The plan gains principles 7 (Agendum is whole without Wol), 8 (rare proposals at the moment they help, with their reason shown), 9 (me, then a rule, then Wol: every assignment says which made it) and 10 (local first; a cloud model only for a kind of task the person turns on, told what is sent: the chair's choice).
2. It gains the sections Objections (Eeyore's five, each answered or left open), What Wol will not do, How we would know it helps (the golden tasks first, Wol kept only if it beats text matching), and Learning over time; bounded summaries go into What it could do; the open questions point to their answers.

## § 6 Any other business

The chair asked which local models would suit best now. Claude searched the current roundups (none tested on classification) and reported, for a 16 GB Mac, Qwen3.5 4B or Gemma 4 E4B for filing and Qwen3.5 9B for short summaries, running through Ollama, which uses Apple's MLX since March 2026; perhaps smaller still, an embedding model with a classifier trained on the person's own items, to be tested. **Marie** advised recording the sizes and the way to choose, with the names in one dated line. The chair said the Mac has 16 GB and asked for the dated note and a short overview of installing such a model on a first-generation MacBook Air; the secretary took this to mean the M1 MacBook Air of 2020, since the first MacBook Air of 2008 cannot run these models.

The chair then asked Little Marie-Who-Folds for more on what Wol should not do. **Marie** said a boundary decides once what would otherwise be decided every day, and gave six more: Wol leaves no clutter (summaries are views, context items have a limit and an end); it makes no new categories on its own; it does not become a second home (no chat window, inbox or badges); it brings no drawer of settings; it keeps nothing of what it was shown, beyond a log for the person to check; and it is never needed to leave, so the file stays plain Agendum. Each is to be kept by a test, not by good intentions. *Eeyore said it was the first list he had ever liked, because it was mostly about things not happening.*

**Decided:** the dated note on local models, the overview "Trying one on an M1 MacBook Air (16 GB)" and Marie's six go into the plan.

**Eeyore's closing remarks.** Asked by the chair, Eeyore said the plan was better than the idea had been that morning because Wol had become smaller: local, rare, with its reasons shown, and easy to let go of. He asked that objections 1 and 5 stay open until evidence answers them, and that the meeting remember its promise to switch Wol off if it does not beat text matching; he found principle 7 comforting, since if Wol never comes nothing is lost; and he asked the chair, when Wol thaws, to try the little owl on their own files first, with nobody watching, and believe what it does rather than what it says. **Decided:** his request goes into How we would know it helps.

## § 7 Next meeting

When the agenda has enough items.

## § 8 Closing of the meeting

The chair closed the meeting and thanked the panel for coming at such short notice on such a windy night. *Owl, quite moved by Eeyore's remarks, offered him the last biscuit, which was a thistle.*

## Decisions and where they are recorded

| § | Decision | Recorded in |
| --- | --- | --- |
| 5.1 | Principles 7 to 10 (whole without Wol; rare proposals with their reason; me, rule, Wol; local first, cloud opt-in) | `docs/plans/WOL-IN-THE-MACHINE.md`, Principles |
| 5.2 | Objections, What Wol will not do, How we would know it helps, Learning over time; bounded summaries; the open questions answered in part | `docs/plans/WOL-IN-THE-MACHINE.md` |
| 6 | Local models as of 2026-10 (dated), and trying one on an M1 MacBook Air | `docs/plans/WOL-IN-THE-MACHINE.md`, Local models |
| 6 | Marie's six boundaries, each to be kept by a test | `docs/plans/WOL-IN-THE-MACHINE.md`, What Wol will not do |
| 6 | Eeyore's request: the owner tries it on their own files first; switched off if it does not beat text matching | `docs/plans/WOL-IN-THE-MACHINE.md`, How we would know it helps |

*Minutes kept by Claude. Approved by David the Squirrel and Eeyore.*
