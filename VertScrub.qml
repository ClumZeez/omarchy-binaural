import QtQuick
import Quickshell
import qs.Commons

// Vertical volume scrub. Uses global Y so left/right motion is ignored,
// and warps the cursor back in when it hits the screen edge so a drag
// can keep going past the top of the bar.
MouseArea {
  id: root

  property real value: 1
  property real span: Style.space(96)
  property bool dragging: false
  property bool didMove: false
  property real lastGlobalY: 0
  property real warpTargetY: -1
  property int idleCursor: Qt.PointingHandCursor
  property real tapSlop: 3
  // Larger than any real mouse step; smaller than a screen-edge warp.
  readonly property real maxStep: 64

  hoverEnabled: true
  preventStealing: true
  acceptedButtons: Qt.LeftButton
  cursorShape: dragging || didMove ? Qt.SizeVerCursor : idleCursor

  signal scrubbed(real value)
  signal tapped()

  function globalOf(lx, ly) {
    var p = mapToGlobal(lx, ly)
    if (p === undefined || p === null)
      p = mapToGlobal(Qt.point(lx, ly))
    return p
  }

  function screenH() {
    var win = root.QsWindow ? root.QsWindow.window : null
    if (win && win.screen) return win.screen.height
    return 1080
  }

  function warpTo(gx, gy) {
    Quickshell.execDetached([
      "hyprctl", "dispatch",
      "hl.dsp.cursor.move({ x = " + Math.round(gx) + ", y = " + Math.round(gy) + " })"
    ])
  }

  function applyDy(dy) {
    if (Math.abs(dy) < 0.2) return
    root.didMove = true
    var next = Math.max(0, Math.min(1, root.value + dy / Math.max(24, root.span)))
    if (Math.abs(next - root.value) < 0.001) return
    root.scrubbed(next)
  }

  onPressed: {
    root.dragging = true
    root.didMove = false
    root.warpTargetY = -1
    var g = root.globalOf(mouse.x, mouse.y)
    root.lastGlobalY = g.y
  }

  onPositionChanged: {
    if (!pressed) return
    var g = root.globalOf(mouse.x, mouse.y)
    var dy = root.lastGlobalY - g.y

    // Warp is async. Until the cursor actually lands, or if Y jumps by
    // more than a real mouse step, adopt the new Y and do not scrub —
    // that jump is what was slamming volume to 0.
    if (root.warpTargetY >= 0) {
      if (Math.abs(g.y - root.warpTargetY) < 56 || Math.abs(dy) > root.maxStep) {
        root.lastGlobalY = g.y
        root.warpTargetY = -1
      }
      return
    }
    if (Math.abs(dy) > root.maxStep) {
      root.lastGlobalY = g.y
      return
    }

    root.applyDy(dy)
    root.lastGlobalY = g.y

    var sh = root.screenH()
    var wrap = 240
    if (g.y < 24) {
      root.warpTargetY = g.y + wrap
      root.warpTo(g.x, root.warpTargetY)
    } else if (g.y > sh - 24) {
      root.warpTargetY = g.y - wrap
      root.warpTo(g.x, root.warpTargetY)
    }
  }

  onReleased: {
    var wasDrag = root.didMove
    root.dragging = false
    root.didMove = false
    root.warpTargetY = -1
    if (!wasDrag) root.tapped()
  }

  onCanceled: {
    root.dragging = false
    root.didMove = false
    root.warpTargetY = -1
  }

  onWheel: function(w) {
    var step = w.angleDelta.y > 0 ? 0.05 : -0.05
    root.scrubbed(Math.max(0, Math.min(1, root.value + step)))
  }
}
