# After launch

## Read the feedback

- The HN thread: `curl -s https://hn.algolia.com/api/v1/items/ITEM_ID` returns the whole comment
  tree as JSON.
- The GitHub side: `gh issue list`, `gh pr list`, and the repo's traffic and stars.

## Turn it into proposals

Make a numbered list. For each item give who raised it (with a link), what they want, what it
would take, and your recommendation. Separate ideas that are new from questions the README or
docs already answer. The user picks ("do 1 through 5"). Do nothing they didn't pick.

## Do the picked items end to end

1. Write a test that would have caught the problem, then fix or build the item.
2. Commit with credit:
   - **A GitHub user:**
     `Co-authored-by: LOGIN <ID+LOGIN@users.noreply.github.com>`, with the ID from
     `gh api users/LOGIN -q .id`. Merged PR commits keep their author. Commits you add on top of
     a PR get the contributor as co-author.
   - **An HN commenter:** put "Suggested by NAME on Hacker News:" and the comment link
     (`https://news.ycombinator.com/item?id=…`) in the commit body. Don't make up an email.
   - **Someone who showed the problem without suggesting the fix:** "Found looking at … NAME
     shared on Hacker News:" and the link.
3. Push and wait for CI to go green. Re-run a job that failed on a flaky mirror.
4. If the user runs the tool, update their installed copy to the published version.

## Replies

- The user writes HN replies. Give them the facts: what's true, what changed, the commit link.
- Thank-you comments on merged PRs, and replies on issues, are outward actions. Ask first, then
  keep them short.

## Keep the README answering questions

When the same question shows up twice, restructure the README so it answers it, e.g. with a
section on what the tool adds to the incumbent, or with a note for people who already use the
incumbent. Don't add an FAQ heading.
