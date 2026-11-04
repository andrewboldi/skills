#!/usr/bin/env python3
"""Add arXiv papers to the book's bibliography in one step.

usage: python3 -I tools/add_arxiv.py new_rows.tsv

new_rows.tsv has the columns of tools/data/candidates.tsv, tab-separated: key, arxiv_id, tier (A/B/C), section code
(must appear in tools/data/groups.tsv), short name. Rows whose arXiv id or key is already known are skipped. For the
new rows the script
  1. fetches title, authors, dates and category from the arXiv API (tools/fetch_arxiv.py, polite to the API),
  2. merges the result into tools/data/arxiv_meta.json,
  3. appends the rows to tools/data/candidates.tsv,
  4. regenerates papers.tex and refs_auto.bib (tools/build_meta.py),
and prints the fetched titles so that you can check that every id is the paper you meant.
Download the PDFs afterwards with tools/fetch_papers.py.
"""
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
DATA = os.path.join(ROOT, "tools", "data")


def rows_of(path):
    rows = []
    for line in open(path, encoding="utf-8"):
        if line.strip() and not line.startswith("#"):
            p = line.rstrip("\n").split("\t")
            p += [""] * (5 - len(p))
            rows.append(p[:5])
    return rows


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    cand_path = os.path.join(DATA, "candidates.tsv")
    known = rows_of(cand_path)
    known_keys = {r[0] for r in known}
    known_ids = {r[1] for r in known}
    incoming = rows_of(sys.argv[1])
    bad = [r for r in incoming if r[2] not in ("A", "B", "C") or not r[3]]
    if bad:
        sys.exit(f"every row needs tier A, B or C and a section code: {bad}")
    codes = set()
    for line in open(os.path.join(DATA, "groups.tsv"), encoding="utf-8"):
        if line.strip() and not line.startswith("#"):
            codes.update(c.strip() for c in (line.rstrip("\n").split("\t") + ["", ""])[2].split(","))
    unknown = sorted({r[3] for r in incoming} - codes)
    if unknown:
        sys.exit(f"section codes not in tools/data/groups.tsv: {unknown} (add them there first)")
    new = [r for r in incoming if r[0] not in known_keys and r[1] not in known_ids]
    skipped = [r[0] for r in incoming if r not in new]
    if skipped:
        print("already known, skipped:", ", ".join(skipped))
    if not new:
        return
    with tempfile.TemporaryDirectory(prefix="add_arxiv_") as tmp:
        tsv = os.path.join(tmp, "rows.tsv")
        open(tsv, "w", encoding="utf-8").write("\n".join("\t".join(r) for r in new) + "\n")
        subprocess.run([sys.executable, "-I", os.path.join(ROOT, "tools", "fetch_arxiv.py"), tsv, tmp], check=True)
        fetched = json.load(open(os.path.join(tmp, "arxiv_meta.json"), encoding="utf-8"))
    missing = [r[1] for r in new if r[1] not in fetched]
    if missing:
        sys.exit(f"arXiv returned nothing for: {missing}; nothing was changed")
    meta_path = os.path.join(DATA, "arxiv_meta.json")
    meta = json.load(open(meta_path, encoding="utf-8"))
    meta.update(fetched)
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)
        f.write("\n")
    cand = open(cand_path, encoding="utf-8").read()
    with open(cand_path, "a", encoding="utf-8") as f:
        if cand and not cand.endswith("\n"):
            f.write("\n")
        f.write("\n".join("\t".join(r) for r in new) + "\n")
    subprocess.run([sys.executable, "-I", os.path.join(ROOT, "tools", "build_meta.py"),
                    cand_path, os.path.join(DATA, "venues.tsv"), meta_path, ROOT], check=True)
    print("added (check that each title is the paper you meant):")
    for r in new:
        print(f"  {r[0]:28s} {r[1]:12s} {fetched[r[1]]['title'][:90]}")


if __name__ == "__main__":
    main()
