import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Beats.js" as Beats

// One generator process → one PipeWire stream (application.name=Binaural).
// Tones, brown noise, and rain are mixed inside Python. No mpv / MPRIS.
// Process starts only while something is sounding; STOP tears it down.
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string pluginId: "callum.binaural"
  readonly property string sourceDir: {
    if (manifest && manifest.__sourceDir)
      return String(manifest.__sourceDir).replace(/^file:\/\//, "").replace(/\/$/, "")
    return decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "")).replace(/\/$/, "")
  }
  readonly property string generatorPath: sourceDir + "/binaural"

  readonly property var entry: Beats.findEntry(shell ? shell.shellConfig : null, pluginId)
  readonly property var config: Beats.config(entry)
  readonly property var presets: Beats.PRESETS
  property real carrierHz: Beats.DEFAULT_CARRIER

  property string presetId: "alpha"
  property bool noise: false
  property bool rain: false
  property bool playing: false
  property bool noiseLive: false
  property bool rainLive: false
  property real volume: 1
  // Last audible tone level before Space/click mute (never 50%-reset).
  property real volumeSnap: 1
  property real noiseVolume: 1
  property real noiseVolumeSnap: 1
  property real rainVolume: 1
  property real rainVolumeSnap: 1
  property real masterVolume: 1
  property bool hydrated: false
  // Moodist light-rain.mp3 — decoded once by the generator to PCM cache.
  readonly property string rainFile: sourceDir + "/assets/light-rain.mp3"

  // Snapshot for bar right-click master mute / restore.
  property bool muted: false
  property bool snapPlaying: false
  property bool snapNoise: false
  property bool snapRain: false

  readonly property var preset: Beats.resolvePreset(presetId)
  readonly property string presetName: preset ? preset.name : "Binaural"
  readonly property string effect: preset ? preset.effect : ""
  readonly property real beatHz: preset ? preset.beat : 10
  readonly property string beatText: Beats.beatLabel(beatHz)
  readonly property string statusLabel: playing ? presetName : "Binaural"
  readonly property bool sounding: playing || noiseLive || rainLive

  function persist() {
    var current = { id: pluginId }
    for (var existing in (entry || {})) if (existing !== "id") current[existing] = entry[existing]
    current.preset = presetId
    current.noise = noise
    current.rain = rain
    current.volume = volume
    current.noiseVolume = noiseVolume
    current.rainVolume = rainVolume
    current.masterVolume = masterVolume
    current.carrier = carrierHz
    if (shell && typeof shell.updateEntryInline === "function")
      shell.updateEntryInline(pluginId, current)
  }

  function schedulePersist() {
    persistTimer.restart()
  }

  function hydrate() {
    if (hydrated) return
    hydrated = true
    presetId = config.preset
    noise = config.noise
    rain = config.rain
    volume = config.volume
    volumeSnap = volume > 0.001 ? volume : 1
    noiseVolume = config.noiseVolume
    noiseVolumeSnap = noiseVolume > 0.001 ? noiseVolume : 1
    rainVolume = config.rainVolume
    rainVolumeSnap = rainVolume > 0.001 ? rainVolume : 1
    masterVolume = config.masterVolume
    carrierHz = config.carrier
    // Do not warm-start the generator — no stream until something sounds.
  }

  function generatorArgs() {
    var p = Beats.resolvePreset(presetId)
    return [
      "python3", generatorPath,
      "--carrier", String(carrierHz),
      "--beat", String(p.beat),
      "--no-noise",
      "--no-tones",
      "--rain-file", rainFile
    ]
  }

  function ensureGenerator() {
    if (player.running) return
    if (!(playing || noiseLive || rainLive)) return
    player.command = generatorArgs()
    player.running = true
  }

  function tell(line) {
    if (!player.running) {
      if (!(playing || noiseLive || rainLive)) return
      ensureGenerator()
    }
    if (!player.running) return
    var parts = String(line).split("\n")
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].length) player.write(parts[i] + "\n")
    }
  }

  function shutdownIfIdle() {
    if (playing || noiseLive || rainLive) return
    if (!player.running) return
    // Fade beds/tones then STOP so the PipeWire stream disappears.
    player.write("TONES off\nNOISE off\nRAIN off\nSTOP\n")
  }

  function applyNoiseLive(on) {
    noiseLive = !!on
    if (noiseLive) {
      ensureGenerator()
      tell("NOISE on\n")
      tell("NOISEVOL " + noiseGain() + "\n")
    } else {
      if (player.running) tell("NOISE off\n")
      shutdownIfIdle()
    }
  }

  function applyRainLive(on) {
    rainLive = !!on
    if (rainLive) {
      ensureGenerator()
      tell("RAIN on\n")
      tell("RAINVOL " + rainGain() + "\n")
    } else {
      if (player.running) tell("RAIN off\n")
      shutdownIfIdle()
    }
  }

  function stopTones() {
    if (!playing) return
    playing = false
    if (player.running) tell("TONES off\n")
    shutdownIfIdle()
  }

  function startPlayer(nextPreset) {
    var p = Beats.resolvePreset(nextPreset || presetId)
    var wasPlaying = playing
    muted = false
    presetId = p.id
    playing = true
    schedulePersist()
    ensureGenerator()
    if (wasPlaying) {
      tell("PRESET " + p.beat + "\n")
      return
    }
    // Tones only — never touch rain/noise.
    tell("PRESET " + p.beat + "\nTONES on\n")
    tell("VOLUME " + toneGain() + "\n")
  }

  function play(id) {
    var p = Beats.resolvePreset(id)
    if (playing && p.id === presetId) {
      stopTones()
      return
    }
    startPlayer(p.id)
  }

  function stop() {
    // Hard stop: all three off. Does not snapshot for right-click restore.
    muted = false
    snapPlaying = false
    snapNoise = false
    snapRain = false
    playing = false
    noiseLive = false
    rainLive = false
    if (player.running)
      player.write("TONES off\nNOISE off\nRAIN off\nSTOP\n")
  }

  function muteAll() {
    if (muted) return
    snapPlaying = playing
    snapNoise = noiseLive
    snapRain = rainLive
    muted = true
    playing = false
    noiseLive = false
    rainLive = false
    if (player.running)
      player.write("TONES off\nNOISE off\nRAIN off\nSTOP\n")
  }

  function unmuteAll() {
    if (!muted) return
    muted = false
    if (snapPlaying) {
      var p = Beats.resolvePreset(presetId)
      playing = true
      ensureGenerator()
      tell("PRESET " + p.beat + "\nTONES on\n")
      tell("VOLUME " + toneGain() + "\n")
    }
    applyNoiseLive(snapNoise)
    applyRainLive(snapRain)
  }

  // Bar right-click: only control that affects all three elements.
  function toggle() {
    if (muted) unmuteAll()
    else if (sounding) muteAll()
    // Nothing audible and not muted → no-op (do not auto-start a mix).
  }

  function setNoise(value) {
    muted = false
    applyNoiseLive(!!value)
    noise = noiseLive
    schedulePersist()
  }

  // Space/tap: on/off only. Level stays put (restore snap only if it was 0%).
  function toggleNoise() {
    if (noiseLive) {
      setNoise(false)
      return
    }
    if (noiseVolume <= 0.001)
      setNoiseVolume(noiseVolumeSnap > 0.001 ? noiseVolumeSnap : 1)
    setNoise(true)
  }

  function toneGain() {
    return Math.max(0, Math.min(1, volume * masterVolume))
  }

  function noiseGain() {
    return Math.max(0, Math.min(1, noiseVolume * masterVolume))
  }

  function rainGain() {
    return Math.max(0, Math.min(1, rainVolume * masterVolume))
  }

  function applyAllVolumes() {
    tell("VOLUME " + toneGain() + "\n")
    tell("NOISEVOL " + noiseGain() + "\n")
    tell("RAINVOL " + rainGain() + "\n")
  }

  // Oscilloscope: tones only (still scaled by masterVolume).
  // Drag / Shift-nudge implies intent to hear it — arm tones.
  function setVolume(value) {
    var next = Beats.clampVolume(value, volume)
    if (Math.abs(next - volume) < 0.001) return
    volume = next
    if (next > 0.001) volumeSnap = next
    schedulePersist()
    tell("VOLUME " + toneGain() + "\n")
    // 0% means off — stop tones; any audible level arms them.
    if (next <= 0.001) stopTones()
    else ensureTonesPlaying()
  }

  // Space / tap on carrier or amplitude: tones on/off. Level/Hz unchanged.
  // On starts last preset, or Delta on first run.
  function toggleTones() {
    if (playing) {
      stopTones()
      return
    }
    ensureTonesPlaying()
  }

  function ensureTonesPlaying() {
    if (playing) return
    startPlayer(presetId)
  }

  // Hero sine scrub: carrier Hz (both ears move; beat offset unchanged).
  // Drag / Shift-nudge arms tones.
  function setCarrier(hz) {
    var next = Beats.clampCarrier(hz, carrierHz)
    if (Math.abs(next - carrierHz) < 0.01) return
    carrierHz = next
    schedulePersist()
    tell("CARRIER " + carrierHz + "\n")
    ensureTonesPlaying()
  }

  // IPC volume: master gain over tones + noise + rain.
  function setMasterVolume(value) {
    var next = Beats.clampVolume(value, masterVolume)
    if (Math.abs(next - masterVolume) < 0.001) return
    masterVolume = next
    schedulePersist()
    applyAllVolumes()
  }

  // Drag / Shift-nudge sets level and arms the bed (Space still toggles off).
  function setNoiseVolume(value) {
    var next = Beats.clampVolume(value, noiseVolume)
    if (Math.abs(next - noiseVolume) < 0.001) return
    noiseVolume = next
    if (next > 0.001) noiseVolumeSnap = next
    schedulePersist()
    tell("NOISEVOL " + noiseGain() + "\n")
    // 0% deactivates; any audible level arms.
    if (next <= 0.001) {
      if (noiseLive) setNoise(false)
    } else if (!noiseLive) {
      setNoise(true)
    }
  }

  function setRainVolume(value) {
    var next = Beats.clampVolume(value, rainVolume)
    if (Math.abs(next - rainVolume) < 0.001) return
    rainVolume = next
    if (next > 0.001) rainVolumeSnap = next
    schedulePersist()
    tell("RAINVOL " + rainGain() + "\n")
    if (next <= 0.001) {
      if (rainLive) setRain(false)
    } else if (!rainLive) {
      setRain(true)
    }
  }

  function setRain(value) {
    muted = false
    applyRainLive(!!value)
    rain = rainLive
    schedulePersist()
  }

  function toggleRain() {
    if (rainLive) {
      setRain(false)
      return
    }
    if (rainVolume <= 0.001)
      setRainVolume(rainVolumeSnap > 0.001 ? rainVolumeSnap : 1)
    setRain(true)
  }

  function statusJson() {
    return JSON.stringify({
      playing: playing,
      preset: presetId,
      name: presetName,
      effect: effect,
      beat: beatHz,
      carrier: carrierHz,
      noise: noiseLive,
      rain: rainLive,
      muted: muted,
      noisePref: noise,
      rainPref: rain,
      volume: Math.round(volume * 100),
      noiseVolume: Math.round(noiseVolume * 100),
      rainVolume: Math.round(rainVolume * 100),
      masterVolume: Math.round(masterVolume * 100),
      headphones: true
    })
  }

  Timer {
    id: persistTimer
    interval: 400
    repeat: false
    onTriggered: root.persist()
  }

  Component.onCompleted: hydrate()

  Process {
    id: player
    stdinEnabled: true
    onStarted: {
      player.write("VOLUME " + root.toneGain() + "\n")
      player.write("NOISEVOL " + root.noiseGain() + "\n")
      player.write("RAINVOL " + root.rainGain() + "\n")
      player.write("CARRIER " + root.carrierHz + "\n")
      player.write("NOISE " + (root.noiseLive ? "on" : "off") + "\n")
      player.write("RAIN " + (root.rainLive ? "on" : "off") + "\n")
      if (root.playing) {
        var p = Beats.resolvePreset(root.presetId)
        player.write("PRESET " + p.beat + "\n")
        player.write("TONES on\n")
      } else {
        player.write("TONES off\n")
      }
    }
    onExited: function() {
      // Only respawn if something still needs audio (crash mid-play).
      if (root.playing || root.noiseLive || root.rainLive)
        Qt.callLater(root.ensureGenerator)
    }
  }

  IpcHandler {
    target: "binaural"

    function status(): string { return root.statusJson() }
    function play(id: string): string { root.play(id); return root.statusJson() }
    // Alias kept for sessions that still call `beat` after the 1.5.x rename.
    function beat(id: string): string { root.play(id); return root.statusJson() }
    function stop(): string { root.stop(); return root.statusJson() }
    function toggle(): string { root.toggle(); return root.statusJson() }
    function noise(value: string): string {
      var v = String(value || "").toLowerCase()
      if (v === "on" || v === "true" || v === "1") root.setNoise(true)
      else if (v === "off" || v === "false" || v === "0") root.setNoise(false)
      else root.toggleNoise()
      return root.statusJson()
    }
    function rain(value: string): string {
      var v = String(value || "").toLowerCase()
      if (v === "on" || v === "true" || v === "1") root.setRain(true)
      else if (v === "off" || v === "false" || v === "0") root.setRain(false)
      else root.toggleRain()
      return root.statusJson()
    }
    // Master gain over tones + noise + rain (per-bed levels stay as set in the UI).
    function volume(value: string): string {
      if (value !== undefined && value !== null && String(value).length)
        root.setMasterVolume(value)
      return root.statusJson()
    }
    // Carrier Hz (Hemi-Sync band); both ears move, beat offset unchanged.
    function carrier(value: string): string {
      if (value !== undefined && value !== null && String(value).length)
        root.setCarrier(value)
      return root.statusJson()
    }
  }
}
