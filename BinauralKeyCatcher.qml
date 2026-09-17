import QtQuick

// PanelKeyCatcher plus Shift+Up/Down/K/J → nudgeRequested(+1/-1).
// Up/K increases, Down/J decreases. Plain arrows / hjkl still move focus.
Item {
  id: root

  property bool blocked: false

  signal moveRequested(int dx, int dy)
  signal nudgeRequested(int dir)
  signal activateRequested()
  signal returnRequested()
  signal closeRequested()
  signal deleteRequested()
  signal tabRequested(int direction)
  signal textKey(string text)

  focus: true
  Keys.priority: Keys.BeforeItem
  Keys.onPressed: function(event) {
    if (blocked) return
    // Auto-repeat (key held) is intentional — 1-unit steps rely on it.

    if (event.key === Qt.Key_Escape) {
      closeRequested(); event.accepted = true; return
    }
    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
      tabRequested((event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Backtab ? -1 : 1)
      event.accepted = true
      return
    }

    var shift = !!(event.modifiers & Qt.ShiftModifier)
    var t = event.text || ""
    // Shift+Up/K raise; Shift+Down/J lower — same as value scrub.
    if (shift && (event.key === Qt.Key_Up || event.key === Qt.Key_K || t === "k" || t === "K")) {
      nudgeRequested(1)
      event.accepted = true
      return
    }
    if (shift && (event.key === Qt.Key_Down || event.key === Qt.Key_J || t === "j" || t === "J")) {
      nudgeRequested(-1)
      event.accepted = true
      return
    }

    if (event.key === Qt.Key_Down || t === "j") {
      moveRequested(0, 1); event.accepted = true; return
    }
    if (event.key === Qt.Key_Up || t === "k") {
      moveRequested(0, -1); event.accepted = true; return
    }
    if (event.key === Qt.Key_Right || t === "l") {
      moveRequested(1, 0); event.accepted = true; return
    }
    if (event.key === Qt.Key_Left || t === "h") {
      moveRequested(-1, 0); event.accepted = true; return
    }
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      returnRequested()
      activateRequested(); event.accepted = true; return
    }
    if (event.key === Qt.Key_Space) {
      activateRequested(); event.accepted = true; return
    }
    if (t === "x" || t === "X") {
      deleteRequested(); event.accepted = true; return
    }
    if (t && t.length === 1) {
      textKey(t)
    }
  }
}
