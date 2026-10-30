#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-only
"""Word-level diff of two Lotus Agenda .AG files (research tool, not part of Agendum).

The other half of an experiment with agenda_driver.py: change one thing in
Agenda, save, and see which header words, block words and link words moved.

    python3 tools/agformat/agdiff.py BEFORE.AG AFTER.AG

Words that change on every save (save counter, dates, last box values) are
left out; new free blocks are only counted. See DRIVING_AGENDA.md.
"""
import struct
import sys

from agdump import AgendaFile

# Header words that change on every save or with the cursor (noise in a diff)
NOISY = {0x5C, 0x60, 0x1E8, 0x1EE} | set(range(0x168, 0x178, 2)) | set(range(0x1F4, 0x212, 2))


def fmt(words):
    return " ".join(f"{x:x}" for x in words)


def diff(a, b, out=print):
    new_free = 0
    for o in range(0, 0x400, 2):
        x, y = a.w(o), b.w(o)
        if x != y and o not in NOISY:
            out(f"hdr {o:#05x}: {x:#06x} -> {y:#06x}")
    for i in range(1, max(a.last_block, b.last_block) + 1):
        wa = a.bw(i) if i <= a.last_block else None
        wb = b.bw(i) if i <= b.last_block else None
        if wa == wb:
            continue
        if wb is not None and wb[1] == 0 and (wa is None or wa[1] == 0):
            new_free += 1
        elif wa is None or wa[1] == 0:
            out(f"+blk {i} t{wb[1]}: {fmt(wb)}")
        elif wb is None or wb[1] == 0:
            out(f"-blk {i} t{wa[1]}")
        else:
            out(f" blk {i} t{wb[1]}: " + " ".join(f"w{k}:{wa[k]:#x}->{wb[k]:#x}" for k in range(32) if wa[k] != wb[k]))
    for l in sorted(set(a.links) | set(b.links)):
        ra, rb = a.links.get(l), b.links.get(l)
        if ra == rb:
            continue
        if ra is None:
            out(f"+lnk {l} t{struct.unpack_from('<H', rb, 2)[0]}: {fmt(struct.unpack('<14H', rb))}")
        elif rb is None:
            out(f"-lnk {l}")
        else:
            wa, wb = struct.unpack("<14H", ra), struct.unpack("<14H", rb)
            out(f" lnk {l} t{wb[1]}: " + " ".join(f"w{k}:{wa[k]:#x}->{wb[k]:#x}" for k in range(14) if wa[k] != wb[k]))
    if new_free:
        out(f"({new_free} new free blocks)")


if __name__ == "__main__":
    before, after = (AgendaFile(open(p, "rb").read()) for p in sys.argv[1:3])
    diff(before, after)
