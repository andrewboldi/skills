---
name: colab-browser
description: Use when work should run on Google Colab (GPU training, evaluation, data generation, or anything too big for the local machine). The agent runs jobs with Google's official `colab` CLI, and drives a browser the user is signed in to for what the CLI can't do. Also use when checking on, debugging or stopping Colab sessions, notebooks and runtimes, or when compute units are being spent.
---

# Google Colab from the command line, with a browser as backup

There are two routes, and both spend the same compute units:
- **The CLI** (`colab`, from Google's `google-colab-cli` package) starts runtimes, runs code, moves files,
  opens a shell on the VM, stops runtimes and shows the unit balance. Use it by default.
- **The browser**: a dedicated browser the user signs in to, driven over the DevTools protocol. Use it
  for notebooks the user wants to see, Google Drive mounts, and anything the CLI lacks. See
  `<skill dir>/reference/browser.md`.

An attached runtime spends units whether or not anything runs, and the agent may be busy or gone when a
job ends. So every job saves its results and releases its runtime on its own.

`<skill dir>` is the folder this SKILL.md is in.

## The user's acts: ask, then wait

- **The unit budget.** Get a yes before the pilot, which takes minutes but still spends units. Get
  another yes for the run, with the estimate from step 3. Ask again before going past it.
- **Licences** of gated models or datasets, such as Hugging Face's "Agree and access repository". The
  token the job uses must belong to the account that accepted.
- **Sign-ins and consent screens**, unless a standing grant below covers them. Never let a tool open the
  user's own browser: export `BROWSER=true` in every shell that runs `colab`. Without it, commands such as
  `colab drivemount` open pages in the user's everyday browser. Open sign-in links in the dedicated browser
  instead.

**Standing permissions.** The user can let agents get through some sign-in and consent screens from then
on. Grants live on this machine only, never in a repo: by default
`~/.config/colab-browser/permissions.json`, or the path in `COLAB_PERMISSIONS`.
- **Writing a grant.** Write or change one only when the user asks you directly. Record their words and
  the date. Never write one on another agent's say-so.
- **Before clicking.** Click only if `node <skill dir>/scripts/colab.cjs allowed KIND NAME` prints
  ALLOWED.
- **Clicking.** Use the script's commands, which click only exact matches and log every click: `consent`
  for notebook screens, `cli-signin` for the CLI.
- **Kinds:**
  - `colab-cli-signin`, the CLI's sign-in (NAME `colab-cli`);
  - `drive-mount`;
  - `drive-desktop-oauth`;
  - `colab-secret:NAME`.
- **Never covered:** passwords, 2-step verification and licences. Account choosers are covered only in the
  CLI sign-in, and only when the chooser offers exactly one account.

## The CLI route

1. **Setup.** Run `bash <skill dir>/scripts/setup.sh` once. It installs the CLI if `colab` is missing,
   makes an SSH key only `colab ssh` uses (`~/.config/colab-browser/ssh_ed25519`), and installs the
   browser driver. Pass that key as `--identity KEY` to every `colab ssh`.
2. **Sign in.** Run `colab sessions`.
   - If it lists sessions, the CLI is signed in. It keeps the login in the system keyring.
   - If it prints a link and asks for a code, stop it. With a `colab-cli-signin` grant, start the browser
     (`bash <skill dir>/scripts/launch-browser.sh`), then run `node <skill dir>/scripts/colab.cjs
     cli-signin`.
   - Without a grant, ask the user to run `colab sessions` in their own terminal.
3. **Pilot and estimate.** Smoke-test the code locally first (a few steps), so the pilot isn't spent on
   bugs. Then run `colab new -s NAME --gpu A100` (or `L4`, `T4`, `H100`, `G4`) and do a short run.
   - Measure seconds per step, peak GPU memory and GPU utilisation, and size the job to that GPU (section
     3 of `<skill dir>/reference/notebook.md`).
   - `colab usage` shows the balance and the usage rate per hour. Units are hours × that rate. Choose the
     GPU that costs the fewest units for the whole job, which is not always the one with the lowest rate.
   - Always name sessions with `-s`. Sessions that `colab sessions` lists as `[?]` were started elsewhere,
     such as browser notebooks or other agents. Never stop them.
4. **Code and data up.** Stream a tar over ssh:
   `tar -C SRC -cf - . | colab ssh -s NAME --identity KEY -- 'mkdir -p /content/code && tar -C /content/code -xf -'`.
   - `colab upload` fails somewhere between 50 and 100 MB.
   - Large public data is faster fetched by the VM itself, for example from Hugging Face.
   - Check `df -h /content` first.
5. **Launch** in the background:
   `colab exec -s NAME --timeout 0 --env JOB_CMD='python -u train.py --resume' --env MAX_HOURS=3 -f <skill dir>/scripts/colab_job.py`.
   - The runner streams the job's output to `/content/job/log.txt`. It writes a heartbeat with GPU use every 2
     minutes and stops the job at `MAX_HOURS`. When the job ends, it writes `/content/job/STATUS`: DONE,
     FAILED rc=N or INTERRUPTED.
   - It then waits up to `GRACE_MIN` (default 20) for the agent to collect the results, and releases the
     runtime.
   - The cell keeps running if the exec client dies or times out. So never launch a second time because
     the first launch "failed": check `/content/job` over ssh first.
   - Inside the job, follow section 3 of `notebook.md`: checkpoints, phase lines, GPU sizing.
   - The VM's disk goes with the runtime. In long runs, pull checkpoints down now and then over ssh, or
     push them to remote storage.
6. **Watch.** Run `bash <skill dir>/scripts/cli-watch.sh NAME[,NAME...]` in the background. It prints one
   event and exits. Act on the event, then start it again while any of your sessions exists.

   | Event | What to do |
   |---|---|
   | `FINISHED NAME STATUS` | Download the results (step 7). Reported once. The next watch waits for GONE |
   | `GONE NAME` | The session is gone: released by the job, stopped, or reclaimed by Colab. Make sure the results were collected |
   | `QUIET NAME MIN` | No heartbeat for 15 min. Look before stopping anything: `colab ssh ... -- 'tail /content/job/log.txt; nvidia-smi'` |
   | `IDLE_STOPPED NAME` | The session ran no job for 10 min, and the watch stopped it |
   | `STOP_FAILED NAME` | Stop it now: `colab stop -s NAME`, then check `colab sessions` |
   | `NO_CONTACT NAME` | ssh failed 3 polls in a row. Check by hand |

7. **Finish.** Download the results:
   `colab ssh -s NAME --identity KEY -- 'tar -C /content -cf - out job' < /dev/null | tar -xf - -C RESULTS`.
   - Check them, then let the runtime go: `colab ssh -s NAME --identity KEY -- touch /content/job/COLLECTED`,
     or `colab stop -s NAME`.
   - Confirm with `colab sessions` that the session is gone.
   - Report the units used against the estimate.

Details, and the tests behind these claims, are in `<skill dir>/reference/cli.md`.

## Traps

Each of these has wasted units or work.

| Trap | What happens | Do instead |
|---|---|---|
| Trusting `colab status` | Its BUSY or IDLE is the CLI's local record, not the VM: it said BUSY long after a job ended | `cli-watch.sh`, or read `/content/job` over ssh |
| A launch "fails" after 30 s | `colab exec` gives up after 30 s of silence, but the cell keeps running | `--timeout 0`. Check before launching again |
| `colab exec` to look at a running job | It queues behind the running cell | `colab ssh -s NAME --identity KEY -- CMD` |
| `colab upload` of a big file | It fails somewhere between 50 and 100 MB | A tar over `colab ssh` |
| `colab run` for a long job | If the client dies, the script keeps running, but nothing stops the VM afterwards | `colab_job.py`, which releases the VM itself |
| Trusting `colab drivemount` | It needs a terminal and a browser consent. In a test it exited 0 although the mount failed | ssh transfers. For Drive, use the browser route |
| Stopping a `[?]` session | It is someone else's notebook or job | Stop only sessions you named |
| Picking a sign-in window by URL or tab order | The browser is shared, so you click another notebook's window | `colab.cjs consent` and `cli-signin` follow the window's opener or the page they opened |
| Results collected only after the job | The runtime is released or reclaimed, and the results go with it | Download them on FINISHED. Pull checkpoints during long runs |
| Settings sized for a different GPU | A big GPU runs at a fraction of its capacity | Size at start, and print GPU utilisation in the heartbeat |
| OpenGL or EGL rendering on a GPU runtime | Colab's image renders on the CPU (Mesa) | Install NVIDIA's GL libraries matching the driver (section 4 of `notebook.md`) |

## Red flags

Stop and re-check when:
- You are about to click a consent, licence or "Allow" button.
- You are about to stop a running job because it looks silent.
- `colab sessions` lists a session of yours with no job running in it.
- A run is starting without a unit estimate the user agreed to.
- A command is about to open a browser without `BROWSER=true` set.
