"""Print the Crossref record of each DOI (title, authors, venue, volume, pages, date, type, publisher), to check a
bibliography entry before it goes into refs_manual.bib.

usage: python3 -I tools/crossref.py DOI [DOI ...]
"""
import json, sys, time, urllib.request
for doi in sys.argv[1:]:
    url = "https://api.crossref.org/works/" + doi
    req = urllib.request.Request(url, headers={"User-Agent": "study-book-tools/0.1 (personal research)"})
    try:
        d = json.load(urllib.request.urlopen(req, timeout=40))["message"]
    except Exception as e:
        print("DOI %s -> FAILED %s\n" % (doi, e)); continue
    au = d.get("author", [])
    names = ["%s %s" % (a.get("given", ""), a.get("family", a.get("name", ""))) for a in au]
    issued = d.get("issued", {}).get("date-parts", [[None]])[0]
    print("DOI  :", doi)
    print("TITLE:", " ".join(d.get("title", ["?"])))
    print("AUTH :", "; ".join(names[:8]), ("... (%d total)" % len(names)) if len(names) > 8 else "")
    print("WHERE:", " / ".join(d.get("container-title", [])) , "| vol", d.get("volume"), "| issue", d.get("issue"), "| art/page", d.get("article-number") or d.get("page"), "| issued", issued)
    print("TYPE :", d.get("type"), "| publisher:", d.get("publisher"))
    print()
    time.sleep(1.2)
