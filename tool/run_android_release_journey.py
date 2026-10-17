#!/usr/bin/env python3
"""Run an embedded AOT integration journey, without Flutter Driver or UI input.

Build the journey APK with JOURNEY_RELEASE_LOG=true, JOURNEY_SCREENSHOTS=false,
and INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE=false. This runner installs
that APK, launches its exported launcher activity, and reads only the new app's
PID and the flutter log tag. It never clears the device's logcat buffers.

The DBJ1 protocol uses <= 800-byte base64 payloads, sequence/count, UTF-8 byte
length, and FNV-1a32 as an accidental-corruption checksum (not authentication).
Success requires a complete, valid release report AND the framework's matching
"All tests passed" verdict. A report emitted before a failing tearDown cannot
produce success. On failure/timeout, only the launched test app is force-stopped.
"""

from __future__ import annotations

import argparse
import base64
import binascii
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import re
import selectors
import subprocess
import sys
import time
from typing import Any, BinaryIO


class JourneyError(RuntimeError):
    """A failed device command, test, or report-integrity check."""


def fnv1a32(data: bytes) -> str:
    checksum = 0x811C9DC5
    for byte in data:
        checksum = ((checksum ^ byte) * 0x01000193) & 0xFFFFFFFF
    return f"{checksum:08x}"


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


