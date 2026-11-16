#!/usr/bin/env python3
"""submit-link.py URL "TITLE"

Prints Hacker News's submit link with the URL and title filled in: the user opens it and
presses submit. Checks that the title starts with "Show HN: " and fits HN's 80 characters.
"""
import sys
import urllib.parse

if len(sys.argv) != 3:
    sys.exit(__doc__.strip())
url, title = sys.argv[1], sys.argv[2].strip()

problems = []
if not title.startswith("Show HN: "):
    problems.append('the title should start with "Show HN: "')
if len(title) > 80:
    problems.append(f"the title is {len(title)} characters; HN allows 80")
if not url.startswith(("https://", "http://")):
    problems.append("the URL should start with https://")
for p in problems:
    print("problem:", p, file=sys.stderr)

print(f"{len(title)} characters: {title}")
query = urllib.parse.urlencode({"u": url, "t": title}, quote_via=urllib.parse.quote)
print("https://news.ycombinator.com/submitlink?" + query)
sys.exit(1 if problems else 0)
