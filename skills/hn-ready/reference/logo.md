# Logo

Worked example: `~/tmux-restore/assets/logo.svg`. It's a terminal window with traffic-light
dots, tmux's green status bar and split panes, plus a counter-clockwise "restore" arrow around
clock hands.

## Make it

- Write the SVG by hand, with `viewBox="0 0 256 256"`, `role="img"` and `aria-label="NAME"`.
- Draw it from motifs of the tool's domain. Use flat shapes and 3–5 colors.
- Reuse one accent color in the ecosystem badge. tmux-restore's green `1bb91f` is in both.
- Give the logo its own dark body, so one file reads on GitHub's white and dark (`#0d1117`)
  themes alike, with no `<picture>` pair needed.
- Generate curves from numbers rather than eyeballing them. For an arc, pick the center C, the
  radius r and the start and end angles, compute the endpoints in a few lines of Python, and
  write the path from those.

## Check it

1. Run `bash ~/.claude/skills/hn-ready/scripts/render-logo.sh assets/logo.svg logo-check.png 132`, then Read the PNG. It
   shows a large render and the README's display size (132 px), each on white and on `#0d1117`.
2. Look at every shape that points somewhere. tmux-restore's arrowhead shipped pointing
   backwards and stayed that way for two weeks, until the user noticed.
   - An arrowhead's tip must lie along the arc's tangent at the end it sits on, in the
     direction of travel, with its base straddling the arc.
   - In SVG coordinates (y points down), at point P on a circle around C, with
     `(dx, dy) = P - C`, the tangent is:
     - `(dy, -dx)` for counter-clockwise on screen ("restore", "undo")
     - `(-dy, dx)` for clockwise
   - Compute the tip as `P + L·unit(tangent)` and check it in the zoomed render.
3. Check it at the display size: the main symbol must still read at 132 px.

When something is changed, put the before and after side by side and show the user.
