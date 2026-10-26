"""Acceptance boundaries for the user's revised native-4K 60 fps goal."""
import math
import unittest

from run_benchmark import meets_target


def full_report():
    phases = []
    for name in ("day_movement", "day_combat", "night_combat", "night_base", "cycling_weather_combat"):
        phases.append(dict(phase=name, mean_fps=60.0, frame_ms={"p95": 1000 / 60},
                           simulation_seconds=8.0, wall_seconds=8.0,
                           counts={"mobile": 400, "structures": 160}, pixels=[3840, 2160],
                           day_cycle=name == "cycling_weather_combat", weather_option=3,
                           start_hour=12.0, end_hour=13.0))
    return dict(status="valid", process_exit_code=0, process_log_errors=[], target_fps=60,
                resolution=[3840, 2160], scale_3d=1.0, mobile_per_player=100,
                structures_per_player=40, physics_ticks_per_second=30, teams=[0, 0, 1, 1],
                release=True, live_commander_ai=True, phases=phases)


class AcceptanceTests(unittest.TestCase):
    def test_exact_revised_boundary_passes(self):
        self.assertTrue(meets_target(full_report()))

    def test_every_phase_must_meet_frame_rate_and_tail_budget(self):
        for index in range(5):
            for field, value in (("mean_fps", 59.999), ("p95", math.nextafter(1000 / 60, math.inf))):
                report = full_report()
                target = report["phases"][index]
                (target["frame_ms"] if field == "p95" else target)[field] = value
                with self.subTest(phase=index, field=field):
                    self.assertFalse(meets_target(report))

    def test_scope_and_lifetime_requirements_remain(self):
        for change in (dict(resolution=[1920, 1080]), dict(diagnostic=True),
                       dict(release=False), dict(live_commander_ai=False),
                       dict(process_exit_code=1), dict(process_log_errors=["error"]),
                       dict(target_fps=120), dict(physics_ticks_per_second=15)):
            report = full_report()
            report.update(change)
            with self.subTest(change=change):
                self.assertFalse(meets_target(report))
        report = full_report()
        report["phases"].pop()
        self.assertFalse(meets_target(report))

    def test_slow_simulation_does_not_qualify(self):
        report = full_report()
        report["phases"][2]["real_time_ratio"] = .979
        self.assertFalse(meets_target(report))


if __name__ == "__main__":
    unittest.main()
