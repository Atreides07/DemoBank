#!/usr/bin/env python3
"""Record only scoped device/performance metadata, never all properties/logcat."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
from datetime import datetime, timezone

parser = argparse.ArgumentParser()
parser.add_argument('device')
parser.add_argument('--output', default='.artifacts/performance/device.json')
parser.add_argument('--adb', default=os.environ.get('DEMO_ADB', 'adb'))
args = parser.parse_args()

def shell(*command):
    return subprocess.check_output([args.adb, '-s', args.device, 'shell', *command], text=True).strip()

def prop(name):
    return shell('getprop', name)

mem = shell('cat', '/proc/meminfo')
display = shell('dumpsys', 'display')
battery = shell('dumpsys', 'battery')
rate = re.search(r'mActiveRenderFrameRate=([\d.]+)', display)
fields = {}
for key in ['level', 'temperature', 'status', 'AC powered', 'USB powered']:
    match = re.search(r'^\s*' + re.escape(key) + r':\s*(.+)$', battery, re.M)
    if match:
        fields[key] = match.group(1)
report = {
    'recordedAtUtc': datetime.now(timezone.utc).isoformat(),
    'deviceSerial': args.device,
    'manufacturer': prop('ro.product.manufacturer'),
    'model': prop('ro.product.model'),
    'android': prop('ro.build.version.release'),
    'sdk': prop('ro.build.version.sdk'),
    'platform': prop('ro.board.platform'),
    'abi': prop('ro.product.cpu.abi'),
    'buildFingerprint': prop('ro.build.fingerprint'),
    'qemu': prop('ro.kernel.qemu'),
    'screen': shell('wm', 'size'),
    'density': shell('wm', 'density'),
    'activeRefreshHz': float(rate.group(1)) if rate else None,
    'memTotalKiB': int(re.search(r'MemTotal:\s*(\d+)', mem).group(1)),
    'battery': fields,
}
path = Path(args.output)
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({k: report[k] for k in ['model', 'android', 'platform', 'activeRefreshHz', 'memTotalKiB', 'qemu']}, ensure_ascii=False))
