# Minutes of the panel meeting, 2026-10-28-1224

**Place:** Owl's house, the Hundred Acre Wood
**Present:** Mattias (chair); Old Mitch Lilypad (Lotus Agenda), José Who Brews (Elixir), Carsten Stargazer (Org-mode), Little Marie-Who-Folds (tidiness); Joel and Jeff, the Chipmunk Brothers (guests: launching an online business); Claude (Owl's cousin); Owl, host
**Apologies:** Great-Uncle Joe, David the Squirrel, Dr. Russell
**Secretary:** Claude · **Approvers:** Little Marie-Who-Folds, Old Mitch Lilypad
**Agenda:** [dagordning.md](dagordning.md) · **At commit:** `e88bd67`

*The third meeting of the day, held in the afternoon. The Chipmunk Brothers had kept their places on the bookshelf since the morning and had, by their own account, read six licences over lunch. Owl had put out a fresh pot of honey and a dictionary, in case of Latin. The panel's voices are lenses in the spirit of the people behind the pseudonyms (`.claude/skills/expert-review/SKILL.md`), written by Claude, not their words; the meeting was held with the `meeting` skill.*

## § 1 Opening of the meeting

Owl opened the licence meeting, In order 1 on the roadmap, tabled from meeting 2026-10-28-0908, § 12. There were no thoughts under Next meeting in the chair's project file; the agenda was the comparison's four questions.

## § 2 Election of a chair, a secretary and two approvers

Mattias chairs; Claude keeps the minutes; Marie and Mitch approve them.

## § 3 Adoption of the agenda

The agenda was adopted as worded.

## § 4 The previous minutes

| Decision (2026-10-28-2) | Status | Evidence |
| --- | --- | --- |
| § 5 A series of meetings | Under way: this is the second | `docs/ROADMAP.md` (In order) |
| §§ 6–9 Private and public, the creek, where public stops, the site | Recorded; markers and site not built yet | `docs/plans/GITHUB.md` § 7, ADR 0050 |
| § 10 Pseudonyms | Done | `.claude/skills/expert-review/SKILL.md`, `0ceff1c` |
| § 11 The dry run as a script | Not yet | `docs/ROADMAP.md` (In order) |
| § 12 A comparison including GPL and AGPL | Done | `6591706` |
| § 13 Marie's order of work | Done | `docs/ROADMAP.md` (In order) |

## § 5 The online check of the FSL and BSL

**Background.** The licence comparison was written from memory; the last session recommended checking the Functional Source License and the Business Source License against their own texts before choosing.

**Discussion.** Claude reported what the texts say. In FSL 1.1 a competing use is making the software available in a *commercial* product or service that substitutes for it, offers substantially similar functionality, or substitutes for another product of the licensor's that uses it and already exists when a version is released; internal use, non-commercial education and research, and professional services are expressly allowed, and each version becomes Apache-2.0 (or MIT) two years after release, irrevocably. So the "existing product" clause would not yet cover a service that is not built. In BSL 1.1, without an additional use grant no production use is allowed at all, so for Agendum the grant is a must; the change licence must be GPL-2.0-compatible, and each version converts at the latest four years after its first release. Neither finding changes the comparison's main lines.

**Noted:** the comparison corrected (`docs/plans/GITHUB.md` § 7).

## § 6 How much protection the core needs, and whether "open source" matters

*[A page here was soaked in the creek. — Rabbit]*

The panel's advice was split: Mitch, the Chipmunks and Marie leaned towards the FSL, José and Carsten towards Apache-2.0; no one advised the BSL or PolyForm.

Before deciding, the chair asked what the community thinks of the AGPL. Claude answered: it is approved by the OSI and the FSF, and has become the open-source answer to cloud hosting, with Elasticsearch (2024) and Redis (2025) adding it as an open option after being forked over stricter licences, and Grafana moving to it in 2021; Plausible Analytics, an Elixir and Phoenix application with a hosted business, uses it. Against it: many companies ban it (Google's internal policy is the known example), its network clause is vaguely worded, and the contributor agreement that a business on the AGPL needs is seen by some as one-sided. In the Elixir world it is unusual, but accepted for an application rather than a library. For Agendum it protects the service less than the FSL, but keeps the open-source name and nothing waits two years.

**Decided:** open now, with copyleft: the code under the AGPL, open source by the OSI's definition.

## § 7 The licence chosen

**Background.** With the direction set, which licence exactly and in which variant; checked by a lawyer before anything is published.

**Discussion.** On "only" against "or later": **Carsten** noted that Emacs and Org-mode trust the FSF with "or later"; **Mitch and the Chipmunks** pointed out that Grafana and Plausible chose "only", to keep control, and that with a contributor agreement the owner may still move to a later version. On the documents: **Marie** preferred one licence for everything; **José** said a code licence fits text badly, as someone quoting the manual on a blog should not have to wonder about "source".

**Decided:** `AGPL-3.0-only` for the code; `CC BY 4.0` for the guide, the manual and `docs/`; both subject to the lawyer's check.

## § 8 Contributors' terms: a CLA or a DCO

*[A page here was soaked in the creek. — Rabbit]*

**Decided:** a CLA that grants a licence, with the right to relicense; the contributor keeps their copyright; the model text chosen with the lawyer; a bot asks for it on a first pull request.

## § 9 Any other business

*[A page here was soaked in the creek. — Rabbit]*

The chair asked for a note on the checklist for going public to confirm this decision. **Decided:** step 7 of the checklist in `docs/plans/GITHUB.md` § 7, and a roadmap item: the licence confirmed after a lawyer's check, before publishing.

## § 10 Next meeting

The practical meeting on the dry run's results (In order 3), where the licence's confirmation is also checked.

## § 11 Closing of the meeting

*Owl closed the meeting and offered the Chipmunks the dictionary as a souvenir; they declined, having found that none of the six licences was in Latin.*

## Decisions and where they are recorded

| § | Decision | Recorded in |
| --- | --- | --- |
| 5 | The FSL and BSL facts corrected | `docs/plans/GITHUB.md` § 7 |
| 6 | Open now, with copyleft | ADR 0051, `docs/plans/GITHUB.md` § 7 |
| 7 | `AGPL-3.0-only` for the code, `CC BY 4.0` for the documents | ADR 0051, `docs/plans/GITHUB.md` § 7, `docs/ARCHITECTURE.md` |
| 8 | A CLA that grants a licence, from a model text | ADR 0051, `docs/plans/GITHUB.md` § 7 |
| 9 | The decision confirmed after a lawyer's check, before publishing | `docs/plans/GITHUB.md` § 7 (step 7), `docs/ROADMAP.md` (In order, Housekeeping) |

*Minutes kept by Claude. Approved by Little Marie-Who-Folds and Old Mitch Lilypad.*
