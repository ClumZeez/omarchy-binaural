import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Beats.js" as Beats

// One generator process for the whole session. Clicks only write stdin
// (TONES / NOISE / PRESET) so on/off is a short fade, not a process spawn.
// Rain is a local mpv loop (Moodist light-rain); toggles pause/unpause over IPC.
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
  readonly property string rainIpcPath: sourceDir + "/rain-ipc"
  readonly property string rainSock: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omarchy-binaural-rain.sock"

  readonly property var entry: Beats.findEntry(shell ? shell.shellConfig : null, pluginId)
  readonly property var config: Beats.config(entry)
  readonly property var presets: Beats.PRESETS
  readonly property real carrierHz: Beats.CARRIER_HZ

  property string presetId: "alpha"
  property bool noise: false
  property bool rain: false
  property bool playing: false
  property bool noiseLive: false
  property bool rainLive: false
  property real volume: 1
  property real noiseVolume: 1
  property real rainVolume: 1
  property real masterVolume: 1
  property bool hydrated: false
  property bool rainNeedsRespawn: true
  // mpv volume (0–100+) at rain scrub 100%. Edit this to change rain loudness.
  readonly property real rainVolumeMax: 80
  // Moodist light-rain.mp3 — local loop, no stream latency.
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
    noiseVolume = config.noiseVolume
    rainVolume = config.rainVolume
    masterVolume = config.masterVolume
    ensureGenerator()
    // Warm mpv paused so the first rain toggle is an IPC unpause, not a spawn.
    warmRain()
  }

  function warmRain() {
    if (rainPlayer.running) return
    startRain(true)
  }

  function generatorArgs() {
    var p = Beats.resolvePreset(presetId)
    return [
      "python3", generatorPath,
      "--carrier", String(carrierHz),
      "--beat", String(p.beat),
      "--no-noise",
      "--no-tones"
    ]
  }

  function ensureGenerator() {
    if (player.running) return
    player.command = generatorArgs()
    player.running = true
  }

  function tell(line) {
    ensureGenerator()
    if (!player.running) return
    var parts = String(line).split("\n")
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].length) player.write(parts[i] + "\n")
    }
  }

  function applyNoiseLive(on) {
    noiseLive = !!on
    tell("NOISE " + (noiseLive ? "on" : "off") + "\n")
  }

  function applyRainLive(on) {
    rainLive = !!on
    if (rainLive) startRain()
    else stopRain()
  }

  function stopTones() {
    if (!playing) return
    playing = false
    tell("TONES off\n")
  }

  function startPlayer(nextPreset) {
    var p = Beats.resolvePreset(nextPreset || presetId)
    var wasPlaying = playing
    muted = false
    presetId = p.id
    playing = true
    schedulePersist()
    if (wasPlaying) {
      tell("PRESET " + p.beat + "\n")
      return
    }
    // Tones only — never touch rain/noise.
    tell("PRESET " + p.beat + "\nTONES on\n")
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
    applyNoiseLive(false)
    applyRainLive(false)
    tell("TONES off\n")
  }

  function muteAll() {
    if (muted) return
    snapPlaying = playing
    snapNoise = noiseLive
    snapRain = rainLive
    muted = true
    playing = false
    applyNoiseLive(false)
    applyRainLive(false)
    tell("TONES off\n")
  }

  function unmuteAll() {
    if (!muted) return
    muted = false
    if (snapPlaying) {
      var p = Beats.resolvePreset(presetId)
      playing = true
      tell("PRESET " + p.beat + "\nTONES on\n")
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

  function toggleNoise() {
    setNoise(!noiseLive)
  }

  function rainJson(cmd) {
    // Fire-and-forget: a single Process drops mid-scrub updates when the
    // previous python IPC is still running, which felt like volume jumps.
    Quickshell.execDetached([
      "python3", rainIpcPath, rainSock,
      JSON.stringify({ command: cmd })
    ])
  }

  function rainIpc(paused) {
    rainJson(["set_property", "pause", !!paused])
  }

  function toneGain() {
    return Math.max(0, Math.min(1, volume * masterVolume))
  }

  function noiseGain() {
    return Math.max(0, Math.min(1, noiseVolume * masterVolume))
  }

  function rainVolumeValue() {
    // Per-bed scrub × master. mpv softvol is cubic — invert so equal %
    // keeps relative loudness vs linear noise.
    var t = Math.max(0, Math.min(1, rainVolume * masterVolume))
    if (t <= 0)
      return 0
    return Math.round(rainVolumeMax * Math.pow(t, 1.0 / 3.0))
  }

  function applyRainVolume() {
    if (!rainPlayer.running) return
    rainJson(["set_property", "volume", rainVolumeValue()])
  }

  function applyAllVolumes() {
    tell("VOLUME " + toneGain() + "\n")
    tell("NOISEVOL " + noiseGain() + "\n")
    applyRainVolume()
  }

  // Oscilloscope: tones only (still scaled by masterVolume).
  function setVolume(value) {
    var next = Beats.clampVolume(value, volume)
    if (Math.abs(next - volume) < 0.001) return
    volume = next
    schedulePersist()
    tell("VOLUME " + toneGain() + "\n")
  }

  // IPC volume: master gain over tones + noise + rain.
  function setMasterVolume(value) {
    var next = Beats.clampVolume(value, masterVolume)
    if (Math.abs(next - masterVolume) < 0.001) return
    masterVolume = next
    schedulePersist()
    applyAllVolumes()
  }

  function setNoiseVolume(value) {
    var next = Beats.clampVolume(value, noiseVolume)
    if (Math.abs(next - noiseVolume) >= 0.001) {
      noiseVolume = next
      schedulePersist()
      tell("NOISEVOL " + noiseGain() + "\n")
    }
    // 0% disables the bed; any audible level arms it.
    if (next <= 0.001) {
      if (noiseLive) setNoise(false)
    } else if (!noiseLive) {
      setNoise(true)
    }
  }

  function setRainVolume(value) {
    var next = Beats.clampVolume(value, rainVolume)
    if (Math.abs(next - rainVolume) >= 0.001) {
      rainVolume = next
      schedulePersist()
      applyRainVolume()
    }
    // 0% disables the bed; any audible level arms it.
    if (next <= 0.001) {
      if (rainLive) setRain(false)
    } else if (!rainLive) {
      setRain(true)
    }
  }

  function startRain(paused) {
    var startPaused = !!paused
    if (rainPlayer.running && !rainNeedsRespawn) {
      if (!startPaused) {
        rainIpc(false)
        applyRainVolume()
      }
      return
    }
    // Respawn when the rain asset or mpv flags change.
    rainNeedsRespawn = false
    rainRetry.stop()
    if (rainPlayer.running)
      rainPlayer.running = false
    Quickshell.execDetached(["rm", "-f", rainSock])
    var cmd = [
      "mpv", "--no-video", "--really-quiet",
      "--loop-file=inf",
      "--volume=" + String(rainVolumeValue()),
      "--input-ipc-server=" + rainSock,
      "--audio-client-name=BinauralRain",
      rainFile
    ]
    if (startPaused)
      cmd.splice(3, 0, "--pause")
    rainPlayer.command = cmd
    rainPlayer.running = true
  }

  function stopRain() {
    rainRetry.stop()
    if (rainPlayer.running) rainIpc(true)
  }

  function setRain(value) {
    muted = false
    applyRainLive(!!value)
    rain = rainLive
    schedulePersist()
  }

  function toggleRain() {
    setRain(!rainLive)
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
    id: rainPlayer
    onExited: function() {
      // Local loop should not exit; if it does, respawn while rain is armed.
      if (root.rainLive) {
        root.rainNeedsRespawn = true
        rainRetry.restart()
      }
    }
  }

  Timer {
    id: rainRetry
    interval: 1200
    repeat: false
    onTriggered: if (root.rainLive) root.startRain()
  }

  Process {
    id: player
    stdinEnabled: true
    onStarted: {
      player.write("VOLUME " + root.toneGain() + "\n")
      player.write("NOISEVOL " + root.noiseGain() + "\n")
      player.write("NOISE " + (root.noiseLive ? "on" : "off") + "\n")
      if (root.playing) {
        var p = Beats.resolvePreset(root.presetId)
        player.write("PRESET " + p.beat + "\n")
        player.write("TONES on\n")
      }
    }
    onExited: function() {
      Qt.callLater(root.ensureGenerator)
    }
  }

  IpcHandler {
    target: "binaural"

    function status(): string { return root.statusJson() }
    function play(id: string): string { root.play(id); return root.statusJson() }
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
  }
}
