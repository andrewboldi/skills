#!/usr/bin/env python3
"""Search the downloaded paper PDFs for regular expressions and print the matches with context.

usage: python3 -I tools/pdfgrep.py KEY REGEX [REGEX ...] [--n N] [--w W]
       python3 -I tools/pdfgrep.py --list

KEY is a bibliography key listed in <PAPERS_DIR>/manifest.tsv (written by tools/fetch_papers.py; PAPERS_DIR is set in
tools/book.env). The text of each PDF is extracted once with pdftotext and cached in build/txtcache/. --n is the
number of matches shown per regex (default 3), --w the number of characters of context on each side (default 200).
Matching is case-insensitive. Use it to verify a claim about a paper against the paper's own text, and quote the
match (with its page, from pdftotext -f N -l N) in the provenance notes.
"""
import glob
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))


def papers_dir():
    d = "papers"
    env = os.path.join(HERE, "book.env")
    if os.path.exists(env):
        m = re.search(r'^PAPERS_DIR="?([^"\s#]+)"?', open(env, encoding="utf-8").read(), flags=re.M)
        if m:
            d = m.group(1)
    return os.path.join(ROOT, d) + "/"


PAPERS = papers_dir()
CACHE = os.path.join(ROOT, "build", "txtcache") + "/"


def manifest():
    ids = {}
    path = PAPERS + "manifest.tsv"
    if not os.path.exists(path):
        sys.exit(f"no {path}; download the papers first (tools/fetch_papers.py)")
    for line in open(path, encoding="utf-8"):
        f = line.rstrip("\n").split("\t")
        if len(f) >= 5 and f[4] == "ok":
            ids[f[0]] = f[1]
    return ids


def pdf_of(key, ids):
    exact = PAPERS + f"{key}_{ids[key]}.pdf" if key in ids else None
    if exact and os.path.exists(exact):
        return exact
    hits = sorted(glob.glob(PAPERS + f"{key}_*.pdf"))
    if not hits:
        sys.exit(f"no PDF for key {key!r}; try --list")
    return hits[0]


def text_of(key, ids):
    os.makedirs(CACHE, exist_ok=True)
    pdf = pdf_of(key, ids)
    cf = CACHE + os.path.basename(pdf)[:-4] + ".txt"
    if not os.path.exists(cf) or os.path.getmtime(cf) < os.path.getmtime(pdf):
        out = subprocess.run(["pdftotext", "-q", pdf, "-"], capture_output=True, text=True, timeout=180).stdout
        out = out.replace("ﬁ", "fi").replace("ﬂ", "fl").replace("ﬀ", "ff")
        out = re.sub(r"-\n(?=[a-z])", "", out)
        out = re.sub(r"\s+", " ", out)
        open(cf, "w", encoding="utf-8").write(out)
    return open(cf, encoding="utf-8").read()


def main():
    args = sys.argv[1:]
    ids = manifest()
    if not args or args[0] == "--list":
        print(" ".join(sorted(ids)))
        return
    n, w = 3, 200
    if "--n" in args:
        i = args.index("--n")
        n = int(args[i + 1])
        del args[i:i + 2]
    if "--w" in args:
        i = args.index("--w")
        w = int(args[i + 1])
        del args[i:i + 2]
    key, pats = args[0], args[1:]
    t = text_of(key, ids)
    print(f"=== {key} ({len(t)} characters)")
    for pat in pats:
        ms = list(re.finditer(pat, t, re.I))
        print(f"--- [{pat}] {len(ms)} match(es)")
        for m in ms[:n]:
            a, b = max(0, m.start() - w), min(len(t), m.end() + w)
            print("   ..." + t[a:b] + "...")


if __name__ == "__main__":
    main()
