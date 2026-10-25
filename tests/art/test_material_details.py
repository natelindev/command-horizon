"""Relief and cutout contracts. Run with python3 -m unittest discover -s tests/art."""
import importlib.util
from pathlib import Path
import unittest

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("material_details", ROOT / "tools/textures/generate_material_details.py")
DETAIL = importlib.util.module_from_spec(spec)
spec.loader.exec_module(DETAIL)


class MaterialDetailsTests(unittest.TestCase):
    def test_relief_normals_have_correct_axes(self):
        y, x = np.mgrid[:32, :32]
        flat = DETAIL.normal(np.zeros((32, 32)))
        np.testing.assert_allclose(flat, np.broadcast_to([.5, .5, 1], flat.shape))
        # A rising height field tilts the normal against the slope. Image rows
        # grow downward, so OpenGL's Y channel has the opposite sign from X.
        ramp = DETAIL.normal(x*.2 + y*.3)[2:-2, 2:-2]
        self.assertTrue(np.all(ramp[:, :, 0] < .5))
        self.assertTrue(np.all(ramp[:, :, 1] > .5))
        np.testing.assert_allclose(np.linalg.norm(ramp*2-1, axis=-1), 1)

    def test_noise_is_deterministic_and_periodic(self):
        a = DETAIL.periodic_noise(256, 8, 71)
        np.testing.assert_array_equal(a, DETAIL.periodic_noise(256, 8, 71))
        self.assertLess(np.max(abs(a[0]-a[-1])), .01)
        self.assertLess(np.max(abs(a[:, 0]-a[:, -1])), .01)
        self.assertGreater(float(a.std()), .1)

    def test_shipped_normals_and_packing(self):
        for name in ["metal_micro", "mechanical_trim"]:
            normal = np.array(Image.open(DETAIL.SURFACES / (name+"_normal.png"))).astype(float)/255*2-1
            self.assertLess(float(np.max(abs(np.linalg.norm(normal, axis=-1)-1))), .012)
            self.assertTrue(np.all(normal[:, :, 2] > 0))
            orm = np.array(Image.open(DETAIL.SURFACES / (name+"_orm.png")))
            self.assertGreater(float(orm[:, :, 1].std()), 3)
            self.assertGreater(int(orm[:, :, 0].min()), 100)
            if name == "metal_micro":
                self.assertEqual(int(orm[:, :, 2].max()), 0)

    def test_leaf_masks_have_gaps_and_clean_borders(self):
        for kind in ["leaves", "needles"]:
            alpha = np.array(Image.open(DETAIL.FOLIAGE / (kind+"_cutout.png")))[:, :, 3]
            coverage = np.mean(alpha > 102)
            self.assertGreater(coverage, .1)
            self.assertLess(coverage, .6)
            self.assertFalse(np.any(alpha[[0, -1], :]))
            self.assertFalse(np.any(alpha[:, [0, -1]]))
