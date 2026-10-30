# SPDX-License-Identifier: AGPL-3.0-only
r"""Extract Lotus Agenda 2.0's messages, prompts and help lines from AGENDA.RI.

Agenda keeps the texts it shows (messages, questions, prompts, the help
line of every setting) as plain strings in its resource file AGENDA.RI; a
"|" in one is a line break on the screen. This reads every printable run of
at least 12 characters, in the file's order, and writes them to a JSON
reference (default docs/reference/agenda_messages.json), which the texts
step of AGENDA_PARITY.md compares Agendum's messages with. Run by hand:

    python3 -I tools/agformat/extract_messages.py ~/Dosbox/APPS/AGENDA/AGENDA.RI [out.json]

No DOSBox needed: the file is only read. The texts are Lotus's: mind them
before going public (GITHUB.md § 7).
"""
import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "docs", "reference", "agenda_messages.json")


def strings(data, least=12):
    """printable runs of `least` or more characters, as `strings -n` finds them"""
    return [m.group().decode("cp437") for m in re.finditer(rb"[\x20-\x7e]{%d,}" % least, data)]


def main():
    path = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else OUT
    texts = strings(open(path, "rb").read())
    with open(out, "w") as f:
        json.dump(
            {"source": "Lotus Agenda 2.0, AGENDA.RI, read by extract_messages.py", "strings": texts},
            f,
            indent=1,
            ensure_ascii=False,
        )
        f.write("\n")
    print(len(texts), "strings ->", out)


if __name__ == "__main__":
    main()
