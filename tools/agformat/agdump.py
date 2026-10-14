#!/usr/bin/env python3
"""Reference reader for Lotus Agenda 2.0 .AG files (research tool, not part of Agendum).

Dumps a file's items, categories and views as JSON, following the layout in
docs/AGENDA_FILE_FORMAT.md. Usage:

    python3 tools/agformat/agdump.py FILE.AG            # JSON on stdout
    python3 tools/agformat/agdump.py --check FILE.AG... # consistency checks only

Fields whose meaning is not known are left out; see the format document.
"""
import datetime
import json
import struct
import sys

HEADER_SIZE = 0x400
BLOCK = 64
PAGE = 512
LINK = 28
LINKS_MARK = b"\xff\xffLINKS\xff"
ENCODING = "cp437"  # code page 850 differs only in a few letters; Agenda used the DOS code page

# Block types (word 1 of a block)
B_FREE, B_ITEM, B_TEXT, B_CATEGORY, B_VIEW = 0, 1, 2, 3, 4
B_CONDITIONS, B_SECTION, B_NOTE, B_DATA, B_FAMILY, B_MACRO = 5, 6, 7, 8, 9, 10
# Link types (word 1 of a link record)
L_FREE, L_ASSIGN, L_RANGE, L_COLUMN, L_COND, L_ACTION, L_DATEFILTER = 0, 1, 2, 3, 6, 7, 8
L_INDEX, L_DATE = 9, 12

TRASH = 1  # system categories !Trash!, !Circular Reference!, !Current Alarms!, !Past Alarms! = blocks 1, 3, 5, 7
CATEGORY_TYPES = {0: "standard, exclusive children", 1: "standard", 5: "unindexed",
                  9: "numeric", 13: "date"}


def how(flags):
    """Origin of an assignment, from the low bits of link word 8."""
    if flags & 0x40:
        return "automatic"      # Entry date, or a When date Agenda found in the text
    return {0: "explicit", 1: "text match", 2: "condition"}.get(flags & 0x3F, f"0x{flags & 0x3F:x}")


def lotus_date(days):
    """Lotus 1-2-3 serial date (days since 1899-12-30, fraction = time of day)."""
    if not days or days < 1:
        return None
    return (datetime.datetime(1899, 12, 30) + datetime.timedelta(days=days)).isoformat(timespec="minutes")


