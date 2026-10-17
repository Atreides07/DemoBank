"""Offline evidence tests: no adb executable, SDK, helper, or device is run."""

from __future__ import annotations

from contextlib import redirect_stdout
import copy
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


RUNNER_PATH = Path(__file__).resolve().parents[1] / "measure_android_release.py"
spec = importlib.util.spec_from_file_location("measure_android_release", RUNNER_PATH)
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


def latency(*frames):
    return "16666667\n" + "\n".join("\t".join(map(str, frame)) for frame in frames) + "\n"


class SurfaceEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.marker = 1_000_000_000
        self.old = (900_000_000, 940_000_000, 930_000_000)
        self.quiet = [self.old]
        self.response = (1_040_000_000, 1_080_000_000, 1_060_000_000)

    def test_first_response_uses_actual_present_not_buffer_order_or_frame_ready(self):
        later = (1_045_000_000, 1_100_000_000, 1_055_000_000)
        raw = latency(later, self.old, self.response, (0, 0, 0))
        first = runner.select_first_response(self.quiet, runner.parse_surface_latency(raw), self.marker)
        self.assertEqual(first, self.response)
        self.assertEqual((first[1] - self.marker) / 1e6, 80.0)

    def test_pre_marker_presentations_do_not_count_as_responses(self):
        with self.assertRaisesRegex(runner.MeasurementError, "No new actual"):
            runner.select_first_response(self.quiet, [self.old, (950_000_000, 990_000_000, 980_000_000)], self.marker)

    def test_pending_pre_input_frame_cannot_be_skipped_for_a_later_good_frame(self):
        # This frame presents after input but was ready beforehand. Accepting a
        # later frame would silently change what "first response" means.
        pending = (980_000_000, 1_010_000_000, 990_000_000)
        with self.assertRaisesRegex(runner.MeasurementError, "already pending"):
            runner.select_first_response(self.quiet, [self.old, self.response, pending], self.marker)

    def test_desired_timestamp_alone_before_input_is_rejected(self):
        with self.assertRaisesRegex(runner.MeasurementError, "already pending"):
            runner.select_first_response(self.quiet, [(999_999_999, 1_080_000_000, 1_060_000_000)], self.marker)

    def test_invalid_or_unfinished_fields_cannot_produce_success(self):
        for bad in (0, -1, runner.FENCE_PENDING, runner.FENCE_PENDING + 1):
            for column in range(3):
                frame = list(self.response)
                frame[column] = bad
                with self.subTest(value=bad, column=column):
                    parsed = runner.parse_surface_latency(latency(self.old, frame))
                    with self.assertRaises(runner.MeasurementError):
                        runner.select_first_response(self.quiet, parsed, self.marker)

    def test_unfinished_earlier_frame_cannot_be_hidden_by_later_completed_frame(self):
        unfinished = (1_005_000_000, 1_010_000_000, runner.FENCE_PENDING)
        with self.assertRaisesRegex(runner.MeasurementError, "unfinished"):
            runner.select_first_response(self.quiet, [unfinished, self.response], self.marker)

    def test_frame_ready_after_presentation_is_invalid(self):
        with self.assertRaisesRegex(runner.MeasurementError, "invalid"):
            runner.select_first_response(self.quiet, [(1_010_000_000, 1_020_000_000, 1_030_000_000)], self.marker)

    def test_absent_or_unsupported_timestamp_data_is_not_zero_latency(self):
        for raw in ("", "no layer\n", "0\n", "16666667\n1 2\n", "16666667\n1 bad 3\n"):
            with self.subTest(raw=raw), self.assertRaises(runner.MeasurementError):
                runner.parse_surface_latency(raw)
        for raw in ("16666667\n", latency((0, 0, 0)), latency((1, runner.FENCE_PENDING, 2))):
            with self.subTest(raw=raw), self.assertRaises(runner.MeasurementError):
                runner.latest_present(runner.parse_surface_latency(raw))

    def test_idle_requires_two_completed_quiet_snapshots(self):
        self.assertTrue(runner.verify_idle([self.old], [self.old, (0, 0, 0)]))
        self.assertFalse(runner.verify_idle([self.old], [self.old, self.response]))
        with self.assertRaises(runner.MeasurementError):
            runner.verify_idle([], self.quiet)

    def test_marker_is_finite_unique_and_later_than_quiet_frame(self):
        self.assertEqual(runner.parse_marker("BEFORE_INJECT_NS=1000000000\n"), self.marker)
        for raw in ("", "BEFORE_INJECT_NS=0\n", f"BEFORE_INJECT_NS={runner.FENCE_PENDING}\n",
                    "BEFORE_INJECT_NS=1\nBEFORE_INJECT_NS=2\n"):
            with self.subTest(raw=raw), self.assertRaises(runner.MeasurementError):
                runner.parse_marker(raw)
        with self.assertRaisesRegex(runner.MeasurementError, "does not precede"):
            runner.select_first_response([self.response], [self.response], self.marker)

    def test_wrapped_layer_names_are_normalized_and_other_apps_backgrounds_excluded(self):
        name = f"SurfaceView[{runner.PACKAGE}/{runner.PACKAGE}.MainActivity](BLAST)#1494"
        raw = (f"RequestedLayerState{{{name} parentId=1493 relativeParentId=1491 z=-2}}\n"
               f"RequestedLayerState{{Background for {name} parentId=1493}}\n"
               "SurfaceView[dev.other.app/.MainActivity](BLAST)#42\n"
               f"{name}\n")
        self.assertEqual(runner.own_surface_layers(raw), [name])

    def test_display_override_controls_coordinates(self):
        self.assertEqual(runner.parse_display_size("Physical size: 720x1600\nOverride size: 360x800\n"), (360, 800))
        for raw in ("", "Physical size: 0x0\n", "Physical size: 1600x720\n"):
            with self.subTest(raw=raw), self.assertRaises(runner.MeasurementError):
                runner.parse_display_size(raw)

    def test_pss_is_kib_not_rss_or_decimal_megabytes(self):
        raw = "TOTAL RSS: 200000\nTOTAL PSS: 108835 TOTAL RSS: 222222\n"
        self.assertEqual(runner.parse_pss_kib(raw) / 1024, 106.2841796875)
        with self.assertRaises(runner.MeasurementError):
            runner.parse_pss_kib("TOTAL RSS: 108835\n")

    def test_startup_requires_reported_launch_type_and_complete_os_timing(self):
        raw = "Status: ok\nLaunchState: COLD\nTotalTime: 493\nWaitTime: 497\n"
        self.assertEqual(runner.parse_startup(raw, "COLD")["TotalTime"], 493)
        for bad in (raw.replace("COLD", "WARM"), raw.replace("Status: ok", "Status: timeout"),
                    raw.replace("WaitTime: 497\n", "")):
            with self.subTest(raw=bad), self.assertRaises(runner.MeasurementError):
                runner.parse_startup(bad, "COLD")


