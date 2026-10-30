#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-only
"""Reference reader for Lotus Agenda 2.0 .AG files (research tool, not part of Agendum).

Dumps a file's items, categories, views, macros and file settings as JSON,
following the layout in docs/AGENDA_FILE_FORMAT.md. Usage:

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
B_COLUMN_STATS, B_MACRO_VAR, B_DATE_RANGE = 11, 12, 13
# Link types (word 1 of a link record)
L_FREE, L_ASSIGN, L_FILTER, L_COLUMN, L_COND, L_ACTION, L_SORT = 0, 1, 2, 3, 6, 7, 8
L_INDEX, L_DATE, L_ALARM = 9, 12, 13

TRASH, CURRENT_ALARMS = 1, 5  # system categories: !Trash! 1, !Circular Reference! 3, !Current Alarms! 5, !Past Alarms! 7
CATEGORY_TYPES = {0: "standard", 1: "unindexed", 2: "numeric", 3: "date"}  # bits 2-3 of word 26

WEEKDAYS = ["?", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
MONTHS = ["?", "January", "February", "March", "April", "May", "June", "July", "August",
          "September", "October", "November", "December"]
# Unit of a relative or recurring date expression (low nibble of its byte 0)
DATE_UNITS = {2: "named month", 4: "hours", 5: "days", 6: "working days", 7: "weekday",
              9: "weeks", 10: "fortnights", 11: "months", 13: "quarters", 14: "years"}
POSITIONS = {0: None, 1: "beginning", 2: "end", 3: "whole"}


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


def date_format(f):
    """A date format word: a date column's w10, or the file's global one at
    header 0x182 (decoded 2026-10-26 by changing each field of Agenda's
    Display Format box): bits 0-4 the date format, 1 MMDDYY ... 20
    Relative # in the box's order, 0 the global default (columns); 5-7 the
    separator; 0x100 the time separator hm; 0x400 a 12-hour clock; 0x800
    am/pm; 0x1000 the day of week; 13-14 what is displayed."""
    return {"display": ["date", "date time", "time date", "time"][(f >> 13) & 3],
            "format": f & 0x1F or "global",
            "separator": ["/", "-", ".", ",", " ", ":", "?", "?"][(f >> 5) & 7],
            "time_separator": "hm" if f & 0x100 else ":",
            "day_of_week": bool(f & 0x1000), "clock_12h": bool(f & 0x400),
            "am_pm": bool(f & 0x800)}


def time_word(w):
    """hour | minute << 5; hour 24 means no time."""
    hour, minute = w & 0x1F, (w >> 5) & 0x3F
    return None if hour == 24 else f"{hour:02d}:{minute:02d}"


def date_expression(raw, kind):
    """The 8-byte 'how the date was given' field of a date value or date range.

    kind 0: an absolute date, the 8 bytes are the date as a double (lowest
    byte | 0x80 when a time was given). kind 1 relative, kind 2 recurring:
    unit, index/position, count, day/interval, flags, time.
    """
    if kind == 0:
        return {"kind": "absolute", "time_given": bool(raw[0] & 0x80)}
    b0, b1 = raw[0], raw[1]
    count = struct.unpack_from("<h", raw, 2)[0]
    unit = DATE_UNITS.get(b0 & 0x0F, f"unit {b0 & 0x0F}")
    out = {"kind": "recurring" if b0 & 0xC0 == 0xC0 else "relative", "unit": unit}
    if out["kind"] == "recurring":
        out["interval"] = raw[4]                    # 1 every, 2 every other / every 2
        if b0 & 0x0F == 7:
            out["weekday"] = WEEKDAYS[b1 & 7]
    else:
        out["count"] = count                        # next 1, last -1, N units from today / ago
        index, position = b1 >> 4, b1 & 3
        if POSITIONS[position]:
            out["position"] = POSITIONS[position]
        if b0 & 0x0F == 7 and index:
            out["weekday"] = WEEKDAYS[index & 7]
        if b0 & 0x0F == 2 and index:
            out["month"] = MONTHS[index] if index < 13 else index
        if b0 & 0x40:                               # 0x50: byte 4 is the day of the month (0-based)
            out["day_of_month"] = raw[4] + 1
        if raw[5] & 0x10:
            out["this"] = True                      # this week / this month / end of this week
    t = time_word(struct.unpack_from("<H", raw, 6)[0])
    if t:
        out["time"] = t
    return out


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

    def short_category(self, c):
        return self.category_name(c).split(";")[0] if c else None

    def note(self, owner_words):
        """Note text, or the name of the note file when the note is kept outside the .AG."""
        n = owner_words[3]
        if not n:
            return None
        w = self.bw(n)
        if w[9] == 1:                               # note file: w4 = text block with its name
            return {"file": self.chain(w[4])}
        return self.chain(w[2])

    def date_range(self, b):
        """Type-13 block: start/end expression + date, and whether each is relative."""
        raw = self.block(b)
        out = {}
        for name, off, rel in (("start", 6, 22), ("end", 24, 40)):
            date = lotus_date(struct.unpack_from("<d", raw, off + 8)[0])
            if date:
                out[name] = date
                out[name + "_given_as"] = date_expression(raw[off:off + 8], raw[rel])
        return out

    def filter_elements(self, first):
        out = []
        for l in self.walk(first, 4, self.lw):
            lw = self.lw(l)
            f = {"category": lw[2], "assigned": not lw[8] & 1}
            if lw[9]:
                f["range"] = self.date_range(lw[9])
                f["inside_range"] = not lw[8] & 2
            out.append(f)
        return out

    def sort_key(self, l):
        """Type-8 link: one sort key of a view or a section."""
        if not l:
            return None
        lw = self.lw(l)
        flags = lw[9]
        on = ("category note" if flags & 0x180 == 0x180 else "category" if flags & 0x100
              else "item text" if flags & 0x80 else f"0x{flags:x}")
        key = {"on": on, "descending": bool(flags & 2), "n/a first": bool(flags & 0x20)}
        if lw[2]:
            key["category"] = lw[2]
            key["sequence"] = ["category hierarchy", "alphabetic", "numeric", "date"][(flags >> 2) & 3]
        return key

    def category_settings(self, w):
        t = (w[26] >> 2) & 3
        s = {"exclusive_children": t == 0 and not w[26] & 1,
             "assignment_actions": {0: None, 0x400: False, 0x800: True}.get(w[26] & 0xC00),
             "apply_conditions": {0: None, 0x40: "on demand", 0x80: "never"}.get(w[26] & 0xC0, "automatically"),
             "protected": {0: None, 1: False, 2: True}.get(w[23] & 3)}
        if t == 3:                                  # date category
            s.update({"assign_item_date": ["never", "when entered", "item text edited", "note edited",
                                           "item or note edited", "when assigned", "assigned or edited",
                                           "from item text", "from note text", "from item or note text",
                                           ][min((w[23] >> 9) & 15, 9)],
                      "which_date_in_text": w[30] + 1,
                      "set_from_done_key": bool(w[23] & 0x80), "set_from_when_key": bool(w[23] & 0x100),
                      "recurring_dates": bool(w[23] & 0x4000),
                      "conflicts": {0: None, 0x20: "keep old", 0x40: "override"}.get(w[23] & 0x60)})
        else:
            s.update({"match_name": not w[28] & 0x08, "match_short_name": not w[28] & 0x10,
                      "text_matching": {0: None, 0x4000: False, 0x8000: True}.get(w[28] & 0xC000),
                      "match_on": [None, "item text", "note text", "item and note"][w[28] & 3],
                      "allow_explicit": not w[28] & 0x80,
                      "relationship": {0: None, 0x20: "or", 0x40: "and"}.get(w[28] & 0x60),
                      "confirm": {0: None, 0x200: "always", 0x400: "sometimes"}.get(w[28] & 0x600),
                      "match_strength": [None, "exact", "partial", "minimal"][(w[23] >> 7) & 3],
                      "assignment_conditions": {0: None, 1: False, 2: True}.get(w[29]) if t == 0 else None})
        return {k: v for k, v in s.items() if v is not None}

    def conditions(self, set_block):
        """Type-5 block: assignment conditions (type-6 links), actions (type-7), special action."""
        if not set_block:
            return None
        w = self.bw(set_block)
        out = {"conditions": [{"category": self.lw(l)[2], "assigned": not self.lw(l)[8]}
                              for l in self.walk(w[11], 4, self.lw)],
               "actions": [{"category": self.lw(l)[2], "assign": not self.lw(l)[8]}
                           for l in self.walk(w[13], 4, self.lw)]}
        special = {0: None, 8: "discard", 0x10: "done", 0x18: "export"}.get(w[15], w[15])
        if special:
            out["special_action"] = special
            if w[9]:
                out["export_file"] = self.chain(w[9])
        return out

    def categories(self, c=None):
        c = c or self.root_category
        w = self.bw(c)
        parts = self.category_name(c).split(";")
        cat = {
            "id": c,
            "name": parts[0],
            "short_name": parts[1] if len(parts) > 1 and parts[1] else None,
            "also_match": [p for p in parts[2:] if p],
            "type": CATEGORY_TYPES[(w[26] >> 2) & 3],
            "note": self.note(w),
            "settings": self.category_settings(w),
            "conditions": self.conditions(w[19]),
            "children": [self.categories(ch) for ch in self.walk(w[17], 15, self.bw)],
        }
        return {k: v for k, v in cat.items() if v not in (None, [], {})}

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
            assignments, alarm = [], None
            for link in self.walk(w[9], 4, self.lw):
                lw = self.lw(link)
                if lw[2] == CURRENT_ALARMS and lw[8] & 0x200:  # alarm: w9 = type-13 link
                    al = self.lw(lw[9])
                    alarm = {"date_category": al[5], "minutes_before": al[6]}
                    continue
                a = {"category": lw[2], "how": how(lw[8])}
                v = self.value(lw)
                if v is not None:
                    a["value"] = v
                    if lw[8] & 0x180 == 0x100:      # date: how it was typed
                        rec = self.links[lw[9]]
                        kind = struct.unpack_from("<H", rec, 26)[0]
                        if kind in (1, 2):
                            a["given_as"] = date_expression(rec[10:18], kind)
                assignments.append(a)
            item = {"id": n, "text": self.chain(w[2], self.block(n)[50:62]),
                    "note": self.note(w), "assignments": assignments,
                    # discarded items stay in the file, assigned only to !Trash! (block 1)
                    "trashed": any(a["category"] == TRASH for a in assignments)}
            if alarm:
                item["alarm"] = alarm
            out.append(item)
        return out

    def column(self, l):
        lw = self.lw(l)
        col = {"category": lw[2], "width": lw[8] - 1}
        ctype = (self.bw(lw[2])[26] >> 2) & 3
        if ctype == 3:                              # date: format inline in w10
            col["date_format"] = date_format(lw[10])
        elif ctype == 2:                            # numeric: format in w11
            f = lw[11]
            col["number_format"] = {"decimals": (f >> 4) & 31, "label": [None, "%", "$", "?"][f & 3],
                                    "thousands_separator": bool(f & 0x8000),
                                    "negative_parentheses": bool(f & 0x4000),
                                    "percent_of_total": bool(f & 0x1000)}
        return col

    def views(self):
        out = []
        for v in self.walk(self.first_view, 9, self.bw):
            w = self.bw(v)
            name = self.cstr(self.block(v)[44:]) + (self.chain(w[2]) if w[2] else "")
            sections = []
            for s in self.walk(w[3], 4, self.bw):
                sw = self.bw(s)
                sec = {"category": sw[2], "columns": [self.column(c) for c in self.walk(sw[8], 7, self.lw)]}
                if sw[5]:
                    sec["filter"] = self.filter_elements(sw[5])
                if sw[10]:
                    sec["sort"] = [k for k in (self.sort_key(sw[10]), self.sort_key(sw[11])) if k]
                sections.append(sec)
            f20, f21 = w[20], w[21]
            view = {"id": v, "name": name,
                    "hide_empty_sections": bool(f20 & 0x8000), "hide_done": bool(f20 & 1),
                    "hide_dependent": bool(f20 & 0x40), "hide_inherited": bool(f20 & 2),
                    "hide_column_heads": bool(f21 & 0x40), "section_separators": bool(f20 & 0x80),
                    "number_items": bool(f21 & 0x20),
                    "section_sorting": [None, "category order", "alphabetic", "numeric"][(f21 >> 1) & 3],
                    "sort": [k for k in (self.sort_key(w[10]), self.sort_key(w[11])) if k],
                    "sort_new_items": ["on leaving section", "when entered", "on demand", "?"][w[12] & 3],
                    "filter": self.filter_elements(w[5]) if w[5] else [],
                    "sections": sections}
            if w[12] & 0x300:                       # datebook: period in bits 4-5
                period = ["day", "week", "month", "quarter"][(w[12] >> 4) & 3]
                # a day runs from hour w15 to hour w16 (0xC8hh); longer periods from weekday w15 to w16
                span = ([f"{w[15] & 0xFF}:00", f"{w[16] & 0xFF}:00"] if period == "day"
                        else [WEEKDAYS[w[15]] if w[15] else "Sunday", WEEKDAYS[w[16]] if w[16] else "Sunday"])
                view["datebook"] = {"period": period, "from": span[0], "to": span[1]}
            out.append(view)
        return out

    def macros(self):
        first = self.w(0x9A)
        return [self.chain(self.bw(m)[2], self.block(m)[24:]).split("\r")[0]
                for m in self.walk(first, 5, self.bw)]

    def settings(self):
        """File-level settings from the header (File Properties and its sub-boxes)."""
        w = self.w
        return {"tab_size": w(0x7C), "backup_on_open": bool(w(0x5E)),
                "empty_trash": {0: "on demand", 0x40: "when file closed", 0x80: "end of day",
                                0xC0: "when discarded"}[w(0x8C) & 0xC0],
                "process_done_items": {0: "no action", 0x200: "discard", 0x800: "export"}.get(w(0x8C) & 0xE00),
                "text_matching": bool(w(0x8C) & 0x4000), "assignment_conditions": bool(w(0x8C) & 0x2000),
                "assignment_actions": bool(w(0x98) & 2),
                "relationship": {1: "or", 2: "and"}.get(w(0x8E) & 3),
                "week": [WEEKDAYS[w(0x18E)] if w(0x18E) else "Sunday", WEEKDAYS[w(0x190)]],
                "morning": f"{w(0x186) & 0xFF}:00", "afternoon": f"{w(0x18A) & 0xFF}:00",
                "evening": f"{w(0x188) & 0xFF}:00",
                "month_alone_means": "last day" if w(0x192) & 1 else "first day",
                "date_format": date_format(w(0x182))}

    def to_json(self):
        return {"description": self.description, "password": self.password or None,
                "created": self.created, "saved": self.saved, "settings": self.settings(),
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
            if any(x > self.last_block for x in (lw[2], lw[5]) if lw[1] in (L_ASSIGN, L_FILTER, L_COLUMN, L_SORT)):
                errors.append(f"link {lid} (type {lw[1]}) points past the last block: {lw}")
                continue
            if lw[1] in (L_ASSIGN, L_FILTER, L_COLUMN, L_COND, L_ACTION) and self.bw(lw[2])[1] != B_CATEGORY:
                errors.append(f"link {lid} (type {lw[1]}): category {lw[2]} is a type {self.bw(lw[2])[1]} block")
            if lw[1] == L_ASSIGN and self.bw(lw[5])[1] != B_ITEM:
                errors.append(f"link {lid}: item {lw[5]} is a type {self.bw(lw[5])[1]} block")
            if lw[1] == L_SORT and lw[2] and self.bw(lw[2])[1] != B_CATEGORY:
                errors.append(f"sort key {lid}: category {lw[2]} is a type {self.bw(lw[2])[1]} block")
            if lw[1] in (L_FILTER, L_SORT) and self.bw(lw[5])[1] not in (B_VIEW, B_SECTION):
                errors.append(f"link {lid} (type {lw[1]}): owner {lw[5]} is a type {self.bw(lw[5])[1]} block")
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
