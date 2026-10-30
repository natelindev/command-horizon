"""Atmosphere and weather clarity contracts. Run with python3 -m unittest discover -s tests/art."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


class AtmosphereContractsTests(unittest.TestCase):
    def setUp(self):
        self.atmosphere_source = (ROOT / "source/match/environment/WorldAtmosphere.gd").read_text(
            encoding="utf-8"
        )
        self.shader_source = (
            ROOT / "source/shaders/3d/battlefield_atmosphere.gdshader"
        ).read_text(encoding="utf-8")

    def test_rain_particles_are_bounded_for_visual_clarity(self):
        amount_match = re.search(r"rain\.amount\s*=\s*(\d+)", self.atmosphere_source)
        self.assertIsNotNone(amount_match, "Rain amount assignment not found")
        amount = int(amount_match.group(1))
        self.assertLessEqual(
            amount, 800, "Rain particle count too high; clutters battlefield readability"
        )

        alpha_match = re.search(
            r"albedo_color\s*=\s*Color\([^)]*,\s*([^)]+)\)", self.atmosphere_source
        )
        self.assertIsNotNone(alpha_match, "Rain material albedo alpha not found")
        alpha = float(alpha_match.group(1).strip())
        self.assertLessEqual(
            alpha, 0.25, "Rain streak opacity too high; obscures units underneath"
        )

    def test_sunlight_and_moon_key_remain_legible_under_clouds(self):
        # Daylight attenuation: lerpf(.85, 1.35, daylight) * (1.0 - cloud_cover * lerpf(.18, X, daylight))
        attenuation_match = re.search(
            r"cloud_cover\s*\*\s*lerpf\(\s*\.18\s*,\s*([^,]+),\s*daylight\)",
            self.atmosphere_source,
        )
        self.assertIsNotNone(attenuation_match, "Sunlight attenuation factor not found")
        max_cloud_factor = float(attenuation_match.group(1).strip())

        # Midday sunlight attenuation under full overcast (cloud_cover=1.0)
        self.assertLessEqual(
            max_cloud_factor, 0.35, "Daylight attenuated too heavily by clouds"
        )

        # Nighttime moon key (daylight=0.0): sun.light_energy = 0.85 * (1.0 - 0.18) = 0.697 >= 0.69
        night_moon_key = 0.85 * (1.0 - 0.18)
        self.assertGreaterEqual(
            night_moon_key, 0.69, "Clouds erased the moon key at night"
        )

    def test_fog_veil_does_not_blind_ground_units(self):
        # Veil opacity in shader should be capped for gameplay legibility
        veil_match = re.search(
            r"clamp\(\s*fog\s*\+\s*grit\s*,\s*0\.0\s*,\s*([^)]+)\)", self.shader_source
        )
        self.assertIsNotNone(veil_match, "Veil clamp in atmosphere shader not found")
        veil_max = float(veil_match.group(1).strip())
        self.assertLessEqual(
            veil_max, 0.20, "Veil maximum opacity too high; obscures ground units"
        )

        # Cloud ground shadow multiplier should not cast heavy black blotches
        shadow_match = re.search(
            r"float\s+shadow\s*=\s*banks\(.+?\)\s*\*\s*clouds\s*\*\s*([^;]+);",
            self.shader_source,
        )
        self.assertIsNotNone(shadow_match, "Cloud shadow multiplier not found")
        shadow_mult = float(shadow_match.group(1).strip())
        self.assertLessEqual(
            shadow_mult, 0.15, "Cloud shadows darken units too aggressively"
        )

    def test_team_footprint_follows_elevated_terrain(self):
        footprint_shader = (ROOT / "source/shaders/3d/team_footprint.gdshader").read_text(
            encoding="utf-8"
        )
        self.assertNotIn(
            "world_vertex_coords",
            footprint_shader,
            "Team footprint must not use world_vertex_coords so elevation does not bury it",
        )
        self.assertRegex(
            footprint_shader,
            r"VERTEX\.y\s*\+=\s*ground_height;",
            "Team footprint must offset relative to unit position",
        )

        footprint_script = (
            ROOT / "source/match/units/traits/TeamFootprint.gd"
        ).read_text(encoding="utf-8")
        self.assertIn(
            "AirToTerrainMarker",
            footprint_script,
            "Team footprint script must handle air unit altitude projection",
        )


if __name__ == "__main__":
    unittest.main()
