---
name: colab-browser
description: Use when work should run on Google Colab (GPU training, evaluation, data generation, or anything too big for the local machine) and the agent drives Colab through a real browser the user signs in to. Also use when checking on, debugging or stopping Colab notebooks and runtimes, or when compute units are being spent.
---

# Google Colab through a signed-in browser

Colab has no API for starting runtimes, so the agent drives a real browser that the user has
signed in to. The user signs in and gives consent; the agent does everything else.

An attached runtime spends compute units whether or not anything runs, and the agent may be busy
or gone when a job ends. So every notebook finishes, saves its results and releases its runtime
on its own.

`<skill dir>` is the folder this SKILL.md is in.

## The user's acts: ask, then wait

- Signing in to Google, account choosers, 2-step verification.
- Consent dialogs: "Connect to Google Drive", notebook access to Colab secrets, OAuth screens.
  Click one yourself only when the user has said to, for that dialog.
- Accepting the licence of a gated model or dataset, such as Hugging Face's "Agree and access
  repository". The token in Colab's secrets must belong to the account that accepted.
- The unit budget. Get a yes before the pilot, which takes minutes but still spends units, and
  again for the run, with the estimate from step 2. Ask again before going past it.

## Process

1. **Browser.** Run `bash <skill dir>/scripts/setup.sh` once, then
   `bash <skill dir>/scripts/launch-browser.sh`. That reuses a running instance, or starts one
   with its own profile and the DevTools port. If Colab shows "Sign in", ask the user to sign in
   in that window; the profile keeps the session.
2. **Pilot and estimate.** Smoke-test the code locally first (a few steps), so the pilot isn't
   spent on bugs. Then do a short run on the GPU you were given. Measure seconds per step,
   peak GPU memory and GPU utilisation, and size the job to that GPU
   (`<skill dir>/reference/notebook.md`).
   - Units are hours × the usage rate shown in Colab's Resources panel.
   - Choose the GPU that costs the fewest units for the whole job, which is not always the one
     with the lowest rate.
3. **Notebook.** Build it to the contract in `<skill dir>/reference/notebook.md`:
   - data copied to local disk;
   - output streamed into the cell;
   - a heartbeat line every 2 minutes, with GPU utilisation, and a line at the start of each
     phase (loading data, each epoch);
   - checkpoints and finished results on Drive as they appear;
   - a deadline;
   - `finally`: write a DONE or FAILED marker, flush Drive, `runtime.unassign()`.
4. **Launch.** Open the notebook in the browser, set the runtime type and run it. Handle any
   dialog as the gates say. Don't attach a runtime before it has work: it bills while it waits.
5. **Watch.** Run `node <skill dir>/scripts/colab.cjs watch` in the background.
   - It exits with one event line: IDLE_STOPPED, STOP_FAILED, QUIET_RUNNING or RUNTIME_LOST.
   - Act on the event, then start the watch again. Keep doing this while any runtime is attached.
   - Between events, `node <skill dir>/scripts/colab.cjs status` and `... outputs TAB` show
     progress.
   - Detail is in `<skill dir>/reference/monitoring.md`.
6. **Quiet is not idle.** Before stopping a cell that is running, check the job's own evidence:
   - fresh heartbeat lines;
   - GPU utilisation;
   - its log and checkpoints;
   - a DONE or FAILED marker.

   Then stop it with `node <skill dir>/scripts/colab.cjs stop TAB`, and confirm with `status`
   that the runtime is gone.
7. **Finish.** Confirm the runtime has been released, copy the results down, and report the units
   used against the estimate.

## Traps

Each of these has wasted real units.

| Trap | What happens | Do instead |
|---|---|---|
| A long job started with `subprocess.run(...)` in a cell | The child's output goes to the runtime's log, not the cell, so a live job looks dead | `Popen` with `print(line, flush=True)`, or `!python -u ...` |
| Judging progress from Drive files on the local machine | Files the runtime writes reach Drive minutes late, often about 10 | Read the cell output in the browser; treat Drive as lagging |
| A runtime polling a Drive file for new jobs | Colab's Drive mount caches files, so outside edits may never appear and the runtime sits idle | Give the job list at launch; exit when it is empty |
| Settings sized for a different GPU | A big GPU runs at a fraction of its capacity | Size at start, and print GPU utilisation in the heartbeat |
| Results collected by the agent after the job | The agent's session ends, the runtime is recycled, and the results are lost | Copy results to Drive as they finish; finalize in `finally` |
| Training straight from the Drive mount | Slow file reads starve the GPU | Copy data to `/content` first |
| OpenGL or EGL rendering on a GPU runtime | Colab's image renders on the CPU (Mesa) | Install NVIDIA's GL libraries matching the driver (notebook.md) |
| Closing the tab to stop a job | The runtime keeps billing | `colab.cjs stop TAB`, then check that `status` says "no runtime" |

## Red flags

Stop and re-check when:
- You are about to click a consent, licence or "Allow" button.
- You are about to stop a running cell because it looks silent.
- `status` shows a runtime CONNECTED with nothing running.
- A run is starting without a unit estimate the user agreed to.
