import QtQuick
import qs.Commons

// Faint original geometric mark behind the panel body; does not take input.
Item {
  id: root

  property color color: Color.muted
  property real markOpacity: 0.11

  clip: true
  enabled: false

  Image {
    id: logo
    width: Math.round(root.height * 0.52)
    height: width
    x: root.width - width * 0.58
    y: root.height - height * 0.78
    source: Qt.resolvedUrl("icon.svg")
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    smooth: true
    opacity: root.markOpacity
  }
}
