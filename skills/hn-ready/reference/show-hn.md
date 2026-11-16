# Show HN kit

Write the kit to a file in a launch folder outside the repo, e.g. `~/NAME-launch/show-hn.md`.
The user does the posting.

## 1. Title

- Use the form `Show HN: Name verbs what [when]`, at most 80 characters (HN's limit). Keep it
  plain and descriptive, with no adjectives.
- Name the category, not one vendor.
- Go through a few versions with the user, e.g. "Show HN: Portwho shows which process is
  listening on a TCP port" (63 characters).

## 2. Submit link

Use `python3 <skill dir>/scripts/submit-link.py REPO_URL "TITLE"`. It checks the title and prints
`https://news.ycombinator.com/submitlink?u=…&t=…`. The link opens HN's form already filled in,
and the user presses submit.

## 3. First comment: talking points only

The user posts a short comment right after submitting, in their own words. A polished pasted
comment invites flags. Give them facts to choose from:
- Why it exists: the real pain, in a sentence or two.
- The non-obvious part of how it works.
- What it was tested on: platforms, containers, CI.
- Upstream bugs found along the way, and the PRs filed for them.
- The ask: which contributions would help, e.g. adapters for other tools.

## 4. Rules to pass on

- Anywhere else (Reddit, Discord, friends), share the GitHub link, never the HN link. Never ask
  for upvotes: HN's voting-ring detection buries the post.
- Plan to stay around for 2–3 hours after posting to answer comments.
- Before posting:
  - CI is green and the badges read "passing".
  - The install line works from the published URL.
  - The GIF and logo load on GitHub.
  - The user has run the published version through the real situation it's built for, so
    they can answer from experience.

## 5. When to post

Data: 72,954 Show HN posts from Oct 2024 to Oct 2026. The numbers below are a snapshot of that
window.
- Best: Sunday 09:00–11:00 Pacific, with about 6 competing posts an hour against 10–12 on
  weekday mornings.
- Then Monday 07:00–10:00, then Friday 09:00–12:00.
- Avoid weekdays 17:00–20:00 and 22:00–02:00.
- Election days showed no effect.
- Timing is worth only about half a percentage point. About 2.9% of Show HN posts reach 50
  points. The title, the first comment and answering replies matter more.

## 6. A slow start isn't the end

A post can sit at 1 point for hours and still make it. HN's second-chance pool re-ups some
posts days later: one went from 1 point to the front page three days after posting, and got 50
points, 35 comments and 60 stars in a day. Keep improving the repo in the meantime. When the thread wakes up, follow `reference/after-launch.md`.
