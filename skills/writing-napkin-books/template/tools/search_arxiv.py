#!/usr/bin/env python3
"""Run several arXiv API search queries, de-duplicate, and print a compact list.

usage: python3 -I search_arxiv.py <outdir> <max_per_query> <outname> <query> [<query> ...]
Each query uses arXiv search syntax, e.g.  all:"surface code" AND all:"decoder"
Hits (with abstracts) are saved to <outdir>/<outname>.json.
"""
import json
import re
import sys
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

ATOM = "{http://www.w3.org/2005/Atom}"


def squash(s):
    return re.sub(r"\s+", " ", s or "").strip()


def run(query, n):
    qs = urllib.parse.urlencode({
        "search_query": query, "start": 0, "max_results": n,
        "sortBy": "submittedDate", "sortOrder": "descending"})
    req = urllib.request.Request("https://export.arxiv.org/api/query?" + qs,
                                 headers={"User-Agent": "napkin-book-tools/0.1 (personal research)"})
    with urllib.request.urlopen(req, timeout=60) as r:
        root = ET.fromstring(r.read())
    out = []
    for e in root.findall(ATOM + "entry"):
        m = re.search(r"arxiv\.org/abs/(.+?)(v\d+)?$", squash(e.findtext(ATOM + "id")))
        if not m:
            continue
        out.append({
            "id": m.group(1),
            "title": squash(e.findtext(ATOM + "title")),
            "authors": [squash(a.findtext(ATOM + "name")) for a in e.findall(ATOM + "author")],
            "published": squash(e.findtext(ATOM + "published"))[:10],
            "abstract": squash(e.findtext(ATOM + "summary")),
        })
    return out


def main():
    outdir, n, outname, queries = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4:]
    hits = {}
    for qi, q in enumerate(queries):
        try:
            res = run(q, n)
        except Exception as ex:  # keep going if one query fails
            print("QUERY FAILED:", q, ex)
            continue
        print("q%d: %-100s -> %d hits" % (qi, q[:100], len(res)))
        for h in res:
            rec = hits.setdefault(h["id"], dict(h, queries=[]))
            rec["queries"].append(qi)
        time.sleep(3.5)
    with open("%s/%s.json" % (outdir, outname), "w", encoding="utf-8") as f:
        json.dump(hits, f, indent=1, ensure_ascii=False)
    print("\n%d unique hits\n" % len(hits))
    for h in sorted(hits.values(), key=lambda r: r["published"], reverse=True):
        fa = h["authors"][0] if h["authors"] else "?"
        print("%-11s %s q%-8s %-96s | %s" % (h["id"], h["published"],
              ",".join(map(str, h["queries"])), h["title"][:96], fa[:20]))


if __name__ == "__main__":
    main()
