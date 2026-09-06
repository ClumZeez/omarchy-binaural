import QtQuick
import QtQuick.Effects
import qs.Commons

// Noun Project sine mark (assets/SineWave.svg), tinted to the theme.
Item {
  id: root

  property color color: Color.foreground
  property real iconSize: Style.bar.iconCanvas

  implicitWidth: iconSize
  implicitHeight: iconSize
  width: iconSize
  height: iconSize

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

  Behavior on color { ColorAnimation { duration: 100 } }

  MultiEffect {
    anchors.fill: src
    source: src
    colorization: 1.0
    colorizationColor: root.color
  }
}
