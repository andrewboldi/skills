#!/usr/bin/env python3
"""Generate papers.tex (paper-card metadata macros) and refs_auto.bib from verified arXiv metadata.

usage: python3 -I tools/build_meta.py tools/data/candidates.tsv tools/data/venues.tsv tools/data/arxiv_meta.json <outdir>

Every field printed in a paper-card header or in the bibliography comes from the arXiv API response (title,
authors, date, category); nothing is typed from memory except the venue/org columns of venues.tsv, which hold only
confirmed values. Normally run through tools/add_arxiv.py; tools/check.sh verifies that the committed files are
exactly what this script generates.
"""
import json
import re
import sys

MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
# Edit for your corpus: author strings that are organizations, not people (kept whole, never split into names),
# e.g. {"Open X-Embodiment Collaboration", "Gemini Robotics Team"}.
GROUPS = set()
# Edit for your corpus: arXiv metadata spelling -> spelling the authors themselves use (cite the evidence in
# provenance/), e.g. {"Simon Aliberts": "Simon Alibert"}.
NAME_FIXES = {}
PARTICLES = {"van", "von", "de", "der", "den", "da", "di", "del", "la", "le", "du", "dos", "das"}
# Venue strings in venues.tsv look like "ICML 2024" or "Science Robotics 2023 (vol. 8)". Extend these two tables
# for the field of the book; unknown venues become an @online entry with the venue as a note.
CONF = ("AISTATS", "ICML", "NeurIPS", "ICLR", "CoRL", "RSS", "ICRA", "IROS", "CVPR", "ICCV", "ECCV", "ACL",
        "EMNLP", "NAACL", "AAAI", "IJCAI", "KDD", "COLM", "MLHC", "STOC", "FOCS", "SODA", "QIP")
JOURNAL = {"TMLR": "Transactions on Machine Learning Research",
           "JMLR": "Journal of Machine Learning Research",
           "RA-L": "IEEE Robotics and Automation Letters",
           "IEEE RA-L": "IEEE Robotics and Automation Letters",
           "Science Robotics": "Science Robotics",
           "Nature": "Nature",
           "Science": "Science",
           "Nature Machine Intelligence": "Nature Machine Intelligence",
           "Physical Review Letters": "Physical Review Letters",
           "PRX Quantum": "PRX Quantum"}


def tex_escape(s):
    """Escape LaTeX specials outside $...$ segments; convert unicode pi inside math."""
    parts = re.split(r"(\$[^$]*\$)", s)
    out = []
    for p in parts:
        if p.startswith("$") and p.endswith("$") and len(p) >= 2:
            p = p.replace("π", r"\pi ")
            out.append(p)
        else:
            for ch, rep in (("\\", r"\textbackslash{}"), ("&", r"\&"), ("%", r"\%"),
                            ("#", r"\#"), ("_", r"\_"), ("~", r"\textasciitilde{}")):
                p = p.replace(ch, rep)
            p = p.replace("π", r"$\pi$")
            out.append(p)
    return "".join(out)


def lastname(full):
    toks = [t for t in full.replace(".", ". ").split() if t]
    if not toks:
        return full
    ln = toks[-1]
    if len(toks) >= 2 and toks[-2].lower() in PARTICLES:
        ln = toks[-2] + " " + ln
    return ln


def short_authors(authors):
    if not authors:
        return ""
    authors = [NAME_FIXES.get(a, a) for a in authors]
    first = authors[0]
    if first in GROUPS:
        return first
    if len(authors) == 1:
        return lastname(first)
    if len(authors) == 2:
        return lastname(authors[0]) + " and " + lastname(authors[1])
    return lastname(first) + " et al."


