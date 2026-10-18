#!/usr/bin/env python3
"""External OS measurements of the already-installed ordinary bank release.

Nothing runs on import. All adb/device/APK/output arguments are explicit; this
tool never installs an APK or changes device settings. The installed base APK
must match --apk. Run only when the bank app is foreground (Home tab for routes)
and the device is available. Output is a new startup.json or routes.json, including partial/failure
evidence. Existing reports are never overwritten.

Startup records three force-stopped COLD and three home/resume HOT launches via
ActivityManager. Routes records six cycles through the four navigation tabs.
--nav-y must come from the current device screenshot; x coordinates are the four
equal-width navigation centers on the current portrait display. For routes,
compile android_input_marker.c with the Android NDK clang for the device ABI and
pass that executable as --helper. No SDK/NDK paths are discovered or assumed.

Routes measure automated injection -> first new Flutter SurfaceView actual
presentation. The native CLOCK_MONOTONIC marker precedes exec input tap, so this
conservative bound includes input-tool startup and dispatch. It does not measure
a physical finger, semantic destination acceptance, a completed transition, or
network readiness. A complete report means valid samples, not a performance
budget verdict. No app instrumentation or Dart source changes are involved.
"""

from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import time
import uuid
from typing import Any


PACKAGE = "dev.demobank.bank_app"
ACTIVITY = PACKAGE + "/.MainActivity"
FENCE_PENDING = (1 << 63) - 1
ROUTES = (("Платежи", 1), ("Аналитика", 2), ("Профиль", 3), ("Главная", 0))
Frame = tuple[int, int, int]  # desiredPresent, actualPresent, frameReady, ns.


class MeasurementError(RuntimeError):
    """Missing or invalid evidence, never an implicitly successful sample."""


def finite_stamp(value: int) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and 0 < value < FENCE_PENDING


def valid_frame(frame: Frame) -> bool:
    return all(finite_stamp(value) for value in frame) and frame[2] <= frame[1]


def parse_surface_latency(raw: str) -> list[Frame]:
    """Retain unfinished slots too, so selection cannot skip a suspect first frame."""
    lines = [line.strip() for line in raw.splitlines() if line.strip()]
    if not lines or not lines[0].isdigit() or not finite_stamp(int(lines[0])):
        raise MeasurementError("SurfaceFlinger latency refresh period is missing/invalid")
    frames = []
    for line in lines[1:]:
        fields = line.split()
        if len(fields) != 3 or not all(re.fullmatch(r"-?[0-9]+", field) for field in fields):
            raise MeasurementError("Malformed SurfaceFlinger timestamp triple")
        frames.append(tuple(map(int, fields)))
    return frames


def latest_present(frames: list[Frame]) -> int:
    completed = [frame[1] for frame in frames if valid_frame(frame)]
    if not completed:
        raise MeasurementError("SurfaceFlinger contains no completed finite frame")
    return max(completed)


def verify_idle(before: list[Frame], quiet: list[Frame]) -> bool:
    return latest_present(before) == latest_present(quiet)


def select_first_response(quiet: list[Frame], after: list[Frame], marker: int) -> Frame:
    if not finite_stamp(marker):
        raise MeasurementError("Native monotonic input marker is missing/invalid")
    if latest_present(quiet) >= marker:
        raise MeasurementError("Pre-input snapshot does not precede the input marker")
    previous = set(quiet)
    candidates = [frame for frame in after if frame not in previous
                  and finite_stamp(frame[1]) and frame[1] >= marker]
    if not candidates:
        raise MeasurementError("No new actual presentation after the input marker")
    first = min(candidates, key=lambda frame: frame[1])
    if not valid_frame(first):
        raise MeasurementError("First new presentation has invalid/unfinished fences")
    if first[0] < marker or first[2] < marker:
        raise MeasurementError("First new presentation was already pending before input")
    return first


