#!/usr/bin/env python3
"""List the bibliography keys the book cites, split into arXiv papers and other sources.

usage: python3 -I make_cited_keys.py <guide-dir> > tools/data/cited_keys.json

Reads the citation keys that biber recorded in build/main.bcf (so build the book first), looks each key up in
refs_auto.bib (arXiv papers; the arXiv id comes from the eprint field) and refs_manual.bib (everything else), and
prints {"arxiv": {bibkey: arxiv_id}, "manual": [bibkey, ...]} in citation order.
"""
import json
import re
import sys


def main():
    gdir = sys.argv[1] if len(sys.argv) > 1 else "."
    bcf = open(f"{gdir}/build/main.bcf", encoding="utf-8").read()
    keys = list(dict.fromkeys(re.findall(r"<bcf:citekey[^>]*>([^<]+)</bcf:citekey>", bcf)))
    auto = open(f"{gdir}/refs_auto.bib", encoding="utf-8").read()
    eprints = {}
    for m in re.finditer(r"@\w+\{([^,]+),(.*?)\n\}\n", auto, flags=re.S):
        e = re.search(r"eprint = \{([^}]+)\}", m.group(2))
        if e:
            eprints[m.group(1)] = e.group(1)
    manual = set(re.findall(r"@\w+\{([^,]+),", open(f"{gdir}/refs_manual.bib", encoding="utf-8").read()))
    out = {"arxiv": {k: eprints[k] for k in keys if k in eprints},
           "manual": [k for k in keys if k in manual]}
    unknown = [k for k in keys if k not in eprints and k not in manual]
    if unknown:
        sys.exit(f"keys in neither bibliography: {unknown}")
    json.dump(out, sys.stdout, indent=1)
    print()


if __name__ == "__main__":
    main()
