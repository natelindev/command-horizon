"""Contracts for player color visibility, health bar indicators, and combat readability.
Run with: python3 -m unittest tests/art/test_player_color_contracts.py
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


class PlayerColorContractsTests(unittest.TestCase):
    def setUp(self):
        self.health_bar_source = (
            ROOT / "source/match/units/traits/HealthBar.gd"
        ).read_text(encoding="utf-8")
        self.footprint_shader = (
            ROOT / "source/shaders/3d/team_footprint.gdshader"
        ).read_text(encoding="utf-8")
        self.player_source = (
            ROOT / "source/match/players/Player.gd"
        ).read_text(encoding="utf-8")
        self.object_materials_source = (
            ROOT / "source/match/ObjectMaterials.gd"
        ).read_text(encoding="utf-8")
        self.hit_shader = (
            ROOT / "source/shaders/3d/material_hit.gdshader"
        ).read_text(encoding="utf-8")

    def test_health_bar_has_one_health_track(self):
        self.assertIn("func _track_width()", self.health_bar_source)
        self.assertNotIn("PIP_WIDTH", self.health_bar_source)
        self.assertNotIn("UNDERLINE_HEIGHT", self.health_bar_source)

    def test_team_footprint_visibility_bounds(self):
        # Footprint must maintain elevated ground offset contract
        self.assertNotIn(
            "world_vertex_coords",
            self.footprint_shader,
            "Team footprint must not use world_vertex_coords so elevation does not bury it",
        )
        self.assertRegex(
            self.footprint_shader,
            r"VERTEX\.y\s*\+=\s*ground_height;",
            "Team footprint must offset relative to unit position",
        )

        # Footprint strength must be strong enough for combat visibility
        strength_match = re.search(
            r"uniform\s+float\s+strength\s*=\s*([0-9.]+);", self.footprint_shader
        )
        self.assertIsNotNone(strength_match, "Strength uniform not found in footprint shader")
        strength = float(strength_match.group(1))
        self.assertGreaterEqual(
            strength,
            0.50,
            "Footprint strength is too faint; will be lost under combat smoke and terrain",
        )
        self.assertLessEqual(
            strength,
            0.95,
            "Footprint strength is too harsh; will occlude terrain features",
        )

    def test_player_color_material_contract(self):
        # Material must be identified as TeamColor so shaders and passes recognize it
        self.assertRegex(
            self.player_source,
            r'resource_name\s*=\s*"TeamColor_[^"]+"',
            "Player dynamic material must begin with TeamColor prefix",
        )

        # Emission must be tuned so team markings do not get lost in dark shadows
        emission_match = re.search(
            r"emission_energy_multiplier\s*=\s*([0-9.]+)", self.player_source
        )
        self.assertIsNotNone(emission_match, "Emission multiplier not found in Player.gd")
        multiplier = float(emission_match.group(1))
        self.assertGreaterEqual(
            multiplier,
            0.20,
            "Player color emission is too faint to prevent dark ambient occlusion crush",
        )
        self.assertLessEqual(
            multiplier,
            0.50,
            "Player color emission is too bright; must look like paint, not neon lamps",
        )

    def test_hit_flash_preserves_team_markings(self):
        # ObjectMaterials must implement team mesh detection
        self.assertIn(
            "static func _is_team_mesh",
            self.object_materials_source,
            "ObjectMaterials must have _is_team_mesh to detect team trim",
        )
        self.assertIn(
            "not _is_team_mesh(node)",
            self.object_materials_source,
            "ObjectMaterials._collect_hit_surfaces must exclude team markings from hit flash",
        )

        # Hit flash shader must keep restrained emission to avoid washing out adjacent team markings
        emission_match = re.search(
            r"EMISSION\s*=\s*hit_color\.rgb\s*\*\s*hit_strength\s*\*\s*([0-9.]+);",
            self.hit_shader,
        )
        self.assertIsNotNone(emission_match, "Emission factor not found in material_hit.gdshader")
        emission_factor = float(emission_match.group(1))
        self.assertLessEqual(
            emission_factor,
            0.80,
            "Hit flash emission is too strong; will wash out neighboring team markings",
        )


if __name__ == "__main__":
    unittest.main()
