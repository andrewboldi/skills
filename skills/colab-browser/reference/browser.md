# The browser route

Use a browser when the CLI can't do the job: a notebook the user wants to see or edit, a Google Drive
mount, or a Colab feature the CLI lacks. The agent drives a dedicated browser that the user has signed in
to, over the DevTools protocol. The gates and standing permissions in SKILL.md apply here too.

The notebook carries the same safety as a CLI job: it saves its results and releases its runtime on its own
(`<skill dir>/reference/notebook.md`). Watching and stopping are in `<skill dir>/reference/monitoring.md`.

## Steps

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
   - **Expect more consent screens.** On a fresh runtime, mounting Drive can open a Google
     sign-in window after the "Connect to Google Drive" dialog. It can show two screens in turn,
     each with Continue and Cancel: "You're signing back in to Google Drive for desktop", then
     "Google Drive for desktop wants access to your Google Account". The mount waits for both.
   - **If nobody answers.** After about 2 minutes `drive.mount` fails with `ValueError: mount
     failed`, and the runtime stays attached with nothing running until it is stopped. Mount with
     `drive.mount('/content/drive', timeout_ms=600000)` when a person may have to click.
   - **So:** have the user ready to click, or a `drive-desktop-oauth` grant to use; `consent`
     clicks through both screens. If the mount failed, stop the runtime.
   - **Don't reload the notebook tab while a mount waits,** and close sign-in windows left from
     a failed mount (`colab.cjs popups --close`) before you run it again.
5. **Watch.** Run `node <skill dir>/scripts/colab.cjs watch --only NOTEBOOK[,NOTEBOOK...]` in the
   background. Name your notebooks: the browser may also hold other projects' notebooks, and the
   watch stops only the tabs it manages.
   - It exits with one event line: IDLE_STOPPED, STOP_FAILED, QUIET_RUNNING, RUNTIME_LOST, or
     IDLE_UNMANAGED for another tab's idle runtime. Tell the user about that one; don't stop it.
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
   used against the estimate. Then close the notebook's tab, and any Drive page you opened. An
   open Colab or Drive page keeps growing, to gigabytes over a day, and that memory is taken from
   everything else on the machine, other agents' work included. The notebook stays on Drive, so
   reopen it when you need it again.

## Browser traps

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
| Leaving the tab open after the job | An idle Colab or Drive page keeps growing, to gigabytes over a day, taking memory from everything else on the machine | Once `status` says "no runtime" and the results are copied, close the tab |
| Nobody answers the Drive-for-desktop sign-in window | `drive.mount` fails after about 2 minutes and the runtime idles | Be ready to click, or use a standing grant; stop the runtime if the mount failed |