def parse_marker(raw: str) -> int:
    stamps = re.findall(r"^BEFORE_INJECT_NS=([0-9]+)\s*$", raw, re.MULTILINE)
    if len(stamps) != 1 or not finite_stamp(int(stamps[0])):
        raise MeasurementError("Exactly one finite native input marker is required")
    return int(stamps[0])


def own_surface_layers(raw: str) -> list[str]:
    layers = []
    for line in raw.splitlines():
        # Recent Android versions wrap names in RequestedLayerState. Passing the
        # entire wrapper to --latency silently yields an empty timestamp buffer.
        name = line.strip().removeprefix("RequestedLayerState{").split(" parentId=", 1)[0].rstrip("}")
        if name.startswith("SurfaceView[" + PACKAGE + "/") and name not in layers:
            layers.append(name)
    return layers


def parse_display_size(raw: str) -> tuple[int, int]:
    matches = re.findall(r"^(?:Physical|Override) size:\s*(\d+)x(\d+)\s*$", raw, re.MULTILINE)
    if not matches:
        raise MeasurementError("Current display size is missing")
    width, height = map(int, matches[-1])
    if width <= 0 or height <= width:
        raise MeasurementError("Routes require the current portrait display")
    return width, height


def parse_startup(raw: str, expected_state: str) -> dict[str, Any]:
    fields = {}
    for key in ("Status", "LaunchState", "TotalTime", "WaitTime", "ThisTime"):
        match = re.search(r"^" + key + r":\s*(\S+)\s*$", raw, re.MULTILINE)
        if match:
            fields[key] = match.group(1)
    if fields.get("Status") != "ok" or fields.get("LaunchState") != expected_state:
        raise MeasurementError("ActivityManager did not report the requested " + expected_state + " launch")
    for key in ("TotalTime", "WaitTime"):
        if not fields.get(key, "").isdigit():
            raise MeasurementError("ActivityManager " + key + " is missing/invalid")
        fields[key] = int(fields[key])
    if "ThisTime" in fields:
        if not fields["ThisTime"].isdigit():
            raise MeasurementError("ActivityManager ThisTime is invalid")
        fields["ThisTime"] = int(fields["ThisTime"])
    return fields


def parse_pss_kib(raw: str) -> int:
    match = re.search(r"\bTOTAL PSS:\s*([0-9]+)\b", raw)
    if not match or int(match[1]) <= 0:
        raise MeasurementError("Package meminfo TOTAL PSS is missing/invalid")
    return int(match[1])


def distribution(values: list[float]) -> dict[str, Any]:
    if not values or not all(math.isfinite(value) and value >= 0 for value in values):
        raise MeasurementError("Cannot summarize missing/invalid latency samples")
    ordered = sorted(values)
    return {"count": len(values), "min": ordered[0], "max": ordered[-1],
            **{name: ordered[math.floor((len(ordered) - 1) * quantile + .5)]
               for name, quantile in (("p50", .5), ("p95", .95), ("p99", .99))}}


