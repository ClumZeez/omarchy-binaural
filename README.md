# Binaural — beats for the Omarchy bar

Six binaural-beat presets and a noise-floor icon. That is the whole
plugin. Click the sine in the bar, pick a state, optionally leave the
brown-noise floor on so the sine is not the thing you hear.

The carrier is **110 Hz** — in the 100–200 Hz band Hemi-Sync / the Gateway
Experience uses — and is not a control. Headphones are required: a binaural
beat is the difference between the two ears.

## Presets

| Preset | Effect | Beat |
|---|---|---|
| Delta | Deep sleep | 2 Hz |
| Theta | Wind down | 6 Hz |
| Alpha | Creative work | 10 Hz |
| SMR | Calm focus | 14 Hz |
| Beta | Problem solving | 20 Hz |
| Gamma | Peak Focus | 40 Hz |

Alpha is the default. The noise floor is on by default.

## The popup

A two-by-three grid: name, a word or two for the effect, the beat frequency.
Click a tile to start it and restore the last rain/noise prefs. Click the
playing tile (or right-click the bar icon) to silence everything; those
prefs are kept for the next start.

Grain and rain icons sit on the title row. Hover for the label, click to
arm a bed. Brown noise is generated here; rain is **Sleepscapes Rain**, a
live rain stream (Sleepscapes Rain as fallback). Both can be on at once.

## Bar widget

| Action | Result |
|---|---|
| Left click | Open / close the popup |
| Right click | Power the last preset + rain/noise prefs on or off |
| Middle click | Toggle noise |

While playing, the bar shows the sine pair plus the preset name.

## Requirements

- Omarchy with the Quattro shell (`omarchy-shell`, Quickshell based).
- `python3` (standard library only) and `pw-play` (PipeWire) or `paplay`.
  Both ship with Omarchy.

No extra packages, no sudo.

## Install

Drop the folder in place (this repo is already a plugin directory):

```bash
# if you cloned it somewhere else:
cp -a . ~/.config/omarchy/plugins/callum.binaural
omarchy-shell shell rescanPlugins
omarchy plugin enable callum.binaural --section center
```

From git, once it is published:

```bash
omarchy plugin add <git-url> --enable
```

## Remove

```bash
omarchy plugin remove callum.binaural
```

## Settings

Inline on the widget's entry in `~/.config/omarchy/shell.json`. The popup
writes these itself.

| Key | Default | Meaning |
|---|---|---|
| `preset` | `alpha` | Last chosen preset id |
| `noise` | `true` | Brown-noise floor preference |
| `rain` | `false` | Rain-bed preference |
| `volume` | `1` | Master mix, 0–1 |
| `noiseVolume` | `1` | Brown-noise level, 0–1 |
| `rainVolume` | `1` | Rain level, 0–1 |

## IPC

```bash
omarchy-shell binaural status
omarchy-shell binaural play alpha
omarchy-shell binaural stop
omarchy-shell binaural toggle
omarchy-shell binaural noise          # toggle
omarchy-shell binaural noise on
omarchy-shell binaural noise off
omarchy-shell binaural volume 0.5
omarchy-shell shell toggle callum.binaural   # open / close the popup
```

## How it works

- `Service.qml` is the engine: one instance per shell, owns the player
  process, remembers the preset and the noise switch.
- `BarWidget.qml` is the bar label and the popup, one per monitor.
- `SineIcon.qml` tints `assets/SineWave.svg` for the bar and the hero.
- `NoiseIcon.qml` tints `assets/Noise.svg` for the noise-floor control.
- `BeatWave.qml` scrolls the sine mark behind the playing tile at the beat rate.
- `Beats.js` is the preset table and config parsing.
- `binaural` is a small Python generator. Left = 110 Hz, right = 110 Hz +
  beat. Optional uncorrelated brown noise in each ear. Fade in on start, fade
  out on stop. Live `PRESET` / `NOISE` / `STOP` commands on stdin so flipping
  the switch does not restart the stream.

## License

[MIT](LICENSE) © 2026 Callum Lees