class FakeDevice:
    """An allowlisted in-process transport: these commands never reach adb."""

    def __init__(self, apk_sha, *, pending_before_input=False, wrong_apk=False):
        self.sha = "0" * 64 if wrong_apk else apk_sha
        self.pending_before_input = pending_before_input
        self.commands = []
        self.frames = [(90_000_000_000, 90_040_000_000, 90_030_000_000)]
        self.layer = f"SurfaceView[{runner.PACKAGE}/{runner.PACKAGE}.MainActivity](BLAST)#42"
        self.pss_reads = 0

    def run(self, *arguments):
        self.commands.append(arguments)
        if arguments[0] == "push":
            self.assert_remote(arguments[2])
            return "1 file pushed\n"
        raise AssertionError(arguments)

    def assert_remote(self, name):
        if not name.startswith("/data/local/tmp/demobank-os-measure-"):
            raise AssertionError(name)

    def shell(self, *arguments):
        self.commands.append(arguments)
        if arguments == ("pm", "path", runner.PACKAGE):
            return "package:/data/app/scoped-bank/base.apk\n"
        if arguments == ("sha256sum", "/data/app/scoped-bank/base.apk"):
            return self.sha + "  /data/app/scoped-bank/base.apk\n"
        if arguments == ("wm", "size"):
            return "Physical size: 720x1600\nOverride size: 360x800\n"
        if arguments == ("dumpsys", "activity", "activities"):
            return f"topResumedActivity=ActivityRecord{{42 u0 {runner.PACKAGE}/.MainActivity t1}}\n"
        if arguments == ("dumpsys", "SurfaceFlinger", "--list"):
            return f"RequestedLayerState{{{self.layer} parentId=41}}\n"
        if arguments == ("dumpsys", "SurfaceFlinger", "--latency", self.layer):
            return latency(*self.frames)
        if arguments == ("dumpsys", "meminfo", runner.PACKAGE):
            self.pss_reads += 1
            return f"TOTAL PSS: {108835 + self.pss_reads} TOTAL RSS: 200000\n"
        if arguments[:3] in (("mkdir", "-m", "700"), ("chmod", "700", arguments[-1]), ("rm", "-f", arguments[-1])):
            self.assert_remote(arguments[-1])
            return ""
        if arguments[0] == "rmdir":
            self.assert_remote(arguments[1])
            return ""
        if arguments[0].startswith("/data/local/tmp/demobank-os-measure-"):
            self.assert_remote(arguments[0])
            marker = self.frames[-1][1] + 100_000_000
            desired = marker - 1 if self.pending_before_input else marker + 40_000_000
            self.frames.append((desired, marker + 80_000_000, marker + 60_000_000))
            return f"BEFORE_INJECT_NS={marker}\n"
        if arguments == ("input", "keyevent", "KEYCODE_HOME"):
            return ""
        if arguments[:3] == ("am", "start", "-W") and arguments[-2:] == ("-n", runner.ACTIVITY):
            return ("Status: ok\nLaunchState: " + ("COLD" if "-S" in arguments else "HOT")
                    + "\nTotalTime: 493\nWaitTime: 497\n")
        raise AssertionError(arguments)