def validate_complete(report: dict[str, Any]) -> dict[str, Any]:
    """Require every planned observation; missing samples cannot improve percentiles."""
    samples = report["samples"]
    if report["phase"] == "startup":
        expected = {(kind, iteration) for kind in ("force_stopped", "resume_from_home")
                    for iteration in range(1, 4)}
        actual = [(row["kind"], row["iteration"]) for row in samples]
        if len(actual) != 6 or set(actual) != expected:
            raise MeasurementError("Startup requires all three COLD and three HOT samples")
        for row in samples:
            parsed = parse_startup(row["raw"], "COLD" if row["kind"] == "force_stopped" else "HOT")
            if not row.get("valid") or any(row.get(key) != value for key, value in parsed.items()):
                raise MeasurementError("Startup sample fields do not match their raw evidence")
        return {kind: distribution([row["TotalTime"] for row in samples if row["kind"] == kind])
                for kind in ("force_stopped", "resume_from_home")}
    expected = Counter((cycle, label) for cycle in range(1, 7) for label, _ in ROUTES)
    if Counter((row["cycle"], row["route"]) for row in samples) != expected:
        raise MeasurementError("Routes require all 24 observations across six complete cycles")
    for row in samples:
        before = parse_surface_latency(row["beforeLatencyRaw"])
        quiet = parse_surface_latency(row["quietLatencyRaw"])
        after = parse_surface_latency(row["afterLatencyRaw"])
        stamp = parse_marker(row["inputMarkerRaw"])
        first = select_first_response(quiet, after, stamp)
        if (not row.get("valid") or not row.get("idleBeforeInputVerified")
                or not verify_idle(before, quiet) or stamp != row["preInjectionMonotonicNs"]
                or list(first) != row["selectedTripleNs"]
                or row["conservativeInputToPresentMs"] != (first[1] - stamp) / 1e6):
            raise MeasurementError("Route sample does not match its raw idle/frame evidence")
    if [row["stage"] for row in report["memory"]] != ["before-routes", *[f"cycle-{n}" for n in range(1, 7)]]:
        raise MeasurementError("All seven package PSS snapshots are required")
    return distribution([row["conservativeInputToPresentMs"] for row in samples])


class Adb:
    def __init__(self, executable: str, device: str):
        self.prefix = [executable, "-s", device]

    def run(self, *arguments: str) -> str:
        try:
            result = subprocess.run(self.prefix + list(arguments), capture_output=True,
                                    text=True, timeout=45, check=False)
        except (OSError, subprocess.TimeoutExpired) as error:
            raise MeasurementError("adb command could not complete: " + str(error)) from error
        if result.returncode:
            raise MeasurementError("adb command failed: " + result.stderr.strip() + " " + result.stdout.strip())
        return result.stdout

    def shell(self, *arguments: str) -> str:
        return self.run("shell", shlex.join(arguments))


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def save(path: Path, report: dict[str, Any]) -> None:
    temporary = path.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def verify_installed_apk(adb: Adb, expected_sha: str) -> dict[str, str]:
    raw = adb.shell("pm", "path", PACKAGE)
    paths = [line.removeprefix("package:").strip() for line in raw.splitlines() if line.startswith("package:")]
    if len(paths) != 1 or not paths[0].endswith("/base.apk"):
        raise MeasurementError("Expected the already-installed, single-base bank APK")
    digest_raw = adb.shell("sha256sum", paths[0])
    match = re.match(r"([a-fA-F0-9]{64})\s", digest_raw)
    if not match or match[1].lower() != expected_sha:
        raise MeasurementError("Installed bank APK does not match --apk; nothing was installed")
    return {"packagePathRaw": raw, "sha256Raw": digest_raw, "sha256": match[1].lower()}


def assert_foreground(adb: Adb) -> None:
    raw = adb.shell("dumpsys", "activity", "activities")
    if not any(re.search(r"(?:topResumedActivity|mResumedActivity)\s*[:=]", line)
               and PACKAGE + "/" in line for line in raw.splitlines()):
        raise MeasurementError("The bank app must be foreground before injecting navigation input")


def collect_startup(adb: Adb, report: dict[str, Any], report_path: Path) -> None:
    for kind in ("force_stopped", "resume_from_home"):
        for iteration in range(1, 4):
            row: dict[str, Any] = {"kind": kind, "iteration": iteration, "valid": False}
            report["samples"].append(row)
            if kind == "resume_from_home":
                adb.shell("input", "keyevent", "KEYCODE_HOME")
                time.sleep(.7)
            command = ["am", "start", "-W"] + (["-S"] if kind == "force_stopped" else [])
            row["raw"] = adb.shell(*command, "-n", ACTIVITY)
            save(report_path, report)
            row.update(parse_startup(row["raw"], "COLD" if kind == "force_stopped" else "HOT"))
            row["valid"] = True
            save(report_path, report)
            print(json.dumps({key: value for key, value in row.items() if key != "raw"}), flush=True)
            time.sleep(2.5)


