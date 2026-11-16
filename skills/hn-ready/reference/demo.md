# Demo GIF

A real recording of the tool doing its one trick, 20–30 s long. Never use a mock-up. Aim for
about 110×32 characters: that renders around 1000×700 px and under 300 KB, shown at width 820.

The recording is also an end-to-end test. Recording a demo has caught real bugs that the unit
tests missed.

## Story

Three beats: the setup, the event the tool handles, and the payoff.
- Explain the event with a typed comment, e.g. `kill %1     # the dev server dies`.
- Use a small throwaway project with realistic contents, e.g. `~/acme-api` with a 15-line
  `server.js`, and real tools in it (an editor, a dev server, an agent).

## Tools

- asciinema: `uv tool install asciinema`.
- agg: download the release binary from github.com/asciinema/agg into `~/.local/bin`.
- ffmpeg and ImageMagick, to check the frames.

## Recipe

1. **Isolate.** The demo gets its own folder (`DEMO=~/NAME-launch/demo`), its own config, and a
   minimal shell prompt through its own `ZDOTDIR`, e.g. `PROMPT='%F{blue}%~%f %F{green}❯%f '`.
   Run any tool that shows the user's account or settings from a clean profile. Nothing personal
   may show.
2. **Stage the scene** before recording: start what the viewer will see and get it into the
   state the demo needs.
3. **Write a driver script** that types like a person, ends on the payoff, and holds that frame:
   ```bash
   #!/usr/bin/env bash
   DEMO=~/NAME-launch/demo
   export ZDOTDIR=$DEMO/zdot
   prompt() { printf '\e[34m~/acme-api\e[0m \e[32m❯\e[0m '; }
   say() { local s=$1 i; for ((i = 0; i < ${#s}; i++)); do printf '%s' "${s:i:1}"; sleep 0.04; done; sleep 0.6; echo; }
   clear; prompt; sleep 0.8; say "the command"; the command
   ```
4. **If the demo uses tmux**, it must never reach the user's own tmux server. Agents often run
   inside it, with `TMUX` set.
   - Give the demo its own socket folder, `$DEMO/tmux`. Keep it short: a socket's full path,
     `$DEMO/tmux/tmux-UID/default`, must stay under about 100 characters. Deep scratch folders
     fail with "File name too long".
   - The driver starts with these lines, so every tmux command it types or runs, even
     `tmux kill-server`, reaches only the demo's server:
     ```bash
     export TMUX_TMPDIR=$DEMO/tmux
     unset TMUX TMUX_PANE
     mkdir -p "$TMUX_TMPDIR"
     ```
   - While staging, define this in every shell call and use `T` instead of `tmux`:
     `T() { env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$DEMO/tmux" tmux "$@"; }`
   - To end a full-screen program on cue, run a timer in the background, e.g.
     `(sleep 5; tmux detach-client) &`.
   - Never clear `TMUX=` before running plugin scripts: that also reaches the user's server.
5. **Record** at a fixed size. This works without a terminal:
   `env -u TMUX -u TMUX_PANE TERM=xterm-256color asciinema rec --overwrite -q --cols 110 --rows 32 -c 'bash driver.sh' demo.cast`
6. **Trim** anything after the payoff, if the driver didn't end cleanly. The cast is JSON lines:
   a header, then `[time, "o", text]` events. Drop events after a given time or marker with a
   few lines of Python.
7. **Render:** `agg --idle-time-limit 1.5 --font-size 15 --theme monokai --last-frame-duration 4 demo.cast demo.gif`
   Add `--speed 2` or more when the real thing takes longer than 30 s.
8. **Look at it.** Run `bash <skill dir>/scripts/contact-sheet.sh demo.gif sheet.png 2` and Read
   each sheet. Check each frame:
   - The payoff is visible and the text is readable.
   - Nothing personal shows: no account names, no notices from the user's own settings, no
     unrelated paths, no username in a path.

   Read single frames at full size where the sheet is too small.
9. **Clean up.**
   - Stop the demo's processes (`T kill-server` for a tmux demo), and the rest by pid.
   - Trash the throwaway project and what tools left about it, e.g. an agent's per-project
     session folder.
   - Find leftover processes by working directory (`readlink /proc/PID/cwd`). Never use
     `pgrep -f` or `pkill -f` with a pattern that's also in your own command line: it matches
     your own shell.
10. **Keep** the driver, config and cast in `$DEMO`, outside the repo, so the demo can be
    re-recorded.

In the README, put `<img src="assets/demo.gif" alt="ONE SENTENCE THAT TELLS THE STORY"
width="820">` right under the pitch. After the push, check that
`https://raw.githubusercontent.com/OWNER/REPO/main/assets/demo.gif` returns 200.

For a tool that isn't a terminal program, record the screen instead. The story and the
frame-by-frame check stay the same.
