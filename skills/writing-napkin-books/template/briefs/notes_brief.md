# Reading notes for <book title>: reader's brief

[Compiler: list the sources at the end (5-10 per reader) and give each reader this file.]

You read the full text of the sources listed below and write quote-backed notes that the chapter writers will build
on and the fact-checkers will use to find passages. You do not write chapter text.

## Method

* Use the PDF in `papers/` (`<key>_<arxiv id>.pdf`, downloaded by `tools/fetch_papers.py`; `manifest.tsv` says which
  version) or download the latest arXiv version into a new, empty directory. Extract text with `pdftotext -layout`
  and search with `python3 -I tools/pdfgrep.py KEY REGEX`. Look at key tables and figures on rendered pages
  (`pdftoppm -r 110 -f N -l N`), because text extraction scrambles tables.
* Quotes are verbatim, at most 25 words each, with a page locator (the PDF page of the version you read; say which
  version).
* Write NOT STATED when you searched the text and found nothing. Never fill a gap from memory.
* Where a source contradicts itself (abstract versus table, text versus figure, one version versus another), quote
  both.

## For each source

1. Bibliographic data, verified: title, authors, arXiv id and version, v1 date (arXiv API), venue with the evidence
   (arXiv comment or journal-ref, proceedings page, Crossref), project or code page.
2. Problem and setting.
3. Method in about five lines, with the key design choices.
4. Data and experimental setup: what, how much, how many trials or seeds.
5. Headline results with numbers, each with a quote and page, and the baselines they are compared with.
6. Limitations: the authors' own (quoted), then what you see.
7. What later work builds on it, only where a paper says so (give the source).
8. A proposed tier (A essential, B important, C context) with one line of reasoning, and a one-sentence "read it
   for".

## Output

`provenance/notes/<file>.md`, one section per source in the order given, with a first line stating the method and
the date. Commit only that file with a path-limited commit (`git add -- '<path>'`, `git commit -m "..." -- '<path>'`;
never delete files, never commit anything else, never push). Final message: the sources covered, anything you could
not get, and the five facts most likely to be misstated by a writer.

## Sources

| key | arXiv id or URL | why it is on the list |
|---|---|---|
