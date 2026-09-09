import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "io.github.jk.rtk-gain"

  readonly property color fg: root.bar ? root.bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(root.fg, 1.4)
  readonly property color accent: Color.accent
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family

  // --- Data from rtk gain --format json ---
  property int totalCommands: 0
  property real totalInput: 0
  property real totalOutput: 0
  property real totalSaved: 0
  property real avgSavingsPct: 0
  property real totalTimeMs: 0
  property real avgTimeMs: 0
  property bool hasData: false
  property bool popupOpen: false

  function formatTokens(n) {
    if (n >= 1000000) return (n / 1000000).toFixed(1) + "M"
    if (n >= 1000) return (n / 1000).toFixed(1) + "K"
    return String(Math.round(n))
  }

  function formatTime(ms) {
    var secs = Math.round(ms / 1000)
    if (secs >= 3600) {
      var h = Math.floor(secs / 3600)
      var m = Math.floor((secs % 3600) / 60)
      return h + "h" + (m > 0 ? m + "m" : "")
    }
    if (secs >= 60) {
      var mins = Math.floor(secs / 60)
      var s = secs % 60
      return mins + "m" + (s > 0 ? s + "s" : "")
    }
    return secs + "s"
  }

  function parseData(text) {
    try {
      var data = JSON.parse(text)
      var s = data.summary
      totalCommands = s.total_commands || 0
      totalInput = s.total_input || 0
      totalOutput = s.total_output || 0
      totalSaved = s.total_saved || 0
      avgSavingsPct = s.avg_savings_pct || 0
      totalTimeMs = s.total_time_ms || 0
      avgTimeMs = s.avg_time_ms || 0
      hasData = true
    } catch (e) {
      console.warn("rtk-gain: failed to parse JSON:", e)
    }
  }

  function close() {
    root.popupOpen = false
  }

  // --- Polling (every 60s) ---
  Timer {
    interval: 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!fetchProcess.running) {
        fetchProcess.running = true
      }
    }
  }

  Process {
    id: fetchProcess
    command: ["rtk", "gain", "--format", "json"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseData(text)
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (text.trim() !== "") console.warn("rtk-gain:", text.trim())
    }
  }

  // --- Bar icon ---
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰄪"
    iconComponent: Component {
      Text {
        text: "󰄪"
        color: button.foreground
        font.family: button.fontFamily
        font.pixelSize: button.fontSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }
    onPressed: function(b) {
      if (b === Qt.RightButton) {
        fetchProcess.running = true
      } else {
        root.popupOpen = !root.popupOpen
      }
    }
  }

  // --- Popup panel ---
  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    triggerMode: "click"
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(300))
    contentHeight: popup.fittedContentHeight(panel.implicitHeight)

    Column {
      id: panel
      width: parent.width
      spacing: Style.space(12)

      // Hero section
      Item {
        width: parent.width
        implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

        Text {
          id: heroIcon
          text: "󰄪"
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: 24
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
        }

        Column {
          id: heroLabels
          anchors.left: heroIcon.right
          anchors.leftMargin: Style.space(14)
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)

          Text {
            text: "RTK Token Savings"
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: 15
            font.bold: true
          }

          Text {
            text: root.hasData
              ? root.totalCommands + " commands · " + root.formatTime(root.totalTimeMs)
              : "Loading…"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: 12
          }
        }
      }

      // Separator
      Rectangle {
        width: parent.width
        height: 1
        color: root.dim
        opacity: 0.15
      }

      // Stats rows
      Column {
        width: parent.width
        spacing: Style.space(6)

        Repeater {
          model: [
            { label: "Input tokens", value: root.formatTokens(root.totalInput) },
            { label: "Output tokens", value: root.formatTokens(root.totalOutput) },
            { label: "Tokens saved", value: root.formatTokens(root.totalSaved) },
            { label: "Avg exec time", value: root.formatTime(root.avgTimeMs) }
          ]

          Row {
            required property var modelData
            width: panel.width
            spacing: Style.space(8)

            Text {
              text: modelData.label
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: 12
              width: parent.width * 0.55
            }

            Text {
              text: modelData.value
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: 12
              font.bold: true
              horizontalAlignment: Text.AlignRight
              width: parent.width * 0.45 - Style.space(8)
            }
          }
        }
      }

      // Separator
      Rectangle {
        width: parent.width
        height: 1
        color: root.dim
        opacity: 0.15
      }

      // Efficiency meter
      Column {
        width: parent.width
        spacing: Style.space(4)

        Row {
          width: parent.width

          Text {
            text: "Efficiency"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: 12
          }

          Item { width: parent.width - effLabel.width - effValue.width; height: 1 }

          Text {
            id: effLabel
            text: ""
            visible: false
          }

          Text {
            id: effValue
            text: root.avgSavingsPct.toFixed(1) + "%"
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: 12
            font.bold: true
          }
        }

        Rectangle {
          width: parent.width
          height: Style.space(6)
          radius: Style.space(3)
          color: root.dim
          opacity: 0.15

          Rectangle {
            width: parent.width * Math.min(1.0, root.avgSavingsPct / 100)
            height: parent.height
            radius: parent.radius
            color: root.avgSavingsPct > 50 ? root.accent
              : root.avgSavingsPct > 20 ? root.fg
              : root.dim
          }
        }
      }

      // Hint
      Text {
        text: "Right-click icon to refresh"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: 10
        opacity: 0.5
      }
    }
  }
}
