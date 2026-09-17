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
  readonly property real carrierHz: ready ? beats.carrierHz : Beats.DEFAULT_CARRIER
  readonly property real carrierLevel: Beats.levelFromCarrier(carrierHz)
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

  // Keyboard cursor. Header row (-1): carrier | volume | noise | rain.
  // Preset rows 0–2: 2-column grid. Focus rings only while keyboardNavActive.
  // Shift+Up/Down nudges the focused header control (Hz / %).
  property int cursorRow: 0
  property int cursorCol: 0
  property bool keyboardNavActive: false
  // True briefly while Shift-nudging so icons match drag scrub visuals.
  property bool nudgeFlash: false

  readonly property int headerCols: 4
  readonly property int presetCols: 2
  readonly property real volumeStep: 0.01
  readonly property real carrierStep: 1
  readonly property int headerIconH: Style.space(44)
  readonly property int headerValueH: Style.font.caption + Style.space(4)

  readonly property bool opened: popupOpen
  function open() {
    popupOpen = true
    keyboardNavActive = false
    resetCursor()
  }
  function close() {
    popupOpen = false
    keyboardNavActive = false
  }
  function togglePanel() {
    popupOpen = !popupOpen
    if (popupOpen) {
      keyboardNavActive = false
      resetCursor()
    } else {
      keyboardNavActive = false
    }
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

  function focusPreset(id) {
    keyboardNavActive = false
    var list = root.presets
    if (!Array.isArray(list)) return
    for (var i = 0; i < list.length; i++) {
      if (list[i] && list[i].id === id) {
        cursorRow = Math.floor(i / 2)
        cursorCol = i % 2
        return
      }
    }
  }

  function focusBed(which) {
    keyboardNavActive = false
    cursorRow = -1
    cursorCol = (String(which) === "rain") ? 3 : 2
  }

  function focusHeader(which) {
    keyboardNavActive = false
    cursorRow = -1
    var w = String(which || "")
    if (w === "carrier") cursorCol = 0
    else if (w === "volume") cursorCol = 1
    else if (w === "rain") cursorCol = 3
    else cursorCol = 2
  }

  function headerColMax() { return root.headerCols - 1 }

  function moveCursor(dx, dy) {
    keyboardNavActive = true
    var row = cursorRow
    var col = cursorCol

    if (row < 0) {
      // Header strip.
      if (dy > 0) {
        // Down into presets: carrier/volume → left col, noise/rain → right.
        cursorRow = 0
        cursorCol = col >= 2 ? 1 : 0
        return
      }
      if (dy < 0)
        return
      col = col + dx
      if (col < 0) col = 0
      if (col > headerColMax()) col = headerColMax()
      cursorCol = col
      return
    }

    // Preset grid.
    if (dy < 0 && row === 0) {
      cursorRow = -1
      // Left preset col → carrier; right → noise (skip volume unless coming from right via left).
      cursorCol = col === 0 ? 0 : 2
      return
    }

    row = row + dy
    col = col + dx
    if (row < 0) row = 0
    if (row > 2) row = 2
    if (col < 0) col = 0
    if (col > 1) col = 1
    cursorRow = row
    cursorCol = col
  }

  function cursorOnCarrier() { return cursorRow < 0 && cursorCol === 0 }
  function cursorOnVolume() { return cursorRow < 0 && cursorCol === 1 }
  function cursorOnNoise() { return cursorRow < 0 && cursorCol === 2 }
  function cursorOnRain() { return cursorRow < 0 && cursorCol === 3 }
  function cursorOnPreset(id) {
    if (cursorRow < 0) return false
    var p = presetAt(cursorRow, cursorCol)
    return !!(p && p.id === id)
  }

  function nudgeFocused(dir) {
    if (!root.ready) return
    keyboardNavActive = true
    nudgeFlash = true
    nudgeFlashTimer.restart()
    var d = dir >= 0 ? 1 : -1
    if (cursorRow >= 0) return
    if (cursorOnCarrier()) {
      root.beats.setCarrier(root.carrierHz + d * root.carrierStep)
      return
    }
    if (cursorOnVolume()) {
      root.beats.setVolume(Math.max(0, Math.min(1, root.volume + d * root.volumeStep)))
      return
    }
    if (cursorOnNoise()) {
      root.beats.setNoiseVolume(Math.max(0, Math.min(1, root.noiseVolume + d * root.volumeStep)))
      return
    }
    if (cursorOnRain()) {
      root.beats.setRainVolume(Math.max(0, Math.min(1, root.rainVolume + d * root.volumeStep)))
    }
  }

  function activateCursor() {
    if (!root.ready) return
    keyboardNavActive = true
    if (cursorRow < 0) {
      // Header: Space is on/off only — levels move via drag / Shift+Up/Down.
      if (cursorOnCarrier()) { root.beats.toggleTones(); return }
      if (cursorOnVolume()) { root.beats.toggleTones(); return }
      if (cursorOnNoise()) { root.beats.toggleNoise(); return }
      if (cursorOnRain()) { root.beats.toggleRain(); return }
      return
    }
    var p = presetAt(cursorRow, cursorCol)
    if (p && p.id) root.beats.play(p.id)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Timer {
    id: nudgeFlashTimer
    interval: 120
    onTriggered: root.nudgeFlash = false
  }

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
    readonly property bool hasCursor: root.keyboardNavActive && preset && root.cursorOnPreset(preset.id)
    // Theme selected-border-width defaults to 0; force a 1px box so the
    // grid seams stay visible (and so a selected fill edge cannot stand
    // in for a neighbor's missing left border).
    readonly property var tileBorderSpec: {
      // Focus ring must win over selected fill — otherwise the playing preset
      // looks unfocused while the keyboard is parked on it.
      var state = hasCursor ? "focus" : (selected ? "selected" : (hot ? "hover-cursor" : "normal"))
      var spec = Border.controlSpec(state, root.fg, root.accent)
      var w = Math.max(Border.left(spec), Border.right(spec), Border.top(spec), Border.bottom(spec), Border.uniformWidth(spec))
      if (w <= 0)
        return Border.withWidth(spec, Math.max(1, Style.normalBorderWidth))
      return spec
    }

    implicitHeight: Style.space(76)
    radius: Style.cornerRadius
    // Do not clip — BorderOverlay AA sits on the edge and clip eats it.
    color: hasCursor
      ? Style.focusFillFor(root.fg, root.accent)
      : (selected
        ? Style.selectedFillFor(root.fg, root.accent)
        : Style.controlFill(false, hot, root.fg, root.accent))
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
      onClicked: {
        if (!root.ready || !tile.preset || !tile.preset.id) return
        root.focusPreset(tile.preset.id)
        root.beats.play(tile.preset.id)
      }
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
    // Name only when playing with the popup closed — keeps the chip compact
    // while the popup is open so toggling presets cannot slide the anchor.
    fixedWidth: {
      if (root.vertical) return -1
      if (root.playing && !root.popupOpen) {
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
        restLevel: Beats.levelFromCarrier(Beats.DEFAULT_CARRIER)
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        visible: root.playing && !root.popupOpen && !root.vertical
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

    BinauralKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onNudgeRequested: function(dir) { root.nudgeFocused(dir) }
      onActivateRequested: root.activateCursor()

    Column {
      id: column
      width: parent.width
      spacing: Style.space(12)

      Item {
        id: headerRow
        width: parent.width
        height: root.headerIconH + root.headerValueH

        Item {
          id: heroIcon
          anchors.left: parent.left
          anchors.top: parent.top
          // Width follows the icon only — Hz text uses a fixed slot so
          // 99→100 Hz cannot shove amplitude / beds sideways.
          width: heroSine.width
          height: root.headerIconH + root.headerValueH

          BorderSurface {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Math.max(0, Math.round((root.headerIconH - heroSine.height - Style.space(10)) / 2))
            width: Math.ceil(heroSine.width + Style.space(10))
            height: Math.ceil(heroSine.height + Style.space(10))
            radius: Math.min(Style.cornerRadius, Math.floor(height / 2))
            color: root.keyboardNavActive && root.cursorOnCarrier()
              ? Style.focusFillFor(root.fg, root.accent) : "transparent"
            borderSpec: root.keyboardNavActive && root.cursorOnCarrier()
              ? Border.controlSpec("focus", root.fg, root.accent)
              : Border.controlSpec("normal", root.fg, root.accent)
            opacity: root.keyboardNavActive && root.cursorOnCarrier() ? 1 : 0
            z: 0
            Behavior on opacity { NumberAnimation { duration: 100 } }
          }

          SineIcon {
            id: heroSine
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Math.max(0, Math.round((root.headerIconH - height) / 2))
            z: 1
            iconSize: Style.font.display
            // Grey when tones off — focus ring stays separate.
            color: root.playing ? root.accent : root.fg
            level: root.carrierLevel
            restLevel: Beats.levelFromCarrier(Beats.DEFAULT_CARRIER)
            scrubbing: carrierScrub.valueScrubbing
              || (root.nudgeFlash && root.keyboardNavActive && root.cursorOnCarrier())
          }

          // Metrics for the widest Hz label in-band (200 Hz).
          Text {
            id: carrierHzMetrics
            visible: false
            textFormat: Text.PlainText
            text: "200 Hz"
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Text {
            id: carrierValue
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: root.headerIconH
            width: carrierHzMetrics.implicitWidth
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            text: Math.round(root.carrierHz) + " Hz"
            color: root.playing ? root.accent : root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            opacity: carrierScrub.valueScrubbing || carrierScrub.containsMouse
              || (root.keyboardNavActive && root.cursorOnCarrier()) ? 1 : 0
            z: 2
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
          }

          VertScrub {
            id: carrierScrub
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: Math.max(heroSine.width, Style.space(44))
            height: root.headerIconH
            value: root.carrierLevel
            resetGestures: true
            onScrubbed: function(v) {
              root.focusHeader("carrier")
              if (root.ready) root.beats.setCarrier(Beats.carrierFromLevel(v))
            }
            // Tap / Space: tones on/off (not a value change).
            onTapped: {
              root.focusHeader("carrier")
              if (root.ready) root.beats.toggleTones()
            }
            // Double-click or right-click → default carrier (100 Hz).
            onResetRequested: {
              root.focusHeader("carrier")
              if (root.ready) root.beats.setCarrier(Beats.DEFAULT_CARRIER)
            }
          }
        }

        Column {
          id: heroCopy
          anchors.left: heroIcon.right
          anchors.leftMargin: Style.space(14)
          anchors.top: parent.top
          anchors.topMargin: Math.max(0, Math.round((root.headerIconH - height) / 2))
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
          anchors.top: parent.top
          iconBand: root.headerIconH
          valueBand: root.headerValueH
          volume: root.volume
          hasCursor: root.keyboardNavActive && root.cursorOnVolume()
          nudging: root.nudgeFlash && root.keyboardNavActive && root.cursorOnVolume()
          // Wave runs only while a preset is actually playing — beds alone
          // must not look like a selected beat.
          active: root.playing
          hz: root.playing ? root.beatHz : 10
          color: root.accent
          idleColor: root.fg
          fontFamily: root.fontFamily
          onMoved: function(v) {
            root.focusHeader("volume")
            if (root.ready) root.beats.setVolume(v)
          }
          onActivated: {
            root.focusHeader("volume")
            if (root.ready) root.beats.toggleTones()
          }
        }

        Row {
          id: floorControls
          anchors.right: parent.right
          anchors.rightMargin: Style.space(4)
          anchors.top: parent.top
          spacing: Style.space(7)

          FloorButton {
            on: root.noiseLive
            hasCursor: root.keyboardNavActive && root.cursorOnNoise()
            bed: "noise"
            tip: "Noise"
            volume: root.noiseVolume
            glyph: noiseGlyph
            onActivated: {
              root.focusBed("noise")
              if (root.ready) root.beats.toggleNoise()
            }
            onVolumeMoved: function(v) {
              root.focusBed("noise")
              if (root.ready) root.beats.setNoiseVolume(v)
            }
          }
          FloorButton {
            on: root.rainLive
            hasCursor: root.keyboardNavActive && root.cursorOnRain()
            bed: "rain"
            tip: "Rain"
            volume: root.rainVolume
            glyph: rainGlyph
            onActivated: {
              root.focusBed("rain")
              if (root.ready) root.beats.toggleRain()
            }
            onVolumeMoved: function(v) {
              root.focusBed("rain")
              if (root.ready) root.beats.setRainVolume(v)
            }
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
    property string bed: ""
    property real volume: 1
    property Component glyph: null
    signal activated()
    signal volumeMoved(real volume)

    implicitWidth: Math.max(
      glyphLoader.item ? Math.ceil(glyphLoader.item.width) : Style.font.display,
      valueLabel.implicitWidth
    )
    implicitHeight: root.headerIconH + root.headerValueH

    readonly property bool hot: scrub.containsMouse || scrub.valueScrubbing
    readonly property bool showValue: hot || hasCursor || scrub.valueScrubbing
    // Grey only when off — level is independent (Shift/drag). Focus ring separate.
    readonly property color glyphColor: {
      if (!floor.on)
        return root.fg
      if (floor.hot)
        return Qt.lighter(root.accent, 1.18)
      return root.accent
    }

    BorderSurface {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: Math.max(0, Math.round((root.headerIconH - height) / 2))
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
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: Math.max(0, Math.round((root.headerIconH - (item ? item.height : Style.font.display)) / 2))
      z: 1
      sourceComponent: floor.glyph
      onLoaded: {
        if (!item) return
        item.iconSize = Style.font.display
        item.color = Qt.binding(function() { return floor.glyphColor })
        if (item.level !== undefined)
          item.level = Qt.binding(function() { return floor.volume })
        if (item.scrubbing !== undefined)
          item.scrubbing = Qt.binding(function() {
            return scrub.valueScrubbing || (floor.hasCursor && root.nudgeFlash)
          })
      }
    }

    Text {
      id: valueLabel
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: root.headerIconH
      textFormat: Text.PlainText
      text: Math.round(floor.volume * 100) + "%"
      color: floor.glyphColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      opacity: floor.showValue ? 1 : 0
      z: 2

      Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    VertScrub {
      id: scrub
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      width: parent.width
      height: root.headerIconH
      value: floor.volume
      onScrubbed: function(v) { floor.volumeMoved(v) }
      onDraggingChanged: {
        if (scrub.dragging && floor.bed)
          root.focusBed(floor.bed)
      }
      onTapped: floor.activated()
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
