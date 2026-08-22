import QtQuick

// Original procedural seismograph field. It keeps the panel animated without
// bundling game footage, screenshots, logos, or other third-party artwork.
Item {
  id: root

  property color color: "#808080"
  property bool active: false
  property real phase: 0

  enabled: false
  opacity: 0.18

  NumberAnimation on phase {
    from: 0
    to: Math.PI * 2
    duration: 9000
    loops: Animation.Infinite
    running: root.active
  }

  Canvas {
    id: field
    anchors.fill: parent

    onPaint: {
      var ctx = getContext("2d")
      var w = width
      var h = height
      ctx.clearRect(0, 0, w, h)
      if (w <= 0 || h <= 0) return

      ctx.strokeStyle = String(root.color)
      ctx.lineWidth = 1
      ctx.globalAlpha = 0.22
      for (var row = 1; row < 7; row++) {
        var gy = h * row / 7
        ctx.beginPath()
        ctx.moveTo(0, gy)
        ctx.lineTo(w, gy)
        ctx.stroke()
      }

      ctx.globalAlpha = 0.9
      ctx.lineWidth = 1.4
      for (var trace = 0; trace < 3; trace++) {
        var center = h * (trace + 1) / 4
        ctx.beginPath()
        for (var x = 0; x <= w; x += 3) {
          var p = x / w
          var envelope = Math.exp(-Math.pow((p - 0.52) * 7, 2))
          var tremor = Math.sin(p * 70 + root.phase * (trace + 1))
          var drift = Math.sin(p * 9 - root.phase + trace * 1.7)
          var y = center + drift * h * 0.012 + tremor * envelope * h * (0.045 + trace * 0.012)
          if (x === 0) ctx.moveTo(x, y)
          else ctx.lineTo(x, y)
        }
        ctx.stroke()
      }
    }

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Connections {
      target: root
      function onPhaseChanged() { field.requestPaint() }
      function onColorChanged() { field.requestPaint() }
    }
  }
}
