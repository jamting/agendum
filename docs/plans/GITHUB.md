# Wol's Agendum on GitHub

**Status:** done (2026-10-30): the repository is public as `jamting/agendum` (section 7, moving day), the private workshop kept apart as `jamting/agendum-wolery`; the site is live on GitHub Pages at `jamting.github.io/agendum/`, published on every push to main (`.github/workflows/pages.yml`, `mix agendum.pages`; meeting 2026-10-30-2020), and every version tag a GitHub Release with a Homebrew tap. Still open: the lawyer's check of the licence and the CLA before the first outside pull request is merged (ROADMAP, Housekeeping). Moving it to `plans/archive/` is the owner's decision. Earlier: the private repository (`jamting/agendum`, section 2) and the checks on every push (section 3, `.github/workflows/check.yml`) are done, 2026-10-17; GitHub Pages (section 4) waits for the public repository, as Pages needs a paid plan for a private one (owner, 2026-10-23); section 7's direction was set at the meeting of 2026-10-21-2324, § 10 (open core; a public repository of the clone when it is done, made by rewriting a copy), and refined at the meeting of 2026-10-28-0908 (what is private, the redactions, the line between public and private, the site, the pseudonyms, the dry run; the licence tabled to its own meeting), and the licence chosen at the meeting of 2026-10-28-1224 (AGPL-3.0-only, CC BY 4.0 for the documents, a CLA; ADR 0051), to be confirmed after a lawyer's check before publishing. Written 2026-10-14 from a conversation between the owner and Claude. The repository is to go on GitHub as a **private** repository, with a README, a guide for setting up and contributing (`CONTRIBUTING.md`), checks run on every push, and, if possible, the documentation and a product page on GitHub Pages.

## 1. Before the first push

Checked on 2026-10-14:

- **No personal data in the history.** The only data file ever committed is the shipped starter, `starters/planner.agendum`. Local files (`*.agendum`, the built `agendum` binary, `tmp/`, `_build/`) are ignored by `.gitignore`.
- **Author:** every commit is by the owner, with their own e-mail address; it is visible to everyone who can see the repository. (GitHub can hide it in future commits: Settings ▸ Emails ▸ "Keep my email addresses private", and a `users.noreply.github.com` address in `git config`.)
- **Size:** `.git` is about 4 MB.

- **Local Claude Code settings:** `.claude/settings.local.json` was untracked on 2026-10-14 and is in `.gitignore`; each person keeps their own. `.claude/skills/` is shared on purpose (the guide, manual and learning-comments skills). The file is still in the history's older commits; it only ever allowed `git add` and `git commit`, so that is harmless.

To decide:

- **Third-party reference material** is in git under `docs/reference/`: the plain text of the Lotus Agenda manuals, Agenda's help file and the Lotus support Q&A, the designers' 1990 CACM article, an essay on Agenda, and the Agenda patent (a US patent: public). The owner's DOSBox screenshots and the manuals' PDFs are not in git. For a **private** repository this is reference material for the people working on it; if the repository or a site is ever made **public** (section 7), these files should not be published (keep them out of the public repository, or out of git and fetched by a script). `mix docs` does not include them (its extras are `README.md`, `CLAUDE.md`, `docs/*.md` and `docs/adr/*.md`).

## 2. Creating the repository

With the GitHub CLI (`gh auth login` first), from the project folder:

```sh
gh repo create agendum --private --source . --remote origin --push \
  --description "Wol's Agendum: Lotus Agenda (1988) rebuilt in Elixir, with a terminal UI"
```

Then in Settings: default branch `main`; under Branches, a rule for `main` that requires the checks (section 3) to pass before merging a pull request, once collaborators come.

## 3. Checks on every push: GitHub Actions

A workflow, `.github/workflows/check.yml`, runs `mix check` (format, warnings as errors, Credo, Dialyzer, the tests) on every push and pull request:

- Erlang/OTP 28 or later and Elixir 1.20 (`erlef/setup-beam`); the terminal layer needs OTP 28's raw mode (ADR 0002).
- Cache `deps/`, `_build/` and Dialyzer's PLT (keyed on `mix.lock` and the versions), or Dialyzer takes minutes each run.
- The tests need no terminal: the TUI is tested through `Update` and `Render` (pure), so they run on a plain Ubuntu runner.

A second workflow, `.github/workflows/fuzz.yml`, runs the long fuzz run (`FUZZ_RUNS=3000`) every night on `main`, and by hand with `gh workflow run fuzz.yml`; it only reads `check.yml`'s cache. Each night has a seed of its own; a failure writes the command that repeats it locally into the run's summary.

Private repositories get a monthly allowance of Actions minutes (2,000 on the Free plan, at the time of writing); `mix check` takes about a minute with warm caches.

**Releases** (meeting 2026-10-30-2020, § 7): every version tag builds the escript (on OTP 28, so it also runs on 29) and attaches it to a GitHub Release, with the version's `CHANGELOG.md` section as notes (`.github/workflows/release.yml`; an older tag by hand, `gh workflow run release.yml -f tag=vX.Y.Z`). The escript needs Erlang/OTP 28 or later on the machine that runs it, which the notes say; the Homebrew tap, `jamting/homebrew-agendum`, brings Erlang along and picks each release up by itself.

## 4. Documentation and a product page: GitHub Pages

What there is to publish, all generated or static HTML:

- **API and design documentation:** `mix docs` writes `_build/docs/` (ex_doc): the core facade first, the modules, the design documents (`docs/*.md`) and the ADRs.
- **The user guide** (`docs/guide/index.html`, Piglet's short guide) and **the manual** (`docs/manual/`, Owl teaching Rabbit). `mix docs` already copies both into `_build/docs/` so the README's links work there.
- **A product page:** does not exist yet. A single static page (`site/index.html`) in the program's own look: what Agendum is (from the README and `docs/AGENDA_HISTORY.md`), a few screens (`tools/screenshots/` draws them as PNGs), how to install, and links to the guide, the manual and the API docs.

A workflow, `.github/workflows/pages.yml`, on pushes to `main`: run `mix docs`, put the product page at the root and the docs under it (`/docs/`, `/guide/`, `/manual/`), and publish with `actions/upload-pages-artifact` and `actions/deploy-pages`. Settings ▸ Pages ▸ Source: GitHub Actions.

**Decided at the meeting of 2026-10-30-2020** (the repository is public, so the paid-plan and visibility notes below no longer apply): the site lives at `jamting.github.io/agendum/`; a hand-written `site/index.html` with four doors; the docs, guide, manual, devlog and `llms.txt` under it; Releases and a Homebrew tap. The pieces and their order are the roadmap's Housekeeping item.

**Two things to know:**

- **GitHub Pages for a private repository needs a paid plan** (GitHub Pro, Team or Enterprise; on the Free plan Pages works for public repositories only).
- **A Pages site is public** even when the repository is private, on every plan except Enterprise Cloud (which can limit a site to the organisation's members). So the docs and product page would be visible to anyone with the address. That suits a product page, also for a paid product; but `_build/docs/` holds the API documentation, the design documents and the ADRs, including the plans for a multi-user web app, which would show competitors how it is built. While section 7 is open, publish only the product page and the user guide (and perhaps the manual), and keep the API and design documentation to the repository (or a downloadable artifact from the Actions workflow).

If either is a problem while the repository is private, the docs can be built in the Actions workflow and kept as a downloadable artifact instead, or Pages waits until the repository goes public.

## 5. Files GitHub looks for

- `README.md`: the front page of the repository (exists; kept current).
- `CONTRIBUTING.md`: setting up and contributing (exists). GitHub links to it when someone opens an issue or a pull request.
- `LICENSE`: none for now in this private workshop (section 1); a short notice in the README that the code is not open source and all rights are reserved keeps that clear. The public copy gets AGPL-3.0 (ADR 0051, section 7).
- Optional later: `.github/ISSUE_TEMPLATE/` (a bug report asking for the debug log, `AGENDUM_LOG=1`, ADR 0027), a pull request template with the checklist from CLAUDE.md, and `CODE_OF_CONDUCT.md` when there are contributors.

## 6. Order of work

1. Decide section 1 (reference material, contributors' terms); the local settings file is done, and the licence waits for section 7.
2. Create the private repository and push (section 2).
3. Add the checks workflow and see it pass (section 3).
4. Decide on Pages (plan, public site); then the product page and the Pages workflow (section 4).
5. Issue and pull request templates, branch protection, when others join.

## 7. Later: public

*[A page here was soaked in the creek. — Rabbit]*

**How the public repository is made**, when the clone is declared done (Roadmap, Housekeeping):

Before it (meeting 2026-10-26-1524; the owner, 2026-10-26: every extra usable before going public, such as the feeds' ingested categories): the clone's safety items, a general code review, a meeting on what information to make public in the docs, a tidy pass with a sweep of SPEC, and a dry run of the steps below on a copy, checked by `mix check` before anything is pushed (ROADMAP, In order).

1. This repository stays the private workshop, unchanged; nothing is rewritten in it.
2. A copy is rewritten with `git filter-repo` into a new repository. Every commit, its message, date, tag and `Co-Authored-By` line is kept: the history of small, tested steps is the best evidence of how the work was done, and the project is presented truthfully as directed by the owner and built with an AI.
3. Out of the history: the third-party reference material (`docs/reference/`: the Lotus manuals' text, Agenda's help file, the Lotus Q&A, Agenda's starter `.AG` files, the CACM article, the essay; the patent may stay), and the private files on the list below. Removing a file from the first commit (`23fa863`, where the reference material came in) changes every commit's hash after it.
4. Added back once, in a final commit: the minutes (`docs/meetings/`), the reviews (`docs/reviews/`, without their "Business value" section), `docs/VISION.md` and this plan, each without its business passages.
5. The commit hashes the documents cite (424 distinct ones on 2026-10-21) are brought up to date from filter-repo's commit map, in one commit.
6. Before publishing: the minutes that use real people's names as the panel's lenses are read once more (each already says the voices are not their words), and the captured Agenda texts of the DOSBox comparison (Roadmap, Towards parity) are checked: menu words are short, long help lines are Lotus's text. *Decided by the owner, 2026-10-28:* all the captured texts go into the copy, the question goes to the lawyer (step 7).
7. Before publishing: **the licence decision confirmed** (meeting 2026-10-28-1224, §§ 6–8; ADR 0051). A lawyer where the owner lives checks AGPL-3.0-only for the code, CC BY 4.0 for the documents and the CLA's model text; then the owner confirms the decision, or a meeting changes it. Only then do `LICENSE`, the documents' licence, an SPDX line in each source file and `CONTRIBUTING.md` with the CLA (and its bot) go into the copy. *Changed by the owner, 2026-10-28:* the lawyer's check is put off for now, and the dry run's copy has the licence already (its fourth step); the practical meeting decides whether a lawyer checks it before publishing. *Decided at the practical meeting (meeting 2026-10-28-1911, § 9):* publishing does not wait for the lawyer; no outside pull request is merged until a lawyer has read `CLA.md` and the dual-licensing question (the CLA bot blocks merging without a signature), and until then the public README says contributions open later.
*[A page here was soaked in the creek. — Rabbit]*
8. Before publishing: **this repository renamed on GitHub** (the owner, 2026-10-28), from `jamting/agendum` to `jamting/agendum-wolery` (chosen at the practical meeting, meeting 2026-10-28-1911, § 10: Owl's house in *The House at Pooh Corner*, in his own spelling), so the public repository can be `jamting/agendum`. Then the workshop's remote set to the new address (`git remote set-url origin …`), and a push checked to run CI and the pre-push hook. GitHub's redirect from the old name stops when the public repository takes it, so every clone of the workshop needs the new address.

*[A page here was soaked in the creek. — Rabbit]*

*[A page here was soaked in the creek. — Rabbit]*

**Decided at the meeting of 2026-10-28-0908** (a series of meetings: this one on the content; a licence meeting; a practical meeting on the dry run):

*[A page here was soaked in the creek. — Rabbit]*
- **Redactions** (§ 7): a whole private file is simply absent from the public copy. A private passage inside a public document is marked in this workshop, `<!-- private -->` … `<!-- /private -->`, and the copy script replaces it with one line, *"[A page here was soaked in the creek. — Rabbit]"*; the story (Tigger bounced Rabbit and his papers into the creek) is told once, in the public `docs/INDEX.md`. A leak test checks that no marked passage reaches the copy.
*[A page here was soaked in the creek. — Rabbit]*
- **The site** (§ 9): see the roadmap's Housekeeping (four doors, Pages, `llms.txt`, Releases and a Homebrew tap, the devlog).
- **Pseudonyms** (§ 10 and its addendum): the panel's lenses go by Wood names (the table in `.claude/skills/expert-review/SKILL.md`). New texts use them from now on; older texts keep the real names in this private workshop, and the public copy's whole history is mapped in one sweep by `filter-repo --replace-text` and `--replace-message`, from a private name list in `tools/public/`. The skill's table pairs real names with pseudonyms, so it is marked private; the leak test looks for every real name and surname.
- **The history** (§ 11): the steps above stand. Old versions carry no markers, so the minutes, reviews, `VISION.md` and this plan leave the whole history and come back once, redacted. The dry run is a re-runnable script in `tools/public/` (`filter-repo` from Homebrew), checked by `mix check`, the leak test and a check that every cited commit hash exists in the copy; the go or no-go is taken at the practical meeting.
*[A page here was soaked in the creek. — Rabbit]*
- **The licence** (§ 12, tabled; decided at the next meeting, below): the comparison below is widened to GPL-3.0 and AGPL-3.0 as well as the Functional Source License (FSL: no competing service, each version Apache-2.0 or MIT after two years); a legal check before choosing.

**Decided at the meeting of 2026-10-28-1224** (the licence meeting; ADR 0051), subject to a lawyer's check and the owner's confirmation before publishing (step 7 above):

- **Direction** (§ 6): open now, with copyleft: the code under the AGPL, open source by the OSI's definition; a hosted competitor may run Agendum, but offers its changed source to its users.
- **The licence** (§ 7): `AGPL-3.0-only` for the code (a later version only by the owner's choice); `CC BY 4.0` for the guide, the manual and `docs/`.
- **Contributors** (§ 8): a CLA that grants a licence, with the right to relicense; the contributor keeps their copyright; a model text (Harmony, or in the style of Apache's ICLA) chosen with the lawyer; a bot asks on a first pull request.
*[A page here was soaked in the creek. — Rabbit]*

**Decided at the practical meeting of 2026-10-28-1911** (the dry run's report of 2026-10-28):

- **Go** (§ 13), on conditions: the fixes below done, a fresh dry run clean, and the owner reads and approves its report before the rename and the push; before it too, the README's look (a screenshot, a Find your way section, § 14; the name's story) and the guide and manual in the blog extra's stylesheet (Roadmap, Housekeeping).
- **The fixes** (§§ 5–8, 12): the lines linking to a private plan reworded at the source; the commit messages with business words reworded in the copy, the owner's wording; Lotus's four starter `.AG` files out of the history, their tests run only where the files are; `docs/reference/README.md` marked so the copy lists what it has, the captured texts kept with their longest help lines listed for the owner (step 6); surnames inside Markdown formatting (`_Name_`) found and mapped, as `\b` misses them.
- **The lawyer** (§ 9): before the first outside pull request is merged, not before publishing (step 7).
- **The workshop's name** (§ 10): `jamting/agendum-wolery` (step 8).
- **No sync** (§ 11): confirmed.

*[A page here was soaked in the creek. — Rabbit]*

