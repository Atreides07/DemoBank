"""Offline contract tests: neither an Android SDK nor a device is used."""

from __future__ import annotations

import base64
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest


RUNNER_PATH = Path(__file__).resolve().parents[1] / "run_android_release_journey.py"
RUN_ID = "abcdef0123456789"
spec = importlib.util.spec_from_file_location("android_release_journey", RUNNER_PATH)
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


def _frames(status="passed", mode="release", run_id=RUN_ID):
    report = {
        "protocolVersion": 1,
        "runId": run_id,
        "app": "bank",
        "buildMode": mode,
        "status": status,
        "stage": "аналитика → операции",
        "completedScenarios": [
            {"scenario": "ui_" + ("я" * 1000), "status": status},
        ],
    }
    raw = json.dumps(report, ensure_ascii=False, separators=(",", ":")).encode()
    encoded = base64.b64encode(raw).decode()
    chunks = [encoded[index:index + 640] for index in range(0, len(encoded), 640)]
    count, checksum = len(chunks), runner.fnv1a32(raw)
    lines = [
        f"DBJ1 BEGIN id={run_id} app=bank count={count} "
        f"length={len(raw)} checksum={checksum}",
    ]
    lines += [
        f"DBJ1 CHUNK id={run_id} seq={index} count={count} data={chunk}"
        for index, chunk in enumerate(chunks)
    ]
    lines.append(
        f"DBJ1 COMPLETE id={run_id} count={count} length={len(raw)} "
        f"checksum={checksum} status={status}"
    )
    verdict = f"DBJ1 VERDICT id={run_id} status=passed All tests passed"
    return report, lines, verdict


class ReleaseReportParserTests(unittest.TestCase):
    def parse(self, lines):
        parser = runner.ReleaseReportParser()
        for line in lines:
            parser.feed("I/flutter( 4242): " + line)
        return parser

    def test_unicode_multichunk_report_requires_framework_verdict(self):
        report, lines, verdict = _frames()
        parser = self.parse(lines)
        self.assertFalse(parser.passed)
        parser.feed(verdict)
        self.assertTrue(parser.passed)
        self.assertEqual(parser.report, report)
        self.assertGreater(parser.integrity["chunks"], 1)

    def test_verdict_before_report(self):
        _, lines, verdict = _frames()
        self.assertTrue(self.parse([verdict, *lines]).passed)

    def test_out_of_order_chunks(self):
        _, lines, verdict = _frames()
        self.assertTrue(
            self.parse([lines[0], *reversed(lines[1:-1]), lines[-1], verdict]).passed
        )

    def test_identical_duplicate_chunk(self):
        _, lines, verdict = _frames()
        self.assertTrue(self.parse([lines[0], lines[1], *lines[1:], verdict]).passed)

    def test_truncated_report(self):
        _, lines, _ = _frames()
        with self.assertRaisesRegex(runner.JourneyError, "missing"):
            self.parse([lines[0], *lines[2:]])

    def test_checksum_rejects_corruption(self):
        # Independent FNV-1a32 vector fixes the wire algorithm, not just the
        # agreement between this fixture builder and the parser.
        self.assertEqual(runner.fnv1a32(b"hello"), "4f9f2cab")
        _, lines, _ = _frames()
        lines = [re.sub(r"checksum=[a-f0-9]+", "checksum=00000000", line) for line in lines]
        with self.assertRaisesRegex(runner.JourneyError, "checksum does not match"):
            self.parse(lines)

    def test_utf8_length_rejects_corruption(self):
        _, lines, _ = _frames()
        lines = [re.sub(r"length=\d+", "length=1", line) for line in lines]
        with self.assertRaisesRegex(runner.JourneyError, "length does not match"):
            self.parse(lines)

    def test_invalid_base64(self):
        _, lines, _ = _frames()
        lines[1] = lines[1].split("data=")[0] + "data=!"
        with self.assertRaisesRegex(runner.JourneyError, "base64"):
            self.parse(lines)

    def test_oversized_chunk(self):
        _, lines, _ = _frames()
        lines[1] = lines[1].split("data=")[0] + "data=" + ("A" * 804)
        with self.assertRaisesRegex(runner.JourneyError, "800 bytes"):
            self.parse(lines)

    def test_conflicting_duplicate_chunk(self):
        _, lines, _ = _frames()
        conflicting = lines[1][:-1] + ("A" if lines[1][-1] != "A" else "B")
        with self.assertRaisesRegex(runner.JourneyError, "Conflicting duplicate"):
            self.parse([lines[0], lines[1], conflicting])

    def test_nonrelease_report(self):
        _, lines, _ = _frames(mode="profile")
        with self.assertRaisesRegex(runner.JourneyError, "release/AOT"):
            self.parse(lines)

    def test_failed_report_preserves_failure_evidence(self):
        _, lines, _ = _frames(status="failed")
        parser = runner.ReleaseReportParser()
        with self.assertRaisesRegex(runner.JourneyError, "failed scenario"):
            for line in lines:
                parser.feed(line)
        self.assertEqual(parser.report["status"], "failed")

    def test_failed_framework_verdict_overrides_passed_report(self):
        _, lines, _ = _frames()
        parser = self.parse(lines)
        with self.assertRaisesRegex(runner.JourneyError, "framework verdict is failed"):
            parser.feed(f"DBJ1 VERDICT id={RUN_ID} status=failed Some tests failed")
        self.assertFalse(parser.passed)

    def test_mismatched_verdict_run_id(self):
        _, lines, verdict = _frames()
        with self.assertRaisesRegex(runner.JourneyError, "another run"):
            self.parse([*lines, verdict.replace(RUN_ID, "12345678abcdef90")])

    def test_plain_success_text_does_not_replace_framework_verdict(self):
        _, lines, _ = _frames()
        self.assertFalse(self.parse([*lines, "All tests passed!"]).passed)

    def test_framework_failure_without_report(self):
        with self.assertRaisesRegex(runner.JourneyError, "Flutter test reported a failure"):
            self.parse(["EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK"])


