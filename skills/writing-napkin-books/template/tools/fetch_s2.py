#!/usr/bin/env python3
"""Fetch Semantic Scholar citation counts / venues for arXiv IDs listed in a TSV.

usage: python3 -I fetch_s2.py <candidates.tsv> <outdir>
Writes <outdir>/s2_meta.json (keyed by arxiv id) and prints a table sorted by citations.
"""
import json
import re
import sys
import time
import urllib.error
import urllib.request

FIELDS = "title,year,venue,publicationVenue,citationCount,influentialCitationCount,externalIds,publicationDate"
URL = "https://api.semanticscholar.org/graph/v1/paper/batch?fields=" + FIELDS
ID_RE = re.compile(r"^\d{4}\.\d{4,5}$")


def post(ids):
    body = json.dumps({"ids": ["ARXIV:" + i for i in ids]}).encode()
    req = urllib.request.Request(URL, data=body, headers={
        "Content-Type": "application/json",
        "User-Agent": "napkin-book-tools/0.1 (personal research)"})
    for attempt in range(6):
        try:
            with urllib.request.urlopen(req, timeout=90) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            if e.code == 429:
                time.sleep(10 * (attempt + 1))
                continue
            raise
    raise RuntimeError("rate-limited too long")


def main():
    tsv, outdir = sys.argv[1], sys.argv[2]
    rows = []
    for line in open(tsv, encoding="utf-8"):
        if not line.strip() or line.startswith("#"):
            continue
        p = line.rstrip("\n").split("\t")
        if ID_RE.match(p[1]):
            rows.append((p[0], p[1], p[2], p[3]))
    ids = [r[1] for r in rows]
    res = {}
    for i in range(0, len(ids), 100):
        chunk = ids[i:i + 100]
        data = post(chunk)
        for aid, rec in zip(chunk, data):
            res[aid] = rec
        time.sleep(3)
    with open(outdir + "/s2_meta.json", "w", encoding="utf-8") as f:
        json.dump(res, f, indent=1, ensure_ascii=False)
    table = []
    for key, aid, tier, sec in rows:
        rec = res.get(aid) or {}
        table.append((rec.get("citationCount") if rec else None, key, aid, tier, sec,
                      rec.get("year") if rec else None, (rec.get("venue") or "")[:34] if rec else "NOT FOUND"))
    table.sort(key=lambda t: -(t[0] if t[0] is not None else -1))
    print("%-7s %-17s %-11s %s %-6s %-5s %s" % ("cites", "key", "arxiv", "T", "sec", "year", "S2 venue"))
    for c, key, aid, tier, sec, yr, ven in table:
        print("%-7s %-17s %-11s %s %-6s %-5s %s" % (c, key, aid, tier, sec, yr, ven))


if __name__ == "__main__":
    main()
