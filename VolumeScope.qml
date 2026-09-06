import QtQuick
import qs.Commons

// Header volume: the gap between the title and the floor icons.
// Wave fills the space. Drag straight up/down — the cursor wraps at the
// screen edge so you can keep going past the top of the bar.
Item {
  id: root

  property real volume: 1
  property bool active: false
  property real hz: 10
  property color color: Color.accent
  property color idleColor: Color.foreground
  property string fontFamily: Style.font.family

  readonly property bool hot: scrub.containsMouse || scrub.dragging

  signal moved(real volume)

  implicitWidth: Style.space(120)
  implicitHeight: Style.space(36)

  Oscilloscope {
    id: scope
    anchors.fill: parent
    idleVisible: true
    active: root.active
    hz: root.hz
    level: root.volume
    color: root.active ? root.color : root.idleColor
    // Always show the volume waveform — idle uses idleColor, playing animates.
    opacity: 1
  }

  Text {
    id: percent
    anchors.centerIn: parent
    textFormat: Text.PlainText
    text: Math.round(root.volume * 100) + "%"
    color: root.active ? root.color : root.idleColor
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    opacity: root.hot ? 1 : 0

    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
  }

  VertScrub {
    id: scrub
    anchors.fill: parent
    value: root.volume
    idleCursor: Qt.SizeVerCursor
    onScrubbed: function(v) { root.moved(v) }
    onTapped: {
      // Match floor icons: click mutes an active level; click at 0% restores 50%.
      if (!root.active)
        return
      if (root.volume <= 0.001)
        root.moved(0.5)
      else
        root.moved(0)
    }
  }
}
