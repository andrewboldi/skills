#!/usr/bin/env python3
"""Fetch arXiv metadata for every ID in a candidates TSV and save it as JSON.

usage: python3 -I fetch_arxiv.py <candidates.tsv> <outdir>

Columns of the TSV: key, arxiv_id, tier, section, expected_short_name.
Writes <outdir>/arxiv_meta.json (keyed by arxiv_id) and prints a compact table.
Stdlib only; sleeps between requests to respect the arXiv API etiquette.
"""
import json
import re
import sys
import time
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET

ATOM = "{http://www.w3.org/2005/Atom}"
ARX = "{http://arxiv.org/schemas/atom}"
ID_RE = re.compile(r"^\d{4}\.\d{4,5}$|^[a-z\-]+/\d{7}$")


def squash(s):
    return re.sub(r"\s+", " ", s or "").strip()


def fetch_chunk(ids):
    url = ("https://export.arxiv.org/api/query?max_results=%d&id_list=%s"
           % (len(ids), ",".join(ids)))
    req = urllib.request.Request(url, headers={"User-Agent": "study-book-tools/0.1 (personal research)"})
    for attempt in range(8):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code in (429, 503):
                wait = 45 * (attempt + 1)
                print("HTTP %d from arXiv; backing off %ds (attempt %d)" % (e.code, wait, attempt + 1), flush=True)
                time.sleep(wait)
                continue
            raise
    raise RuntimeError("arXiv API kept rate-limiting")


def parse(xml_bytes):
    out = {}
    root = ET.fromstring(xml_bytes)
    for e in root.findall(ATOM + "entry"):
        raw_id = squash(e.findtext(ATOM + "id"))
        m = re.search(r"arxiv\.org/abs/(.+?)(v\d+)?$", raw_id)
        if not m:  # error entries have ids like http://arxiv.org/api/errors#...
            continue
        aid = m.group(1)
        pc = e.find(ARX + "primary_category")
        out[aid] = {
            "id": aid,
            "latest_version": (m.group(2) or "").lstrip("v"),
            "title": squash(e.findtext(ATOM + "title")),
            "authors": [squash(a.findtext(ATOM + "name")) for a in e.findall(ATOM + "author")],
            "published": squash(e.findtext(ATOM + "published"))[:10],
            "updated": squash(e.findtext(ATOM + "updated"))[:10],
            "abstract": squash(e.findtext(ATOM + "summary")),
            "primary_category": pc.get("term") if pc is not None else "",
            "journal_ref": squash(e.findtext(ARX + "journal_ref")),
            "comment": squash(e.findtext(ARX + "comment")),
            "doi": squash(e.findtext(ARX + "doi")),
        }
    return out


def main():
    tsv, outdir = sys.argv[1], sys.argv[2]
    rows = []
    for line in open(tsv, encoding="utf-8"):
        if not line.strip() or line.startswith("#"):
            continue
        parts = line.rstrip("\n").split("\t")
        key, aid = parts[0], parts[1]
        if not ID_RE.match(aid):
            print("SKIP (placeholder/bad id):", key, aid)
            continue
        rows.append(dict(key=key, id=aid, tier=parts[2], sec=parts[3],
                         exp=parts[4] if len(parts) > 4 else ""))
    ids = [r["id"] for r in rows]
    meta = {}
    for i in range(0, len(ids), 40):
        chunk = ids[i:i + 40]
        raw = fetch_chunk(chunk)
        with open("%s/arxiv_raw_%02d.xml" % (outdir, i // 40), "wb") as f:
            f.write(raw)
        meta.update(parse(raw))
        time.sleep(4)
    with open(outdir + "/arxiv_meta.json", "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=1, ensure_ascii=False)
    missing = [r for r in rows if r["id"] not in meta]
    print("requested %d, received %d, missing %d" % (len(rows), len(meta), len(missing)))
    for r in rows:
        m = meta.get(r["id"])
        if not m:
            print("MISSING  %-16s %-12s %s" % (r["key"], r["id"], r["exp"]))
            continue
        fa = m["authors"][0] if m["authors"] else "?"
        print("%-16s %-11s %s %-3s %-62s | %-22s | %s | exp: %s" % (
            r["key"], r["id"], r["tier"], r["sec"][:3], m["title"][:62], fa[:22], m["published"], r["exp"]))


if __name__ == "__main__":
    main()
