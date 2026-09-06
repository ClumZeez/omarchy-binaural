# Binaural — beats for the Omarchy bar

Six binaural-beat presets plus optional brown-noise and live rain beds.
Click the sine in the bar, pick a state, and leave a bed on so the sine
is not the only thing you hear.

The carrier is **110 Hz** — in the 100–200 Hz band Hemi-Sync / the Gateway
Experience uses — and is not a control. Headphones are required: a binaural
beat is the difference between the two ears.

## Presets

| Preset | Effect | Beat |
|---|---|---|
| Delta | Deep rest | 2 Hz |
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
arm a bed. Brown noise is generated in-process; rain is **Sleepscapes Rain**
(a live mpv stream from stream.willstare.com). Both can be on at once.

Tone volume is the oscilloscope (tones only). Noise and rain each have
their own vertical scrub; icons shrink while scrubbing and disappear at 0%
(which also disables that bed).

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
- `mpv` for the Sleepscapes rain stream.

No sudo.

## Install

Drop the folder in place (this repo is already a plugin directory):

```bash
# if you cloned it somewhere else:
cp -a . ~/.config/omarchy/plugins/callum.binaural
omarchy-restart-shell
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
| `volume` | `1` | Binaural tone mix, 0–1 |
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
omarchy-shell binaural rain           # toggle
omarchy-shell binaural volume 0.5
omarchy-shell shell toggle callum.binaural   # open / close the popup
```

## How it works

- `Service.qml` is the engine: one instance per shell, owns the tone
  generator and the mpv rain player, remembers preset and bed prefs.
- `BarWidget.qml` is the bar label and the popup, one per monitor.
- `SineIcon.qml` tints `assets/SineWave.svg` for the bar and the hero.
- `NoiseIcon.qml` / `RainIcon.qml` draw canvas marks (size follows volume
  while scrubbing).
- `VolumeScope.qml` / `Oscilloscope.qml` are the tone-volume control.
- `Beats.js` is the preset table and config parsing.
- `binaural` is a small Python generator. Left = 110 Hz, right = 110 Hz +
  beat. Optional uncorrelated brown noise in each ear. Fade in on start,
  fade out on stop. Live `PRESET` / `NOISE` / `NOISEVOL` / `VOLUME` /
  `TONES` / `STOP` on stdin.
- `rain-ipc` talks to mpv over a Unix socket for pause/volume.

## License

[MIT](LICENSE) © 2026 Callum Lees
