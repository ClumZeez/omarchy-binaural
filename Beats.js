.pragma library

// Pure logic for the binaural plugin. No Qt objects so it can be
// unit-tested with plain node.

// Hemi-Sync / Gateway Experience carriers sit in the 100–200 Hz band.
// 110 Hz (A2) is low enough to fuse as a beat, high enough not to rumble.
var CARRIER_HZ = 110

var DEFAULT_PRESET = "alpha"
var DEFAULT_NOISE = true
var DEFAULT_VOLUME = 1

var PRESETS = [
  { id: "delta", name: "Delta", effect: "Deep rest",      beat: 2 },
  { id: "theta", name: "Theta", effect: "Wind down",       beat: 6 },
  { id: "alpha", name: "Alpha", effect: "Creative work",   beat: 10 },
  { id: "smr",   name: "SMR",   effect: "Calm focus",      beat: 14 },
  { id: "beta",  name: "Beta",  effect: "Problem solving", beat: 20 },
  { id: "gamma", name: "Gamma", effect: "Peak Focus",      beat: 40 }
]

function findEntry(shellConfig, id) {
  if (!shellConfig) return null
  var layout = shellConfig.bar && shellConfig.bar.layout
  if (layout) {
    for (var section in layout) {
      var list = layout[section]
      if (!Array.isArray(list)) continue
      for (var i = 0; i < list.length; i++) {
        if (list[i] && list[i].id === id) return list[i]
      }
    }
  }
  var plugins = shellConfig.plugins
  if (Array.isArray(plugins)) {
    for (var j = 0; j < plugins.length; j++) {
      if (plugins[j] && plugins[j].id === id) return plugins[j]
    }
  }
  return null
}

function bool(value, fallback) {
  if (value === undefined || value === null) return fallback
  if (typeof value === "string") return value !== "false" && value !== "0" && value !== "off"
  return !!value
}

function clampVolume(value, fallback) {
  if (fallback === undefined) fallback = DEFAULT_VOLUME
  if (value === undefined || value === null || value === "") return fallback
  var n = Number(value)
  if (!isFinite(n)) return fallback
  if (n > 1) n = n / 100
  if (n < 0) n = 0
  if (n > 1) n = 1
  return n
}

function presetById(id) {
  var key = String(id || "")
  for (var i = 0; i < PRESETS.length; i++) {
    if (PRESETS[i].id === key) return PRESETS[i]
  }
  return null
}

function defaultPreset() {
  return presetById(DEFAULT_PRESET) || PRESETS[0]
}

function resolvePreset(id) {
  return presetById(id) || defaultPreset()
}

function beatLabel(hz) {
  var n = Number(hz)
  if (!isFinite(n)) return ""
  var rounded = Math.round(n * 100) / 100
  if (rounded === Math.round(rounded)) return String(Math.round(rounded)) + " Hz"
  return String(rounded) + " Hz"
}

function column(presets, side) {
  var list = Array.isArray(presets) ? presets : PRESETS
  var out = []
  var want = side === 1 ? 1 : 0
  for (var i = 0; i < list.length; i++) {
    if (i % 2 === want) out.push(list[i])
  }
  return out
}

function config(entry) {
  var e = entry || {}
  var preset = resolvePreset(e.preset)
  return {
    preset: preset.id,
    noise: bool(e.noise, DEFAULT_NOISE),
    rain: bool(e.rain, false),
    volume: clampVolume(e.volume, DEFAULT_VOLUME),
    noiseVolume: clampVolume(e.noiseVolume, DEFAULT_VOLUME),
    rainVolume: clampVolume(e.rainVolume, DEFAULT_VOLUME),
    masterVolume: clampVolume(e.masterVolume, DEFAULT_VOLUME),
    carrier: CARRIER_HZ
  }
}
