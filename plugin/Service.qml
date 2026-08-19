import QtQuick
import Quickshell
import Quickshell.Io

// Headless half of the Quake plugin.
//
// Watches the launcher status file so any QML surface can read live state
// later (HUD, bar widget, etc.) without talking to the engine directly.
// The .desktop entry is owned by the package / make install, not rewritten here.

Item {
  id: root

  property var shell: null
  property var manifest: null
  property string omarchyPath: ""

  readonly property string home: Quickshell.env("HOME")
  readonly property string statusPath: (Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")) + "/quake-omarchy/status.json"

  property var status: ({ version: 1, mode: "idle", running: false })

  readonly property string pluginDir: (manifest && manifest.__sourceDir) || (home + "/.config/omarchy/plugins/quake.omarchy")

  readonly property string launcherPath: "omarchy-quake"

  function run() {
    var args = [root.launcherPath]
    for (var i = 0; i < arguments.length; i++) args.push(String(arguments[i]))
    Quickshell.execDetached(args)
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

  IpcHandler {
    target: "omarchy-quake"

    function status(): string {
      return JSON.stringify(root.status)
    }

    function play(): string { root.run("play"); return "ok" }
    function host(): string { root.run("host"); return "ok" }
    function join(addr: string): string {
      if (addr && addr.length) root.run("join", addr)
      else root.run("join")
      return "ok"
    }
    function fetch(): string { root.run("fetch"); return "ok" }
    function stop(): string { root.run("stop"); return "ok" }
    function panel(): string { root.run("panel"); return "ok" }
    function ping(): string { return "ok" }
  }
}
