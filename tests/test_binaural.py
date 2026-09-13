#!/usr/bin/env python3
"""Unit tests for the binaural generator (no PipeWire required)."""

from __future__ import annotations

import importlib.util
import math
import os
import struct
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BIN = ROOT / "binaural"


def load_binaural():
    from importlib.machinery import SourceFileLoader
    return SourceFileLoader("binaural_mod", str(BIN)).load_module()


B = load_binaural()


class TestNoiseAmp(unittest.TestCase):
    def test_noise_floor_is_four_db_down(self):
        # Matches current NOISE_AMP: original 0.24-ish bed, −4 dB, then ×(80/42).
        expected = 0.25 * (10 ** (-4.0 / 20.0)) * (80 / 42)
        self.assertAlmostEqual(B.NOISE_AMP, expected, places=10)


class TestRainCommands(unittest.TestCase):
    def test_rain_wanted_and_rain_on(self):
        eng = B.Engine(110.0, 10.0, noise=False, seed=1, tones=False, rain=False)
        self.assertEqual(eng.rain_wanted, 0.0)
        B.apply_command(eng, "RAIN on")
        self.assertEqual(eng.rain_wanted, 1.0)
        B.apply_command(eng, "RAIN off")
        self.assertEqual(eng.rain_wanted, 0.0)
        B.apply_command(eng, "RAINVOL 0.5")
        self.assertAlmostEqual(eng.rain_vol_wanted, 0.5, places=6)

    def test_rain_mixes_when_wanted(self):
        # Tiny synthetic PCM: alternating left/right peaks.
        frames = 8
        pcm = bytearray()
        for i in range(frames):
            l = 16000 if (i % 2 == 0) else 0
            r = 0 if (i % 2 == 0) else 16000
            pcm += struct.pack("<hh", l, r)
        eng = B.Engine(110.0, 10.0, noise=False, seed=1, tones=False, rain=True, rain_pcm=bytes(pcm))
        eng.rain_gain = 1.0
        eng.rain_vol_gain = 1.0
        out = eng.render(4)
        self.assertEqual(len(out), 4 * 4)
        # Not all zeros — rain contributed.
        samples = struct.unpack("<" + "h" * (len(out) // 2), out)
        self.assertTrue(any(abs(s) > 0 for s in samples))


class TestApplyCommand(unittest.TestCase):
    def test_noise_tones_stop(self):
        eng = B.Engine(110.0, 10.0, noise=True, seed=1, tones=True)
        B.apply_command(eng, "NOISE off")
        self.assertEqual(eng.noise_wanted, 0.0)
        B.apply_command(eng, "TONES off")
        self.assertEqual(eng.tones_wanted, 0.0)
        B.apply_command(eng, "STOP")
        self.assertTrue(eng.stopping)
        self.assertEqual(eng.rain_wanted, 0.0)


class TestRainDecode(unittest.TestCase):
    def test_decode_and_cache(self):
        src = ROOT / "assets" / "light-rain.mp3"
        if not src.is_file():
            self.skipTest("light-rain.mp3 missing")
        with tempfile.TemporaryDirectory() as td:
            link = Path(td) / "light-rain.mp3"
            link.write_bytes(src.read_bytes())
            pcm = B.decode_rain_pcm(str(link))
            self.assertGreater(len(pcm), B.RATE)  # >1s worth of bytes roughly
            cache = Path(B.rain_cache_path(str(link)))
            self.assertTrue(cache.is_file())
            # Second call hits cache
            pcm2 = B.decode_rain_pcm(str(link))
            self.assertEqual(len(pcm), len(pcm2))


class TestIdleSilent(unittest.TestCase):
    def test_idle_after_all_off(self):
        eng = B.Engine(110.0, 10.0, noise=False, seed=1, tones=False, rain=False)
        self.assertTrue(eng.is_idle_silent())
        B.apply_command(eng, "RAIN on")
        self.assertFalse(eng.is_idle_silent())


if __name__ == "__main__":
    os.chdir(ROOT)
    unittest.main()
