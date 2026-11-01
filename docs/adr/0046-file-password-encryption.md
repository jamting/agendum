# ADR 0046: A file password encrypts the file

**Status:** accepted (the owner, 2026-10-26: "as Agenda", with real encryption)

## Context

Lotus Agenda let a file have a password (File Properties ▸ Set file password; the New File box): the file could not be opened without it, and a forgotten password could not be recovered (User's Guide 22-3, 22-8 to 22-9). Agenda's own scheme was weak; Agendum's files are Erlang terms anyone can read with a few lines of code. A password that only asks, without encrypting, would protect nothing.

## Decision

- **The file is encrypted** when it has a password: AES-256-GCM (authenticated, so a wrong password or a changed byte is detected, not misread), with a key derived from the password by PBKDF2-HMAC-SHA256 (600,000 rounds, OWASP 2023) and a fresh random salt and nonce on every save. Erlang's own `:crypto` does it (already in the release through `:ssl`), so no new dependency (ADR 0021).
- **The envelope** (`Agendum.Store`): `AGENDUM-ENC1`, the description in the clear (two bytes of length, then UTF-8; Agenda's header kept it readable too, so the Select File box's F8 shows it), the salt (16 bytes), the nonce (12), the tag (16), then the ordinary file's bytes encrypted. The magic is the additional authenticated data.
- **The password lives in `Database.password`** while the file is open, so that saves keep encrypting and a change to it is an ordinary, undoable change of the file; it is never written: the encrypted payload holds the database with `password: nil`, and the JSON export leaves it out (the export is plain, and says so).
- **Agenda's limits:** up to 12 characters; an empty one removes the password.
- **Lost is lost.** There is no recovery and no back door.

## Consequences

- Opening an encrypted file asks for the password (wrong: Agenda's "The password you typed is incorrect."); the core stays pure: encryption, randomness and the key derivation happen in `Store`, a shell module.
- A save takes about 60 ms longer while the file has a password.
- The debug log (ADR 0027) keeps an encrypted file's text out while it is open: typed characters counted, messages by kind, names and a crash's details hidden (added 2026-11-01). A crash's recovery file is encrypted with the same password (R82b).
- The planned web version stores files on a server; whether it keeps them encrypted with the person's password is for that plan to decide.
