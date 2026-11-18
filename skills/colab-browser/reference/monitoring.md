# Watching, checking and stopping Colab runs

## Reading the browser

- **`node <skill dir>/scripts/colab.cjs status`** prints one line per Colab tab: `RUNNING`,
  `CONNECTED, nothing running` (that one is spending units for nothing), or `no runtime`, and the
  last line the notebook printed.
- **`node <skill dir>/scripts/colab.cjs outputs TAB [CHARS]`** prints the tail of a tab's output.
  Plain text output sits in the page; rich output sits in iframes. The script reads both. TAB is
  part of the tab title, such as the notebook's file name, and must match exactly one tab.
- **Screenshots.** To see something the scripts don't show, take a screenshot of the tab over the
  same DevTools connection and look at it: a dialog, an error banner, the Resources panel.
- **The Resources panel** (click the RAM/Disk meter) shows the units left, the current usage rate
  per hour and the number of active sessions. Take a screenshot to read the numbers, then close
  it.

## The watch loop

`node <skill dir>/scripts/colab.cjs watch` polls every Colab tab every 2 minutes. It exits with
exactly one line, so run it in the background and you get one notification per event:

| Event | Meaning | What to do |
|---|---|---|
| `IDLE_STOPPED` | A runtime was attached with no cell running for over 10 min; the watch stopped it | Find out why the notebook didn't release it, and fix that cell |
| `STOP_FAILED` | Stopping that idle runtime didn't work | Stop it now, by hand or by asking the user: Runtime > Disconnect and delete runtime |
| `QUIET_RUNNING` | A cell has run for 15 min with no new output | Check the evidence below before doing anything |
| `RUNTIME_LOST` | A runtime that was running a cell disconnected | Colab reclaimed it or it crashed. Check the DONE or FAILED marker and the last checkpoint, then resume or report |

Flags: `--idle-min`, `--quiet-min`, `--poll-s`.
- Raise `--quiet-min` only for a job that prints less often. A job that prints nothing for long
  stretches breaks the contract; fix the job instead.
- Start the watch again after every event, for as long as any runtime is attached.
- It only stops runtimes that run nothing. A quiet running cell is reported, never stopped.
- If you're working cell by cell and pause for more than 10 minutes between cells, the watch stops the runtime. That is the point: an attached runtime bills while you think. Pass a larger `--idle-min` only while the user is actively working in the notebook with you.

## Evidence before stopping a quiet cell

A silent cell is usually one of these: a child process whose output doesn't reach the cell, a long
step that prints nothing, or a job that has hung. Look at these, cheapest first:

1. **The cell's heartbeat lines.** Fresh ones mean it's alive, and they carry GPU utilisation.
2. **The GPU.** Colab's Terminal (a button in the notebook's bottom-left toolbar on paid plans)
   opens a shell on the runtime that works while a cell runs: `nvidia-smi`, `ps aux`, and `tail`
   of the local log. A fresh heartbeat with 0% GPU right after a 'loading data' phase line is a
   load, not a hang. The Resources panel shows GPU memory, but flat memory fits both a working and a hung
   job.
3. **The job's own files on Drive:** its log, the newest checkpoint, a DONE or FAILED marker.
   Drive shows them late: compare two reads at least 10 minutes apart before calling a file
   stale.

Stop the cell only when the evidence says hung or done. If you're not sure and the user is around,
ask. A wrong stop throws away the work so far.

## Stopping

Run `node <skill dir>/scripts/colab.cjs stop TAB`.
1. It interrupts the running cell first, so the notebook's `finally` saves results and releases
   the runtime itself.
2. If the runtime is still attached after that, it chooses "Disconnect and delete runtime".
3. It then checks that the runtime is gone. It exits non-zero if it isn't: ask the user to choose
   Runtime > Disconnect and delete runtime.

Closing the tab doesn't stop the billing.

## When your session may end

The notebook carries on without you, so the record has to as well. Write down where the next agent
or session will look: the notebook's URL, the Drive run folder, the budget, the expected end time
and what DONE means. Put it in the project's tracker or notes. A watch loop dies with the session,
and the notebook's own deadline and `finally` are what still protect the units.
