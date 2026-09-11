import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "io.github.jk.rtk-gain"

  readonly property string collectScript: {
    var id = root.moduleName
    var home = Quickshell.env("HOME") || ""
    return home + "/.config/omarchy/plugins/" + id + "/scripts/collect.sh"
  }

  readonly property color fg: root.bar ? root.bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(root.fg, 1.4)
  readonly property color accent: Color.accent
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family

  // --- Summary data ---
  property int totalCommands: 0
  property real totalInput: 0
  property real totalOutput: 0
  property real totalSaved: 0
  property real avgSavingsPct: 0
  property real totalTimeMs: 0
  property real avgTimeMs: 0

  // --- Top commands ---
  property var topCommands: []

  // --- Daily breakdown ---
  property var dailyData: []
  property var weeklyData: []
  property var monthlyData: []
  property int failureCount: 0
  property real recoveryPct: 0
  property string monthlyQuota: "—"
  property real quotaPreservedPct: 0

  property bool hasData: false
  property string errorMessage: ""
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

  function formatDate(dateStr) {
    var parts = dateStr.split("-")
    if (parts.length === 3) return parts[2] + "/" + parts[1]
    return dateStr
  }

  function clearData(message) {
    totalCommands = 0
    totalInput = 0
    totalOutput = 0
    totalSaved = 0
    avgSavingsPct = 0
    totalTimeMs = 0
    avgTimeMs = 0
    topCommands = []
    dailyData = []
    weeklyData = []
    monthlyData = []
    failureCount = 0
    recoveryPct = 0
    monthlyQuota = "—"
    quotaPreservedPct = 0
    errorMessage = message
    hasData = false
  }

  function parseData(text) {
    try {
      var data = JSON.parse(text)
      if (data.error) {
        clearData(data.error)
        return
      }

      var s = data.summary || {}
      totalCommands = s.total_commands || 0
      totalInput = s.total_input || 0
      totalOutput = s.total_output || 0
      totalSaved = s.total_saved || 0
      // rtk reports this value as a percentage (8.4 == 8.4%).
      avgSavingsPct = s.avg_savings_pct || 0
      totalTimeMs = s.total_time_ms || 0
      avgTimeMs = s.avg_time_ms || 0
      topCommands = data.top_commands || []
      dailyData = data.daily || []
      weeklyData = data.weekly || []
      monthlyData = data.monthly || []
      failureCount = data.failures ? data.failures.total || 0 : 0
      recoveryPct = data.failures ? data.failures.recovery_pct || 0 : 0
      monthlyQuota = data.quota ? data.quota.estimated_monthly || "—" : "—"
      quotaPreservedPct = data.quota ? data.quota.preserved_pct || 0 : 0
      errorMessage = ""
      hasData = true
    } catch (e) {
      clearData("Invalid statistics response")
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
    command: ["bash", root.collectScript]
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
    contentWidth: popup.fittedContentWidth(Style.space(480))
    contentHeight: popup.fittedContentHeight(panel.implicitHeight)

    Column {
      id: panel
      width: parent ? parent.width : 0
      spacing: Style.space(10)

      // ═══════ Hero section ═══════
      Item {
        width: panel.width
        implicitHeight: heroLabels.implicitHeight + 4

        Column {
          id: heroLabels
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: 2

          Text {
            text: "RTK Token Savings"
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: 15
            font.bold: true
          }

          Text {
            text: root.hasData
              ? root.totalCommands + " commands · " + root.formatTime(root.totalTimeMs) + " total"
              : root.errorMessage !== "" ? root.errorMessage : "Loading…"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: 11
          }
        }
      }

      // ═══════ Summary stats ═══════
      Rectangle { width: panel.width; height: 1; color: root.dim; opacity: 0.15 }

      Grid {
        columns: 4
        columnSpacing: 8
        rowSpacing: 6
        width: panel.width

        // Row 1: Input / Output
        Text { text: "Input"; color: root.dim; font.family: root.fontFamily; font.pixelSize: 10 }
        Text { text: root.formatTokens(root.totalInput); color: root.fg; font.family: root.fontFamily; font.pixelSize: 11; font.bold: true; width: panel.width / 4 - 8 }
        Text { text: "Output"; color: root.dim; font.family: root.fontFamily; font.pixelSize: 10 }
        Text { text: root.formatTokens(root.totalOutput); color: root.fg; font.family: root.fontFamily; font.pixelSize: 11; font.bold: true }

        // Row 2: Saved / Avg time
        Text { text: "Saved"; color: root.dim; font.family: root.fontFamily; font.pixelSize: 10 }
        Text { text: root.formatTokens(root.totalSaved); color: root.fg; font.family: root.fontFamily; font.pixelSize: 11; font.bold: true; width: panel.width / 4 - 8 }
        Text { text: "Avg time"; color: root.dim; font.family: root.fontFamily; font.pixelSize: 10 }
        Text { text: root.formatTime(root.avgTimeMs); color: root.fg; font.family: root.fontFamily; font.pixelSize: 11; font.bold: true }
      }

      // ═══════ Efficiency bar ═══════
      Row {
        width: panel.width
        spacing: 8

        Text {
          text: "Efficiency"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: 10
          anchors.verticalCenter: parent.verticalCenter
        }

        Rectangle {
          width: panel.width - 100
          height: 6
          radius: 3
          color: Qt.rgba(root.dim.r, root.dim.g, root.dim.b, 0.15)
          anchors.verticalCenter: parent.verticalCenter

          Rectangle {
            width: parent.width * Math.min(1.0, root.avgSavingsPct / 100)
            height: parent.height
            radius: parent.radius
            color: root.avgSavingsPct > 50 ? root.accent
              : root.avgSavingsPct > 20 ? root.fg
              : root.dim
          }
        }

        Text {
          text: root.avgSavingsPct.toFixed(1) + "%"
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: 10
          font.bold: true
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      // ═══════ Top Commands ═══════
      Rectangle { width: panel.width; height: 1; color: root.dim; opacity: 0.15 }

      Column {
        width: panel.width
        spacing: 2
        visible: root.topCommands.length > 0

        Text {
          text: "Top Commands"
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: 11
          font.bold: true
          bottomPadding: 4
        }

        // Header
        Row {
          width: panel.width
          spacing: 4

          Text { text: "Command"; color: root.dim; font.family: root.fontFamily; font.pixelSize: 9; width: panel.width * 0.42 }
          Text { text: "#"; color: root.dim; font.family: root.fontFamily; font.pixelSize: 9; width: panel.width * 0.08; horizontalAlignment: Text.AlignRight }
          Text { text: "Saved"; color: root.dim; font.family: root.fontFamily; font.pixelSize: 9; width: panel.width * 0.14; horizontalAlignment: Text.AlignRight }
          Text { text: "Avg%"; color: root.dim; font.family: root.fontFamily; font.pixelSize: 9; width: panel.width * 0.12; horizontalAlignment: Text.AlignRight }
          Text { text: "Time"; color: root.dim; font.family: root.fontFamily; font.pixelSize: 9; width: panel.width * 0.14; horizontalAlignment: Text.AlignRight }
        }

        Rectangle { width: panel.width; height: 1; color: root.dim; opacity: 0.08 }

        Repeater {
          model: Math.min(root.topCommands.length, 8)

          Item {
            required property int index
            width: panel.width
            height: cmdRow.implicitHeight + 4

            readonly property var cmd: root.topCommands[index]

            Row {
              id: cmdRow
              width: parent.width
              spacing: 4
              anchors.verticalCenter: parent.verticalCenter

              Text {
                text: cmd ? cmd.command : ""
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: 10
                width: panel.width * 0.42
                elide: Text.ElideRight
              }
              Text {
                text: cmd ? String(cmd.count) : ""
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: 10
                width: panel.width * 0.08
                horizontalAlignment: Text.AlignRight
              }
              Text {
                text: cmd ? String(cmd.saved) : ""
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: 10
                font.bold: true
                width: panel.width * 0.14
                horizontalAlignment: Text.AlignRight
              }
              Text {
                text: cmd ? cmd.avg_pct.toFixed(1) + "%" : ""
                color: cmd && cmd.avg_pct > 30 ? root.accent : root.dim
                font.family: root.fontFamily
                font.pixelSize: 10
                width: panel.width * 0.12
                horizontalAlignment: Text.AlignRight
              }
              Text {
                text: cmd ? cmd.time : ""
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: 10
                width: panel.width * 0.14
                horizontalAlignment: Text.AlignRight
              }
            }

            // Impact bar under each row
            Rectangle {
              anchors.bottom: parent.bottom
              anchors.left: parent.left
              width: cmd ? parent.width * (cmd.saved / Math.max(1, root.topCommands[0].saved)) : 0
              height: 1
              color: root.accent
              opacity: 0.3
            }
          }
        }
      }

      // ═══════ Daily Activity ═══════
      Rectangle { width: panel.width; height: 1; color: root.dim; opacity: 0.15; visible: root.dailyData.length > 0 }

      Column {
        width: panel.width
        spacing: 2
        visible: root.dailyData.length > 0

        Text {
          text: "Daily Activity"
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: 11
          font.bold: true
          bottomPadding: 4
        }

        Repeater {
          model: Math.min(root.dailyData.length, 7)

          Item {
            required property int index
            width: panel.width
            height: dayRow.implicitHeight + 2

            readonly property var day: root.dailyData[root.dailyData.length - 1 - index]
            readonly property real maxCmds: {
              var max = 1
              for (var i = 0; i < root.dailyData.length; i++)
                if (root.dailyData[i].commands > max) max = root.dailyData[i].commands
              return max
            }

            Row {
              id: dayRow
              width: parent.width
              spacing: 6
              anchors.verticalCenter: parent.verticalCenter

              Text {
                text: day ? root.formatDate(day.date) : ""
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: 10
                width: 36
              }

              Item {
                width: panel.width - 36 - 50 - 60 - 18
                height: 6
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                  width: parent.width * (day ? day.commands / parent.parent.parent.maxCmds : 0)
                  height: parent.height
                  radius: height / 2
                  color: root.accent
                  opacity: 0.6
                }
              }

              Text {
                text: day ? day.commands + " cmds" : ""
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: 10
                width: 50
                horizontalAlignment: Text.AlignRight
              }

              Text {
                text: day ? root.formatTokens(day.saved_tokens) + " saved" : ""
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: 10
                width: 60
                horizontalAlignment: Text.AlignRight
              }
            }
          }
        }
      }

      // ═══════ Period summaries ═══════
      Rectangle {
        width: panel.width
        height: 1
        color: root.dim
        opacity: 0.15
        visible: root.weeklyData.length > 0 || root.monthlyData.length > 0
      }

      Column {
        width: panel.width
        spacing: 4
        visible: root.weeklyData.length > 0 || root.monthlyData.length > 0

        Text {
          text: "Period Summaries"
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: 11
          font.bold: true
        }

        Row {
          width: panel.width
          spacing: 8

          Text {
            text: "This week"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: 10
            width: panel.width * 0.24
          }
          Text {
            text: root.weeklyData.length > 0
              ? root.weeklyData[root.weeklyData.length - 1].commands + " cmds · "
                + root.formatTokens(root.weeklyData[root.weeklyData.length - 1].saved_tokens) + " saved"
              : "—"
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: 10
            width: panel.width * 0.76 - 8
          }
        }

        Row {
          width: panel.width
          spacing: 8

          Text {
            text: "This month"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: 10
            width: panel.width * 0.24
          }
          Text {
            text: root.monthlyData.length > 0
              ? root.monthlyData[root.monthlyData.length - 1].commands + " cmds · "
                + root.formatTokens(root.monthlyData[root.monthlyData.length - 1].saved_tokens) + " saved"
              : "—"
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: 10
            width: panel.width * 0.76 - 8
          }
        }
      }

      // ═══════ Health and quota ═══════
      Rectangle { width: panel.width; height: 1; color: root.dim; opacity: 0.15 }

      Column {
        width: panel.width
        spacing: 4

        Text {
          text: "Health & Quota"
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: 11
          font.bold: true
        }

        Row {
          width: panel.width
          spacing: 8

          Text { text: "Failures"; color: root.dim; font.family: root.fontFamily; font.pixelSize: 10; width: panel.width * 0.24 }
          Text { text: root.failureCount + " · " + root.recoveryPct.toFixed(1) + "% recovered"; color: root.fg; font.family: root.fontFamily; font.pixelSize: 10; width: panel.width * 0.76 - 8 }
        }

        Row {
          width: panel.width
          spacing: 8

          Text { text: "Monthly quota"; color: root.dim; font.family: root.fontFamily; font.pixelSize: 10; width: panel.width * 0.24 }
          Text { text: root.monthlyQuota + " · " + root.quotaPreservedPct.toFixed(1) + "% preserved"; color: root.fg; font.family: root.fontFamily; font.pixelSize: 10; width: panel.width * 0.76 - 8 }
        }
      }

      // ═══════ Footer ═══════
      Text {
        text: "Right-click to refresh"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: 9
        opacity: 0.4
      }
    }
  }
}
