import QtQuick
import QtQuick.Effects
import QtMultimedia

// Faint, theme-tinted looping video behind the panel content. Loaded via a
// Loader so a box without qt6-multimedia (or without the clip) just keeps
// the static watermark. The clip is desaturated and colorized to the theme,
// center-cropped to cover, and paused whenever the panel is hidden.
Item {
  id: root

  property color tint: "#808080"
  property real strength: 0.10
  property bool active: false
  property url source: Qt.resolvedUrl("demo-loop.mp4")
  property bool failed: false
  readonly property bool showing: active && !failed && player.hasVideo

  clip: true
  enabled: false

  MediaPlayer {
    id: player
    source: root.source
    loops: MediaPlayer.Infinite
    videoOutput: output
    onErrorOccurred: root.failed = true
  }

  VideoOutput {
    id: output
    anchors.fill: parent
    fillMode: VideoOutput.PreserveAspectCrop
    visible: false
    layer.enabled: true
  }

  MultiEffect {
    anchors.fill: output
    source: output
    saturation: -1.0
    colorization: 1.0
    colorizationColor: root.tint
    opacity: root.showing ? root.strength : 0
    Behavior on opacity { NumberAnimation { duration: 400 } }
  }

  onActiveChanged: {
    if (root.failed) return
    if (root.active) player.play()
    else player.pause()
  }

  Component.onCompleted: {
    if (root.active && !root.failed) player.play()
  }
}
