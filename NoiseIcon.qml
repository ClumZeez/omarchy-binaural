import QtQuick
import qs.Commons

// While dragging: lattice size follows volume (1% = small, 0% = gone).
// At rest: full default mark (launch look); color from FloorButton.
Item {
  id: root

  property color color: Color.foreground
  property real iconSize: Style.font.icon
  property real level: 1
  property bool scrubbing: false

  implicitWidth: iconSize
  implicitHeight: iconSize
  width: iconSize
  height: iconSize
  opacity: (root.scrubbing && Math.round(Math.max(0, Math.min(1, root.level)) * 100) <= 0) ? 0 : 1

  readonly property var dots: [
    [13, 7], [25, 7],
    [7, 13], [19, 13],
    [13, 19], [25, 19],
    [7, 25], [19, 25]
  ]

  Behavior on color { ColorAnimation { duration: 100 } }
  Behavior on opacity { NumberAnimation { duration: 80 } }
  onColorChanged: canvas.requestPaint()
  onLevelChanged: canvas.requestPaint()
  onScrubbingChanged: canvas.requestPaint()
  onWidthChanged: canvas.requestPaint()
  onHeightChanged: canvas.requestPaint()

  Canvas {
    id: canvas
    anchors.fill: parent
    antialiasing: true

    onPaint: {
      var ctx = getContext("2d")
      var w = width
      var h = height
      ctx.clearRect(0, 0, w, h)
      var level = Math.max(0, Math.min(1, root.level))
      if (root.scrubbing && Math.round(level * 100) <= 0)
        return
      var t = root.scrubbing ? Math.max(0.08, level) : 1
      var s = Math.min(w, h) / 32
      var r = 3 * s * (0.12 + 0.88 * t)
      ctx.fillStyle = root.color
      for (var i = 0; i < root.dots.length; i++) {
        var d = root.dots[i]
        ctx.beginPath()
        ctx.arc(d[0] * s, d[1] * s, r, 0, Math.PI * 2)
        ctx.fill()
      }
    }
  }
}
