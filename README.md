# Binaural-beats for the Omarchy bar

Six binaural-beat presets plus optional brown-noise and rain sounds.

Headphones are required: a binaural
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

Right-click the bar icon to mute all; right-click
again restores the same mix.

Noise and rain icons sit on top-right. Click to mute/unmute, drag to change volume.
Brown noise is generated in-process; rain is a local loop of
Moodist's **Light Rain** sample (see `THIRD_PARTY.md`).

## Bar widget

| Action | Result |
|---|---|
| Left click | Open / close the popup |
| Right click | Mute all three / restore previous mix |

While playing, the bar shows the sine pair plus the preset name.

## Requirements

- Omarchy with the Quattro shell (`omarchy-shell`, Quickshell based).
- `python3` (standard library only) and `pw-play` (PipeWire) or `paplay`.
- `mpv` for the local rain loop.

No sudo.

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

## IPC

Agent to fill

## How it works

- `Service.qml` is the engine: one instance per shell, owns the tone
  generator and the local mpv rain loop, remembers preset and bed prefs.
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
- `assets/light-rain.mp3` is the rain bed (Moodist; see `THIRD_PARTY.md`).

## License

[MIT](LICENSE) © 2026 Callum Lees
