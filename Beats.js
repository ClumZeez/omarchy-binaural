.pragma library

// Pure logic for the binaural plugin. No Qt objects so it can be
// unit-tested with plain node.

// Carrier scrub band. Default/reset is 100 Hz; drag covers 60–200.
var DEFAULT_CARRIER = 100
var MIN_CARRIER = 60
var MAX_CARRIER = 200
// Back-compat alias for older tests / call sites.
var CARRIER_HZ = DEFAULT_CARRIER

var DEFAULT_PRESET = "delta"
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
  // Config may use 0–100 percent. Values just above 1 (e.g. 1.05 from a
  // +5% keyboard nudge) must clamp to full — not be read as 1.05%.
  if (n > 1) {
    if (n >= 2 && n <= 100) n = n / 100
    else n = 1
  }
  if (n < 0) n = 0
  if (n > 1) n = 1
  return n
}

function clampCarrier(value, fallback) {
  if (fallback === undefined) fallback = DEFAULT_CARRIER
  if (value === undefined || value === null || value === "") return fallback
  var n = Number(value)
  if (!isFinite(n)) return fallback
  if (n < MIN_CARRIER) n = MIN_CARRIER
  if (n > MAX_CARRIER) n = MAX_CARRIER
  return n
}

function levelFromCarrier(hz) {
  var c = clampCarrier(hz)
  return (c - MIN_CARRIER) / (MAX_CARRIER - MIN_CARRIER)
}

function carrierFromLevel(t) {
  var x = Number(t)
  if (!isFinite(x)) x = levelFromCarrier(DEFAULT_CARRIER)
  if (x < 0) x = 0
  if (x > 1) x = 1
  return clampCarrier(MIN_CARRIER + x * (MAX_CARRIER - MIN_CARRIER))
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
    carrier: clampCarrier(e.carrier, DEFAULT_CARRIER)
  }
}
