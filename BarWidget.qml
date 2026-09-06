import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Beats.js" as Beats

// Bar face of binaural beats. The engine lives in Service.qml
// (one per shell); this widget is one per monitor and only renders + relays.
//
//   left click    popup with the six presets and the noise-floor icon
//   right click   master mute / restore (tones + noise + rain)
//   middle click  toggle the brown-noise floor
BarWidget {
  id: root
  moduleName: "callum.binaural"

  readonly property var beats: bar && bar.shell && typeof bar.shell.serviceFor === "function"
    ? bar.shell.serviceFor("callum.binaural") : null
  readonly property bool ready: beats !== null && beats !== undefined
  readonly property bool playing: ready ? beats.playing : false
  readonly property bool noise: ready ? beats.noise : Beats.DEFAULT_NOISE
  readonly property bool rain: ready ? beats.rain : false
  readonly property bool noiseLive: ready ? beats.noiseLive : false
  readonly property bool rainLive: ready ? beats.rainLive : false
  readonly property bool sounding: ready ? beats.sounding : false
  readonly property bool muted: ready ? beats.muted : false
  readonly property real volume: ready ? beats.volume : 1
  readonly property real noiseVolume: ready ? beats.noiseVolume : 1
  readonly property real rainVolume: ready ? beats.rainVolume : 1
  readonly property real beatHz: ready ? beats.beatHz : 10
  readonly property string presetName: ready ? beats.presetName : "Binaural"
  readonly property string effect: ready ? beats.effect : ""
  readonly property string beatText: ready ? beats.beatText : ""
  readonly property var presets: ready ? beats.presets : Beats.PRESETS
  readonly property string presetId: ready ? beats.presetId : Beats.DEFAULT_PRESET
  readonly property var leftPresets: Beats.column(presets, 0)
  readonly property var rightPresets: Beats.column(presets, 1)

  readonly property color accent: Color.accent
  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color iconColor: root.sounding ? root.accent : (root.bar ? root.bar.barForeground : Color.foreground)

  readonly property string tooltip: {
    if (!root.ready) return "Binaural beats"
    if (root.playing)
      return root.presetName + " · " + root.effect + " · " + root.beatText
             + (root.noiseLive ? " · noise" : "")
             + (root.rainLive ? " · rain" : "")
    if (root.muted) return "Binaural — muted, right-click to restore"
    if (root.sounding) return "Binaural — right-click to mute all"
    return "Binaural — click for presets; right-click mutes/restores all"
  }

  property bool popupOpen: false

  readonly property bool opened: popupOpen
  function open() { popupOpen = true }
  function close() { popupOpen = false }
  function togglePanel() { popupOpen = !popupOpen }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  IpcHandler {
    target: "callum.binaural"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
  }

  component PresetTile: BorderSurface {
    id: tile
    property var preset: ({})
    readonly property bool selected: root.playing && preset && preset.id === root.presetId
    readonly property bool hot: tileMouse.containsMouse

    implicitHeight: Style.space(76)
    radius: Style.cornerRadius
    clip: true
    color: selected
      ? Style.selectedFillFor(root.fg, root.accent)
      : (hot ? Style.hoverFillFor(root.fg, root.accent) : Style.normalFillFor(root.fg, root.accent))
    borderSpec: selected
      ? Border.controlSpec("selected", root.fg, root.accent)
      : (hot ? Border.controlSpec("hover-cursor", root.fg, root.accent) : Border.controlSpec("normal", root.fg, root.accent))

    Behavior on color { ColorAnimation { duration: 100 } }

    Row {
      anchors.fill: parent
      anchors.leftMargin: Style.spacing.rowPaddingX
      anchors.rightMargin: Style.spacing.rowPaddingX
      anchors.topMargin: Style.space(10)
      anchors.bottomMargin: Style.space(10)
      spacing: Style.space(8)

      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)

        Text {
          textFormat: Text.PlainText
          text: tile.preset && tile.preset.name ? tile.preset.name : ""
          color: tile.selected ? root.accent : root.fg
          font.family: root.fontFamily
          font.pixelSize: Style.font.subtitle
          font.bold: true
          wrapMode: Text.NoWrap
        }

        Text {
          textFormat: Text.PlainText
          text: tile.preset && tile.preset.effect ? tile.preset.effect : ""
          color: tile.selected ? root.accent : Qt.darker(root.fg, 1.5)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.NoWrap
        }

        Text {
          textFormat: Text.PlainText
          text: tile.preset ? Beats.beatLabel(tile.preset.beat) : ""
          color: tile.selected ? root.accent : Qt.darker(root.fg, 1.35)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 0.6
          wrapMode: Text.NoWrap
        }
      }

      Item {
        width: Math.max(1, parent.width - parent.children[0].width - parent.spacing)
        height: parent.height

        Oscilloscope {
          anchors.centerIn: parent
          width: Math.min(parent.width, parent.height * 2.4)
          height: Math.min(parent.height * 0.78, parent.width * 0.5)
          hz: tile.preset && tile.preset.beat ? tile.preset.beat : 10
          color: root.accent
          active: tile.selected
        }
      }
    }

    MouseArea {
      id: tileMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: if (root.ready && tile.preset && tile.preset.id) root.beats.play(tile.preset.id)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    labelVisible: false
    hasVisualContent: true
    keepSpace: true
    foreground: root.iconColor
    dimmed: false
    useActiveColor: false
    tooltipText: root.tooltip
    horizontalMargin: 8.75
    verticalPadding: 8.75
    fixedWidth: {
      if (root.vertical) return -1
      if (root.playing) return contentRow.implicitWidth + Style.spaceReal(8.75) * 2
      return Style.bar.iconSlot
    }
    fixedHeight: root.vertical ? Style.bar.iconSlot : -1

    onPressed: function(b) {
      if (!root.ready) return
      if (b === Qt.RightButton) root.beats.toggle()
      else if (b === Qt.MiddleButton) root.beats.toggleNoise()
      else root.togglePanel()
    }

    Row {
      id: contentRow
      anchors.centerIn: parent
      spacing: Style.space(6)

      SineIcon {
        iconSize: Style.bar.iconCanvas
        color: root.iconColor
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        visible: root.playing && !root.vertical
        textFormat: Text.PlainText
        text: root.presetName
        color: root.iconColor
        font.family: button.fontFamily
        font.pixelSize: button.fontSize
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(456))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(12)

      Item {
        width: parent.width
        height: Math.max(heroIcon.height, heroCopy.height, floorControls.height)

        SineIcon {
          id: heroIcon
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          iconSize: Style.font.display
          color: root.playing ? root.accent : root.fg
        }

        Column {
          id: heroCopy
          anchors.left: heroIcon.right
          anchors.leftMargin: Style.space(14)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)
          width: Math.max(titleLine.width, heroMeta.implicitWidth)

          Item {
            id: titleLine
            readonly property int hzPadX: Style.space(5)
            readonly property int hzPadY: Style.space(3)
            readonly property int rawPillY: Math.round(heroTitle.baselineOffset - hzLabel.baselineOffset - hzPadY)
            readonly property int lift: Math.max(0, -rawPillY)
            width: heroTitle.implicitWidth + (hzPill.visible ? Style.space(8) + hzPill.width : 0)
            height: {
              var h = lift + heroTitle.implicitHeight
              if (hzPill.visible)
                h = Math.max(h, lift + rawPillY + hzPill.height)
              return h
            }

            Text {
              id: heroTitle
              x: 0
              y: titleLine.lift
              textFormat: Text.PlainText
              text: root.playing ? root.presetName : "Binaural"
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }

            BorderSurface {
              id: hzPill
              visible: root.playing
              x: heroTitle.x + heroTitle.implicitWidth + Style.space(8)
              y: titleLine.lift + titleLine.rawPillY
              width: hzLabel.implicitWidth + titleLine.hzPadX * 2
              height: hzLabel.implicitHeight + titleLine.hzPadY * 2
              color: "transparent"
              borderSpec: Border.controlSpec("normal", root.fg, root.accent)
              radius: Math.min(Style.cornerRadius, Math.floor(height / 2))

              Text {
                id: hzLabel
                x: titleLine.hzPadX
                y: titleLine.hzPadY
                textFormat: Text.PlainText
                text: root.beatText
                color: Qt.darker(root.fg, 1.4)
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }
            }
          }

          Text {
            id: heroMeta
            textFormat: Text.PlainText
            text: (root.playing ? root.effect : "Headphones").toUpperCase()
            color: Qt.darker(root.fg, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1.2
            wrapMode: Text.NoWrap
          }
        }

        VolumeScope {
          id: volScope
          anchors.left: heroCopy.right
          anchors.leftMargin: Style.space(10)
          anchors.right: floorControls.left
          anchors.rightMargin: Style.space(4)
          anchors.verticalCenter: parent.verticalCenter
          height: parent.height
          volume: root.volume
          // Wave runs only while a preset is actually playing — beds alone
          // must not look like a selected beat.
          active: root.playing
          hz: root.playing ? root.beatHz : 10
          color: root.accent
          idleColor: Qt.darker(root.fg, 1.35)
          fontFamily: root.fontFamily
          onMoved: function(v) { if (root.ready) root.beats.setVolume(v) }
        }

        Row {
          id: floorControls
          anchors.right: parent.right
          anchors.rightMargin: Style.space(4)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(7)

          FloorButton {
            on: root.noiseLive
            tip: "Noise"
            volume: root.noiseVolume
            glyph: noiseGlyph
            onActivated: if (root.ready) root.beats.toggleNoise()
            onVolumeMoved: function(v) { if (root.ready) root.beats.setNoiseVolume(v) }
          }
          FloorButton {
            on: root.rainLive
            tip: "Rain"
            volume: root.rainVolume
            glyph: rainGlyph
            onActivated: if (root.ready) root.beats.toggleRain()
            onVolumeMoved: function(v) { if (root.ready) root.beats.setRainVolume(v) }
          }
        }
      }

      Row {
        width: parent.width
        spacing: Style.space(8)

        Column {
          width: (parent.width - parent.spacing) / 2
          spacing: Style.space(8)

          Repeater {
            model: root.leftPresets
            PresetTile {
              required property var modelData
              width: parent.width
              preset: modelData
            }
          }
        }

        Column {
          width: (parent.width - parent.spacing) / 2
          spacing: Style.space(8)

          Repeater {
            model: root.rightPresets
            PresetTile {
              required property var modelData
              width: parent.width
              preset: modelData
            }
          }
        }
      }
    }
  }

  component FloorButton: Item {
    id: floor
    property bool on: false
    property string tip: ""
    property real volume: 1
    property Component glyph: null
    signal activated()
    signal volumeMoved(real volume)

    implicitWidth: glyphLoader.item ? Math.ceil(glyphLoader.item.width) : Style.font.display
    implicitHeight: Style.space(44)

    readonly property bool hot: scrub.containsMouse || scrub.dragging
    readonly property color glyphColor: {
      // Off / 0%: inactive (full rest mark). On: accent, lighter while hot.
      if (!floor.on || floor.volume <= 0.001)
        return root.fg
      if (floor.hot)
        return Qt.lighter(root.accent, 1.18)
      return root.accent
    }

    Loader {
      id: glyphLoader
      anchors.centerIn: parent
      sourceComponent: floor.glyph
      onLoaded: {
        if (!item) return
        item.iconSize = Style.font.display
        item.color = Qt.binding(function() { return floor.glyphColor })
        if (item.level !== undefined)
          item.level = Qt.binding(function() { return floor.volume })
        if (item.scrubbing !== undefined)
          item.scrubbing = Qt.binding(function() { return scrub.dragging })
      }
    }

    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: Math.round(floor.volume * 100) + "%"
      color: floor.glyphColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      opacity: scrub.dragging ? 1 : 0
      z: 2

      Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    VertScrub {
      id: scrub
      anchors.fill: parent
      value: floor.volume
      onScrubbed: function(v) { floor.volumeMoved(v) }
      onTapped: {
        // Click at 0% restores a usable level; a drag from 0% stays at 0%.
        if (floor.volume <= 0.001)
          floor.volumeMoved(0.5)
        else
          floor.activated()
      }
    }

    PanelToolTip {
      visible: scrub.containsMouse && !scrub.dragging
      text: floor.tip
      fontFamily: root.fontFamily
    }
  }

  Component {
    id: noiseGlyph
    NoiseIcon { iconSize: Style.font.display }
  }

  Component {
    id: rainGlyph
    RainIcon { iconSize: Style.font.display }
  }
}
