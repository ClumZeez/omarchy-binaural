import QtQuick
import QtQuick.Effects
import qs.Commons

// At rest: Noun Project sine mark. While scrubbing: canvas sine tracks level
// live (no SVG snap). On release: wavelength lerps toward 100 Hz (restLevel)
// while an Animorphs-style crossfade+scale dissolves into the logo.
Item {
  id: root

  property color color: Color.foreground
  property real iconSize: Style.bar.iconCanvas
  property real level: 1
  property bool scrubbing: false
  property real restLevel: (100 - 60) / (200 - 60)

  // 0 = full dynamic canvas, 1 = full logo.
  property real morph: 1
  // Level used for canvas cycles — live while scrubbing; eases to restLevel on release.
  property real paintLevel: restLevel

  implicitWidth: iconSize
  implicitHeight: iconSize
  width: iconSize
  height: iconSize

  Behavior on color { ColorAnimation { duration: 100 } }

  Behavior on morph {
    id: morphBehavior
    enabled: true
    NumberAnimation { duration: 380; easing.type: Easing.InOutCubic }
  }

  Behavior on paintLevel {
    id: paintLevelBehavior
    enabled: true
    NumberAnimation { duration: 380; easing.type: Easing.InOutCubic }
  }

  onScrubbingChanged: {
    if (scrubbing) {
      morphBehavior.enabled = false
      paintLevelBehavior.enabled = false
      morph = 0
      paintLevel = level
      morphBehavior.enabled = true
      // Keep paintLevel live (no easing) while dragging — re-enable only on release.
    } else {
      paintLevelBehavior.enabled = true
      paintLevel = restLevel
      morph = 1
    }
    wave.requestPaint()
  }

  onLevelChanged: {
    if (scrubbing) {
      paintLevel = level
      wave.requestPaint()
    }
  }

  onPaintLevelChanged: wave.requestPaint()
  onColorChanged: wave.requestPaint()
  onWidthChanged: wave.requestPaint()
  onHeightChanged: wave.requestPaint()

  Image {
    id: src
    anchors.fill: parent
    source: Qt.resolvedUrl("assets/SineWave.svg")
    fillMode: Image.PreserveAspectFit
    sourceSize.width: Math.max(32, Math.round(width * 2))
    sourceSize.height: Math.max(32, Math.round(height * 2))
    visible: false
    layer.enabled: true
    asynchronous: false
  }

  MultiEffect {
    id: restMark
    anchors.centerIn: parent
    width: src.width
    height: src.height
    source: src
    colorization: 1.0
    colorizationColor: root.color
    opacity: root.morph
    scale: 0.82 + 0.18 * root.morph
    visible: root.morph > 0.001
    z: 1
  }

  Canvas {
    id: wave
    anchors.centerIn: parent
    width: parent.width
    height: parent.height
    antialiasing: true
    opacity: 1 - root.morph
    scale: 1.08 - 0.08 * root.morph
    visible: root.morph < 0.999
    z: 0

    onPaint: {
      var ctx = getContext("2d")
      var w = width
      var h = height
      ctx.clearRect(0, 0, w, h)

      var level = Math.max(0, Math.min(1, root.paintLevel))
      // Hz from the 60–200 band. Anchor: 100 Hz → 2 cycles (logo match).
      // Power < 1 keeps growing past 150 without getting needle-thin at 200
      // (linear hit the old hard cap of 3 at 150 and froze).
      var hz = 60 + level * 140
      var cycles = 2 * Math.pow(hz / 100, 0.65)

      var pad = Math.max(1, w * 0.10)
      var amp = h * 0.25
      var mid = h * 0.5
      var lw = Math.max(1.5, Math.min(w, h) * 0.09)

      ctx.strokeStyle = root.color
      ctx.lineWidth = lw
      ctx.lineCap = "round"
      ctx.lineJoin = "round"
      ctx.beginPath()
      var first = true
      var steps = Math.max(64, Math.round(w * 3))
      for (var i = 0; i <= steps; i++) {
        var t = i / steps
        var x = pad + t * (w - pad * 2)
        var y = mid - Math.sin(t * cycles * Math.PI * 2) * amp
        if (first) { ctx.moveTo(x, y); first = false }
        else ctx.lineTo(x, y)
      }
      ctx.stroke()
    }
  }
}
