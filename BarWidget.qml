import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Hollyland Lark M2 transmitter battery, read from the USB receiver by the
// sibling `lark-battery` script. A click opens the panel and reads the
// receiver right then. udev events show/hide the icon the moment the receiver
// is plugged or unplugged, and a slow background read (only while plugged in)
// drives the low-battery alert.
Panel {
  id: root
  moduleName: "rinku.lark-battery"
  ipcTarget: "rinku.lark-battery"

  readonly property string helper: decodeURIComponent(Qt.resolvedUrl("lark-battery").toString().replace("file://", ""))
  readonly property int lowThreshold: setting("lowThreshold", 15)

  property bool present: false
  property bool pending: false
  property string error: ""
  property var tx: []
  property var notified: ({})

  readonly property int connectedCount: tx.filter(t => t.connected).length
  readonly property bool low: tx.some(t => t.connected && t.battery <= lowThreshold)

  readonly property string statusText: {
    if (error) return error
    if (connectedCount === 0) return "Mics off"
    return connectedCount === 1 ? "1 mic on" : connectedCount + " mics on"
  }

  // A request landing mid-read (a plug event, say) runs once that read ends,
  // so the result always reflects the latest state.
  // Trust nothing from the helper's output: at most two transmitters, a
  // boolean and a 0-100 integer each, and a short plain-text error.
  function sanitize(data) {
    var list = Array.isArray(data.tx) ? data.tx.slice(0, 2) : []
    return {
      present: data.present === true,
      error: typeof data.error === "string" ? data.error.slice(0, 60) : "",
      tx: list.map(t => ({
        connected: !!t && t.connected === true,
        battery: Math.max(0, Math.min(100, Math.round(Number(t && t.battery) || 0)))
      }))
    }
  }

  function refresh() {
    if (proc.running) {
      pending = true
      return
    }
    proc.running = true
  }

  function checkLow() {
    var next = {}
    for (var i = 0; i < tx.length; i++) {
      var key = "tx" + (i + 1)
      var isLow = tx[i].connected && tx[i].battery <= lowThreshold
      // Arguments go straight to notify-send, never through a shell.
      if (isLow && !notified[key])
        Quickshell.execDetached(["/usr/bin/notify-send", "-u", "critical", "-a", "Lark M2",
                                 "Lark M2 battery low", "Mic " + (i + 1) + " at " + tx[i].battery + "%"])
      next[key] = isLow
    }
    notified = next
  }

  Component.onCompleted: refresh()
  onOpenedChanged: if (opened) refresh()
  onPresentChanged: if (!present) close()

  visible: present
  implicitWidth: present ? button.implicitWidth : 0
  implicitHeight: present ? button.implicitHeight : 0

  Process {
    id: proc
    command: [root.helper]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = root.sanitize(JSON.parse(text))
          root.present = data.present
          root.error = data.error
          root.tx = data.tx
          root.checkLow()
        } catch (e) {
          root.present = false
          root.tx = []
        }
        if (root.pending) {
          root.pending = false
          root.refresh()
        }
      }
    }
  }

  Timer {
    interval: Math.max(60, root.setting("interval", 600)) * 1000
    running: root.present
    repeat: true
    onTriggered: root.refresh()
  }

  // Blocks on the udev socket, so it costs nothing until a hidraw device
  // comes or goes. Debounced: one plug emits several events.
  Process {
    command: ["/usr/bin/udevadm", "monitor", "--udev", "--subsystem-match=hidraw"]
    running: true
    stdout: SplitParser {
      onRead: function(line) { if (line.indexOf("(hidraw)") !== -1) hotplug.restart() }
    }
  }

  Timer {
    id: hotplug
    interval: 800
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.connectedCount > 0 ? "󰍬" : "󰍭"
    dimmed: root.connectedCount === 0 && !root.error
    active: root.low || root.error !== ""
    onPressed: root.toggle()
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        // Hero: mic icon, title, status
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            text: button.text
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
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
              textFormat: Text.PlainText
              text: "Lark M2"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              textFormat: Text.PlainText
              text: root.statusText.toUpperCase()
              color: root.error ? root.bar.urgent : Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }
        }

        PanelSeparator {
          visible: root.tx.length > 0
          foreground: root.bar.foreground
        }

        // One row per transmitter: label, percentage, bar
        Repeater {
          model: root.tx

          Column {
            required property var modelData
            required property int index
            readonly property bool connected: modelData.connected
            readonly property bool isLow: connected && modelData.battery <= root.lowThreshold
            readonly property color tone: isLow ? root.bar.urgent : root.bar.foreground

            width: column.width
            spacing: Style.space(6)
            opacity: connected ? 1 : 0.45

            Item {
              width: parent.width
              implicitHeight: micLabel.implicitHeight

              Text {
                id: micLabel
                textFormat: Text.PlainText
                text: "Mic " + (index + 1)
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                anchors.left: parent.left
              }

              Text {
                textFormat: Text.PlainText
                text: connected ? modelData.battery + "%" : "Off"
                color: tone
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                font.bold: connected
                anchors.right: parent.right
              }
            }

            Item {
              width: parent.width
              implicitHeight: Style.space(6)

              Rectangle {
                id: track
                anchors.fill: parent
                radius: height / 2
                color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.12)
              }

              Rectangle {
                anchors.left: track.left
                anchors.verticalCenter: track.verticalCenter
                height: track.height
                radius: track.radius
                color: tone
                visible: connected
                width: Math.max(track.height, track.width * Math.min(100, modelData.battery) / 100)

                Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
              }
            }
          }
        }
      }
    }
  }
}
