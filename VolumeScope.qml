import QtQuick
import qs.Commons
import qs.Ui

// Header amplitude wave. Drag / Shift nudges level; tap / Space toggles mute
// (remembers last audible level). Value sits below so it never covers the wave.
Item {
  id: root

  property real volume: 1
  property bool hasCursor: false
  property bool nudging: false
  property bool active: false
  property real hz: 10
  property color color: Color.accent
  property color idleColor: Color.foreground
  property string fontFamily: Style.font.family
  property int iconBand: Style.space(44)
  property int valueBand: Style.font.caption + Style.space(4)

  readonly property bool hot: scrub.containsMouse || scrub.valueScrubbing || root.nudging
  readonly property bool showValue: hot || hasCursor || scrub.valueScrubbing
  // Grey when tones off — volume % is independent (like carrier Hz).
  readonly property color paintColor: root.active ? root.color : root.idleColor

  signal moved(real volume)
  signal activated()

  implicitWidth: Style.space(120)
  implicitHeight: iconBand + valueBand
  height: implicitHeight

  BorderSurface {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: root.iconBand
    anchors.margins: 0
    anchors.leftMargin: -Style.space(4)
    anchors.rightMargin: -Style.space(4)
    radius: Style.cornerRadius
    color: root.hasCursor ? Style.focusFillFor(root.idleColor, root.color) : "transparent"
    borderSpec: root.hasCursor
      ? Border.controlSpec("focus", root.idleColor, root.color)
      : Border.controlSpec("normal", root.idleColor, root.color)
    opacity: root.hasCursor ? 1 : 0
    z: 0
    Behavior on opacity { NumberAnimation { duration: 100 } }
  }

  Oscilloscope {
    id: scope
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: root.iconBand
    z: 1
    idleVisible: true
    active: root.active
    hz: root.hz
    level: root.volume
    color: root.paintColor
    opacity: 1
  }

  Text {
    id: percent
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: root.iconBand
    z: 2
    textFormat: Text.PlainText
    text: Math.round(root.volume * 100) + "%"
    color: root.paintColor
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    opacity: root.showValue ? 1 : 0

    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
  }

  VertScrub {
    id: scrub
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: root.iconBand
    value: root.volume
    idleCursor: Qt.SizeVerCursor
    onScrubbed: function(v) { root.moved(v) }
    onTapped: root.activated()
  }
}
