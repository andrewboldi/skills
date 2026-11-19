# Runs one job inside a Colab kernel, started from the laptop with
#   colab exec -s NAME --timeout 0 --env JOB_CMD='python -u train.py' [--env ...] -f colab_job.py
# The cell keeps running if the exec client dies, so the job never depends on the agent being there.
#
# Settings, as --env NAME=VALUE (the client adds them to os.environ before this runs):
#   JOB_CMD      the shell command to run (required)
#   JOB_CWD      folder to run it in (default /content)
#   JOB_DIR      where the job's record goes (default /content/job): log.txt, heartbeat, STATUS, and the
#                COLLECTED file the agent creates once it has downloaded the results
#   MAX_HOURS    deadline; the job is stopped after this (default 3.5)
#   GRACE_MIN    after the job ends, wait this long for COLLECTED, then release the runtime anyway (default 20)
#   KEEP_RUNTIME set to 1 to skip the release (only while someone is working in the session by hand)
import os, subprocess, threading, time

cmd = os.environ['JOB_CMD']
cwd = os.environ.get('JOB_CWD', '/content')
jd = os.environ.get('JOB_DIR', '/content/job')
max_h = float(os.environ.get('MAX_HOURS', '3.5'))
grace = float(os.environ.get('GRACE_MIN', '20'))
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


t0 = time.time()
status = 'FAILED'
p = None
put('STATUS', 'RUNNING')
log = open(f'{jd}/log.txt', 'a', buffering=1)
try:
    p = subprocess.Popen(cmd, shell=True, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

    def heartbeat():                       # proves the job is alive, and shows GPU use, every 2 min
        while p.poll() is None:
            line = f'[heartbeat] {(time.time() - t0) / 3600:.2f} h, {gpu()}'
            put('heartbeat', line + '\n')
            print(line, flush=True)
            log.write(line + '\n')
            if time.time() - t0 > max_h * 3600:
                print('[deadline] stopping the job', flush=True)
                p.terminate()
            time.sleep(120)
    threading.Thread(target=heartbeat, daemon=True).start()

    for line in p.stdout:                  # the job's output, into the log and the cell
        log.write(line)
        print(line, end='', flush=True)
    p.wait()
    status = 'DONE' if p.returncode == 0 else f'FAILED rc={p.returncode}'
except KeyboardInterrupt:                  # colab restart-kernel, or an interrupt
    status = 'INTERRUPTED'
except Exception as e:                     # the job could not start, e.g. a missing folder
    log.write(f'[error] {e!r}\n')
    raise
finally:
    try:
        if p is not None and p.poll() is None:
            p.terminate()
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
