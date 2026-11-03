# Independent fact-check of <book title>: reader's brief

[Compiler: fill in the <...> and the Blocks section, then give each checker this file and its block. Do not give a
checker your own conclusions about the text.]

You are an independent reader. The text you check was written by another session; treat it as unverified. Your job
is to find what is wrong, overstated, unsupported or unsafe, and to say what is right with evidence. You do not edit
the chapters.

## Evidence you may use

Primary or authoritative sources only: the papers themselves (the arXiv PDFs are in `papers/`; search them with
`python3 -I tools/pdfgrep.py KEY REGEX`, run from the book root), official documentation, standards and datasheets,
textbooks and lecture notes you can open, publisher, library and Crossref records (`python3 -I tools/crossref.py
DOI`), reputable encyclopedic sources for common facts. Derive or recompute formulas and numbers yourself (Python:
<what is installed>). The writers' reports and reading notes in `provenance/` list the claims each writer flagged and
the sources they used: use them to find claims, never as evidence. Record a URL or a verbatim snippet (with its page)
for every claim you call confirmed.

## What to check

1. Every formula (derive it or find it), every symbol and unit, and the sign conventions.
2. Every number in a worked example, a table or a figure: recompute it. Plots are computed from formulas: check that
   the plotted curves and marked points agree with the text.
3. Every "typical" value: is it right, and is "typical" fair?
4. Every statement about a paper, a product, a standard, a tool, a company or a person (what it is, what it does, who
   made it, when, how many): does the source say that? Mind "first", "standard", "most", "always", "state of the art".
5. Paper cards: the Idea matches the paper's method; the Results are the authors' numbers, attributed, from the right
   table and version; the Limits are fair; the tier is defensible.
6. Safety and practical advice: flag anything unsafe, too casual, in the wrong order, or missing an important caution
   for a beginner.
7. Code: run it; judge snippets you cannot run against the documentation.
8. Figures: render the pages (`pdftoppm -r 120 -f N -l N build/main.pdf out`) and look. Are directions of arrows,
   polarities, signs, axes and labels right, and consistent with the text?
9. Elementary-level quality: terms used before they are defined, jumps in the explanation, analogies that mislead.
   Report these briefly in a separate section; they matter less than errors.
10. The new bibliography entries of your block: authors, title, edition, publisher, year against a publisher, library
    or Crossref record.

## Categories

CONFIRMED (evidence given), WRONG (give the correction), OVERSTATED or MISLEADING (give a fairer wording),
UNSUPPORTED (could not verify; say what you tried), SAFETY, and STYLE.

## Output

Write one report, `provenance/factcheck/<block>.md`, in this order: scope (chapters and the commit hash read); method;
the non-confirmed items, most serious first, each with the chapter file and the nearby text, the problem, the
evidence, and a proposed corrected wording; a summary of the confirmed items (counts and the important ones); the
elementary-level findings; what you did not cover. Commit only that file with a path-limited commit from the
repository root:
```
git add -- 'provenance/factcheck/<block>.md'
git commit -m "Fact-check of <block>" -m "<attribution trailer>" -- 'provenance/factcheck/<block>.md'
```
If git reports `.git/index.lock`, wait a few seconds and retry. Never add or commit other files; never reset,
checkout, stash, rebase, amend or push. Never delete files. Do not run background jobs. Be economical with tokens:
read each chapter once, check the claims that carry risk first, and do not re-derive what is textbook-standard unless
a number looks off. Be polite to web servers (no bulk crawling). End with a short final message listing the counts
and the five most serious findings.

## Blocks

<Block letter>: <chapters and their files, figures included>; new references <keys>.
