#!/usr/bin/env python3
"""Join the book and the cited arXiv papers into one PDF with pdfunite, then repair what pdfunite loses.

usage: python3 -I tools/build_volume.py --guide build/main.pdf --order build/papers_order.json \
           --papers-dir papers --out Book_with_papers.pdf [--limit N]

(normally run by tools/build_volume.sh)

1. `pdfunite guide.pdf paper1.pdf paper2.pdf ...` writes the joined file.
2. pdfunite keeps only the pages and the first file's name tree, and the latter points at stale object numbers, so
   afterwards (with pikepdf) this script
     * rebuilds the named destinations of the guide, so every link in the guide works again, and adds
       paperpage:<key> for the first page of each paper (the page numbers in the listing link to these),
     * rewrites the internal links of each paper (citations, sections, equations) as explicit destinations,
       resolved against the original paper,
     * restores the guide's bookmarks and adds one bookmark per paper under "The Papers",
     * restores the guide's page labels (i, ii, ..., 1, 2, ...) and labels paper n's pages P<n>.1, P<n>.2, ...
3. saves the result and re-opens it to verify the page count, the outline and that no named link is left dangling.
"""
import argparse
import json
import os
import subprocess
import sys
import tempfile

import pikepdf
from pikepdf import Array, Dictionary, Name, String


def read_dests(pdf, index):
    """name -> (page index, remaining destination items) for every named destination of pdf."""
    out = {}
    root = pdf.Root
    entries = []
    if "/Names" in root and "/Dests" in root.Names:
        nt = pikepdf.NameTree(root.Names.Dests)
        entries += [(str(k), nt[k]) for k in nt.keys()]
    if "/Dests" in root:
        entries += [(str(k).lstrip("/"), root.Dests[k]) for k in root.Dests.keys()]
    for name, v in entries:
        arr = v.D if isinstance(v, pikepdf.Dictionary) and "/D" in v else v
        if isinstance(arr, pikepdf.Array) and len(arr) >= 1:
            pi = index.get(arr[0].objgen) if isinstance(arr[0], pikepdf.Object) and arr[0].is_indirect else None
            if pi is not None:
                out[name] = (pi, list(arr)[1:])
    return out