# Only this temporary executable is passed as --adb. Its command allowlist also
# verifies PID/tag scoping, retained-buffer reading and package-scoped cleanup.
FAKE_ADB_SOURCE = r'''#!/usr/bin/env python3
import json
from pathlib import Path
import sys
import time

root = Path(__file__).parent
args = sys.argv[1:]
with (root / "commands.jsonl").open("a") as log:
    log.write(json.dumps(args) + "\n")
assert args[:2] == ["-s", "offline-fixture"], args
args = args[2:]
case = json.loads((root / "case.json").read_text())
if args[:1] == ["install"]:
    assert args[1] == "-r" and len(args) == 3, args
    if case.get("installFail"):
        print("Failure [INSTALL_FAILED_TEST_ONLY]")
        sys.exit(1)
    print("Success")
elif args == ["shell", "am", "force-stop", "dev.fixture.bank_app"]:
    pass
elif args == ["shell", "cmd", "package", "resolve-activity", "--brief",
              "-a", "android.intent.action.MAIN", "-c",
              "android.intent.category.LAUNCHER", "dev.fixture.bank_app"]:
    print("dev.fixture.bank_app/.MainActivity")
elif args == ["shell", "date", "+%m-%dT%H:%M:%S"]:
    print("10-16T12:30:45")
elif args == ["shell", "am", "start", "-W", "-n", "dev.fixture.bank_app/.MainActivity"]:
    print("Status: ok")
elif args == ["shell", "pidof", "-s", "dev.fixture.bank_app"]:
    print("4242")
elif args[:1] == ["logcat"]:
    assert args == ["logcat", "--pid=4242", "-b", "main", "-v", "brief",
                    "-T", "10-16 12:30:45.000", "flutter:V", "*:S"], args
    for line in case["lines"]:
        print("I/flutter( 4242): " + line, flush=True)
    if not case.get("exitLogcat"):
        time.sleep(60)
else:
    raise AssertionError(args)
'''


