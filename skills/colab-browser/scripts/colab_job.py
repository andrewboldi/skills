# Runs one job inside a Colab kernel, started from the laptop with
#   colab exec -s NAME --timeout 0 --env JOB_CMD='python -u train.py' [--env ...] -f colab_job.py
# The cell keeps running if the exec client dies, so the job never depends on the agent being there.
#
# Settings, as --env NAME=VALUE (the client adds them to os.environ before this runs):
#   JOB_CMD      the shell command to run (required)
#   JOB_CWD      folder to run it in (default /content)
#   JOB_DIR      where the job's record goes (default /content/job): log.txt, heartbeat (rewritten by this
#                runner every HEARTBEAT_S), output (touched when the job itself prints), STATUS, and the
#                COLLECTED file the agent creates once it has downloaded the results
#   MAX_HOURS    deadline; the job is stopped after this (default 3.5)
#   GRACE_MIN    after the job ends, wait this long for COLLECTED, then release the runtime anyway (default 20)
#   KEEP_RUNTIME set to 1 to skip the release (only while someone is working in the session by hand)
#   HEARTBEAT_S  seconds between heartbeats (default 120)
import os, signal, subprocess, threading, time

cmd = os.environ['JOB_CMD']
cwd = os.environ.get('JOB_CWD', '/content')
jd = os.environ.get('JOB_DIR', '/content/job')
max_h = float(os.environ.get('MAX_HOURS', '3.5'))
grace = float(os.environ.get('GRACE_MIN', '20'))
beat = float(os.environ.get('HEARTBEAT_S', '120'))
os.makedirs(jd, exist_ok=True)
for f in ('COLLECTED', 'STATUS'):
    if os.path.exists(f'{jd}/{f}'):
        os.remove(f'{jd}/{f}')


def put(name, text):
    with open(f'{jd}/{name}.tmp', 'w') as f:
        f.write(text)
    os.replace(f'{jd}/{name}.tmp', f'{jd}/{name}')


def gpu():
    try:
        q = subprocess.run(['nvidia-smi', '--query-gpu=utilization.gpu,memory.used,memory.total',
                            '--format=csv,noheader,nounits'], capture_output=True, text=True, timeout=20).stdout
        util, used, total = [x.strip() for x in q.splitlines()[0].split(',')]
        return f'gpu {util}% mem {int(used) // 1024}/{int(total) // 1024} GiB'
    except Exception:
        return 'no gpu'


def kill_job(p):
    # The command runs in its own process group: signal all of it, so a pipeline or a `;` list can't
    # outlive the shell. SIGKILL whatever is left after 30 s.
    try:
        os.killpg(p.pid, signal.SIGTERM)
        p.wait(timeout=30)
    except subprocess.TimeoutExpired:
        os.killpg(p.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass


t0 = time.time()
deadline_hit = []
status = 'FAILED'
p = None
put('STATUS', 'RUNNING')
log = open(f'{jd}/log.txt', 'a', buffering=1)
try:
    p = subprocess.Popen(cmd, shell=True, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                         start_new_session=True)
    put('output', '')

    def heartbeat():                       # proves the runner is alive, and shows GPU use, every HEARTBEAT_S
        while p.poll() is None:
            line = f'[heartbeat] {(time.time() - t0) / 3600:.2f} h, {gpu()}'
            put('heartbeat', line + '\n')
            print(line, flush=True)
            log.write(line + '\n')
            if time.time() - t0 > max_h * 3600:
                print('[deadline] stopping the job', flush=True)
                log.write('[deadline] stopping the job\n')
                deadline_hit.append(True)
                kill_job(p)
                return
            time.sleep(beat)
    threading.Thread(target=heartbeat, daemon=True).start()

    last = 0
    for line in p.stdout:                  # the job's output, into the log and the cell
        log.write(line)
        print(line, end='', flush=True)
        if time.time() - last > 10:        # the watch reads this file's age to spot a job gone silent
            os.utime(f'{jd}/output')
            last = time.time()
    p.wait()
    status = ('DONE' if p.returncode == 0 else f'FAILED deadline {max_h:g} h' if deadline_hit
              else f'FAILED rc={p.returncode}')
except KeyboardInterrupt:                  # colab restart-kernel, or an interrupt
    status = 'INTERRUPTED'
except Exception as e:                     # the job could not start, e.g. a missing folder
    log.write(f'[error] {e!r}\n')
    raise
finally:
    try:
        if p is not None and p.poll() is None:
            kill_job(p)
        put('STATUS', status)
        print(f'[final] {status}', flush=True)
        log.write(f'[final] {status}\n')
        log.close()
        if os.environ.get('KEEP_RUNTIME') != '1':
            # The results are on the VM's disk: give the agent GRACE_MIN to download them and create COLLECTED.
            end = time.time() + grace * 60
            while time.time() < end and not os.path.exists(f'{jd}/COLLECTED'):
                time.sleep(15)
            print('[release] ' + ('results collected' if os.path.exists(f'{jd}/COLLECTED') else
                                  f'nobody collected the results in {grace:g} min'), flush=True)
    finally:
        if os.environ.get('KEEP_RUNTIME') != '1':
            from google.colab import runtime
            runtime.unassign()             # stop the billing even if the steps above failed
