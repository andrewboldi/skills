# Demo GIF

A real recording of the tool doing its one trick, 20–30 s long. Never use a mock-up. The
tmux-restore GIF ran 25 s at 110×32, came to 1011×693 px and 270 KB, and is shown at width 820.

The recording is also an end-to-end test. tmux-restore's caught a real bug: a dev server that
renamed its process came back as garbage.

## Story

Three beats: the setup, the event the tool handles, and the payoff.
- Explain the event with a typed comment, e.g. `tmux kill-server     # to tmux, the same as a
  reboot`. That line ran inside a driver whose first lines isolate tmux (step 3), so it only
  killed the demo's server.
- Use a small throwaway project with realistic contents, e.g. `~/acme-api` with a 15-line
  `server.js`, and real tools in it (a real agent conversation, vim, a dev server).

## Tools

- asciinema: `uv tool install asciinema`.
- agg: download the release binary from github.com/asciinema/agg into `~/.local/bin`.
- ffmpeg and ImageMagick, to check the frames.

## Recipe

1. **Isolate.** The demo gets its own folder (`DEMO=~/NAME-launch/demo`), its own config, and a
   minimal shell prompt through its own `ZDOTDIR`, e.g. `PROMPT='%F{blue}%~%f %F{green}❯%f '`.
   Nothing personal may show.

   **If the demo uses tmux:** the user's live tmux server must never see a command. Your shell
   calls run inside it, with `TMUX` set.
   - Give the demo its own socket folder, `$DEMO/tmux`. Keep it short: a socket's full path,
     `$DEMO/tmux/tmux-UID/default`, must stay under about 100 characters. Deep scratch folders
     fail with "File name too long".
   - Send every tmux command there: through `T` below while staging, and through the driver's
     first lines while recording.
   - Never clear `TMUX=` before running plugin scripts. That also reaches the live server.
2. **Stage the scene** before recording: start what the viewer will see and get it into the
   state the demo needs. Define this in every shell call that touches tmux, and use `T`
   instead of `tmux`:
   ```bash
   T() { env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$DEMO/tmux" tmux "$@"; }
   ```
3. **Write a driver script** that types like a person, ends on the payoff, and holds that frame.
   A driver that runs any tmux command must start with the isolation lines. Then the commands
   it types and runs, like `tmux kill-server`, reach only the demo's server:
   ```bash
   #!/usr/bin/env bash
   DEMO=~/NAME-launch/demo
   export TMUX_TMPDIR=$DEMO/tmux ZDOTDIR=$DEMO/zdot   # tmux here = the demo's server only
   unset TMUX TMUX_PANE
   mkdir -p "$TMUX_TMPDIR"
   prompt() { printf '\e[34m~/acme-api\e[0m \e[32m❯\e[0m '; }
   say() { local s=$1 i; for ((i = 0; i < ${#s}; i++)); do printf '%s' "${s:i:1}"; sleep 0.04; done; sleep 0.6; echo; }
   clear; prompt; sleep 0.8; say "the command"; the command
   ```
   To end a full-screen program on cue, run a timer in the background, e.g.
   `(sleep 5; tmux detach-client) &`.
4. **Record** at a fixed size. This works without a terminal:
   `env -u TMUX -u TMUX_PANE TERM=xterm-256color asciinema rec --overwrite -q --cols 110 --rows 32 -c 'bash driver.sh' demo.cast`
5. **Trim** anything after the payoff, if the driver didn't end cleanly. The cast is JSON lines:
   a header, then `[time, "o", text]` events. Drop events after a given time or marker with a
   few lines of Python.
6. **Render:** `agg --idle-time-limit 1.5 --font-size 15 --theme monokai --last-frame-duration 4 demo.cast demo.gif`
7. **Look at it.** Run `bash ~/.claude/skills/hn-ready/scripts/contact-sheet.sh demo.gif sheet.png 2`
   and Read each sheet. Check each frame:
   - The payoff is visible and the text is readable.
   - Nothing personal shows: no account names, no notices from the user's own settings, no
     unrelated paths.

   Read single frames at full size where the sheet is too small.
8. **Clean up.**
   - Stop the demo's processes: `T kill-server`, and the rest by pid.
   - Trash the throwaway project and what tools left about it, e.g. Claude Code's
     `~/.claude/projects/-home-USER-acme-api`.
   - Find leftover processes by working directory (`readlink /proc/PID/cwd`). Never use
     `pgrep -f` or `pkill -f` with a pattern that's also in your own command line: it matches
     your own shell.
9. **Keep** the driver, config and cast in `$DEMO`, outside the repo, so the demo can be
   re-recorded.

In the README, put `<img src="assets/demo.gif" alt="ONE SENTENCE THAT TELLS THE STORY"
width="820">` right under the pitch. After the push, check that
`https://raw.githubusercontent.com/OWNER/REPO/main/assets/demo.gif` returns 200.

For a tool that isn't a terminal program, record the screen instead. The story and the
frame-by-frame check stay the same.
