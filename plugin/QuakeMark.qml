import QtQuick
import QtQuick.Effects
import qs.Commons

// Liquipedia Quake Q, colorized to the Omarchy accent. Sized to the
// viewBox so the bowl isn't clipped by the panel's left edge.
Item {
  id: root

  property color foreground: Color.foreground
  property color accent: Color.accent

  readonly property real markHeight: Math.max(Style.space(40), Style.font.display)
  implicitHeight: markHeight
  implicitWidth: Math.round(markHeight * 1151.492 / 1735.227) + Style.space(4)
  width: implicitWidth
  height: implicitHeight
  clip: true

  Image {
    id: logo
    anchors.fill: parent
    anchors.leftMargin: Style.space(2)
    anchors.rightMargin: Style.space(2)
    source: Qt.resolvedUrl("quake-logo.svg")
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    visible: false
    layer.enabled: true
  }

  MultiEffect {
    anchors.fill: logo
    source: logo
    colorization: 1.0
    colorizationColor: root.accent
  }
}
