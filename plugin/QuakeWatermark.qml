import QtQuick
import QtQuick.Effects
import qs.Commons

// Faint Quake Q outline, colorized to the current theme. Sits behind the
// panel body; does not take input.
Item {
  id: root

  property color color: Color.muted
  property real markOpacity: 0.11

  clip: true
  enabled: false

  Image {
    id: logo
    width: Math.round(root.height * 0.62)
    height: Math.round(width * 1735.227 / 1151.492)
    x: root.width - width * 0.58
    y: root.height - height * 0.78
    source: Qt.resolvedUrl("quake-logo-outline.svg")
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    visible: false
    layer.enabled: true
    smooth: true
  }

  MultiEffect {
    anchors.fill: logo
    source: logo
    colorization: 1.0
    colorizationColor: root.color
    opacity: root.markOpacity
  }
}
