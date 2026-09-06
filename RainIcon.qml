import QtQuick
import qs.Commons

// While dragging: size follows volume (1% = small, 0% = gone).
// At rest: always the full default mark (launch look); color comes from FloorButton.
Item {
  id: root

  property color color: Color.foreground
  property real iconSize: Style.font.icon
  property real level: 1
  property bool scrubbing: false
  readonly property real drawn: iconSize * 1.24

  implicitWidth: drawn
  implicitHeight: drawn
  width: drawn
  height: drawn
  // Only hide at 0% while actively scrubbing; rest always shows the mark.
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
      // Rest = full mark; scrub = volume, with a floor so 1% stays visible.
      var t = root.scrubbing ? Math.max(0.08, level) : 1
      var s = Math.min(w, h) / 32
      var ww = 2.45 * s
      var hh = 7.0 * t * s
      var r = Math.min(ww, hh) / 2
      ctx.fillStyle = root.color
      for (var i = 0; i < root.dots.length; i++) {
        var d = root.dots[i]
        var x = d[0] * s - ww / 2
        var y = d[1] * s - hh * 0.32
        ctx.beginPath()
        if (ctx.roundRect) {
          ctx.roundRect(x, y, ww, hh, r)
        } else {
          ctx.arc(x + r, y + r, r, Math.PI, 0, false)
          ctx.arc(x + r, y + hh - r, r, 0, Math.PI, false)
          ctx.closePath()
        }
        ctx.fill()
      }
    }
  }
}