class ReleaseReportParser:
    """Parse scoped logcat lines. No adb or filesystem operations live here."""

    max_report_bytes = 1_000_000
    max_chunks = 4096

    def __init__(self) -> None:
        self.header: dict[str, str] | None = None
        self.chunks: dict[int, str] = {}
        self.report: dict[str, Any] | None = None
        self.integrity: dict[str, Any] | None = None
        self.verdict_id: str | None = None
        self.framework_passed = False
        self.complete = False

    @property
    def passed(self) -> bool:
        return (
            self.complete
            and self.report is not None
            and self.report.get("status") == "passed"
            and self.framework_passed
            and self.header is not None
            and self.verdict_id == self.header["id"]
        )

    def feed(self, line: str) -> None:
        match = re.search(r"\bDBJ1 (BEGIN|CHUNK|COMPLETE|VERDICT) (.*)$", line.strip())
        if not match:
            if re.search(
                r"Some tests failed|Test failed\.|Unhandled Exception|"
                r"EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK",
                line,
                re.IGNORECASE,
            ):
                raise JourneyError("The embedded Flutter test reported a failure")
            return

        command, payload = match.groups()
        fields = {}
        for token in payload.split():
            if "=" in token:
                key, value = token.split("=", 1)
                if key in fields:
                    raise JourneyError(f"Duplicate DBJ1 field: {key}")
                fields[key] = value

        if command == "VERDICT":
            self._verdict(fields, payload)
            return
        if command == "BEGIN":
            self._begin(fields)
            return
        if self.header is None or fields.get("id") != self.header["id"]:
            raise JourneyError("DBJ1 frame has no matching BEGIN/run identity")
        if self.complete:
            raise JourneyError("Unexpected DBJ1 data after COMPLETE")
        if fields.get("count") != self.header["count"]:
            raise JourneyError("DBJ1 chunk counts disagree")
        if command == "CHUNK":
            self._chunk(fields)
        else:
            self._finish(fields)

    def _begin(self, fields: dict[str, str]) -> None:
        if self.header is not None:
            raise JourneyError("Multiple terminal reports from the same test process")
        required = {"id", "app", "count", "length", "checksum"}
        if set(fields) != required:
            raise JourneyError("Incomplete or unexpected DBJ1 BEGIN fields")
        if not re.fullmatch(r"[a-f0-9]{8,32}", fields["id"]):
            raise JourneyError("Invalid DBJ1 run identity")
        if fields["app"] not in {"bank", "fines"}:
            raise JourneyError("Unexpected journey application")
        count = self._integer(fields["count"])
        length = self._integer(fields["length"])
        if not (1 <= count <= self.max_chunks and 1 <= length <= self.max_report_bytes):
            raise JourneyError("DBJ1 report exceeds framing limits")
        if not re.fullmatch(r"[a-f0-9]{8}", fields["checksum"]):
            raise JourneyError("Invalid DBJ1 checksum field")
        self.header = fields

    def _chunk(self, fields: dict[str, str]) -> None:
        if set(fields) != {"id", "seq", "count", "data"}:
            raise JourneyError("Incomplete or unexpected DBJ1 CHUNK fields")
        assert self.header is not None
        sequence = self._integer(fields["seq"])
        if not 0 <= sequence < int(self.header["count"]):
            raise JourneyError("DBJ1 sequence is outside the report")
        data = fields["data"]
        if len(data.encode("ascii", errors="replace")) > 800:
            raise JourneyError("DBJ1 base64 chunk exceeds 800 bytes")
        if not re.fullmatch(r"[A-Za-z0-9+/]+={0,2}", data):
            raise JourneyError("Invalid DBJ1 base64 chunk")
        if sequence in self.chunks and self.chunks[sequence] != data:
            raise JourneyError("Conflicting duplicate DBJ1 chunk")
        self.chunks[sequence] = data

    def _finish(self, fields: dict[str, str]) -> None:
        if set(fields) != {"id", "count", "length", "checksum", "status"}:
            raise JourneyError("Incomplete or unexpected DBJ1 COMPLETE fields")
        assert self.header is not None
        if any(fields[key] != self.header[key] for key in ("length", "checksum")):
            raise JourneyError("DBJ1 BEGIN/COMPLETE integrity fields disagree")
        count = int(self.header["count"])
        if len(self.chunks) != count:
            raise JourneyError("Truncated DBJ1 report: missing base64 chunks")
        try:
            raw = base64.b64decode("".join(self.chunks[index] for index in range(count)), validate=True)
            if len(raw) != int(self.header["length"]):
                raise JourneyError("DBJ1 UTF-8 byte length does not match")
            if fnv1a32(raw) != self.header["checksum"]:
                raise JourneyError("DBJ1 checksum does not match")
            report = json.loads(raw.decode("utf-8"))
        except (binascii.Error, UnicodeError, json.JSONDecodeError) as error:
            raise JourneyError("DBJ1 report is not valid base64/UTF-8/JSON") from error
        if not isinstance(report, dict):
            raise JourneyError("DBJ1 report must be a JSON object")
        if (
            report.get("protocolVersion") != 1
            or report.get("runId") != self.header["id"]
            or report.get("app") != self.header["app"]
            or report.get("status") != fields["status"]
        ):
            raise JourneyError("DBJ1 report identity/status does not match its frames")
        if report.get("buildMode") != "release":
            raise JourneyError("This APK did not execute in release/AOT mode")
        if fields["status"] not in {"passed", "failed"}:
            raise JourneyError("Invalid terminal journey status")
        self.report = report
        self.complete = True
        self.integrity = {"algorithm": "fnv1a32", "checksum": self.header["checksum"],
                          "utf8Bytes": len(raw), "chunks": count}
        if report["status"] != "passed":
            raise JourneyError("The journey JSON reports a failed scenario")

    def _verdict(self, fields: dict[str, str], payload: str) -> None:
        if set(fields) != {"id", "status"}:
            raise JourneyError("Incomplete or unexpected DBJ1 VERDICT fields")
        self.verdict_id = fields["id"]
        if fields["status"] != "passed" or "All tests passed" not in payload:
            raise JourneyError("The embedded Flutter framework verdict is failed")
        self.framework_passed = True
        if self.header is not None and self.verdict_id != self.header["id"]:
            raise JourneyError("Framework verdict belongs to another run")

    @staticmethod
    def _integer(value: str) -> int:
        if not re.fullmatch(r"0|[1-9][0-9]*", value):
            raise JourneyError("Invalid DBJ1 integer field")
        return int(value)


