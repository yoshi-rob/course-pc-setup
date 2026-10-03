#!/usr/bin/env python3
"""Run a command from the project root, recording the command and merged output."""
import datetime
import pathlib
import shlex
import subprocess
import sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
(ROOT / 'logs').mkdir(exist_ok=True)
pointer = ROOT / 'logs/current-log-path'
if not pointer.exists():
    pointer.write_text(str(ROOT / 'logs' / ('setup-' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S') + '.log')) + '\n')
log_path = pathlib.Path(pointer.read_text().strip())
if len(sys.argv) < 2:
    raise SystemExit('Usage: run_logged.py COMMAND [ARG ...]')
with log_path.open('a', buffering=1) as log:
    header = '\n[{}] $ {}\n'.format(datetime.datetime.now(datetime.timezone.utc).isoformat(), shlex.join(sys.argv[1:]))
    log.write(header)
    print(header, end='', flush=True)
    process = subprocess.Popen(sys.argv[1:], cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors='replace', bufsize=1)
    for line in process.stdout:
        log.write(line)
        print(line, end='', flush=True)
    status = process.wait()
    log.write('[exit {}]\n'.format(status))
    print('[exit {}]'.format(status), flush=True)
sys.exit(status)
