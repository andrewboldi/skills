# <Book title>: writer's guide

[Compiler: fill in every <...> and delete every [bracketed hint] before a writer sees this file. Writers read it
whole, then the exemplar chapter. Keep it next to the sources; it is the design document of the book.]

Tracking: <issue ids>. Build one chapter: `bash tools/build_chapter.sh chapters/<file>.tex --png` (section 11).
The finished exemplar is **<chapter>** (`chapters/<file>.tex`, `figures/<prefix>_*.tex`): read it before you write.

## 1. What this book is

<The user's request, quoted. What the book is for, its parts, and where the writers' chapters sit in it.>

## 2. The reader and the level

<What the reader already knows, and what they do not know.> When you need a fact from outside that, state it, give
the intuition, and show a number. Elementary means: no term is used before it is defined; every formula has a worked
example with numbers; every number has a unit; one concrete example beats a page of generalities.

Voice: second person, plain, friendly, concrete (see the exemplar). Short paragraphs. Explain *why* before *how*.
Use analogies and say where they break. Define each new term in italics (`\emph{term}`) at first use, with a
plain-language definition and its unit.

## 3. Chapter map

| No. | file (chapters/) | label | title | pages |
|---|---|---|---|---|
| <1> | <ch01_name> | <ch:name> | <Title> | <6-8> |

Labels you may `\cref` (forward references are fine: they resolve in the full build and print `??` in the
one-chapter build): every chapter label above, and <parts, sections, tables of other chapters that writers need>.
Do not guess other labels. **Your own labels:** `<type>:<chapter slug>-<name>` with type `sec`, `fig`, `tab`, `eq`
or `lst` (for example `fig:decay-rc`); unique in the book.

## 4. What each chapter covers

Every list is a minimum; cut anything that does not fit the page budget, and say in one sentence what you left out.

**<No. Title>.** <the topics in order; the worked examples, with the numbers to use; the figures wanted; one
"Build it" idea; the connection to the book's main topic.>

## 5. How a chapter is built

1. `\chapter{Title}` and `\label{ch:...}`; an opening paragraph of 100-150 words (why this matters to the reader);
   then "By the end you should be able to" with 3-5 `itemize` bullets.
2. 4 to 8 `\section`s, each with a `\label`, about 0.7-1.2 pages each. Use `\paragraph{Name.}` run-in headings for
   sub-ideas.
3. Boxes (they share one counter, so they print as "Example 3.2.1"). Never nest boxes.
   * `insightbox[title]`: Key idea (blue), the one to three formulas or facts to remember.
   * `workedbox[title]`: worked example with numbers (2-4 per chapter).
   * `buildbox[title]`: something to build, run or measure (1-2).
   * `cautionbox[title]`: safety rule or costly mistake (wherever a beginner could be hurt or break something).
   * `connectionbox[title]`: why the book's main topic cares, with `\cref` to later chapters (1-2).
   * `checkbox`: "Check yourself", three short questions with the answers in `\footnotesize` (one per chapter).
   * `readingbox[Further reading]` last: 2-4 books or papers, one sentence each on what to read them for.
   * Reading-guide chapters: `papercard` (arXiv papers) and `webcard` (other sources) with `\cl{Idea.}`,
     `\cl{Results.}`, `\cl{Why it matters.}`, `\cl{Limits.}`. Results are the authors' numbers, attributed to them
     ("the authors report ..."); say which table or version when sources disagree.
4. Floats: `figure` and `table` with `[tbp]`, input right after the paragraph that cites them.

## 6. Writing rules

* <American> English. `python3 -I tools/americanize.py .` must print `changed lines: 0` for your files.
* Units with siunitx: `\qty{330}{\ohm}`, `\qty{9.1}{\milli\ampere}`, `\unit{\volt}`; say once when a quantity is
  dimensionless. Round sensibly (2-3 significant figures); say "about" and use `\approx` for approximations; show
  the step that produces a rounded number.
* Notation, the same in every chapter: <symbol table>. Vectors and matrices bold.
* Spell out an abbreviation at first use. Do not use footnotes.
* **No prices**; say "inexpensive" or "costly". Do not state software versions, release dates, product
  specifications or "the standard tool is X" unless you verified it (official documentation or the papers) and say
  "as of <access date>". Prefer describing the idea over naming a product; when you name one, be certain it exists
  and is what you say.
* Typical values are labeled "typical" and given as ranges or round numbers you are sure about.
* Safety: be conservative. Never encourage bypassing protection; add a `cautionbox` wherever a beginner could be hurt.
* Honest scope: one sentence saying what the chapter leaves out and where to read more.
* No invented history or attributions: if you credit an idea to a person or paper, be certain, and cite it.

## 7. Figures

* Every figure is original. <4-7> per chapter, each in its own file `figures/<prefix>_name.tex` containing the whole
  `figure` float, `\input` right after the paragraph that cites it, with a caption that ends "Original drawing." and
  a label `fig:<slug>-...`.
