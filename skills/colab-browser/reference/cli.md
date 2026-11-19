# The Colab CLI: what was tested, and how it behaves

Tested with google-colab-cli 0.8.0 on CPU runtimes, which cost about 0.1 units an hour. `colab skill`
prints the CLI's own notes, and `colab COMMAND -h` the options. Where these notes and the CLI's notes
disagree, test on a CPU runtime before spending GPU units.

## Sign-in

- **The flow.** `colab sessions`, or any command, prints a Google link and waits for a code. It never
  opens a browser for this.
- **The screens** in a browser already signed in to Google:
  1. an account chooser, "to continue to Google Auth Library";
  2. "You're signing back in to Google Auth Library", with Continue;
  3. "Google Auth Library wants access to your Google Account", with Continue;
  4. a page on sdk.cloud.google.com that shows the code.
- **Where the login is kept.** The CLI stores it in the system keyring, so the sign-in is rare.
- **The automated sign-in.** `colab.cjs cli-signin` does all of this in the automation browser, under a
  `colab-cli-signin` grant.
  - It refuses any other screen, and leaves the page open for the user.
  - `--dry-run` reads the first screen and says what it would do.
- **Testing without signing out.** `PYTHON_KEYRING_BACKEND=keyring.backends.null.Keyring` makes the CLI
  ask again without touching the saved login. Point `COLAB_BIN` at a wrapper that sets it.
- **No browser.** `BROWSER=true` makes Python's `webbrowser` a no-op. The CLI then only prints links,
  which is what you want.

## Sessions

| Command | Behaviour seen |
|---|---|
| `colab new -s NAME [--gpu X]` | Ready in about 3 s on CPU. An unknown `--gpu` value falls back to A100 |
| `colab sessions` | Lists every assigned runtime of the account. Ones started outside this CLI show as `[?]` |
| `colab status -s NAME` | BUSY or IDLE comes from the CLI's local record. It said BUSY for 10 min after the job ended, because the client that started it was killed |
| `colab usage` | Balance, usage rate per hour, active assignments: the same numbers as the browser's Resources panel |
| `colab stop -s NAME` | Releases the runtime. `colab sessions` stops listing it within seconds |

## Running code

- **Kernel state.** `colab exec -s NAME -f FILE.py` sends the file to the session's kernel. Imports and
  variables persist between execs. Piped stdin works too.
- **Silence timeout.** `--timeout` is the silence allowed before the client gives up: 30 s by default,
  `0` for no limit. When it gives up, it exits 1, but the cell keeps running.
- **A killed client.** If the exec client is killed, the cell keeps running. In the test, it went on
  writing to a file for 3 more minutes, and finished.
- **A busy kernel.** An exec sent to a busy kernel waits behind the running cell. To look at a running
  job, use ssh.
- **Self-release.** `from google.colab import runtime; runtime.unassign()` inside the kernel releases the
  VM with no client attached. The session left `colab sessions` within a minute.
- **`colab run`.** It is `new` + `exec` + `stop` in one client. If that client dies, nothing runs the
  `stop`, and the VM stayed attached until `colab stop`.

## Files

| Way | Result |
|---|---|
| `colab upload` | About 2.3 MB/s; 10, 20 and 50 MB worked; 100 MB failed with HTTP 400 |
| `colab ssh ... -- 'cat > FILE' < FILE` | 100 MB in 26 s (about 4 MB/s up), checksum matched |
| `colab ssh ... -- 'cat FILE' > FILE` | 100 MB in 4 s (about 25 MB/s down), checksum matched |
| `colab download` | Fine for small files |

- `colab ssh` needs a key. Pass `--identity KEY`; setup.sh makes one.
- Give it `< /dev/null` unless you pipe data in.
- With one argument after `--`, the CLI runs it as a shell line.

## Drive

- **The flow.** `colab drivemount -s NAME` asks for a Drive consent in a browser, then reads Enter from
  the terminal (`/dev/tty`).
- **The test.** The consent link opened the "Google Drive for desktop" screens.
  - The first attempt then failed with "Error propagating: 400".
  - The second exited 0 with no output, yet the kernel had raised `ValueError: mount failed`.
- **So:**
  - Check a mount with `ls /content/drive/MyDrive`.
  - Prefer ssh transfers.
  - When a job needs Drive, run it as a notebook (`browser.md`).
- **Shared browser.** Never pick a sign-in window by URL or tab order. That test's helper script picked
  the newest Google sign-in window, which belonged to another notebook mounting Drive at the same moment.

## colab_job.py

| Setting (`--env`) | Default | Meaning |
|---|---|---|
| `JOB_CMD` | (required) | the shell command |
| `JOB_CWD` | `/content` | where it runs |
| `JOB_DIR` | `/content/job` | `log.txt`, `heartbeat`, `STATUS`, and `COLLECTED`, which the agent creates |
| `MAX_HOURS` | 3.5 | deadline; the job is terminated after it |
| `GRACE_MIN` | 20 | how long to wait for `COLLECTED` before releasing anyway |
| `KEEP_RUNTIME` | unset | 1 skips the release, only while someone works in the session by hand |

The runner always releases the runtime in a `finally`, even when the job can't start; the reason goes
in the log.

**Tested on a CPU runtime:**
- A job ran on after its launcher was killed.
- `cli-watch.sh` reported FINISHED once.
- Downloading over ssh and creating COLLECTED released the VM within 14 s.
- With nobody collecting and `GRACE_MIN=1`, the VM released itself about a minute after the job.
- A session with no job was stopped by the watch (IDLE_STOPPED).
- A job with no heartbeat was reported (QUIET).