def link_target(annot, dests, index):
    """Resolve an internal link of the original PDF to (page index, tail), None if it is not an internal link."""
    d = None
    if "/Dest" in annot:
        d = annot.Dest
    elif "/A" in annot and annot.A.get("/S") == "/GoTo":
        d = annot.A.get("/D")
    if d is None:
        return None
    if isinstance(d, pikepdf.Array):
        try:
            pi = index.get(d[0].objgen)
        except Exception:
            return "dead"
        return (pi, list(d)[1:]) if pi is not None else "dead"
    name = str(d)
    return dests.get(name, "dead")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--guide", required=True)
    ap.add_argument("--order", required=True)
    ap.add_argument("--papers-dir", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--limit", type=int, default=0, help="use only the first N papers (for tests)")
    ap.add_argument("--raw", help="reuse this pdfunite output instead of running pdfunite (it is kept)")
    a = ap.parse_args()

    meta = json.load(open(a.order, encoding="utf-8"))
    papers = meta["papers"][:a.limit] if a.limit else meta["papers"]
    guide = pikepdf.open(a.guide)
    G = len(guide.pages)
    start = G + 1
    for p in papers:
        if not a.limit and p["start"] != start:
            sys.exit(f"listing says paper {p['key']} starts on page {p['start']}, but it would start on {start}: "
                     f"the guide has {G} pages, the listing was made for {meta['guide_pages']}")
        p["start"] = start
        start += p["pages"]
    files = [os.path.join(a.papers_dir, p["file"]) for p in papers]

    tmpdir = None
    if a.raw:
        raw = a.raw
    else:
        tmpdir = tempfile.mkdtemp(prefix="united_", dir=os.path.dirname(os.path.abspath(a.out)))
        raw = os.path.join(tmpdir, "united_raw.pdf")
        print(f"pdfunite: guide ({G} pages) + {len(files)} papers", flush=True)
        subprocess.run(["pdfunite", a.guide] + files + [raw], check=True)
    united = pikepdf.open(raw)
    assert len(united.pages) == start - 1, (len(united.pages), start - 1)

    # ---- the guide: named destinations ---------------------------------------------------------------
    gidx = {p.objgen: i for i, p in enumerate(guide.pages)}
    gdests = read_dests(guide, gidx)
    nt = pikepdf.NameTree.new(united)
    for name, (pi, tail) in gdests.items():
        nt[name] = Array([united.pages[pi].obj] + tail)
    for p in papers:
        nt[f"paperpage:{p['key']}"] = Array([united.pages[p["start"] - 1].obj, Name.Fit])
    united.Root.Names = united.make_indirect(Dictionary(Dests=nt.obj))
    print(f"named destinations: {len(gdests)} from the guide + {len(papers)} paper starts", flush=True)

    # ---- the papers: internal links -------------------------------------------------------------------
    fixed = dead = 0
    for n, p in enumerate(papers, 1):
        orig = pikepdf.open(os.path.join(a.papers_dir, p["file"]))
        oidx = {pg.objgen: i for i, pg in enumerate(orig.pages)}
        odests = read_dests(orig, oidx)
        base = p["start"] - 1
        for i, opage in enumerate(orig.pages):
            oan = opage.obj.get("/Annots")
            uan = united.pages[base + i].obj.get("/Annots")
            if oan is None or uan is None or len(oan) != len(uan):
                continue
            for oa, ua in zip(oan, uan):
                if oa is None or ua is None or oa.get("/Subtype") != "/Link":
                    continue
                t = link_target(oa, odests, oidx)
                if t is None:
                    continue
                if "/A" in ua:
                    del ua["/A"]
                if "/Dest" in ua:
                    del ua["/Dest"]
                if t == "dead":
                    dead += 1
                else:
                    ua.Dest = Array([united.pages[base + t[0]].obj] + t[1])
                    fixed += 1
        orig.close()
    print(f"links inside papers: {fixed} restored, {dead} had no target and were removed", flush=True)

    # ---- bookmarks ---------------------------------------------------------------------------------------
    def to_item(item):
        dest, page_idx, tail = item.destination, None, []
        if dest is None and item.action is not None and item.action.get("/S") == "/GoTo":
            dest = item.action.get("/D")
        if isinstance(dest, pikepdf.Array):
            page_idx = gidx.get(dest[0].objgen)
            tail = list(dest)[1:]
        elif dest is not None and str(dest) in gdests:
            page_idx, tail = gdests[str(dest)]
        if page_idx is None:
            page_idx, tail = 0, []
        kw = {}
        if len(tail) >= 3 and tail[0] == "/XYZ" and tail[2] is not None:
            kw = {"left": float(tail[1]) if tail[1] is not None else 0.0, "top": float(tail[2])}
            new = pikepdf.OutlineItem(str(item.title), page_idx, "XYZ", **kw)
        else:
            new = pikepdf.OutlineItem(str(item.title), page_idx, "Fit")
        new.children = [to_item(c) for c in item.children]
        new.is_closed = item.is_closed
        return new

    with guide.open_outline() as gout:
        top = [to_item(i) for i in gout.root]
    papers_item = None
    for it in top:
        if it.title.endswith("The Papers"):
            papers_item = it
    if papers_item is None:
        papers_item = pikepdf.OutlineItem("The Papers", G, "Fit")
        top.append(papers_item)
    groups = {}
    for n, p in enumerate(papers, 1):
        groups.setdefault(p["group"], []).append((n, p))
    gname = meta.get("group_names", {})
    for gid, rows in groups.items():
        gi = pikepdf.OutlineItem(f"{gid}  {gname.get(gid, '')}".strip(), rows[0][1]["start"] - 1, "Fit")
        gi.is_closed = True
        for n, p in rows:
            title = f"P{n}  {p.get('plain_title') or p['title']}"
            gi.children.append(pikepdf.OutlineItem(title[:200], p["start"] - 1, "Fit"))
        papers_item.children.append(gi)
    with united.open_outline() as uout:
        uout.root.clear()
        uout.root.extend(top)

    # ---- page labels --------------------------------------------------------------------------------------
    nums = []
    if "/PageLabels" in guide.Root:
        pl = pikepdf.NumberTree(guide.Root.PageLabels)
        for k in sorted(pl.keys()):
            v = pl[k]
            d = Dictionary({str(kk): vv for kk, vv in v.items()})
            nums += [int(k), d]
    for n, p in enumerate(papers, 1):
        nums += [p["start"] - 1, Dictionary(S=Name.D, P=String(f"P{n}."), St=1)]
    united.Root.PageLabels = united.make_indirect(Dictionary(Nums=Array(nums)))

    # ---- document info ---------------------------------------------------------------------------------------
    gi = guide.docinfo
    title = (str(gi["/Title"]) if "/Title" in gi else "Book") + ", with the papers"
    with united.open_metadata() as md:
        md["dc:title"] = title
    united.docinfo["/Title"] = title
    for k in ("/Author", "/Subject", "/Keywords"):
        if k in gi:
            united.docinfo[k] = str(gi[k])
    united.docinfo["/Creator"] = "LaTeX (pdfTeX, KOMA-Script, biblatex) with hyperref; joined with pdfunite"
    united.Root.PageMode = Name.UseOutlines

    print("saving ...", flush=True)
    united.save(a.out)
    united.close()
    if tmpdir:
        os.remove(raw)
        os.rmdir(tmpdir)

    # ---- verify -------------------------------------------------------------------------------------------------
    chk = pikepdf.open(a.out)
    assert len(chk.pages) == start - 1, "page count changed"
    cidx = {pg.objgen: i for i, pg in enumerate(chk.pages)}
    cd = read_dests(chk, cidx)
    missing = 0
    for i in range(G):
        an = chk.pages[i].obj.get("/Annots")
        for a_ in an or []:
            if a_.get("/Subtype") == "/Link" and "/A" in a_ and a_.A.get("/S") == "/GoTo" and not isinstance(a_.A.get("/D"), pikepdf.Array):
                if str(a_.A.D) not in cd:
                    missing += 1
    with chk.open_outline() as o:
        n_out = sum(1 for _ in o.root)
    print(f"verified: {len(chk.pages)} pages, {n_out} top-level bookmarks, {len(cd)} named destinations, "
          f"{missing} guide links without a destination", flush=True)
    if missing:
        sys.exit("some links in the guide have no destination")


if __name__ == "__main__":
    main()
