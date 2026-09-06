import QtQuick
import qs.Commons

// Single-trace scope: y = sin(2π (x·cycles + phase)) · level.
// `level` 0 is a flat line; 1 is the full tile amplitude.
Item {
  id: root

  property real hz: 10
  property color color: Color.accent
  property bool active: false
  property bool idleVisible: false
  property real cycles: 2.2
  property real phase: 0
  property real level: 1

  visible: active || idleVisible
  implicitWidth: Style.space(88)
  implicitHeight: Style.space(36)

  Timer {
    interval: 16
    repeat: true
    running: root.active && root.visible && root.hz > 0.1
    onTriggered: {
      root.phase = (root.phase + root.hz * interval / 1000.0) % 1
      canvas.requestPaint()
    }
  }

  onWidthChanged: canvas.requestPaint()
  onHeightChanged: canvas.requestPaint()
  onColorChanged: canvas.requestPaint()
  onActiveChanged: canvas.requestPaint()
  onLevelChanged: canvas.requestPaint()
  onVisibleChanged: canvas.requestPaint()

  Canvas {
    id: canvas
    anchors.fill: parent
    antialiasing: true

    onPaint: {
      var ctx = getContext("2d")
      var w = width
      var h = height
      ctx.clearRect(0, 0, w, h)
      if (w < 8 || h < 8) return

      var mid = h / 2
      var amp = h * 0.34 * Math.max(0, Math.min(1, root.level))
      var n = Math.max(32, Math.floor(w))
      ctx.beginPath()
      ctx.lineCap = "round"
      ctx.lineJoin = "round"
      ctx.lineWidth = Math.max(1.25, h * 0.07)
      ctx.strokeStyle = root.color
      for (var i = 0; i <= n; i++) {
        var t = i / n
        var y = mid + Math.sin((t * root.cycles + root.phase) * Math.PI * 2) * amp
        if (i === 0) ctx.moveTo(t * w, y)
        else ctx.lineTo(t * w, y)
      }
      ctx.stroke()

      ctx.globalCompositeOperation = "destination-in"
      var fade = ctx.createLinearGradient(0, 0, w, 0)
      fade.addColorStop(0.00, "rgba(0,0,0,0)")
      fade.addColorStop(0.16, "rgba(0,0,0,1)")
      fade.addColorStop(0.84, "rgba(0,0,0,1)")
      fade.addColorStop(1.00, "rgba(0,0,0,0)")
      ctx.fillStyle = fade
      ctx.fillRect(0, 0, w, h)
      ctx.globalCompositeOperation = "source-over"
    }
  }
}
