import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Beats.js" as Beats

// Bar face of binaural beats. The engine lives in Service.qml
// (one per shell); this widget is one per monitor and only renders + relays.
//
//   left click    popup with the six presets and bed controls
//   right click   master mute / restore (tones + noise + rain)
//   in popup      arrows move focus; Enter/Space activates; Esc closes
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
    return "Binaural — click for presets (arrows + Enter in popup); right-click mutes/restores all"
  }

  property bool popupOpen: false

  // Keyboard cursor inside the popup. Beds sit on row -1; presets are a 2×3 grid.
  property int cursorRow: 0
  property int cursorCol: 0

  readonly property bool opened: popupOpen
  function open() {
    popupOpen = true
    resetCursor()
  }
  function close() { popupOpen = false }
  function togglePanel() {
    popupOpen = !popupOpen
    if (popupOpen) resetCursor()
  }

  function presetAt(row, col) {
    var list = root.presets
    if (!Array.isArray(list)) return null
    var i = row * 2 + col
    return (i >= 0 && i < list.length) ? list[i] : null
  }

  function resetCursor() {
    // Land on the playing preset when possible; otherwise Alpha.
    if (root.playing && root.presetId) {
      var list = root.presets
      for (var i = 0; i < list.length; i++) {
        if (list[i] && list[i].id === root.presetId) {
          cursorRow = Math.floor(i / 2)
          cursorCol = i % 2
          return
        }
      }
    }
    cursorRow = 1
    cursorCol = 0
  }

  function moveCursor(dx, dy) {
    var row = cursorRow + dy
    var col = cursorCol + dx
    if (row < -1) row = -1
    if (row > 2) row = 2
    if (col < 0) col = 0
    if (col > 1) col = 1
    cursorRow = row
    cursorCol = col
  }

  function cursorOnNoise() { return cursorRow < 0 && cursorCol === 0 }
  function cursorOnRain() { return cursorRow < 0 && cursorCol === 1 }
  function cursorOnPreset(id) {
    if (cursorRow < 0) return false
    var p = presetAt(cursorRow, cursorCol)
    return !!(p && p.id === id)
  }

  function activateCursor() {
    if (!root.ready) return
    if (cursorRow < 0) {
      if (cursorCol === 0) root.beats.toggleNoise()
      else root.beats.toggleRain()
      return
    }
    var p = presetAt(cursorRow, cursorCol)
    if (p && p.id) root.beats.play(p.id)
  }

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
    readonly property bool hasCursor: preset && root.cursorOnPreset(preset.id)
    // Theme selected-border-width defaults to 0; force a 1px box so the
    // grid seams stay visible (and so a selected fill edge cannot stand
    // in for a neighbor's missing left border).
    readonly property var tileBorderSpec: {
      var state = selected ? "selected" : (hasCursor ? "focus" : (hot ? "hover-cursor" : "normal"))
      var spec = Border.controlSpec(state, root.fg, root.accent)
      var w = Math.max(Border.left(spec), Border.right(spec), Border.top(spec), Border.bottom(spec), Border.uniformWidth(spec))
      if (w <= 0)
        return Border.withWidth(spec, Math.max(1, Style.normalBorderWidth))
      return spec
    }

    implicitHeight: Style.space(76)
    radius: Style.cornerRadius
    // Do not clip — BorderOverlay AA sits on the edge and clip eats it.
    color: selected
      ? Style.selectedFillFor(root.fg, root.accent)
      : Style.controlFill(hasCursor, hot, root.fg, root.accent)
    borderSpec: tileBorderSpec

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
    // Keep playing-chip width stable across presets so the popup anchor
    // does not drift when switching Delta↔SMR↔Gamma (SMR is shortest).
    fixedWidth: {
      if (root.vertical) return -1
      if (root.playing) {
        return Math.ceil(
          Style.bar.iconCanvas + Style.space(6) + longestPresetLabel.implicitWidth
          + Style.spaceReal(8.75) * 2
        )
      }
      return Style.bar.iconSlot
    }
    fixedHeight: root.vertical ? Style.bar.iconSlot : -1

    Text {
      id: longestPresetLabel
      visible: false
      textFormat: Text.PlainText
      text: {
        var best = "Gamma"
        var list = root.presets
        for (var i = 0; i < list.length; i++) {
          var n = list[i] && list[i].name ? String(list[i].name) : ""
          if (n.length > best.length) best = n
        }
        return best
      }
      font.family: button.fontFamily
      font.pixelSize: button.fontSize
    }

    onPressed: function(b) {
      if (!root.ready) return
      if (b === Qt.MiddleButton) return
      if (b === Qt.RightButton) root.beats.toggle()
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
        width: longestPresetLabel.implicitWidth
        elide: Text.ElideNone
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  KeyboardPanel {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    focusTarget: keyCatcher
    contentWidth: popup.fittedContentWidth(Style.space(456))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: root.activateCursor()

    Column {
      id: column
      width: parent.width
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
            hasCursor: root.cursorOnNoise()
            tip: "Noise"
            volume: root.noiseVolume
            glyph: noiseGlyph
            onActivated: if (root.ready) root.beats.toggleNoise()
            onVolumeMoved: function(v) { if (root.ready) root.beats.setNoiseVolume(v) }
          }
          FloorButton {
            on: root.rainLive
            hasCursor: root.cursorOnRain()
            tip: "Rain"
            volume: root.rainVolume
            glyph: rainGlyph
            onActivated: if (root.ready) root.beats.toggleRain()
            onVolumeMoved: function(v) { if (root.ready) root.beats.setRainVolume(v) }
          }
        }
      }

      Row {
        // Floor column widths so an odd leftover pixel cannot overlap the
        // neighbor. A 1px overlap lets the selected fill cover the right
        // column's left border (visible when a left-column preset is on).
        id: presetRow
        width: parent.width
        spacing: Style.space(10)
        readonly property int colWidth: Math.max(1, Math.floor((width - spacing) / 2))

        Column {
          width: presetRow.colWidth
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
          width: presetRow.colWidth
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
  }

  component FloorButton: Item {
    id: floor
    property bool on: false
    property bool hasCursor: false
    property string tip: ""
    property real volume: 1
    property Component glyph: null
    signal activated()
    signal volumeMoved(real volume)

    implicitWidth: glyphLoader.item ? Math.ceil(glyphLoader.item.width) : Style.font.display
    implicitHeight: Style.space(44)

    readonly property bool hot: scrub.containsMouse || scrub.dragging
    readonly property color glyphColor: {
      // Keyboard cursor wins; else off/0% is inactive; on is accent (lighter while hot).
      if (floor.hasCursor)
        return root.accent
      if (!floor.on || floor.volume <= 0.001)
        return root.fg
      if (floor.hot)
        return Qt.lighter(root.accent, 1.18)
      return root.accent
    }

    BorderSurface {
      anchors.centerIn: parent
      width: Math.ceil((glyphLoader.item ? glyphLoader.item.width : Style.font.display) + Style.space(10))
      height: Math.ceil(Style.font.display + Style.space(10))
      radius: Math.min(Style.cornerRadius, Math.floor(height / 2))
      color: floor.hasCursor ? Style.focusFillFor(root.fg, root.accent) : "transparent"
      borderSpec: floor.hasCursor
        ? Border.controlSpec("focus", root.fg, root.accent)
        : Border.controlSpec("normal", root.fg, root.accent)
      opacity: floor.hasCursor ? 1 : 0
      z: 0
      Behavior on opacity { NumberAnimation { duration: 100 } }
    }

    Loader {
      id: glyphLoader
      anchors.centerIn: parent
      z: 1
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
