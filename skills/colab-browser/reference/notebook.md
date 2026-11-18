# The notebook contract

A Colab notebook that runs unattended has these parts. The cells below are one complete example
for a training job: adapt the paths, the command and the deadline. Keep the shape.

## 0. Getting code and data to Drive

- **Transfer.** Use `rclone` if the user has a Drive remote set up; setting one up is the user's
  consent act. Otherwise ask the user to upload the files in Drive's web page.
- **Packing.** Pack many small files into one tar: Drive is slow per file.
- **Checks on the runtime.** Compare the size or checksum of each tar, and check `df -h /content`
  has room for it unpacked.

## 1. Setup cell

```python
import json, os, shutil, subprocess, threading, time
from google.colab import drive, runtime

drive.mount('/content/drive')      # the user approves the Drive dialog the first time
RUN = 'run-001'                    # one folder per run on Drive, named in the agent's notes
OUT = f'/content/drive/MyDrive/colab_runs/{RUN}'
os.makedirs(OUT, exist_ok=True)

print(subprocess.run(['nvidia-smi', '--query-gpu=name,memory.total,driver_version',
                      '--format=csv,noheader'], capture_output=True, text=True).stdout, flush=True)

# Code and data travel as tar files on Drive and are unpacked to local disk.
# Never train from the Drive mount: its file reads are slow.
subprocess.run('tar -xf /content/drive/MyDrive/colab_runs/code.tar -C /content/ && '
               'tar -xf /content/drive/MyDrive/colab_runs/data.tar -C /content/', shell=True, check=True)
```

**Secrets.** Read a token with `from google.colab import userdata;
os.environ['HF_TOKEN'] = userdata.get('HF_TOKEN')`, and never print it. The user adds the secret
in Colab's Secrets panel and allows the notebook to read it.

## 2. Job cell: stream, heartbeat, deadline, finalize, release

```python
MAX_HOURS = 3.5                            # well under Colab's session limit; longer jobs resume in a new runtime
t0 = time.time()

def gpu():
    q = subprocess.run(['nvidia-smi', '--query-gpu=utilization.gpu,memory.used,memory.total',
                        '--format=csv,noheader,nounits'], capture_output=True, text=True).stdout
    util, used, total = [x.strip() for x in q.split(',')]
    return f'gpu {util}% mem {int(used) // 1024}/{int(total) // 1024} GiB'

status = 'FAILED'
p = None
try:
    p = subprocess.Popen(['python', '-u', 'train.py', '--out', '/content/out', '--resume'],
                         cwd='/content/code', stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

    def heartbeat():                       # proves the job is alive, and shows GPU use, every 2 min
        while p.poll() is None:
            print(f'[heartbeat] {(time.time() - t0) / 3600:.2f} h, {gpu()}', flush=True)
            if time.time() - t0 > MAX_HOURS * 3600:
                print('[deadline] stopping the job', flush=True)
                p.terminate()
            time.sleep(120)
    threading.Thread(target=heartbeat, daemon=True).start()

    for line in p.stdout:                  # the job's own output, streamed into the cell
        print(line, end='', flush=True)
    p.wait()
    status = 'DONE' if p.returncode == 0 else f'FAILED rc={p.returncode}'
except KeyboardInterrupt:              # Runtime > Interrupt execution, or colab.cjs stop
    status = 'INTERRUPTED'
finally:
    try:
        if p is not None and p.poll() is None:
            p.terminate()
        if os.path.isdir('/content/out'):  # results, even after a failure
            shutil.copytree('/content/out', f'{OUT}/out', dirs_exist_ok=True)
        with open(f'{OUT}/{status.split()[0]}', 'w') as f:
            f.write(status)
        print(f'[final] {status}; results in {OUT}', flush=True)
        drive.flush_and_unmount()          # make sure Drive has every file
    finally:
        runtime.unassign()                 # stop the billing even if saving failed; nobody may be watching
```

- **Streaming.** A child started with `subprocess.run(..., shell=True)` writes past the cell, so its
  output is invisible in the notebook. Stream it as above, or use `!python -u train.py`.
- **Interrupting.** An interrupt (Runtime > Interrupt execution) raises `KeyboardInterrupt` in the
  loop. That runs the `finally` block and releases the runtime.

## 3. Inside the job

- **Checkpoints.** Write them to local disk every N steps, then copy each one to Drive under a
  temporary name and rename it, so a copy is never half-written. At start, resume from the newest
  one. A disconnect then costs at most N steps.
- **Phase lines.** Print a line when each phase starts (loading data, building the model, each
  epoch), so a long data load isn't mistaken for a hang.
- **Finished results.** Copy each one to Drive as soon as it exists (one file per epoch, eval or
  dataset part), not only at the end.
- **Fit the GPU at start.**
  - Try the largest batch first. Keep the first that peaks under about 85% of GPU memory
    (`torch.cuda.max_memory_allocated()`).
  - Turn gradient checkpointing off whenever the batch fits without it: it costs about 30% speed.
  - When a comparison needs the same batch on every run, keep the batch fixed and still drop
    gradient checkpointing where memory allows.
- **Watch GPU utilisation.** If it stays under about 70% while memory is free, the data loader is
  the bottleneck. Set the workers to the CPU count, pre-decode or pre-crop the data onto local
  disk, or decode video on the GPU.
- **Several jobs in one runtime.** Pass the whole job list at launch and exit when it is done.
  Don't poll a Drive file for new jobs: Colab's Drive mount caches files, so edits made elsewhere
  may never appear. Run small jobs, such as evaluations, two or three at a time until GPU
  utilisation is about 85%.

## 4. Rendering on a GPU runtime (MuJoCo, OpenGL, EGL)

Colab's image ships only Mesa's EGL, so `MUJOCO_GL=egl` silently renders on the CPU. Install
NVIDIA's GL libraries for the runtime's driver, then check that one frame takes milliseconds,
not seconds:

```python
drv = subprocess.run(['nvidia-smi', '--query-gpu=driver_version', '--format=csv,noheader'],
                     capture_output=True, text=True).stdout.split('.')[0]
subprocess.run(f'apt-get -qq install -y libnvidia-gl-{drv}', shell=True, check=True)
os.environ['MUJOCO_GL'] = 'egl'
```