class Adb:
    def __init__(self, executable: str, device: str, deadline: float, log: BinaryIO) -> None:
        self.prefix = [executable, "-s", device]
        self.deadline = deadline
        self.log = log

    def run(self, *arguments: str, check: bool = True, timeout: float = 120) -> subprocess.CompletedProcess[str]:
        remaining = self.deadline - time.monotonic()
        if remaining <= 0:
            raise JourneyError("Journey timeout expired during an adb operation")
        try:
            result = subprocess.run(self.prefix + list(arguments), capture_output=True,
                                    text=True, timeout=min(timeout, remaining), check=False)
        except subprocess.TimeoutExpired as error:
            raise JourneyError(f"adb {arguments[0]} timed out") from error
        self.log.write((f"adb {arguments[0]}: exit={result.returncode}\n" + result.stdout + result.stderr).encode())
        if check and result.returncode != 0:
            raise JourneyError(f"adb {arguments[0]} failed; see runner.log")
        return result


def _package(value: str) -> str:
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+", value):
        raise argparse.ArgumentTypeError("Use an explicit Android application ID")
    return value


def _parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--adb", required=True, help="Path to the Android SDK adb executable")
    parser.add_argument("--device", required=True, help="Explicit adb device serial")
    parser.add_argument("--apk", required=True, type=Path, help="AOT journey APK built from integration_test/journey_test.dart")
    parser.add_argument("--package", required=True, type=_package, help="Application ID of that APK")
    parser.add_argument("--output", required=True, type=Path, help="Artifact directory; a unique run subdirectory is created")
    parser.add_argument("--timeout", type=float, default=600, help="Overall install/start/test timeout in seconds (default 600)")
    return parser.parse_args(argv)


def _pid(adb: Adb, package: str) -> str | None:
    result = adb.run("shell", "pidof", "-s", package, check=False, timeout=10)
    value = result.stdout.strip()
    return value if result.returncode == 0 and re.fullmatch(r"[1-9][0-9]*", value) else None


def _watch_logs(adb: Adb, package: str, pid: str, since: str,
                raw_log: BinaryIO, stderr_log: BinaryIO, parser: ReleaseReportParser) -> None:
    process = subprocess.Popen(adb.prefix + ["logcat", f"--pid={pid}", "-b", "main", "-v", "brief",
                                           "-T", since, "flutter:V", "*:S"],
                               stdout=subprocess.PIPE, stderr=stderr_log, bufsize=0)
    assert process.stdout is not None
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    pending = b""
    next_pid_check = time.monotonic() + 2
    try:
        while time.monotonic() < adb.deadline:
            for key, _ in selector.select(timeout=0.25):
                chunk = os.read(key.fileobj.fileno(), 65536)
                if not chunk:
                    raise JourneyError("Scoped logcat ended before a verified framework verdict")
                raw_log.write(chunk)
                pending += chunk
                if len(pending) > 2_000_000:
                    raise JourneyError("Unterminated logcat output exceeded the safety limit")
                while b"\n" in pending:
                    line, pending = pending.split(b"\n", 1)
                    parser.feed(line.decode("utf-8", errors="replace"))
                    if parser.passed:
                        return
            if process.poll() is not None:
                raise JourneyError("Scoped logcat exited before the journey completed")
            if time.monotonic() >= next_pid_check:
                if _pid(adb, package) != pid:
                    raise JourneyError("The journey process exited or restarted before verification")
                next_pid_check = time.monotonic() + 2
        raise JourneyError("Timed out waiting for a valid report and matching 'All tests passed' verdict")
    finally:
        selector.close()
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
        process.stdout.close()