def collect_routes(adb: Adb, report: dict[str, Any], report_path: Path,
                   helper: Path, nav_y: int) -> None:
    display_raw = adb.shell("wm", "size")
    width, height = parse_display_size(display_raw)
    if not 0 < nav_y < height:
        raise MeasurementError("--nav-y must be inside the current display")
    report["display"] = {"width": width, "height": height, "raw": display_raw}
    assert_foreground(adb)
    layer_raw = adb.shell("dumpsys", "SurfaceFlinger", "--list")
    report["ownSurfaceLayerListRaw"] = "\n".join(line for line in layer_raw.splitlines() if PACKAGE in line)
    candidates = []
    for name in own_surface_layers(layer_raw):
        raw = adb.shell("dumpsys", "SurfaceFlinger", "--latency", name)
        frames = parse_surface_latency(raw)
        if any(valid_frame(frame) for frame in frames):
            candidates.append((latest_present(frames), name))
    if not candidates:
        raise MeasurementError("No active bank Flutter SurfaceView has completed frames")
    layer = max(candidates)[1]
    report["surfaceLayer"] = layer
    remote_dir = "/data/local/tmp/demobank-os-measure-" + report["runId"]
    remote_helper = remote_dir + "/input_marker"
    report["helper"] = {"sha256": sha256_file(helper), "remoteNamespace": remote_dir}

    def snapshot() -> str:
        return adb.shell("dumpsys", "SurfaceFlinger", "--latency", layer)

    def memory(stage: str) -> None:
        raw = adb.shell("dumpsys", "meminfo", PACKAGE)
        filename = stage + "-meminfo.txt"
        (report_path.parent / filename).write_text(raw, encoding="utf-8")
        kib = parse_pss_kib(raw)
        report["memory"].append({"stage": stage, "rawFile": filename,
                                 "totalPssKiB": kib, "totalPssMiB": kib / 1024})
        save(report_path, report)

    adb.shell("mkdir", "-m", "700", remote_dir)
    try:
        adb.run("push", str(helper), remote_helper)
        adb.shell("chmod", "700", remote_helper)
        memory("before-routes")
        for cycle in range(1, 7):
            for label, index in ROUTES:
                x = width * (2 * index + 1) // 8
                row: dict[str, Any] = {"cycle": cycle, "route": label, "x": x,
                                       "y": nav_y, "surfaceLayer": layer, "valid": False}
                report["samples"].append(row)
                time.sleep(.8)
                assert_foreground(adb)
                row["beforeLatencyRaw"] = snapshot()
                time.sleep(.25)
                row["quietLatencyRaw"] = snapshot()
                save(report_path, report)
                row["idleBeforeInputVerified"] = verify_idle(
                    parse_surface_latency(row["beforeLatencyRaw"]),
                    parse_surface_latency(row["quietLatencyRaw"]))
                if not row["idleBeforeInputVerified"]:
                    raise MeasurementError("Flutter SurfaceView was not idle before input")
                row["inputMarkerRaw"] = adb.shell(remote_helper, str(x), str(nav_y))
                row["preInjectionMonotonicNs"] = parse_marker(row["inputMarkerRaw"])
                time.sleep(.6)
                row["afterLatencyRaw"] = snapshot()
                save(report_path, report)
                first = select_first_response(parse_surface_latency(row["quietLatencyRaw"]),
                                              parse_surface_latency(row["afterLatencyRaw"]),
                                              row["preInjectionMonotonicNs"])
                row.update(selectedTripleNs=list(first), firstPresentNs=first[1], valid=True,
                           conservativeInputToPresentMs=(first[1] - row["preInjectionMonotonicNs"]) / 1e6)
                save(report_path, report)
                print(json.dumps({key: row[key] for key in ("cycle", "route", "valid", "conservativeInputToPresentMs")},
                                 ensure_ascii=False), flush=True)
            memory(f"cycle-{cycle}")
    finally:
        # Never clear system buffers or another run's files, even on failure.
        try:
            adb.shell("rm", "-f", remote_helper)
            adb.shell("rmdir", remote_dir)
            report["helper"]["cleanedUp"] = True
        except MeasurementError as error:
            report["helper"]["cleanedUp"] = False
            report["helper"]["cleanupFailure"] = str(error)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--phase", choices=("startup", "routes"), required=True)
    parser.add_argument("--adb", required=True, type=Path)
    parser.add_argument("--device", required=True)
    parser.add_argument("--apk", required=True, type=Path, help="Already-installed ordinary bank release APK; not installed by this tool")
    parser.add_argument("--output", required=True, type=Path, help="Explicit artifact directory; existing phase reports are preserved")
    parser.add_argument("--nav-y", type=int, help="Routes only: navigation row center from the current screenshot")
    parser.add_argument("--helper", type=Path, help="Routes only: android_input_marker.c compiled for the device ABI")
    args = parser.parse_args(argv)
    adb_path, apk, output = args.adb.expanduser().resolve(), args.apk.expanduser().resolve(), args.output.expanduser().resolve()
    if not adb_path.is_file() or not os.access(adb_path, os.X_OK) or not apk.is_file():
        parser.error("--adb must be an executable file and --apk an existing file")
    if not args.device.strip() or output.is_relative_to(Path(__file__).resolve().parent):
        parser.error("Use an explicit device and an output directory outside tool source")
    helper = args.helper.expanduser().resolve() if args.helper else None
    if args.phase == "routes" and (not args.nav_y or args.nav_y <= 0 or not helper or not helper.is_file()):
        parser.error("routes requires --nav-y from the current screenshot and an existing --helper")
    output.mkdir(parents=True, exist_ok=True)
    report_path = output / (args.phase + ".json")
    if report_path.exists():
        parser.error("Existing phase report is preserved; choose a new --output directory")
    if args.phase == "routes" and any((output / (stage + "-meminfo.txt")).exists()
                                     for stage in ("before-routes", *[f"cycle-{n}" for n in range(1, 7)])):
        parser.error("Existing PSS evidence is preserved; choose a new --output directory")
    report: dict[str, Any] = {
        "protocolVersion": 1, "runId": uuid.uuid4().hex, "phase": args.phase,
        "recordedAtUtc": datetime.now(timezone.utc).isoformat(), "package": PACKAGE,
        "buildMode": "ordinary release (caller supplied APK)", "apkSha256": sha256_file(apk),
        "deviceSerialSha256": hashlib.sha256(args.device.encode()).hexdigest(),
        "status": "collecting", "samples": [], "memory": [],
        "method": ("ActivityManager am start -W: 3 force-stopped COLD + 3 home/resume HOT launches; "
                   "OS launch times, separate from Flutter first presentation and network readiness."
                   if args.phase == "startup" else
                   "Automated injection -> first Flutter SurfaceView actual presentation after verified idle. "
                   "Native CLOCK_MONOTONIC before exec input tap includes input-tool startup/dispatch. "
                   "Not physical finger input, semantic destination acceptance, completed transition, or network readiness."),
    }
    save(report_path, report)
    try:
        adb = Adb(str(adb_path), args.device)
        report["installedApk"] = verify_installed_apk(adb, report["apkSha256"])
        if args.phase == "startup":
            collect_startup(adb, report, report_path)
        else:
            collect_routes(adb, report, report_path, helper, args.nav_y)
        report["summaryMs"] = validate_complete(report)
        report["status"] = "complete"
    except (MeasurementError, OSError, ValueError, KeyError) as error:
        report["status"] = "failed"
        report["failure"] = str(error)
    finally:
        report["finishedAtUtc"] = datetime.now(timezone.utc).isoformat()
        save(report_path, report)
    print(json.dumps({"status": report["status"], "report": str(report_path),
                      "samples": len(report["samples"]), "failure": report.get("failure")}, ensure_ascii=False), flush=True)
    return 0 if report["status"] == "complete" else 1


if __name__ == "__main__":
    sys.exit(main())
