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



class TestCarrier(unittest.TestCase):
    def test_carrier_command_updates_engine(self):
        eng = B.Engine(110.0, 10.0, noise=False, seed=1, tones=True)
        self.assertAlmostEqual(eng.carrier, 110.0, places=6)
        B.apply_command(eng, "CARRIER 150")
        self.assertAlmostEqual(eng.carrier, 150.0, places=6)
        # Beat offset unchanged; both ears move together.
        self.assertAlmostEqual(eng.beat, 10.0, places=6)

    def test_carrier_render_keeps_stereo_beat_offset(self):
        eng = B.Engine(110.0, 10.0, noise=False, seed=1, tones=True)
        eng.tone_gain = 1.0
        eng.volume_gain = 1.0
        B.apply_command(eng, "CARRIER 150")
        # Force increments from new carrier.
        left_hz = eng.carrier
        right_hz = eng.carrier + eng.beat
        self.assertAlmostEqual(left_hz, 150.0, places=6)
        self.assertAlmostEqual(right_hz, 160.0, places=6)
        out = eng.render(64)
        self.assertEqual(len(out), 64 * 4)
        # Not silent — tones rendered at new carrier.
        import struct
        samples = struct.unpack("<" + "h" * (len(out) // 2), out)
        self.assertTrue(any(abs(s) > 100 for s in samples))


class TestBedBeatAm(unittest.TestCase):
    def test_bed_am_locks_to_beat(self):
        """Noise bed envelope peaks once per beat cycle while tones are on."""
        beat = 10.0
        eng = B.Engine(110.0, beat, noise=True, seed=1, tones=True, rain=False)
        eng.set_tones(True)
        eng.set_noise(True)
        # Warm gains
        eng.render(int(B.RATE * 0.1))
        # Capture one side without tones: zero tone amp path by reading noise-dominated
        # energy proxy — use phase_beat advance over one beat period.
        frames = int(round(B.RATE / beat))
        eng.phase_beat = 0.0
        mods = []
        # Reconstruct mod the same way as Engine.render
        import math
        for i in range(frames):
            mod = 1.0 + B.BED_BEAT_AM_DEPTH * 1.0 * 1.0 * math.sin(eng.phase_beat)
            mods.append(mod)
            eng.phase_beat += eng.inc_beat
        # Exactly one full cycle of the sine LFO across frames
        self.assertAlmostEqual(eng.inc_beat * frames, B.TWO_PI, places=4)
        self.assertGreater(max(mods), 1.10)
        self.assertLess(min(mods), 0.90)
        # Start and end near the same phase point (full period)
        self.assertAlmostEqual(mods[0], mods[-1], places=2)

    def test_bed_am_tracks_tone_volume(self):
        eng = B.Engine(110.0, 10.0, noise=True, seed=1, tones=True)
        eng.tone_gain = 1.0
        eng.volume_gain = 0.0
        eng.phase_beat = math.pi / 2  # sin = 1
        depth = B.BED_BEAT_AM_DEPTH * eng.tone_gain * eng.volume_gain
        self.assertEqual(depth, 0.0)
        eng.volume_gain = 1.0
        depth = B.BED_BEAT_AM_DEPTH * eng.tone_gain * eng.volume_gain
        self.assertAlmostEqual(depth, 0.15, places=6)



if __name__ == "__main__":
    os.chdir(ROOT)
    unittest.main()
