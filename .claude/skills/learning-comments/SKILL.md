---
name: learning-comments
description: Add learning comments to Elixir source files or folders the owner names (e.g. "add learning comments to lib/agenda/tui/update/"): explain the Elixir idioms used, for an experienced programmer new to Elixir, and the complicated places from Agenda's domain side. Comments only, never code changes; one commit per request after asking. Use only when the user asks for learning comments.
---

# Add learning comments

The owner is an experienced programmer who is new to Elixir and uses this
project to learn it. Learning comments explain two things in the code
itself:

1. **Elixir idioms.** Explain the Elixir-specific *why*, not general
   programming.
2. **Domain logic.** Explain the complicated places in Agenda's terms:
   what the code does for the user and why it is done this way.

The model is commit `47dd1cf` (the core facade, `lib/agenda/core/facade/`).
Read a couple of its files first (`items.ex`, `changes.ex`) to match the
voice and density.

## 1. Scope

Take the files or folders the owner named. If none were named, ask; don't
pick a whole tree yourself. Skip what already has learning comments
(`git log --grep="Learning comments"`). For more than a handful of files,
do them in an order where the simpler modules come first. Explain an idiom
in the first file where it appears, and only point back to it later.

## 2. Read before writing

- Read each file whole.
- For domain comments, read the SPEC rules the code cites (`docs/SPEC.md`,
  `R15b` and so on). Check original behaviour in the User's Guide text
  (`docs/reference/*_djvu.txt`, grep it), and `docs/DATA_MODEL.md` for
  stored data.
- Never guess what the domain logic is for. If the code and the SPEC
  don't make it clear, leave that place without a comment and list it in
  your report.

## 3. What to comment

**Elixir idioms**, once per file, at the first place each appears. For
example:

- `alias`, `import`, `@type`/`@typep`/`@spec` and Dialyzer, module
  attributes as constants
- immutability and rebinding (why `before = db` is a real snapshot)
- `|>`, `&` captures (`&1`, `&Mod.f/2`), calling a function value with `.()`
- pattern matching: in function heads, clause order, `_` names, the pin
  `^`, a repeated variable in one pattern, `=` as an assertion ("let it
  crash"), `match?/2`
- `case` / `cond` / `with` (with and without `else`, tagged steps),
  `{:ok, _} | {:error, _}` versus raising, bang `!` functions
- guards and what is allowed in them, `is_map_key/2`
- `for` comprehensions (filters, generators that filter by pattern,
  several generators), `Enum.reduce` as the loop, `flat_map` with
  `[]`/`[x]`, `find_value`
- recursion and tail calls; default arguments and arity
  (`f(a, b \\ x)` defines `f/1` and `f/2`), bodiless heads for defaults
- structs versus maps, `%{m | k: v}` versus `Map.put/3`, nested updates,
  the cost of linked lists (`++`, `length/1`)
- Erlang modules called directly (`:unicode`), sigils (`~D`, `~T`, `~r`)
- in the TUI: the Elm-style `{state, effects}`, effect tuples, and OTP raw
  mode in `Terminal`; in tests: ExUnit `describe`/`setup`, StreamData
  properties

**Domain logic**: what isn't obvious from the names alone. For example:

- the order of steps and why it matters
- why something is computed by comparing before and after rather than
  stored
- what a "conflict" is
- why a value is read once
- a concrete example in Agenda's own terms ("Call Bob tomorrow" typed on
  Monday …)

Cite the SPEC rule or the User's Guide page where that helps. Start a
domain comment with "Domain:" when it sits next to an idiom comment, so
the two kinds stay apart.

## 4. How to write it

- Put the comment where the reader needs it: just above the line or
  clause.
- Keep it short, one to five lines, in the project's voice: plain
  English, no "we"/"I", no exclamation marks.
- Don't comment what the name or the existing `@doc` already says. Don't
  restate the code.
- Make no code changes: no renames, no reformatting beyond what
  `mix format` does. A misplaced existing comment may be moved next to the
  thing it describes. Mention any such move in the report.
- Check every claim about Elixir before writing it (e.g. what guards
  allow, what is a tail call). A wrong learning comment is worse than none.

## 5. Finish

1. Run `mix format` and `mix check`. Only comments changed, so the checks
   must still pass.
2. Make sure `git diff` contains no change to code; comments and blank
   lines only.
3. Report to the owner:
   - which files you commented
   - the idioms you explained, per file, in one line each
   - the domain places you explained
   - the places you left without a comment because the domain reason was
     unclear
4. Ask before committing. Commit as "Learning comments in <area>", listing
   the idioms and domain topics in the message body.