* TikZ for diagrams, `pgfplots` with the `bookplot` style for graphs, `circuitikz` (style `ckt`) for schematics. A
  curve is computed from the formula the text uses, with the parameters of the worked example; never draw a curve by
  hand. Data from a script: save the script in `figures/src/` with its seed, and say so in the file's first comment.
* Palette (defined in the preamble): `navy`, `amber`, `teal`, `rose`, `slate`, `mist`, `sand`, `maroon`, `crimson`;
  `rose` for highlights, `slate` for secondary labels. Label fonts `\sffamily\scriptsize` (`\tiny` only for tick-like
  annotations). Width at most `\textwidth`, height at most about 7 cm.
* Pitfalls: a node with a line break needs `align=`; commas inside `\foreach` items need braces; labels collide
  easily, so place them with explicit anchors; `clip=false` for annotations outside a plot; do not rely on `scale=`
  to shrink text; circuitikz sources and batteries put + at the START of the path (add `invert` or reverse the path,
  and check that current arrows leave the + terminal).
* **Look at every figure.** Build with `--png`, open the PNGs, crop and enlarge (`pdftoppm -r 120 -f N -l N`,
  `convert ... -crop`). Fix overlaps, clipped text, labels over lines, unreadable sizes, arrows that point the wrong
  way.

## 8. Code

Keep each listing as a file in `figures/src/` and include it with `\lstinputlisting[language=Python]{...}`
(style `bookcode`, ASCII only, at most about 25 lines per listing). **Run every snippet**, save its output next to it
(`<name>.out`) and quote that output, so that anyone can rerun it and compare. Show only API calls you are certain of,
and point to the documentation for the rest. <What is installed here, and what is not.>

## 9. Numbers and accuracy

Recompute every number in a worked example with Python and list the checks in your report. A reader will re-derive
them; a wrong number costs more trust than a missing one. Check units and orders of magnitude. For any claim you are
not sure of, hedge ("typically", "often") or omit it, and list it under "flagged claims" so that the independent
fact-checker looks at it first. Separate readers will check this book against the sources, and every error they find
is recorded.

## 10. Citations

Use only keys that exist (`grep` `refs_auto.bib` and `refs_manual.bib` first). <Keys available, grouped: textbooks,
papers.> If you need another source, do not invent a key: write `NEED REF: <full bibliographic data you are sure of,
and URL>` in your report (a `% NEED REF` comment may mark the spot; `tools/check.sh` refuses a release while one
remains). The PDFs of the cited arXiv papers are in `papers/`; verify a claim about a paper with
`python3 -I tools/pdfgrep.py KEY REGEX [REGEX ...]` (`--list` shows the keys).

## 11. Build and check

```
bash tools/build_chapter.sh chapters/<file>.tex --png
```
It builds a test document (preamble, your chapter, its bibliography) in `build/chap/` and prints the page count,
errors, undefined citations, undefined references (fine when the label is in another chapter), overfull boxes and
float warnings; `--png` writes `build/chap/t_<file>-<page>.png`. Acceptance: exit status 0; no `UNDEFINED CITATIONS`;
`overfull hboxes wider than 1pt: 0`; no `Float too large`; at most <N> pages in the harness (the last page is the
bibliography); every figure looked at; every number recomputed; americanize reports no change in your files.

## 12. What you may touch, and what to report

**Save early and often:** write a complete first draft of the chapter file early and refine it in place; the session
can end without warning, and anything not on disk is lost.

Create and edit only `chapters/<your file>` and `figures/<your prefix>_*` (and `figures/src/<your prefix>_*`), plus
your report. Read anything. Do not edit `preamble.tex`, `kit.tex`, `bookmeta.tex`, `main.tex`, the bibliography
files or other chapters; if you need a macro, define it inside your own file with a unique name. Never delete files.
Use `nice`, run one build at a time, and do not start background jobs.

**Commit your work** after the first complete draft, after each round of fixes and when you finish, with a
path-limited commit from the repository root (quote the globs):
```
git add -- '<your paths>'
git commit -m "<chapter>: what changed" -m "<one or two lines>" -m "<attribution trailer>" -- '<your paths>'
```
If git reports `.git/index.lock`, another writer is committing: wait a few seconds and retry. Never use `git add -A`
or `git add .`, and never reset, checkout, restore, stash, rebase, amend or push; the compiler pushes.

**Report.** Save it as `provenance/writers/<chapter>.md`, commit it the same way, and make it your final message:
(a) files written, page count, list of figures; (b) the verification log of recomputed numbers; (c) 10-20 glossary
entries (`Term | one-line definition`) for the new terms; (d) cross-references you would like added in other
chapters; (e) `NEED REF` lines; (f) flagged claims for the fact-checker; (g) known layout issues; (h) commit hashes.