class AgendaFile:
    def __init__(self, data):
        self.d = data
        if data[0:1] != b"T":
            raise ValueError("not an Agenda file (first byte is not 'T')")
        self.w = lambda off: struct.unpack_from("<H", data, off)[0]
        self.description = self.cstr(data[2:0x2B])
        self.password = bytes(b ^ 0xAB for b in data[0x2B:0x38]).split(b"\0")[0].decode(ENCODING)
        self.last_block = self.w(0x3A)
        self.last_link = self.w(0x3E)
        self.root_category = self.w(0x40)
        self.first_view = self.w(0x42)
        self.current_view = self.w(0x44)
        self.saved = lotus_date(struct.unpack_from("<d", data, 0x168)[0])
        self.created = lotus_date(struct.unpack_from("<d", data, 0x170)[0])
        # Block area: blocks 0..last_block, then padding to a 512-byte page.
        end = HEADER_SIZE + (self.last_block + 1) * BLOCK
        self.links_start = (end + PAGE - 1) // PAGE * PAGE
        # Link pages: 18 records of 28 bytes, then FF FF "LINKS" FF.
        self.links = {}
        p = self.links_start
        while data[p + 0x1F8:p + 0x200] == LINKS_MARK:
            for k in range(18):
                rec = data[p + k * LINK:p + (k + 1) * LINK]
                lid = struct.unpack_from("<H", rec, 0)[0]
                if lid:
                    self.links[lid] = rec
            p += PAGE
        self.trailer = data[p:]

    # --- primitives -------------------------------------------------------
    @staticmethod
    def cstr(b):
        return b.split(b"\0")[0].decode(ENCODING)

    def block(self, n):
        o = HEADER_SIZE + n * BLOCK
        return self.d[o:o + BLOCK]

    def bw(self, n):
        return struct.unpack("<32H", self.block(n))

    def lw(self, n):
        return struct.unpack("<14H", self.links[n])

    def chain(self, first, head=b""):
        """Concatenate the C-string pieces of a chain of text blocks (word 2 = next)."""
        out, n, seen = self.cstr(head) if head else "", first, set()
        while n and n not in seen and n <= self.last_block:
            seen.add(n)
            out += self.cstr(self.block(n)[8:])
            n = self.bw(n)[2]
        return out

    def blob(self, n):
        """Data blocks (type 8): word 2 = next, word 3 = bytes used in this block."""
        out = b""
        while n:
            w = self.bw(n)
            out += self.block(n)[8:8 + w[3]]
            n = w[2]
        return out

    def walk(self, first, next_word, getter):
        n, seen = first, set()
        while n and n not in seen:
            seen.add(n)
            yield n
            n = getter(n)[next_word]

    # --- objects ----------------------------------------------------------
    def category_name(self, c):
        return self.chain(self.bw(c)[2])

    def note(self, owner_words):
        n = owner_words[3]
        return self.chain(self.bw(n)[2]) if n else None

    def categories(self, c=None):
        c = c or self.root_category
        w = self.bw(c)
        full = self.category_name(c)
        parts = full.split(";")
        cat = {
            "id": c,
            "name": parts[0],
            "short_name": parts[1] if len(parts) > 1 and parts[1] else None,
            "also_match": [p for p in parts[2:] if p],
            "type": CATEGORY_TYPES.get(w[26], f"unknown {w[26]}"),
            "match_name": bool(w[28] & 0x10) if w[26] != 13 else None,
            "match_short_name": bool(w[28] & 0x08) if w[26] != 13 else None,
            "note": self.note(w),
            "has_conditions": bool(w[19]),
            "children": [self.categories(ch) for ch in self.walk(w[17], 15, self.bw)],
        }
        return cat

    def value(self, lw):
        flags, ref = lw[8], lw[9]
        if flags & 0x100 and flags & 0x80:          # unindexed: text in a data block
            return self.blob(ref).split(b"\0")[0].decode(ENCODING)
        if flags & 0x100:                           # date: a type-12 link record
            rec = self.links[ref]
            return lotus_date(struct.unpack_from("<d", rec, 18)[0])
        if flags & 0x80:                            # numeric: a double inside the link
            return struct.unpack_from("<d", self.links[lw[0]], 18)[0]
        return None

    def items(self):
        out = []
        for n in range(1, self.last_block + 1):
            w = self.bw(n)
            if w[0] != n or w[1] != B_ITEM or w[24] & 0x40:   # 0x40: built-in summary rows
                continue
            assignments = []
            for link in self.walk(w[9], 4, self.lw):
                lw = self.lw(link)
                a = {"category": lw[2], "how": how(lw[8])}
                v = self.value(lw)
                if v is not None:
                    a["value"] = v
                assignments.append(a)
            out.append({"id": n, "text": self.chain(w[2], self.block(n)[50:62]),
                        "note": self.note(w), "assignments": assignments,
                        # discarded items stay in the file, assigned only to !Trash! (block 1)
                        "trashed": any(a["category"] == TRASH for a in assignments)})
        return out

    def views(self):
        out = []
        for v in self.walk(self.first_view, 9, self.bw):
            w = self.bw(v)
            name = self.cstr(self.block(v)[44:]) + (self.chain(w[2]) if w[2] else "")
            sections = []
            for s in self.walk(w[3], 4, self.bw):
                sw = self.bw(s)
                cols = [{"category": self.lw(c)[2], "width": self.lw(c)[8]}
                        for c in self.walk(sw[8], 7, self.lw)]
                sections.append({"category": sw[2], "columns": cols})
            out.append({"id": v, "name": name, "sections": sections})
        return out

    def macros(self):
        first = self.w(0x9A)
        return [self.chain(self.bw(m)[2], self.block(m)[24:]).split("\r")[0]
                for m in self.walk(first, 5, self.bw)]

    def to_json(self):
        return {"description": self.description, "password": self.password or None,
                "created": self.created, "saved": self.saved,
                "categories": self.categories(), "items": self.items(),
                "views": self.views(), "macros": self.macros()}

    def check(self):
        """Every block and link points at objects of the expected type."""
        errors = []
        for n in range(1, self.last_block + 1):
            w = self.bw(n)
            if w[0] not in (0, n):
                errors.append(f"block {n} has id {w[0]}")
        for lid, rec in self.links.items():
            lw = struct.unpack("<14H", rec)
            if lw[1] == L_ASSIGN:
                if self.bw(lw[2])[1] != B_CATEGORY:
                    errors.append(f"link {lid}: category {lw[2]} is a type {self.bw(lw[2])[1]} block")
                if self.bw(lw[5])[1] != B_ITEM:
                    errors.append(f"link {lid}: item {lw[5]} is a type {self.bw(lw[5])[1]} block")
        return errors


def main(argv):
    if argv and argv[0] == "--check":
        for path in argv[1:]:
            f = AgendaFile(open(path, "rb").read())
            errs = f.check()
            j = f.to_json()
            print(f"{path}: {len(j['items'])} items, {len(f.links)} links, "
                  f"{len(j['views'])} views, {len(j['macros'])} macros, {len(errs)} errors")
            for e in errs[:10]:
                print("   ", e)
        return
    f = AgendaFile(open(argv[0], "rb").read())
    json.dump(f.to_json(), sys.stdout, indent=1, ensure_ascii=False)
    print()


if __name__ == "__main__":
    main(sys.argv[1:])
