# Book sources

LaTeX sources of the book, typeset after Evan Chen's *An Infinitely Large Napkin*, and the tools that build it, check
it and (optionally) append the cited arXiv papers into one linked PDF.

| Output | What it is |
|---|---|
| `<BOOK_NAME>.pdf` | The book alone (`build/main.pdf`, copied by `tools/build_volume.sh`) |
| `<BOOK_NAME>_with_papers.pdf` | The book followed by the cited arXiv papers (large; not in git) |

## Build

```bash
latexmk -interaction=nonstopmode -halt-on-error main.tex     # output: build/main.pdf
bash tools/check.sh                                          # regression checks; exit 0 = release-ready
bash tools/build_chapter.sh chapters/<file>.tex --png       # one chapter, with page images
bash tools/contact_sheets.sh build/main.pdf build/qa         # every page, 12 to a sheet, for a visual pass
```

Needs TeX Live (`scrbook`, `lmodern`, `tcolorbox`, `tikz`, `pgfplots`, `siunitx`, `biblatex` with `biber`;
`circuitikz` optional), poppler-utils (`pdftotext`, `pdftoppm`, `pdfinfo`, `pdfunite`), ImageMagick (`montage`,
`convert`) and Python 3 with `pikepdf` for the combined PDF.

## Add papers and build the combined PDF

```bash
printf 'key\tarxiv_id\tA\tsection_code\tShort name\n' > /tmp/rows.tsv        # tier A/B/C; codes in tools/data/groups.tsv
python3 -I tools/add_arxiv.py /tmp/rows.tsv                                 # metadata from the arXiv API -> papers.tex, refs_auto.bib
latexmk -interaction=nonstopmode -halt-on-error main.tex                    # biber records what is cited
python3 -I tools/make_cited_keys.py . > tools/data/cited_keys.json
python3 -I tools/fetch_papers.py tools/data/cited_keys.json papers          # polite, resumable; check disk space first
bash tools/build_volume.sh                                                  # loops until the page count settles
python3 -I tools/verify_volume.py <BOOK_NAME>_with_papers.pdf build/papers_order.json
```

`pdfunite` alone drops the bookmarks and page labels, leaves the book's named destinations pointing at stale objects
and kills the links inside the papers; `tools/build_volume.py` repairs all of that with pikepdf.

## Layout

| Path | What it is |
|---|---|
| `bookmeta.tex` | Title, short title, date, version, PDF metadata, the name of the connection box |
| `preamble.tex`, `kit.tex` | The look (fonts, colors, headings, contents, running heads), paper cards, all boxes, units, plots, listings, lettered parts |
| `main.tex` | Parts and chapters, in order |
| `chapters/`, `figures/` | One file per chapter; one file per figure float (`figures/src/` holds the scripts that compute figure data) |
| `refs_manual.bib` | Hand-checked entries for sources that are not on arXiv |
| `papers.tex`, `refs_auto.bib` | **Generated** by `tools/build_meta.py` from `tools/data/` (never edit by hand) |
| `briefs/` | The writer's guide, the fact-check brief and the reading-notes brief given to agents |
| `provenance/` | The evidence: reading notes, writers' reports, fact-check reports and the log of applied fixes |
| `tools/` | Build, check, metadata and volume scripts; settings in `tools/book.env` |

## Conventions

* Numbers from papers are the authors', attributed to them, and were not reproduced.
* "The compiler" is the voice of the book's editorial judgments.
* Every web source is dated (access date in the bibliography, "as of" in the text).
