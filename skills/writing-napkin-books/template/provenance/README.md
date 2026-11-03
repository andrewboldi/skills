# Provenance: where the book's claims come from

Everything here is text (no paper PDFs); to check a claim, open the source itself. Reports are kept as written,
so they also record what was wrong in the first drafts.

## Reading notes (`notes/`)

Written by reading agents from the full texts of the sources, before the chapters were drafted, following
`briefs/notes_brief.md`: verbatim quotes of at most 25 words with page locators, and `NOT STATED` where the source
is silent. Use them to find a passage, then confirm it in the source.

| File | Covers |
|---|---|
| | |

## Writers' reports (`writers/`)

One per chapter, following section 12 of `briefs/writers_guide.md`: files and page count, the log of recomputed
numbers, proposed glossary entries, cross-references wanted elsewhere, `NEED REF` lines, flagged claims for the
fact-checker, known layout issues.

## Independent fact-checks (`factcheck/`)

Each block was checked by a separate reader that was told to treat the text as unverified and to use primary
sources only (`briefs/factcheck_brief.md`). After each report the fixes were applied and logged in
`factcheck/<block>_applied.md` (APPLIED, ALREADY FIXED or DECLINED with a reason).

| File | Scope | Headline |
|---|---|---|
| | | |

## Other checks

* The epigraph: how its wording and attribution were checked.
* The combined PDF: `tools/verify_volume.py` output.

## Limits

* The checks compare the book with what the sources say. They do not reproduce any experiment.
* Web pages, leaderboards and repositories change; every such source is dated in the text or the bibliography.
* Where sources contradict each other (abstract versus table, one version versus another), the text says which one
  it follows.
