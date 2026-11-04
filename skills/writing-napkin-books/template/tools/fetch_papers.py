#!/usr/bin/env python3
"""Download the PDF of every arXiv paper cited in the book.

usage: python3 -I fetch_papers.py <cited_keys.json> <outdir> [--delay 3]

cited_keys.json has {"arxiv": {bibkey: arxiv_id, ...}, "manual": [...]} (see tools/make_cited_keys.py).
Files are saved as <outdir>/<bibkey>_<arxivid>.pdf (latest arXiv version). The script is polite to arXiv:
one request at a time, a pause between requests, exponential back-off on HTTP 429/503, and it stops if
the disk is nearly full. A manifest (manifest.tsv: key, id, pages, bytes, status) is written next to the PDFs
and re-used on re-runs, so the script is safe to interrupt and restart.
"""
import json
import os
import shutil
import subprocess
import sys
import time

MIN_FREE_GB = 3.0
UA = "napkin-book-tools/0.1 (personal research)"


def pdf_pages(path):
    try:
        out = subprocess.run(["pdfinfo", path], capture_output=True, text=True, timeout=60).stdout
    except Exception:
        return 0
    for line in out.splitlines():
        if line.startswith("Pages:"):
            return int(line.split()[1])
    return 0


def main():
    cited = json.load(open(sys.argv[1], encoding="utf-8"))["arxiv"]
    outdir = sys.argv[2]
    delay = 3.0
    if "--delay" in sys.argv:
        delay = float(sys.argv[sys.argv.index("--delay") + 1])
    os.makedirs(outdir, exist_ok=True)
    manifest_path = os.path.join(outdir, "manifest.tsv")
    done = {}
    if os.path.exists(manifest_path):
        for line in open(manifest_path, encoding="utf-8"):
            f = line.rstrip("\n").split("\t")
            if len(f) >= 5 and f[4] == "ok":
                done[f[0]] = f
    rows = list(done.values())
    todo = [(k, i) for k, i in cited.items() if k not in done]
    print(f"{len(done)} already done, {len(todo)} to fetch", flush=True)
    for n, (key, aid) in enumerate(todo, 1):
        free = shutil.disk_usage(outdir).free / 2**30
        if free < MIN_FREE_GB:
            print(f"STOP: only {free:.1f} GB free", flush=True)
            break
        dest = os.path.join(outdir, f"{key}_{aid}.pdf")
        status = "fail"
        for attempt in range(7):
            tmp = dest + ".part"
            cmd = ["curl", "-sL", "-A", UA, "--max-time", "300", "--max-filesize", str(250 * 2**20),
                   "-o", tmp, "-w", "%{http_code}", f"https://arxiv.org/pdf/{aid}"]
            try:
                code = subprocess.run(cmd, capture_output=True, text=True, timeout=330).stdout.strip()
            except subprocess.TimeoutExpired:
                code = "timeout"
            ok_pdf = False
            if os.path.exists(tmp):
                with open(tmp, "rb") as fh:
                    ok_pdf = fh.read(5) == b"%PDF-"
            if code == "200" and ok_pdf and pdf_pages(tmp) > 0:
                os.replace(tmp, dest)
                status = "ok"
                break
            wait = 40 * (attempt + 1) if code in ("429", "503", "timeout") else 15 * (attempt + 1)
            print(f"  {key} {aid}: HTTP {code}, pdf={ok_pdf}; retry in {wait}s (attempt {attempt + 1})", flush=True)
            if os.path.exists(tmp):
                os.remove(tmp)
            time.sleep(wait)
        pages = pdf_pages(dest) if status == "ok" else 0
        size = os.path.getsize(dest) if status == "ok" else 0
        rows.append([key, aid, str(pages), str(size), status])
        print(f"[{n}/{len(todo)}] {key} {aid} {status} {pages}p {size / 2**20:.1f}MB", flush=True)
        with open(manifest_path, "w", encoding="utf-8") as fh:
            for r in rows:
                fh.write("\t".join(r) + "\n")
        time.sleep(delay)
    ok = sum(1 for r in rows if r[4] == "ok")
    print(f"finished: {ok} ok, {len(rows) - ok} failed; total pages {sum(int(r[2]) for r in rows)}", flush=True)


if __name__ == "__main__":
    main()