def bib_authors(authors, keep=6):
    names = []
    authors = [NAME_FIXES.get(a, a) for a in authors]
    for a in authors[:keep]:
        if a == ":":
            continue
        if a in GROUPS:
            names.append("{%s}" % a)
            continue
        ln = lastname(a)
        given = a[: len(a) - len(ln)].strip() if a.endswith(ln) else " ".join(a.split()[:-1])
        names.append("%s, %s" % (ln, given) if given else ln)
    s = " and ".join(names)
    if len(authors) > keep:
        s += " and others"
    return s


def classify_venue(venue, arx_year):
    """Return (entrytype, fields dict). Unknown venues and technical reports -> online."""
    v = (venue or "").strip()
    m = re.match(r"^(.*?)\s+(\d{4})(.*)$", v)
    if not m:
        return "online", {"year": arx_year, "note": v} if v else {"year": arx_year}
    name, yr, rest = m.group(1).strip(), m.group(2), m.group(3).strip()
    if name in CONF:
        return "inproceedings", {"booktitle": name + ((" " + rest) if rest else ""), "year": yr}
    if name in JOURNAL:
        f = {"journaltitle": JOURNAL[name], "year": yr}
        if rest:
            f["note"] = rest
        return "article", f
    return "online", {"year": arx_year, "note": v}


def load_tsv(path, ncols):
    rows = []
    for line in open(path, encoding="utf-8"):
        if not line.strip() or line.startswith("#"):
            continue
        p = line.rstrip("\n").split("\t")
        p += [""] * (ncols - len(p))
        rows.append(p)
    return rows


def main():
    if len(sys.argv) != 5:
        sys.exit(__doc__)
    venues = {r[0]: (r[1], r[2]) for r in load_tsv(sys.argv[2], 3)}
    meta = json.load(open(sys.argv[3], encoding="utf-8"))
    outdir = sys.argv[4]
    tex, bib, seen = [], [], set()
    for key, aid, tier, sec, _ in [r[:5] for r in load_tsv(sys.argv[1], 5)]:
        if key in seen or aid not in meta:
            continue
        if tier not in ("A", "B", "C"):
            sys.exit(f"{key}: tier must be A, B or C, not {tier!r}")
        seen.add(key)
        m = meta[aid]
        y, mo = m["published"][:4], int(m["published"][5:7])
        venue, org = venues.get(key, ("", ""))
        title = tex_escape(m["title"])

        def d(name, val):
            tex.append(r"\expandafter\def\csname P@%s@%s\endcsname{%s}" % (name, key, val))
        d("title", title)
        d("auth", tex_escape(short_authors(m["authors"])))
        d("year", y)
        d("date", "%s %s" % (MONTHS[mo - 1], y))
        d("arx", aid)
        d("venue", tex_escape(venue))
        d("org", tex_escape(org))
        d("tier", tier)
        d("sec", sec)
        tex.append(r"\colorlet{pc@%s}{%s}" % (key, {"A": "navy", "B": "teal"}.get(tier, "slate")))
        etype, fields = classify_venue(venue, y)
        extra = "".join("  %s = {%s},\n" % (k, tex_escape(v) if k in ("booktitle", "note") else v)
                        for k, v in fields.items() if k != "year")
        bib.append("@%s{%s,\n  author = {%s},\n  title = {{%s}},\n  year = {%s},\n"
                   "  eprinttype = {arxiv},\n  eprint = {%s},\n  eprintclass = {%s},\n%s}\n" % (
                       etype, key, bib_authors(m["authors"]).replace("&", r"\&"), title, fields["year"], aid,
                       m["primary_category"], extra))
    open(outdir + "/papers.tex", "w", encoding="utf-8").write(
        "% AUTO-GENERATED by tools/build_meta.py -- do not edit\n" + "\n".join(tex) + "\n")
    open(outdir + "/refs_auto.bib", "w", encoding="utf-8").write(
        "% AUTO-GENERATED by tools/build_meta.py -- do not edit\n" + "\n".join(bib))
    print("wrote %d papers" % len(seen))


if __name__ == "__main__":
    main()