class OfflineCollectorTests(unittest.TestCase):
    def run_collector(self, phase="routes", **device_options):
        self.scratch = tempfile.TemporaryDirectory(prefix="demobank_measure_test_")
        self.addCleanup(self.scratch.cleanup)
        root = Path(self.scratch.name)
        apk = root / "ordinary.apk"
        apk.write_bytes(b"offline synthetic APK fixture")
        fake_adb = root / "adb-not-executed"
        fake_adb.write_text("must never run")
        fake_adb.chmod(0o700)
        helper = root / "helper-not-executed"
        helper.write_bytes(b"offline helper fixture")
        device = FakeDevice(hashlib.sha256(apk.read_bytes()).hexdigest(), **device_options)
        output = root / "results"
        argv = ["--phase", phase, "--adb", str(fake_adb), "--device", "offline-fixture",
                "--apk", str(apk), "--output", str(output)]
        if phase == "routes":
            argv += ["--helper", str(helper), "--nav-y", "750"]
        with patch.object(runner, "Adb", return_value=device), patch.object(runner.time, "sleep"), redirect_stdout(io.StringIO()):
            code = runner.main(argv)
        report = json.loads((output / (phase + ".json")).read_text())
        return code, report, output, device

    def test_full_routes_retains_all_idle_raw_and_exact_selected_fences(self):
        code, report, output, device = self.run_collector()
        self.assertEqual(code, 0)
        self.assertEqual(report["status"], "complete")
        self.assertEqual(report["summaryMs"], {"count": 24, "min": 80.0, "max": 80.0, "p50": 80.0, "p95": 80.0, "p99": 80.0})
        self.assertEqual(len(report["samples"]), 24)
        self.assertEqual([row["x"] for row in report["samples"][:4]], [135, 225, 315, 45])
        for row in report["samples"]:
            self.assertTrue(row["idleBeforeInputVerified"])
            self.assertEqual(row["beforeLatencyRaw"], row["quietLatencyRaw"])
            marker = row["preInjectionMonotonicNs"]
            self.assertTrue(all(stamp >= marker for stamp in row["selectedTripleNs"]))
            self.assertEqual(row["firstPresentNs"], row["selectedTripleNs"][1])
        self.assertEqual(len(report["memory"]), 7)
        for entry in report["memory"]:
            self.assertEqual(runner.parse_pss_kib((output / entry["rawFile"]).read_text()), entry["totalPssKiB"])
            self.assertEqual(entry["totalPssMiB"], entry["totalPssKiB"] / 1024)
        self.assertTrue(report["helper"]["cleanedUp"])
        self.assertEqual(device.commands[-2:], [("rm", "-f", report["helper"]["remoteNamespace"] + "/input_marker"),
                                                ("rmdir", report["helper"]["remoteNamespace"])])
        self.assertNotIn("offline-fixture", json.dumps(report))
        self.assertFalse(any(command[0] in ("install", "uninstall", "settings", "logcat") for command in device.commands))

    def test_no_missing_or_duplicate_route_may_be_summarized_as_success(self):
        _, report, _, _ = self.run_collector()
        for samples in (report["samples"][:-1], report["samples"][:-1] + report["samples"][:1]):
            incomplete = {**report, "samples": samples}
            with self.assertRaisesRegex(runner.MeasurementError, "all 24"):
                runner.validate_complete(incomplete)

    def test_claimed_idle_flag_cannot_override_changing_raw_snapshot(self):
        _, report, _, _ = self.run_collector()
        corrupt = copy.deepcopy(report)
        corrupt["samples"][0]["beforeLatencyRaw"] = latency((80_000_000_000, 80_040_000_000, 80_030_000_000))
        with self.assertRaisesRegex(runner.MeasurementError, "raw idle/frame"):
            runner.validate_complete(corrupt)

    def test_pre_marker_pending_frame_aborts_with_raw_evidence_and_cleans_only_owned_helper(self):
        code, report, _, device = self.run_collector(pending_before_input=True)
        self.assertEqual(code, 1)
        self.assertEqual(report["status"], "failed")
        self.assertIn("already pending", report["failure"])
        self.assertEqual(len(report["samples"]), 1)
        sample = report["samples"][0]
        self.assertFalse(sample["valid"])
        for key in ("beforeLatencyRaw", "quietLatencyRaw", "afterLatencyRaw", "inputMarkerRaw"):
            self.assertTrue(sample[key])
        self.assertNotIn("summaryMs", report)
        self.assertTrue(report["helper"]["cleanedUp"])
        self.assertEqual(device.commands[-1][0], "rmdir")

    def test_wrong_installed_apk_fails_before_any_ui_input(self):
        code, report, _, device = self.run_collector(wrong_apk=True)
        self.assertEqual(code, 1)
        self.assertIn("does not match", report["failure"])
        self.assertEqual(len(device.commands), 2)
        self.assertEqual(report["samples"], [])

    def test_startup_requires_all_three_cold_and_three_hot_os_launches(self):
        code, report, _, device = self.run_collector(phase="startup")
        self.assertEqual(code, 0)
        self.assertEqual([row["LaunchState"] for row in report["samples"]], ["COLD"] * 3 + ["HOT"] * 3)
        self.assertEqual(sum("-S" in command for command in device.commands), 3)
        self.assertEqual(sum(command == ("input", "keyevent", "KEYCODE_HOME") for command in device.commands), 3)
        with self.assertRaisesRegex(runner.MeasurementError, "all three"):
            runner.validate_complete({**report, "samples": report["samples"][:-1]})

    def test_no_default_device_actions_and_existing_report_is_preserved(self):
        with patch.object(runner.subprocess, "run") as subprocess_run, redirect_stdout(io.StringIO()), patch("sys.stderr", io.StringIO()):
            with self.assertRaises(SystemExit) as stopped:
                runner.main([])
            self.assertEqual(stopped.exception.code, 2)
            subprocess_run.assert_not_called()
        _, report, output, _ = self.run_collector(phase="startup")
        root = output.parent
        argv = ["--phase", "startup", "--adb", str(root / "adb-not-executed"), "--device", "offline",
                "--apk", str(root / "ordinary.apk"), "--output", str(output)]
        with patch.object(runner, "Adb") as adb, patch("sys.stderr", io.StringIO()):
            with self.assertRaises(SystemExit):
                runner.main(argv)
            adb.assert_not_called()
        self.assertEqual(json.loads((output / "startup.json").read_text()), report)


if __name__ == "__main__":
    unittest.main()
