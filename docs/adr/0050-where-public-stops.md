# ADR 0050 — Where public stops

**Status:** accepted · 2026-10-28 (meeting 2026-10-28-0908, § 8; refines the open core of meeting 2026-10-21-2324, § 10)

## Context

Agendum is to get a public repository, made from a copy of this private workshop (`docs/plans/GITHUB.md` § 7). Later work lies on both sides of that line: a modernised terminal program as an extra, more extras, a local client/server so several terminals can have the same file open (as Emacs has), Wol's local agent (local-first, meeting 2026-10-25-0013), and a second front end on the same core (CLAUDE.md rule 6). The line has to be drawn so that the public part never needs to fork to make room for the rest, and so that someone who uses only the public program never loses anything to what comes after.

*[A page here was soaked in the creek. — Rabbit]*

## Decision

- **Public:** the core (`Agendum.Core` and everything under it), the file formats (the Erlang-term file, `agendum-json`, the `.AG` import), the protocol between a front end and a core that holds the file, the terminal programs (the classic one and a modern one as an extra), the extras, the local client/server, and Wol's local agent.
- **One public protocol** serves both the local client/server and any later server, so there is never a second, private protocol to keep in step with the public one.
- **A service adds; it never takes a local feature away.** Everything a person can do with their own file stays in the public program, and their file stays theirs.

*[A page here was soaked in the creek. — Rabbit]*

## Consequences

- New logic for a user action still goes into the core (CLAUDE.md rule 6), and so is public by default; only what is listed as private above lives elsewhere.
*[A page here was soaked in the creek. — Rabbit]*
- The protocol, when it is designed, is designed in public and documented as the file formats are.
- A feature that would only work through a service needs a decision of its own, held against "a service adds, never takes away".
- Private passages in public documents are marked `<!-- private -->` … `<!-- /private -->`, as in this ADR, and the public copy shows each as one creek line (meeting 2026-10-28-0908, § 7). Since moving day (2026-10-30) the markers are no longer used: this is the public repository, and a private passage is written into the owner's private repository instead, with the creek line here in its place (the `expert-review` skill, Private passages).

*[A page here was soaked in the creek. — Rabbit]*
