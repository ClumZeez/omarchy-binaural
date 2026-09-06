import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Beats.js" as Beats

// One generator process for the whole session. Clicks only write stdin
// (TONES / NOISE / PRESET) so on/off is a short fade, not a process spawn.
// Rain is a long-lived mpv stream; later toggles pause/unpause over IPC.
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
  property bool hydrated: false
  property int rainUrlIndex: 0
  // stream list gen — bump when URLs change so shells reload
  readonly property int rainStreamGen: 2
  property bool rainNeedsRespawn: true
  // mpv volume (0–100+) at rain scrub 100%. Edit this to change rain loudness.
  readonly property real rainVolumeMax: 80

  // Sleepscapes Rain: continuous rain/thunder, no music bed.
  // Nature Radio Rain is avoided — it occasionally programs ambient tracks.
  readonly property var rainUrls: [
    "https://stream.willstare.com:8850/stream/1/",
    "https://stream.willstare.com:8850/"
  ]

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
    ensureGenerator()
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

  function restoreBeds() {
    applyNoiseLive(noise)
    applyRainLive(rain)
  }

  function silence() {
    playing = false
    applyNoiseLive(false)
    applyRainLive(false)
    tell("TONES off\n")
  }

  function startPlayer(nextPreset) {
    var p = Beats.resolvePreset(nextPreset || presetId)
    var wasPlaying = playing
    presetId = p.id
    playing = true
    schedulePersist()
    if (wasPlaying) {
      tell("PRESET " + p.beat + "\n")
      return
    }
    tell("PRESET " + p.beat + "\nTONES on\n")
    restoreBeds()
  }

  function play(id) {
    var p = Beats.resolvePreset(id)
    if (playing && p.id === presetId) {
      silence()
      return
    }
    startPlayer(p.id)
  }

  function stop() {
    silence()
  }

  function toggle() {
    if (sounding) silence()
    else startPlayer(presetId)
  }

  function captureBedPrefs() {
    noise = noiseLive
    rain = rainLive
    schedulePersist()
  }

  function setNoise(value) {
    applyNoiseLive(!!value)
    if (playing) {
      noise = noiseLive
      schedulePersist()
      return
    }
    // No preset running: this click is the new mix, including the bed
    // that is currently off.
    captureBedPrefs()
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

  function rainVolumeValue() {
    // Rain scrub is independent of the oscilloscope / binaural volume.
    // mpv softvol is cubic — invert so 20% scrub ≈ 0.2× amplitude like noise.
    var t = Math.max(0, Math.min(1, rainVolume))
    if (t <= 0)
      return 0
    return Math.round(rainVolumeMax * Math.pow(t, 1.0 / 3.0))
  }

  function applyRainVolume() {
    if (!rainPlayer.running) return
    rainJson(["set_property", "volume", rainVolumeValue()])
  }

  function setVolume(value) {
    var next = Beats.clampVolume(value, volume)
    if (Math.abs(next - volume) < 0.001) return
    volume = next
    schedulePersist()
    // Oscilloscope scrub: binaural beat only — do not touch rain/noise beds.
    tell("VOLUME " + volume + "\n")
  }

  function setNoiseVolume(value) {
    var next = Beats.clampVolume(value, noiseVolume)
    if (Math.abs(next - noiseVolume) >= 0.001) {
      noiseVolume = next
      schedulePersist()
      tell("NOISEVOL " + noiseVolume + "\n")
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

  function startRain() {
    if (rainPlayer.running && !rainNeedsRespawn) {
      rainIpc(false)
      applyRainVolume()
      return
    }
    // Respawn so URL / volume-isolation builds actually take effect.
    rainNeedsRespawn = false
    rainRetry.stop()
    if (rainPlayer.running)
      rainPlayer.running = false
    Quickshell.execDetached(["rm", "-f", rainSock])
    var url = rainUrls[rainUrlIndex % rainUrls.length]
    rainPlayer.command = [
      "mpv", "--no-video", "--really-quiet",
      "--volume=" + String(rainVolumeValue()),
      "--idle=yes",
      "--input-ipc-server=" + rainSock,
      "--audio-client-name=BinauralRain",
      "--network-timeout=10",
      url
    ]
    rainPlayer.running = true
  }

  function stopRain() {
    rainRetry.stop()
    if (rainPlayer.running) rainIpc(true)
  }

  function setRain(value) {
    applyRainLive(!!value)
    if (playing) {
      rain = rainLive
      schedulePersist()
      return
    }
    captureBedPrefs()
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
      noisePref: noise,
      rainPref: rain,
      volume: Math.round(volume * 100),
      noiseVolume: Math.round(noiseVolume * 100),
      rainVolume: Math.round(rainVolume * 100),
      headphones: true
    })
  }

  Timer {
    id: persistTimer
    interval: 400
    repeat: false
    onTriggered: root.persist()
  }

  Timer {
    id: rainVolumeTimer
    interval: 50
    repeat: false
    onTriggered: root.applyRainVolume()
  }

  Component.onCompleted: hydrate()

  Process {
    id: rainIpcProc
  }

  Process {
    id: rainPlayer
    onExited: function() {
      if (root.rainLive) {
        root.rainUrlIndex = (root.rainUrlIndex + 1) % root.rainUrls.length
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
      player.write("VOLUME " + root.volume + "\n")
      player.write("NOISEVOL " + root.noiseVolume + "\n")
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
    function volume(value: string): string {
      if (value !== undefined && value !== null && String(value).length)
        root.setVolume(value)
      return root.statusJson()
    }
  }
}