class OfflineRunnerCliTests(unittest.TestCase):
    def run_case(self, case, expected_code, reason=None, timeout=5):
        with tempfile.TemporaryDirectory(prefix="demobank_fake_adb_") as scratch:
            root = Path(scratch)
            fake_adb = root / "fake-adb"
            fake_adb.write_text(FAKE_ADB_SOURCE)
            fake_adb.chmod(0o700)
            apk = root / "synthetic.apk"
            apk.write_bytes(b"not-an-actual-apk; offline CLI fixture only")
            (root / "case.json").write_text(json.dumps(case))
            result = subprocess.run(
                [sys.executable, str(RUNNER_PATH), "--adb", str(fake_adb),
                 "--device", "offline-fixture", "--apk", str(apk),
                 "--package", "dev.fixture.bank_app", "--output", str(root / "results"),
                 "--timeout", str(timeout)],
                capture_output=True,
                text=True,
                timeout=30,
                check=False,
            )
            self.assertEqual(result.returncode, expected_code, result.stdout + result.stderr)
            summary = json.loads(result.stdout)
            report_text = Path(summary["report"]).read_text()
            metadata = json.loads(report_text)
            commands = [json.loads(line) for line in (root / "commands.jsonl").read_text().splitlines()]
            self.assertEqual(metadata["status"], "passed" if expected_code == 0 else "failed")
            self.assertEqual(summary["status"], metadata["status"])
            self.assertTrue((Path(summary["artifacts"]) / "release-journey.log").is_file())
            self.assertNotIn("offline-fixture", report_text)  # Device serial is hashed.
            if reason:
                self.assertIn(reason, metadata["failure"])
            for command in commands:
                self.assertNotIn("input", command)
                self.assertNotIn("uiautomator", command)
                if command[2] == "logcat":
                    self.assertNotIn("-c", command)
                    self.assertIn("--pid=4242", command)
                    self.assertEqual(command[-2:], ["flutter:V", "*:S"])
            if case.get("installFail"):
                self.assertEqual(len(commands), 1)
            elif expected_code == 0:
                self.assertTrue(metadata["frameworkAllTestsPassed"])
                self.assertFalse(metadata["runner"]["appStoppedAfterFailure"])
                self.assertIsNone(metadata["failure"])
                self.assertGreater((Path(summary["artifacts"]) / "release-journey.log").stat().st_size, 0)
            else:
                self.assertTrue(metadata["runner"]["appStoppedAfterFailure"])
                self.assertEqual(
                    commands[-1][-4:],
                    ["shell", "am", "force-stop", "dev.fixture.bank_app"],
                )

    def test_success(self):
        _, lines, verdict = _frames()
        self.run_case({"lines": [*lines, verdict]}, 0)

    def test_failed_report(self):
        _, lines, verdict = _frames(status="failed")
        self.run_case({"lines": [*lines, verdict]}, 1, "failed scenario")

    def test_framework_failure_after_passed_report(self):
        _, lines, _ = _frames()
        verdict = f"DBJ1 VERDICT id={RUN_ID} status=failed Some tests failed"
        self.run_case({"lines": [*lines, verdict]}, 1, "framework verdict is failed")

    def test_corruption(self):
        _, lines, verdict = _frames()
        lines = [re.sub(r"checksum=[a-f0-9]+", "checksum=00000000", line) for line in lines]
        self.run_case({"lines": [*lines, verdict]}, 1, "checksum does not match")

    def test_timeout_without_verdict(self):
        _, lines, _ = _frames()
        self.run_case({"lines": lines}, 1, "Timed out waiting", timeout=3)

    def test_unexpected_logcat_exit(self):
        self.run_case({"lines": [], "exitLogcat": True}, 1, "before")

    def test_install_failure_does_not_start_app(self):
        self.run_case({"lines": [], "installFail": True}, 1, "install failed")


if __name__ == "__main__":
    unittest.main()
