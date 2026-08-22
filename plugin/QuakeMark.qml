import QtQuick
import qs.Commons

// Original geometric launcher mark, colorized to the Omarchy accent.
Item {
  id: root

  property color foreground: Color.foreground
  property color accent: Color.accent

  readonly property real markHeight: Math.max(Style.space(40), Style.font.display)
  implicitHeight: markHeight
  implicitWidth: markHeight
  width: implicitWidth
  height: implicitHeight
  clip: true

  Image {
    anchors.fill: parent
    anchors.leftMargin: Style.space(2)
    anchors.rightMargin: Style.space(2)
    source: Qt.resolvedUrl("icon.svg")
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    smooth: true
  }
}
