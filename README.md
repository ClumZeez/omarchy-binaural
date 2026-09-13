# Binaural — beats for the Omarchy bar

![Binaural popup](preview.png)

A minimal binaural beat suite, including options for brown noise or rain sounds with independent level controls.

Headphones are required: a binaural beat is the difference between the two
ears. The carrier is **110 Hz**.

## Presets

| Preset | Effect | Beat |
|---|---|---|
| Delta | Deep rest | 2 Hz |
| Theta | Wind down | 6 Hz |
| Alpha | Creative work | 10 Hz |
| SMR | Calm focus | 14 Hz |
| Beta | Problem solving | 20 Hz |
| Gamma | Peak Focus | 40 Hz |

## The popup

Noise and rain icons sit on the top-right, binaural beat control is the oscilloscope in the middle:
click to mute/unmute, drag to change volume.

Brown noise is generated in-process; rain is Moodist's **Light Rain** sample
decoded once to PCM and mixed in the same stream (see `THIRD_PARTY.md`).

Right-click the bar icon to mute all three; right-click again restores the
same mix.

## Bar widget

| Action | Result |
|---|---|
| Left click | Open / close the popup |
| Right click | Mute all three / restore previous mix |

While playing, the bar shows the beat name.

## Requirements

- Omarchy with the Quattro shell (`omarchy-shell`, Quickshell based).
- `python3` (standard library only) and `pw-play` (PipeWire) or `paplay`.
- `ffmpeg` to decode the rain sample on first use (cached as
  `assets/light-rain.48000.s16le`).

No sudo. No `mpv` (rain no longer registers an MPRIS player).

## Install

Drop the folder in place (this repo is already a plugin directory):

```bash
# if you cloned it somewhere else:
cp -a . ~/.config/omarchy/plugins/callum.binaural
omarchy-restart-shell
omarchy plugin enable callum.binaural --section center
```

From git:

```bash
omarchy plugin add https://github.com/ClumZeez/omarchy-binaural --enable
```

## Remove

```bash
omarchy plugin remove callum.binaural
```

## Keyboard (in the popup)

With the popup open:

| Key | Action |
|---|---|
| Arrow keys (or `h` `j` `k` `l`) | Move focus across noise, rain, and the six presets |
| Enter / Space | Toggle the focused preset or bed |
| Esc | Close the popup |

No global Hyprland binds — keyboard control only works while the popup is open.

## IPC

```bash
omarchy-shell binaural status
omarchy-shell binaural play alpha     # tones only (beds unchanged)
omarchy-shell binaural stop           # stop tones + noise + rain
omarchy-shell binaural toggle         # mute all / restore (same as bar right-click)
omarchy-shell binaural noise          # toggle noise
omarchy-shell binaural rain           # toggle rain
omarchy-shell binaural volume 0.5     # master gain over tones + noise + rain
omarchy-shell shell toggle callum.binaural   # open / close the popup
```

Per-bed levels stay in the popup (oscilloscope / noise / rain scrubs).
`volume` on IPC is the master fader; it does not overwrite those scrubs.

## How it works

- `Service.qml` is the engine: one instance per shell. It starts a single
  Python generator only while tones, noise, or rain are sounding, and sends
  `STOP` when all three are off so the PipeWire stream disappears.
- Exactly one PipeWire stream: `application.name=Binaural` /
  `media.name=Binaural` via `pw-play`. No `BinauralRain`, no MPRIS.
- `BarWidget.qml` is the bar label and the popup, one per monitor.
- `SineIcon.qml` tints `assets/SineWave.svg` for the bar and the hero.
- `NoiseIcon.qml` / `RainIcon.qml` draw canvas marks (size follows volume
  while scrubbing).
- `VolumeScope.qml` / `Oscilloscope.qml` are the tone-volume control.
- `Beats.js` is the preset table and config parsing.
- `binaural` is a small Python generator. Left = 110 Hz, right = 110 Hz +
  beat. Optional uncorrelated brown noise in each ear. Rain PCM loop mixed
  the same way. Fade in on start, fade out on stop. Live `PRESET` / `NOISE` /
  `RAIN` / `NOISEVOL` / `RAINVOL` / `VOLUME` / `TONES` / `STOP` on stdin.
- `assets/light-rain.mp3` is the rain bed (Moodist; see `THIRD_PARTY.md`).

## License

[MIT](LICENSE) © 2026 Callum Lees
