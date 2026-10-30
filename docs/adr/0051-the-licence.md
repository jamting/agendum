# ADR 0051 — The licence: AGPL-3.0-only for the code, CC BY 4.0 for the documents, a CLA for contributions

**Status:** accepted · 2026-10-28 (meeting 2026-10-28-1224, §§ 6–8; the comparison in `docs/plans/GITHUB.md` § 7). The lawyer's check is put off for now (the owner, 2026-10-28): the licence is in the dry run's copy, and the practical meeting decides whether a lawyer checks it before publishing. Decided there (meeting 2026-10-28-1911, § 9): publishing does not wait; a lawyer checks the CLA and the dual-licensing question before the first outside pull request is merged.

## Context

The clone gets a public repository (ADR 0050). Until now there was no licence ("all rights reserved"), which a private repository needs nothing more for. A public one needs a licence that keeps the promise that a person's program and data stay theirs: a released version can never be taken back, and someone can carry it on if the owner stops. The licence meeting weighed Apache-2.0, GPL-3.0, AGPL-3.0, the Functional Source License, the Business Source License and PolyForm Noncommercial.

*[A page here was soaked in the creek. — Rabbit]*

## Decision

- **The code** (the core, the terminal programs, the extras, the tools) is licensed under the **GNU Affero General Public License, version 3 only** (`AGPL-3.0-only`). Agendum is open source by the OSI's definition; anyone who runs a changed version for others over a network offers them its source.
- **"Only", not "or later"**: a later AGPL version applies only if the owner decides so; the contributors' agreement lets the owner make that change.
- **The documents** (the guide, the manual, `docs/`) are licensed under **Creative Commons Attribution 4.0** (`CC BY 4.0`): text may be copied and adapted with credit.
- **Contributions** come under a **contributor licence agreement** (CLA): the contributor keeps their copyright and gives the owner a broad licence to their contribution, including the right to relicense it. A model text is used (the Harmony agreements or one in the style of Apache's ICLA), chosen with the lawyer, not written from scratch; a bot asks for it on a first pull request.

## Consequences

- Before the first outside pull request is merged (meeting 2026-10-28-1911, § 9; first: before publishing), the decision is confirmed after a lawyer's check where the owner lives (the checklist in `docs/plans/GITHUB.md` § 7, step 7): the AGPL's network clause for Agendum and the CLA's model text.
- The public copy gets a `LICENSE` file (AGPL-3.0), a licence for the documents, an SPDX line at the top of each source file and `CONTRIBUTING.md` with the CLA; done in the tidy pass or the dry run, not in this private workshop's history.
- What is already in the repository fits: no runtime dependencies (ADR 0021); the blog's design (MIT) and fonts (SIL Open Font License), and the dev tools (MIT or Apache-2.0), combine with the AGPL.
- If a library is ever split off the core for others to depend on (a reader for the file format, say), the AGPL will keep most Elixir developers from using it; such a library may need a permissive licence of its own, a decision then.
- The AGPL does not stop anyone from hosting Agendum; it makes them share their changes.

*[A page here was soaked in the creek. — Rabbit]*
