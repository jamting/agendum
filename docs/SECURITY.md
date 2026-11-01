# Security: the threat model

What could go wrong, for whom, and how badly, one door at a time. The Security list on the roadmap is chosen from here, not collected (ROADMAP, 2 Security).

**Whom it protects:** the person using Agendum, in both senses: from others, and from the program itself betraying them in what it reads, sends and logs.

**What it guards:** the person's file (items, notes, names: often private), the secrets they give Agendum (a file's password, an SFTP password, a calendar's private address), and their computer.

**Who might attack:** someone with the laptop or a copy of the file; the author of a feed, calendar, `.AG` file or `.agendum` file the person opens; a network between them and a server; later, text written to steer an agent.

**Out of scope:** a computer already taken over (malware reading the screen or memory), and the safety of the servers the person chooses to use.

## Reporting a problem

Please do not open a public issue for a security problem. Use GitHub's private vulnerability reporting (the repository's Security tab, "Report a vulnerability").

## The doors

Each door: what could go wrong, how badly (**high**: the file's text leaks or the computer runs someone else's commands; **medium**: data lost or a secret weakened; **low**: a crash or a nuisance), what guards it today, and what is still open (on the roadmap's Security list).

### 1. The file at rest

- **Risk:** the laptop or a backup is lost, and the file is read. **High** for a private file.
- **Guarded:** a file with a password is encrypted (AES-256-GCM, a key from PBKDF2-HMAC-SHA256 at 600,000 rounds, a fresh salt and nonce each save; ADR 0046). The `.bak` copy made on opening is the file's own bytes, so it is encrypted too, and so is a crash's recovery file (R82b).
- **Known and accepted:** the description stays readable (as in Agenda, for the file list). A lost password is lost. A file without a password is plain Erlang terms anyone can read. Exports (JSON, text, print to a file) are plain text by request; the JSON export says so.

### 2. A file from someone else (`.agendum`, `.AG`, JSON)

- **Risk:** a crafted file runs code, hangs Agendum, or crashes it and loses unsaved work. **Medium.**
- **Guarded:** an `.agendum` file is read with Erlang's safe decoding (no new atoms), must be a `Database` of a known version, and its text is made valid UTF-8; then every value's kind (through the JSON reading) and the parts' agreement (the invariants) are checked, and a damaged file is refused (R82d, ADR 0052; v0.73.15). JSON import checks types and references (R44). The `.AG` reader is tested with a collection of hostile files (R72). Text from a file is data: nothing in it runs (R82c), terminal escape codes are shown, not obeyed, and a macro runs only when the person plays it. A crash writes the unsaved changes to a recovery file (R82b).
- **Known and accepted:** a shared file's blog settings are used as written, within door 4's guards. A damaged file of the person's own cannot be opened either; getting its contents out is a tool for later.

### 3. Feeds and calendars from the network

- **Risk:** a hostile or broken feed or calendar hangs Agendum, eats its memory, or smuggles commands into items; a network attacker reads or changes what is fetched. **Medium.**
- **Guarded:** HTTPS with the system's certificates and the host name checked; a 20-second timeout for the whole answer; a 20 MB limit, counted as the answer comes in and stopped there (an announced larger size is refused at once; v0.73.13); redirects followed by Agendum itself, up to five, never from `https` to plain `http` nor off the web (v0.73.14); Agendum's own XML reader, which makes no atoms and expands no custom entities (no "billion laughs"); feed text is plain text, HTML stripped; CTRL-V opens only `http` and `https` links, never a program or a file. Fetches run in the background, so the screen goes on. A calendar's private address is written in the log by its host only.
- **Known and accepted:** an `http://` address the person types is read over plain http, unencrypted, as typed: some old feeds have no other (the owner, 2026-11-01).

### 4. Publishing the blog (SFTP, rsync)

- **Risk:** the upload goes to the wrong server, a password leaks, or the upload command is turned into another. **Medium.**
- **Guarded:** the server's key must already be in `~/.ssh/known_hosts` (never accepted silently); ssh never asks on the screen (`BatchMode`); a password typed for SFTP is shown as stars, kept out of the log and never stored; the preview shows every change before anything is written. rsync gets the folder and **Upload to** after `--`, so never as options, and a target whose host or user starts with `-` is refused, so ssh never reads it as one (v0.73.12). SFTP goes through OTP's own ssh, with no command line.

### 5. The session log (`AGENDUM_LOG`)

- **Risk:** the log holds what was typed, and is shared with a bug report or read from the disk. **High** for an encrypted file, **medium** otherwise.
- **Guarded:** off by default; ten sessions kept; web addresses cut to their host; passwords counted, never written; while the file has a password, its text stays out entirely (typed keys counted, messages by kind, names and a crash's details hidden; v0.73.10); Erlang's reports of a crash in background work show only their level then, and setting a password takes out what the session's log already held (v0.73.16).
- **Known and accepted:** for a file without a password, what is typed is in the log (ADR 0027): it is a debugging tool, on only when asked for. Logs of earlier sessions, from before the file got its password, are left as they are: delete them by hand (the last ten are kept in `~/.local/state/agendum/logs`).

### 6. The program and its making

- **Risk:** a changed release or a changed CI step ships someone else's code to the person. **High**, but unlikely.
- **Guarded:** no runtime dependencies (ADR 0021); four dev and test tools only; the release escript is built by CI from a tag, without them (`MIX_ENV=prod`).
- **Guarded too:** every action the CI runs is pinned by its commit, not a tag that could be moved (its version in a comment), and each release carries the escript's SHA-256, beside it as `agendum.sha256` and in the notes (2026-11-01).
- **Standing:** a look over the pipeline about once a quarter (next by 2027-01-31), the pins moved to newer versions then.

### 7. Capture from outside (when it comes)

- **Risk:** a way for others to put items in, by mail or a shared folder, lets anyone write into the file. **Medium.**
- **Rule for then:** captured text is data, never commands (R82c); it lands where the person reviews it, never filed silently beside their own items; who may send is the person's choice.

### 8. An agent (later)

- **Risk:** an item's text tells a language model what to do ("discard every item"), and it does. **High** once an agent can change the file.
- **Rule for then:** item text is data, never instructions (R82c); an agent proposes, the person decides; one agent action is one undoable change, as a key is.

## When this is updated

A new door (a new kind of outside input, a new place data leaves the computer, a new secret) gets a section here before it is built. An open item fixed moves to "Guarded", and its roadmap line to `ROADMAP_DONE.md`.