def main(argv: list[str] | None = None) -> int:
    arguments = _parse_args(argv)
    if not math.isfinite(arguments.timeout) or arguments.timeout <= 0:
        raise SystemExit("--timeout must be finite and positive")
    apk = arguments.apk.expanduser().resolve()
    if not apk.is_file() or apk.suffix.lower() != ".apk":
        raise SystemExit("--apk must point to an existing APK file")
    apk_sha256 = _sha256_file(apk)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S_%fZ")
    output = arguments.output.expanduser().resolve() / stamp
    output.mkdir(parents=True, exist_ok=False)
    report_path = output / "release-journey.json"
    parser = ReleaseReportParser()
    started = time.monotonic()
    deadline = started + arguments.timeout
    launched = False
    failure: str | None = None
    pid: str | None = None
    stage = "install"
    stopped_after_failure = False
    try:
        with (output / "runner.log").open("wb", buffering=0) as actions, \
             (output / "release-journey.log").open("wb", buffering=0) as raw_log, \
             (output / "logcat-stderr.log").open("wb", buffering=0) as logcat_stderr:
            adb = Adb(arguments.adb, arguments.device, deadline, actions)
            adb.run("install", "-r", str(apk))
            adb.run("shell", "am", "force-stop", arguments.package)
            stage = "resolve_launcher"
            resolved = adb.run("shell", "cmd", "package", "resolve-activity", "--brief",
                               "-a", "android.intent.action.MAIN", "-c", "android.intent.category.LAUNCHER",
                               arguments.package).stdout
            component = next((line.strip() for line in reversed(resolved.splitlines())
                              if re.fullmatch(re.escape(arguments.package) + r"/\.?[A-Za-z_][A-Za-z0-9_.]*", line.strip())), None)
            if component is None:
                raise JourneyError("Could not resolve the requested APK's launcher activity")
            # Device-local timestamp before launch. The subsequent --pid logcat
            # reads its retained buffer, so an early report is not missed.
            device_time = adb.run("shell", "date", "+%m-%dT%H:%M:%S").stdout.strip()
            if not re.fullmatch(r"\d{2}-\d{2}T\d{2}:\d{2}:\d{2}", device_time):
                raise JourneyError("Could not read a logcat-compatible device timestamp")
            since = device_time.replace("T", " ") + ".000"
            stage = "launch"
            launch = adb.run("shell", "am", "start", "-W", "-n", component, timeout=60)
            if re.search(r"\bError:|Exception", launch.stdout + launch.stderr):
                raise JourneyError("Android rejected the launcher activity; see runner.log")
            launched = True
            stage = "find_pid"
            pid_deadline = min(deadline, time.monotonic() + 30)
            while time.monotonic() < pid_deadline:
                pid = _pid(adb, arguments.package)
                if pid is not None:
                    break
                time.sleep(0.1)
            if pid is None:
                raise JourneyError("The launched journey application did not expose a PID")
            stage = "scoped_flutter_logcat"
            _watch_logs(adb, arguments.package, pid, since, raw_log, logcat_stderr, parser)
    except (JourneyError, OSError, subprocess.SubprocessError) as error:
        failure = str(error)
    finally:
        if failure is not None and launched:
            # Do not let a timed-out embedded test continue interacting with its
            # own UI after the caller has received a failed result.
            try:
                result = subprocess.run([arguments.adb, "-s", arguments.device, "shell", "am", "force-stop",
                                         arguments.package], capture_output=True, timeout=10, check=False)
                stopped_after_failure = result.returncode == 0
            except (OSError, subprocess.SubprocessError):
                pass
        metadata = {
            "status": "passed" if failure is None and parser.passed else "failed",
            "journey": parser.report,
            "frameworkAllTestsPassed": parser.framework_passed,
            "integrity": parser.integrity,
            "runner": {"package": arguments.package, "pid": pid,
                       "deviceSerialSha256": hashlib.sha256(arguments.device.encode()).hexdigest(),
                       "apkName": apk.name, "apkSha256": apk_sha256,
                       "startedAtUtc": stamp, "elapsedSeconds": round(time.monotonic() - started, 3),
                       "lastStage": stage, "appStoppedAfterFailure": stopped_after_failure},
            "failure": failure,
        }
        report_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": metadata["status"], "artifacts": str(output), "report": str(report_path)},
                     ensure_ascii=False))
    if failure:
        print(f"Release journey failed: {failure}", file=sys.stderr)
    return 0 if metadata["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
