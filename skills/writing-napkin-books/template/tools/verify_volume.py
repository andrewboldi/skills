#!/usr/bin/env python3
"""Spot-check the links and bookmarks of the combined PDF.

usage: python3 -I verify_volume.py <combined.pdf> <papers_order.json> [--samples N]

For a sample of internal links in the guide and inside a few papers it prints the words under the link, the page
the link jumps to and the first words of that page, so that a person can see that the jumps land in the right place.
It also checks every link of the whole file for a valid target page and lists the first bookmarks and page labels.
"""
import argparse
import json
import random
import re
import subprocess

import pikepdf


def page_words(pdf_path, n, cache={}):
    key = (pdf_path, n)
    if key not in cache:
        out = subprocess.run(["pdftotext", "-bbox", "-f", str(n + 1), "-l", str(n + 1), pdf_path, "-"],
                             capture_output=True, text=True).stdout
        cache[key] = [(float(a), float(b), float(c), float(d), w) for a, b, c, d, w in
                      re.findall(r'<word xMin="([\d.]+)" yMin="([\d.]+)" xMax="([\d.]+)" yMax="([\d.]+)">([^<]*)</word>', out)]
    return cache[key]


def under(pdf_path, n, rect, height):
    x0, y0, x1, y1 = [float(v) for v in rect]
    top, bottom = height - y1, height - y0                       # pdftotext measures y from the top
    return " ".join(w for a, b, c, d, w in page_words(pdf_path, n)
                    if x0 - 1 <= (a + c) / 2 <= x1 + 1 and top - 1 <= (b + d) / 2 <= bottom + 1)


def head(pdf_path, n, k=70):
    out = subprocess.run(["pdftotext", "-f", str(n + 1), "-l", str(n + 1), "-layout", pdf_path, "-"],
                         capture_output=True, text=True).stdout
    return re.sub(r"\s+", " ", out).strip()[:k]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("pdf")
    ap.add_argument("order")
    ap.add_argument("--samples", type=int, default=8)
    a = ap.parse_args()
    meta = json.load(open(a.order, encoding="utf-8"))
    G = meta["guide_pages"]
    pdf = pikepdf.open(a.pdf)
    idx = {p.objgen: i for i, p in enumerate(pdf.pages)}
    nt = pikepdf.NameTree(pdf.Root.Names.Dests)
    names = {str(k): nt[k] for k in nt.keys()}

    def target(an):
        d = an.Dest if "/Dest" in an else (an.A.get("/D") if "/A" in an and an.A.get("/S") == "/GoTo" else None)
        if d is None:
            return None
        if isinstance(d, pikepdf.Array):
            return idx.get(d[0].objgen, "BAD")
        v = names.get(str(d))
        if v is None:
            return "BAD"
        arr = v.D if isinstance(v, pikepdf.Dictionary) else v
        return idx.get(arr[0].objgen, "BAD")

    total = bad = uri = 0
    links = []
    for i, pg in enumerate(pdf.pages):
        for an in pg.obj.get("/Annots") or []:
            if an is None or an.get("/Subtype") != "/Link":
                continue
            t = target(an)
            if t is None:
                uri += 1
                continue
            total += 1
            if t == "BAD":
                bad += 1
            else:
                links.append((i, an, t))
    print(f"{len(pdf.pages)} pages: {total} internal links, {bad} with a bad target, {uri} external links")
    random.seed(7)
    print("\n-- sample of links in the guide (page: words under the link -> target page: start of its text)")
    guide_links = [l for l in links if l[0] < G]
    for i, an, t in random.sample(guide_links, min(a.samples, len(guide_links))):
        h = float(pdf.pages[i].MediaBox[3])
        print(f"p{i + 1}: [{under(a.pdf, i, an.Rect, h)[:50]}] -> p{t + 1}: {head(a.pdf, t)}")
    for p in random.sample(meta["papers"], min(3, len(meta["papers"]))):
        lo, hi = p["start"] - 1, p["start"] - 1 + p["pages"]
        inner = [l for l in links if lo <= l[0] < hi]
        print(f"\n-- paper {p['key']} (pages {lo + 1}-{hi}): {len(inner)} internal links; sample")
        for i, an, t in random.sample(inner, min(3, len(inner))):
            h = float(pdf.pages[i].MediaBox[3])
            ok = "ok" if lo <= t < hi else "OUTSIDE THE PAPER"
            print(f"p{i + 1}: [{under(a.pdf, i, an.Rect, h)[:40]}] -> p{t + 1} ({ok}): {head(a.pdf, t, 60)}")
    print("\n-- listing links: the page number in the listing jumps to the first page of the paper")
    bad_l = 0
    for i, an, t in links:
        if i < G and "/A" in an and str(an.A.get("/D", "")).startswith("paperpage:"):
            key = str(an.A.D)[len("paperpage:"):]
            want = next(p["start"] - 1 for p in meta["papers"] if p["key"] == key)
            if want != t:
                bad_l += 1
    print(f"  mismatches: {bad_l}")
    print("\n-- bookmarks")
    with pdf.open_outline() as o:
        for it in list(o.root)[:12]:
            print("  ", it.title[:60], f"({len(it.children)} children)")
    print("\n-- page labels (first of each range)")
    pl = pikepdf.NumberTree(pdf.Root.PageLabels)
    for k in list(sorted(pl.keys()))[:6]:
        print("  ", int(k) + 1, {str(kk): str(vv) for kk, vv in pl[k].items()})
    if bad or bad_l:
        raise SystemExit(f"FAIL: {bad} links with a bad target, {bad_l} listing links to the wrong page")
    print("\nverify_volume: all internal links have valid targets")


if __name__ == "__main__":
    main()
