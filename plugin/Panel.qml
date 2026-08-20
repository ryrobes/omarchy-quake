import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root

  property var shell: null
  property var manifest: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")

  property bool opened: false
  property bool hideAfterLaunch: false
  property string focusSection: "actions"
  property int cursorIndex: 0
  property string edition: "auto"
  property string hostMap: "e1m2"
  property string joinTarget: ""
  property bool fullscreen: true
  property string resolution: "native"
  property bool vsync: false
  property string playerName: Quickshell.env("USER") || "player"
  property int shirtColor: 0
  property int pantsColor: 0
  property var peers: []
  property var mapList: []
  property var sourceInfo: ({})
  property var matchStatus: ({})
  property string errorText: ""
  property bool dismissAfterRcon: false
  property string mapQuery: ""
  // Collapsible sections. dmIntent narrows the deathmatch section to the
  // host or join flow ("" from the header shows both).
  property bool dmExpanded: false
  property string dmIntent: ""
  property bool settingsOpen: false

  readonly property string home: Quickshell.env("HOME")
  readonly property string pluginDir: (manifest && manifest.__sourceDir) || (home + "/.config/omarchy/plugins/quake.omarchy")
  readonly property string statusPath: (Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")) + "/quake-omarchy/status.json"
  readonly property string iconPath: pluginDir + "/icon.svg"
  property var status: ({ version: 1, mode: "idle", running: false })
  readonly property string joinCommand: Model.joinCommand(status)
  readonly property string editionMeta: Model.editionMeta(sourceInfo, status, edition)
  readonly property string mapsEdition: {
    if (status && status.edition && (root.hosting || status.mode === "host" || status.mode === "starting"))
      return String(status.edition)
    return root.edition
  }
  readonly property var mapOptions: root.mapList && root.mapList.length ? root.mapList : Model.mapsFor(root.mapsEdition)
  readonly property string launcherPath: "omarchy-quake"
  readonly property string defaultName: Quickshell.env("USER") || "player"
  readonly property string displayError: (status && status.error) ? String(status.error) : errorText
  readonly property bool hosting: Model.hosting(status) && !root.starting
  readonly property var matchClients: Model.matchClients(matchStatus)
  readonly property string matchLine: Model.matchLine(matchStatus, hostMap)
  readonly property var filteredMaps: Model.filterMaps(root.mapOptions, root.mapQuery, 12)
  readonly property bool starting: {
    if (!status || status.error) return false
    var mode = String(status.mode || "")
    if (mode === "starting") return true
    if (mode === "fetch" || mode === "idle" || mode === "error" || mode === "") return false
    // Launched from here, game process up, window not mapped yet.
    if (root.hideAfterLaunch && status.window !== true) return true
    return false
  }
  readonly property string startingLabel: {
    var launch = status && status.launch ? String(status.launch) : ""
    if (launch === "host") return "Starting deathmatch"
    if (launch === "join") return "Connecting"
    return "Starting Quake"
  }

  readonly property color background: Color.menu.background
  readonly property color foreground: Color.menu.text
  readonly property color accent: Color.accent
  readonly property color muted: Color.muted
  readonly property color scrim: Color.menu.scrim
  readonly property color borderColor: Color.menu.border
  readonly property color selectedBackground: Color.menu.selectedBackground
  readonly property string fontFamily: Style.font.menuFamily
  readonly property int cornerRadius: Style.cornerRadius
  readonly property bool busy: !!(root.starting || (status && (status.mode === "fetch" || ((status.running || status.alive) && status.mode !== "idle"))))
  readonly property int fetchPercent: status && status.fetch ? Number(status.fetch.percent || 0) : 0
  readonly property var fakeBar: QtObject {
    readonly property color foreground: root.foreground
    readonly property color background: root.background
    readonly property color urgent: Color.urgent
    readonly property string fontFamily: root.fontFamily
  }

  function open(payloadJson) {
    root.opened = true
    root.errorText = ""
    root.mapQuery = ""
    root.dmExpanded = false
    root.dmIntent = ""
    root.settingsOpen = false
    try {
      var payload = JSON.parse(payloadJson || "{}")
      if (payload && payload.mode === "starting")
        root.hideAfterLaunch = true
      else
        root.hideAfterLaunch = false
    } catch (e) {
      root.hideAfterLaunch = false
    }
    statusFile.reload()
    liveStatus.running = false
    liveStatus.running = true
    if (!root.starting) {
      refreshPeers()
      refreshSource()
      refreshMaps()
    }
    Qt.callLater(function() {
      if (!root.starting && !root.hosting) keyCatcher.forceActiveFocus()
    })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "quake.omarchy")
    else close()
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function run() {
    var args = ["env", "QO_FROM_PANEL=1", root.launcherPath]
    for (var i = 0; i < arguments.length; i++) args.push(String(arguments[i]))
    Quickshell.execDetached(args)
  }

  function dismissLaunch() {
    if (!root.hideAfterLaunch && !(status && status.mode === "starting")) return
    root.hideAfterLaunch = false
    root.dismiss()
  }

  function play() {
    root.hideAfterLaunch = true
    run("play", "--edition", edition)
    launchWatchdog.restart()
  }
  function host() {
    root.hideAfterLaunch = true
    run("host", "--edition", edition, "--map", hostMap)
    launchWatchdog.restart()
  }
  function join() {
    root.hideAfterLaunch = true
    if (joinTarget && joinTarget.length) {
      run("join", joinTarget)
      launchWatchdog.restart()
      return
    }
    // No address picked: the CLI checks the clipboard, then scans the
    // tailnet/LAN, and reports if nothing is live.
    run("join")
    launchWatchdog.restart()
  }

  function openDeathmatch(intent) {
    if (root.dmExpanded && root.dmIntent === intent) {
      root.dmExpanded = false
      root.dmIntent = ""
      return
    }
    root.dmExpanded = true
    root.dmIntent = intent || ""
    if (intent !== "host") root.refreshPeers()
  }
  function stop() { run("stop") }
  function copyJoin() { run("share") }

  function rcon() {
    var args = [root.launcherPath, "rcon"]
    for (var i = 0; i < arguments.length; i++) args.push(String(arguments[i]))
    rconProc.command = args
    rconProc.running = false
    rconProc.running = true
  }

  function changelevel(map) {
    var m = String(map || "")
    if (!m.length) return
    var i
    var ok = false
    for (i = 0; i < root.mapOptions.length; i++) {
      if (String(root.mapOptions[i]) === m) { ok = true; break }
    }
    if (!ok) {
      root.errorText = m + " is not in this edition"
      return
    }
    root.hostMap = m
    root.setConfig("map", m)
    if (root.hosting) {
      root.dismissAfterRcon = true
      root.rcon("changelevel", m)
    }
  }

  function refreshMatch() {
    if (!root.hosting) return
    if (matchProc.running) return
    matchProc.running = true
  }

  onHostingChanged: {
    if (!root.hosting) root.matchStatus = ({})
  }

  onStatusChanged: {
    if (!status) return
    var mode = String(status.mode || "")
    if (mode !== "idle" || status.error) launchWatchdog.stop()
    if (root.hideAfterLaunch && (mode === "idle" || mode === "error" || status.error))
      root.hideAfterLaunch = false
    if (!root.opened) return
    if (root.hideAfterLaunch && status.window === true)
      Qt.callLater(root.dismissLaunch)
  }

  // If the CLI never writes any status after a launch click, the exec
  // itself failed (binary missing from PATH, broken install). Say so
  // instead of silently doing nothing.
  Timer {
    id: launchWatchdog
    interval: 4000
    onTriggered: {
      var mode = status ? String(status.mode || "") : ""
      if (mode === "idle" && !((status && status.error))) {
        root.hideAfterLaunch = false
        root.errorText = "omarchy-quake did not respond — is it installed and on PATH? (make install, or pacman -S omarchy-quake)"
      }
    }
  }

  Process {
    id: liveStatus
    command: [root.launcherPath, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parseJson(text, null)
        if (parsed && typeof parsed === "object") root.status = parsed
      }
    }
  }

  Process {
    id: windowProc
    command: ["hyprctl", "clients", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (root.starting && Model.gameWindowMapped(text))
          root.dismissLaunch()
      }
    }
  }

  Timer {
    id: windowWatch
    interval: 200
    running: root.opened && root.starting
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!windowProc.running) windowProc.running = true
    }
  }

  function setConfig(key, value) {
    run("config", key, String(value))
  }

  function applyConfigText(text) {
    var cfg = Model.parseConfig(text)
    if (cfg.edition) root.edition = cfg.edition
    if (cfg.map) root.hostMap = cfg.map
    root.fullscreen = cfg.fullscreen !== undefined ? Model.isTruthy(cfg.fullscreen) : !Model.isTruthy(cfg.windowed)
    root.vsync = Model.isTruthy(cfg.vsync)
    root.resolution = Model.resolutionValue(cfg)
    root.playerName = (cfg.name && String(cfg.name).length) ? String(cfg.name) : root.defaultName
    var shirt = (cfg.shirt !== undefined && cfg.shirt !== "") ? cfg.shirt : cfg.topcolor
    var pants = (cfg.pants !== undefined && cfg.pants !== "") ? cfg.pants : cfg.bottomcolor
    root.shirtColor = Model.clampColor(shirt)
    root.pantsColor = Model.clampColor(pants)
  }

  function commitName() {
    var name = String(root.playerName || "").trim()
    if (!name.length) name = root.defaultName
    if (name.length > 15) name = name.slice(0, 15)
    root.playerName = name
    root.setConfig("name", name)
  }

  component ColorSwatchRow: Column {
    id: swatchRow
    property string label: ""
    property int value: 0
    signal picked(int value)
    spacing: Style.spacing.labelGap
    width: parent ? parent.width : implicitWidth

    Row {
      spacing: Style.spacing.controlGap
      Text {
        text: swatchRow.label
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }
      Text {
        text: Model.colorName(swatchRow.value)
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    Row {
      spacing: Style.space(4)
      Repeater {
        model: Model.playerColors()
        Rectangle {
          width: Style.space(20)
          height: Style.space(20)
          radius: 2
          color: modelData.hex
          border.width: Model.clampColor(swatchRow.value) === modelData.value ? 2 : 1
          border.color: Model.clampColor(swatchRow.value) === modelData.value
            ? root.accent
            : root.borderColor
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: swatchRow.picked(modelData.value)
          }
        }
      }
    }
  }

  // Clickable section header with a chevron; content elsewhere binds
  // `visible` to the expanded flag and the Column reflows.
  component SectionExpander: Item {
    id: expander
    property string label: ""
    property string hint: ""
    property bool expanded: false
    signal toggled()
    width: parent ? parent.width : implicitWidth
    implicitHeight: headerRow.implicitHeight + Style.space(6)
    height: implicitHeight

    Row {
      id: headerRow
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width
      spacing: Style.spacing.controlGap

      Text {
        text: expander.expanded ? "▾" : "▸"
        color: root.accent
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }
      Text {
        id: expanderLabel
        text: expander.label
        color: Qt.darker(root.foreground, 1.4)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }
      Text {
        width: Math.max(0, headerRow.width - expanderLabel.implicitWidth - Style.space(40))
        text: expander.hint
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: expander.toggled()
    }
  }

  function refreshPeers() {
    peerProc.running = false
    peerProc.running = true
  }

  function refreshSource() {
    sourceProc.running = false
    sourceProc.running = true
  }

  function refreshMaps() {
    mapsProc.running = false
    mapsProc.running = true
  }

  onMapsEditionChanged: refreshMaps()

  function selectPeer(peer) {
    joinTarget = Model.peerTarget(peer)
  }

  FileView {
    id: configFile
    path: (Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")) + "/quake-omarchy/config"
    watchChanges: true
    printErrors: false
    onLoaded: root.applyConfigText(text())
    onFileChanged: reload()
  }

  FileView {
    id: statusFile
    path: root.statusPath
    watchChanges: true
    printErrors: false
    onLoaded: {
      try { root.status = JSON.parse(String(text() || "{}")) }
      catch (e) {}
    }
    onFileChanged: reload()
  }

  Process {
    id: mapsProc
    command: [root.launcherPath, "maps", root.mapsEdition]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parseJson(text, [])
        var list = parsed instanceof Array ? parsed : []
        root.mapList = list
        if (list.length) {
          var found = false
          var i
          for (i = 0; i < list.length; i++) {
            if (String(list[i]) === root.hostMap) { found = true; break }
          }
          if (!found && !root.hosting) {
            root.hostMap = String(list[0])
            root.setConfig("map", root.hostMap)
          }
        }
      }
    }
  }

  Process {
    id: sourceProc
    command: [root.launcherPath, "source", root.edition]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parseJson(text, {})
        root.sourceInfo = parsed && typeof parsed === "object" ? parsed : {}
      }
    }
  }

  Process {
    id: peerProc
    command: [root.launcherPath, "peers"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parseJson(text, [])
        root.peers = parsed instanceof Array ? parsed : []
      }
    }
  }

  Process {
    id: matchProc
    command: [root.launcherPath, "host-status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parseJson(text, {})
        root.matchStatus = parsed && typeof parsed === "object" ? parsed : {}
        if (root.matchStatus && root.matchStatus.ok && root.matchStatus.map) {
          var live = String(root.matchStatus.map)
          if (live.length && live !== root.hostMap)
            root.hostMap = live
        }
      }
    }
  }

  Process {
    id: rconProc
    command: [root.launcherPath, "rcon", "status"]
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var err = String(text || "").trim()
        if (err.length) root.errorText = err
      }
    }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.errorText = ""
        Qt.callLater(root.refreshMatch)
        if (root.dismissAfterRcon) {
          root.dismissAfterRcon = false
          Qt.callLater(root.dismiss)
        }
      } else {
        root.dismissAfterRcon = false
      }
    }
  }

  Timer {
    id: matchTimer
    interval: 2000
    running: false
    repeat: true
    triggeredOnStart: false
    onTriggered: root.refreshMatch()
  }

  PanelWindow {
    id: window
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quake-omarchy"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: (root.starting || root.hosting) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive
    mask: Region { item: (root.starting || root.hosting) ? card : hitLayer }

    Item {
      id: hitLayer
      anchors.fill: parent

    Rectangle {
      anchors.fill: parent
      color: root.starting ? "transparent" : root.scrim
      MouseArea {
        anchors.fill: parent
        enabled: !root.starting
        onClicked: root.dismiss()
      }
    }

    BorderSurface {
      id: card
      anchors.centerIn: parent
      width: Math.min(Style.space(580), window.width - Style.gapsOut * 4)
      readonly property int chrome: Style.spacing.panelPadding * 2 + borderTop + borderBottom
      readonly property int maxHeight: window.height - Style.gapsOut * 4
      height: Math.min(body.implicitHeight + chrome, maxHeight)
      implicitHeight: height
      radius: root.cornerRadius
      color: root.background
      borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))
      padding: Style.spacing.panelPadding
      clip: true

      // Animated backdrop when plugin/demo-loop.mp4 and qt6-multimedia
      // exist; otherwise the Loader errors out quietly and the static
      // watermark below stays.
      Loader {
        id: videoLoader
        anchors.fill: parent
        asynchronous: true
        source: Qt.resolvedUrl("VideoBackdrop.qml")
        onLoaded: {
          item.tint = Qt.binding(function() { return root.muted })
          item.active = Qt.binding(function() { return root.opened })
        }
      }

      QuakeWatermark {
        anchors.fill: parent
        color: root.muted
        visible: !(videoLoader.status === Loader.Ready && videoLoader.item && videoLoader.item.showing)
      }

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onPressed: function(event) {
          if (mapFilter.activeFocus) return
          if (event.key === Qt.Key_Escape) { root.dismiss(); event.accepted = true }
          else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.starting) event.accepted = true
            else if (root.hosting && root.filteredMaps.length)
              root.changelevel(root.filteredMaps[0])
            else if (root.busy) root.stop()
            else root.play()
            event.accepted = true
          }
        }
      }

      Flickable {
        id: flick
        anchors.fill: parent
        anchors.topMargin: card.borderTop + Style.spacing.panelPadding
        anchors.rightMargin: card.borderRight + Style.spacing.panelPadding
        anchors.bottomMargin: card.borderBottom + Style.spacing.panelPadding
        anchors.leftMargin: card.borderLeft + Style.spacing.panelPadding
        contentWidth: width
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Column {
          id: body
          width: flick.width
          spacing: Style.spacing.rowGap

        PanelHero {
          width: parent.width
          title: "Quake"
          meta: root.starting ? (root.startingLabel + " · " + (root.editionMeta || "loading"))
            : (root.hosting ? ("Hosting · " + root.matchLine) : root.editionMeta)
          detail: ""
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconComponent: Component {
            QuakeMark {
              foreground: root.foreground
              accent: root.accent
            }
          }
          trailingControl: (joinCommand.length && !root.starting) ? copyButton : null
        }

        Component {
          id: copyButton
          Button {
            text: "Copy"
            tooltipText: "Copy join command for the other machine"
            foreground: root.foreground
            bordered: true
            onClicked: root.copyJoin()
          }
        }

        Column {
          width: parent.width
          visible: root.starting
          spacing: Style.spacing.rowGap

          Text {
            width: parent.width
            text: (status && status.map) ? ("Loading " + status.map) : "Loading the engine…"
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.Wrap
          }

          Item {
            width: parent.width
            height: Style.space(8)
            Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              height: Style.space(6)
              radius: 1
              color: root.selectedBackground
              Rectangle {
                anchors.fill: parent
                color: root.accent
                SequentialAnimation on opacity {
                  running: root.starting && root.opened
                  loops: Animation.Infinite
                  NumberAnimation { from: 0.25; to: 1; duration: 700; easing.type: Easing.InOutQuad }
                  NumberAnimation { from: 1; to: 0.25; duration: 700; easing.type: Easing.InOutQuad }
                }
              }
            }
          }

          Text {
            width: parent.width
            text: {
              var launch = status && status.launch ? String(status.launch) : ""
              if (launch === "host") return "Vulkan can take a few seconds. Super+Shift+Q changes maps once you’re in."
              if (launch === "join") return "Vulkan can take a few seconds, then you’ll connect to " + (status && status.join ? String(status.join) : "the host") + "."
              return "Vulkan can take a few seconds."
            }
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
          }

          Button {
            text: "Cancel"
            foreground: root.foreground
            bordered: true
            onClicked: {
              root.hideAfterLaunch = false
              root.stop()
            }
          }
        }

        Text {
          width: parent.width
          visible: joinCommand.length > 0 && !root.starting
          text: joinCommand
          color: root.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.Wrap
        }

        Text {
          width: parent.width
          visible: joinCommand.length > 0 && !root.starting
          text: root.hosting
            ? "Type a map name, then click it. Super+Shift+[ / ] cycles without this overlay. Esc plays."
            : "Send that line to the other machine. They run it, or paste it below. Do not use Multiplayer → TCP/IP inside Quake."
          color: root.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.Wrap
        }

        Item {
          width: parent.width
          height: Style.space(8)
          visible: status && status.mode === "fetch"
          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: Style.space(6)
            radius: 1
            color: root.selectedBackground
            Rectangle {
              width: parent.width * Math.max(0, Math.min(1, root.fetchPercent / 100))
              height: parent.height
              color: root.accent
            }
          }
        }

        PanelSeparator { width: parent.width; visible: !root.starting }

        PanelSectionHeader {
          visible: root.hosting
          text: "MATCH"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Text {
          width: parent.width
          visible: root.hosting
          text: root.matchClients.length === 0
            ? "Waiting for players…"
            : root.matchClients.length + " player" + (root.matchClients.length === 1 ? "" : "s")
          color: root.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        Repeater {
          model: root.hosting ? root.matchClients.length : 0
          Row {
            width: body.width
            spacing: Style.spacing.controlGap
            property var client: root.matchClients[index] || ({})

            Text {
              width: parent.width * 0.52
              text: String(client.name || "")
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
            }
            Text {
              width: parent.width * 0.18
              text: client.frags === undefined ? "" : String(client.frags)
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignRight
            }
            Text {
              width: parent.width * 0.30 - parent.spacing * 2
              text: String(client.time || "")
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignRight
            }
          }
        }

        TextField {
          id: mapFilter
          width: parent.width
          visible: root.hosting
          placeholderText: "Filter maps — click a name to changelevel"
          text: root.mapQuery
          foreground: root.foreground
          onTextChanged: root.mapQuery = text
          onAccepted: {
            if (root.filteredMaps.length) root.changelevel(root.filteredMaps[0])
          }
        }

        Repeater {
          model: root.hosting ? root.filteredMaps.length : 0
          Button {
            width: body.width
            text: String(root.filteredMaps[index] || "")
            leftAlign: true
            foreground: root.foreground
            selected: String(root.filteredMaps[index] || "") === root.hostMap
            onClicked: root.changelevel(root.filteredMaps[index])
          }
        }

        Text {
          width: parent.width
          visible: root.hosting
          text: "Click a map to changelevel (keeps everyone connected). Super+Shift+Q hides this overlay."
          color: root.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.Wrap
        }

        PanelSectionHeader {
          visible: !root.hosting && !root.starting
          text: "LAUNCH"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Flow {
          width: parent.width
          visible: !root.hosting && !root.starting
          spacing: Style.spacing.controlGap

          Button {
            text: busy ? "Stop" : "Play singleplayer"
            foreground: root.foreground
            bordered: true
            onClicked: busy ? root.stop() : root.play()
          }
          Button {
            text: "Host deathmatch"
            foreground: root.foreground
            bordered: true
            enabled: !busy
            selected: root.dmExpanded && root.dmIntent === "host"
            onClicked: root.openDeathmatch("host")
          }
          Button {
            text: "Join deathmatch"
            foreground: root.foreground
            bordered: true
            enabled: !busy
            selected: root.dmExpanded && root.dmIntent === "join"
            onClicked: root.openDeathmatch("join")
          }
        }

        PanelSeparator { width: parent.width; visible: !root.hosting && !root.starting }

        SectionExpander {
          visible: !root.hosting && !root.starting
          label: "DEATHMATCH"
          hint: root.dmExpanded ? "" : (root.playerName + " · " + root.hostMap)
          expanded: root.dmExpanded
          onToggled: {
            root.dmExpanded = !root.dmExpanded
            root.dmIntent = ""
            if (root.dmExpanded) root.refreshPeers()
          }
        }

        Column {
          id: dmBody
          width: parent.width
          visible: root.dmExpanded && !root.hosting && !root.starting
          spacing: Style.spacing.rowGap

          Column {
            width: parent.width
            spacing: Style.spacing.labelGap

            Text {
              text: "Name"
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Row {
              width: parent.width
              spacing: Style.spacing.controlGap

              TextField {
                id: nameField
                width: parent.width - preview.width - parent.spacing
                text: root.playerName
                placeholderText: root.defaultName
                maximumLength: 15
                foreground: root.foreground
                onEditingFinished: {
                  root.playerName = text
                  root.commitName()
                }
                onAccepted: {
                  root.playerName = text
                  root.commitName()
                }
              }

              Item {
                id: preview
                width: nameField.height
                height: nameField.height
                Rectangle {
                  anchors.bottom: parent.bottom
                  width: parent.width
                  height: Math.round(parent.height * 0.55)
                  radius: 2
                  color: Model.colorHex(root.pantsColor)
                }
                Rectangle {
                  anchors.top: parent.top
                  width: parent.width
                  height: Math.round(parent.height * 0.55)
                  radius: 2
                  color: Model.colorHex(root.shirtColor)
                }
              }
            }
          }

          ColorSwatchRow {
            width: parent.width
            label: "Shirt"
            value: root.shirtColor
            onPicked: function(v) {
              root.shirtColor = v
              root.setConfig("shirt", String(v))
            }
          }

          ColorSwatchRow {
            width: parent.width
            label: "Pants"
            value: root.pantsColor
            onPicked: function(v) {
              root.pantsColor = v
              root.setConfig("pants", String(v))
            }
          }

          Column {
            width: parent.width
            visible: root.dmIntent !== "join"
            spacing: Style.spacing.rowGap

            SearchableDropdown {
              width: parent.width
              label: "Map"
              value: root.hostMap
              foreground: root.foreground
              options: root.mapOptions
              onChanged: function(v) {
                root.hostMap = v
                root.setConfig("map", v)
              }
            }

            Button {
              text: "Start hosting " + root.hostMap
              foreground: root.foreground
              bordered: true
              enabled: !busy
              onClicked: root.host()
            }

            Text {
              width: parent.width
              text: "Hosting copies a join command for the other machine (same Tailscale tailnet, or the same LAN). Up to 8 players; Super+Shift+Q changes maps mid-match."
                + (root.edition === "rerelease"
                  ? " 2021 re-release hosts need the same remaster on every machine."
                  : " Shareware/classic hosts are joinable with the same original PAKs.")
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.Wrap
            }
          }

          PanelSeparator { width: parent.width; visible: root.dmIntent === "" }

          Column {
            width: parent.width
            visible: root.dmIntent !== "host"
            spacing: Style.spacing.rowGap

            Text {
              width: parent.width
              text: root.peers && root.peers.length
                ? root.peers.length + " game" + (root.peers.length === 1 ? "" : "s") + " advertising nearby — click one to join."
                : "No games advertising nearby. Paste host:port below — or copy the host’s join command anywhere and just click Join."
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.Wrap
            }

            Repeater {
              model: root.peers ? root.peers.length : 0
              Button {
                width: dmBody.width
                property var peer: root.peers[index] || ({})
                text: Model.peerLabel(peer)
                leftAlign: true
                foreground: root.foreground
                selected: root.joinTarget === Model.peerTarget(peer)
                onClicked: {
                  root.selectPeer(peer)
                  root.join()
                }
              }
            }

            TextField {
              id: joinField
              width: parent.width
              placeholderText: "host:26000 (empty: use the copied join command)"
              text: root.joinTarget
              foreground: root.foreground
              onEditingFinished: root.joinTarget = text
              onAccepted: {
                root.joinTarget = text
                root.join()
              }
            }

            Row {
              spacing: Style.spacing.controlGap
              Button {
                text: "Join"
                foreground: root.foreground
                bordered: true
                enabled: !busy
                onClicked: {
                  root.joinTarget = joinField.text
                  root.join()
                }
              }
              Button {
                text: "Rescan"
                foreground: root.foreground
                bordered: true
                onClicked: root.refreshPeers()
              }
            }
          }
        }

        SectionExpander {
          visible: !root.hosting && !root.starting
          label: "SETTINGS"
          hint: root.settingsOpen ? "" : ((root.fullscreen ? "fullscreen" : "windowed") + " · " + root.resolution + " · " + Model.editionLabel(root.edition))
          expanded: root.settingsOpen
          onToggled: root.settingsOpen = !root.settingsOpen
        }

        Column {
          width: parent.width
          visible: root.settingsOpen && !root.hosting && !root.starting
          spacing: Style.spacing.rowGap

          Toggle {
            width: parent.width
            label: "Fullscreen"
            description: "Off: Esc frees the mouse. Click the game to recapture."
            checked: root.fullscreen
            foreground: root.foreground
            onClicked: {
              root.fullscreen = !root.fullscreen
              root.setConfig("fullscreen", root.fullscreen ? "true" : "false")
            }
          }

          Dropdown {
            width: parent.width
            label: "Resolution"
            value: root.resolution
            foreground: root.foreground
            options: Model.resolutionOptions()
            onChanged: function(v) {
              root.resolution = v
              root.setConfig("resolution", v)
            }
          }

          Toggle {
            width: parent.width
            label: "VSync"
            checked: root.vsync
            foreground: root.foreground
            onClicked: {
              root.vsync = !root.vsync
              root.setConfig("vsync", root.vsync ? "true" : "false")
            }
          }

          Dropdown {
            width: parent.width
            label: "Edition"
            value: root.edition
            foreground: root.foreground
            options: [
              { value: "auto", label: "Auto (classic, then shareware)" },
              { value: "shareware", label: "Shareware" },
              { value: "classic", label: "Registered / classic" },
              { value: "rerelease", label: "2021 re-release" }
            ]
            onChanged: function(v) {
              root.edition = v
              root.setConfig("edition", v)
              root.refreshSource()
              root.refreshMaps()
            }
          }
        }

        Text {
          width: parent.width
          visible: displayError.length > 0
          text: displayError
          color: Color.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.Wrap
        }
        }
      }
    }
    }
  }
}
