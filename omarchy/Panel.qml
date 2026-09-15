import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "yux.whisper"
  ipcTarget: "yux.whisper"
  manageIpc: false

  // Paths
  readonly property string scriptDir: Quickshell.env("HOME") + "/Projects/WhisperApp/omarchy"
  readonly property string statePath: Quickshell.env("HOME") + "/.local/state/omarchy/whisper.json"
  readonly property string configPath: Quickshell.env("HOME") + "/.config/omarchy/whisper.json"

  // Dictation State
  property string dictationState: "idle"
  property string recognizedText: ""
  property string errorMessage: ""
  property real startedAt: 0.0
  property var historyList: []
  property int elapsedSeconds: 0

  // Config properties
  property string groqApiKey: ""
  property bool correctText: true
  property string language: "auto"
  property bool showOsd: true

  // Feedback banner
  property string feedbackMessage: ""

  // Bar appearance
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool vertical: bar ? bar.vertical : false
  readonly property int barSize: bar ? bar.barSize : Style.bar.sizeHorizontal

  readonly property string barDisplayText: {
    if (vertical) {
      if (dictationState === "recording") return "󰍬"
      if (dictationState === "transcribing" || dictationState === "correcting") return "󰑐"
      if (dictationState === "done") return "󰄬"
      return "󰍬"
    }
    if (dictationState === "recording") {
      return "󰍬 ฟัง... " + formatTime(elapsedSeconds)
    }
    if (dictationState === "transcribing") {
      return "󰑐 Whisper..."
    }
    if (dictationState === "correcting") {
      return "󰑐 AI แก้คำ..."
    }
    if (dictationState === "done") {
      return "󰄬 เรียบร้อย"
    }
    if (dictationState === "error") {
      return "󰅚 ผิดพลาด"
    }
    return "󰍬 Whisper"
  }

  readonly property string tooltipContent: {
    var tip = "🎙️ Whisper AI Dictation (Omarchy)\n"
    tip += "สถานะ: " + dictationState + "\n"
    tip += "คีย์ลัด: SUPER + H (กดค้าง = Hold to Talk / แตะ = Toggle)\n"
    tip += "ยกเลิก: SUPER + ALT + ESCAPE\n"
    tip += "คลิกซ้าย: เปิดการตั้งค่าและดูประวัติ"
    return tip
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // --- State Tracker ---
  FileView {
    id: stateFileView
    path: root.statePath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: root.reloadState()
    onLoaded: root.parseState(text())
  }

  FileView {
    id: configFileView
    path: root.configPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: root.reloadConfig()
    onLoaded: root.parseConfig(text())
  }

  function reloadState() {
    stateFileView.reload()
  }

  function reloadConfig() {
    configFileView.reload()
  }

  function parseState(raw) {
    if (!raw || raw.trim() === "") return
    try {
      var data = JSON.parse(raw)
      root.dictationState = data.state || "idle"
      root.recognizedText = data.text || ""
      root.errorMessage = data.error || ""
      root.startedAt = data.started_at || 0.0
      if (Array.isArray(data.history)) {
        root.historyList = data.history
      }
      if (root.dictationState === "recording" && root.startedAt > 0) {
        root.elapsedSeconds = Math.max(0, Math.floor(Date.now() / 1000 - root.startedAt))
      } else if (root.dictationState === "idle") {
        root.elapsedSeconds = 0
      }
    } catch (e) {
      console.warn("whisper: error parsing state JSON:", e)
    }
  }

  function parseConfig(raw) {
    if (!raw || raw.trim() === "") return
    try {
      var data = JSON.parse(raw)
      if (typeof data.groq_api_key === "string") root.groqApiKey = data.groq_api_key
      if (typeof data.correct_text === "boolean") root.correctText = data.correct_text
      if (typeof data.language === "string") root.language = data.language
    } catch (e) {
      console.warn("whisper: error parsing config JSON:", e)
    }
  }

  // --- Timer for Recording ---
  Timer {
    id: recordingTimer
    interval: 500
    repeat: true
    running: root.dictationState === "recording"
    onTriggered: {
      if (root.startedAt > 0) {
        root.elapsedSeconds = Math.max(0, Math.floor(Date.now() / 1000 - root.startedAt))
      } else {
        root.elapsedSeconds += 1
      }
    }
  }

  function formatTime(sec) {
    var m = Math.floor(sec / 60)
    var s = sec % 60
    return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s)
  }

  function formatTimeAgo(ts) {
    if (!ts) return ""
    var diffSec = Math.max(0, Math.floor(Date.now() / 1000 - ts))
    if (diffSec < 60) return "เมื่อสักครู่"
    var diffMin = Math.floor(diffSec / 60)
    if (diffMin < 60) return diffMin + " นาทีที่แล้ว"
    var diffHour = Math.floor(diffMin / 60)
    if (diffHour < 24) return diffHour + " ชม. ที่แล้ว"
    return Math.floor(diffHour / 24) + " วันที่แล้ว"
  }

  function runCmd(args) {
    var cmd = [root.scriptDir + "/whisper-ctl"]
    for (var i = 0; i < args.length; i++) {
      cmd.push(args[i])
    }
    Quickshell.execDetached(cmd)
  }

  function copyTextToClipboard(txt) {
    if (!txt) return
    Quickshell.execDetached(["wl-copy", "--", txt])
    root.feedbackMessage = "คัดลอกลง Clipboard แล้ว!"
    feedbackTimer.restart()
  }

  Timer {
    id: feedbackTimer
    interval: 2000
    onTriggered: root.feedbackMessage = ""
  }

  // --- IPC Handler for omarchy-shell ---
  IpcHandler {
    target: "yux.whisper"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function start(): void { root.runCmd(["start"]) }
    function stop(): void { root.runCmd(["stop"]) }
    function cancel(): void { root.runCmd(["cancel"]) }
  }

  // --- Bar Widget Button ---
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.barDisplayText
    labelVisible: true
    hasVisualContent: true
    fixedWidth: root.vertical ? root.barSize : -1
    fixedHeight: root.vertical ? Style.bar.iconSlot : -1
    horizontalMargin: 8.75
    verticalPadding: 6
    tooltipText: root.tooltipContent

    Rectangle {
      visible: root.dictationState === "recording"
      anchors.fill: parent
      radius: Style.cornerRadius
      color: Color.urgent
      opacity: 0.2

      SequentialAnimation on opacity {
        running: root.dictationState === "recording"
        loops: Animation.Infinite
        NumberAnimation { to: 0.35; duration: 600; easing.type: Easing.InOutQuad }
        NumberAnimation { to: 0.10; duration: 600; easing.type: Easing.InOutQuad }
      }
    }

    onPressed: function(buttonCode) {
      root.toggle()
    }
  }

  // --- Floating Status OSD Pill ---
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: osdWindow
      required property var modelData
      screen: modelData
      visible: root.dictationState !== "idle" && root.showOsd

      WlrLayershell.namespace: "whisper-osd"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"

      anchors { top: true; bottom: true; left: true; right: true }
      mask: Region { item: osdCard }

      BorderSurface {
        id: osdCard
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(70)

        width: Math.min(Style.space(480), Math.max(Style.space(260), osdContent.implicitWidth + Style.space(32)))
        height: Math.max(Style.space(46), osdContent.implicitHeight + Style.space(20))

        color: Util.alpha(Color.background, 0.95)
        borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
        radius: Style.cornerRadius

        RowLayout {
          id: osdContent
          anchors.centerIn: parent
          spacing: Style.space(12)

          Item {
            width: Style.space(24)
            height: Style.space(24)
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
              id: recDot
              visible: root.dictationState === "recording"
              anchors.centerIn: parent
              width: Style.space(14)
              height: Style.space(14)
              radius: Style.space(7)
              color: Color.urgent

              SequentialAnimation on scale {
                running: root.dictationState === "recording"
                loops: Animation.Infinite
                NumberAnimation { to: 1.3; duration: 500; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 0.9; duration: 500; easing.type: Easing.InOutQuad }
              }
            }

            Text {
              visible: root.dictationState === "transcribing" || root.dictationState === "correcting"
              anchors.centerIn: parent
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              color: "#f59e0b"
              text: "󰑐"

              RotationAnimator on rotation {
                running: root.dictationState === "transcribing" || root.dictationState === "correcting"
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 1000
              }
            }

            Text {
              visible: root.dictationState === "done"
              anchors.centerIn: parent
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              color: "#10b981"
              text: "󰄬"
            }

            Text {
              visible: root.dictationState === "error"
              anchors.centerIn: parent
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              color: Color.urgent
              text: "󰅚"
            }
          }

          ColumnLayout {
            spacing: Style.space(2)
            Layout.alignment: Qt.AlignVCenter

            Text {
              font.family: Style.font.family
              font.bold: true
              font.pixelSize: Style.font.body
              color: Color.popups.text

              text: {
                if (root.dictationState === "recording") return "กำลังฟังเสียง... (" + root.formatTime(root.elapsedSeconds) + ")"
                if (root.dictationState === "transcribing") return "กำลังถอดเสียง (Groq Whisper)..."
                if (root.dictationState === "correcting") return "กำลังเกลาคำ (Llama 3.3)..."
                if (root.dictationState === "pasting") return "กำลังวางข้อความ..."
                if (root.dictationState === "done") return "วางข้อความเรียบร้อย!"
                if (root.dictationState === "error") return root.errorMessage || "เกิดข้อผิดพลาด"
                return ""
              }
            }

            Text {
              visible: root.dictationState === "recording" || (root.dictationState === "done" && root.recognizedText !== "")
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: Util.alpha(Color.popups.text, 0.7)
              elide: Text.ElideRight
              Layout.maximumWidth: Style.space(380)

              text: {
                if (root.dictationState === "recording") {
                  return "ปล่อยปุ่ม SUPER+H หรือกดอีกครั้งเพื่อจบ"
                }
                if (root.dictationState === "done") {
                  return "“" + root.recognizedText + "”"
                }
                return ""
              }
            }
          }
        }
      }
    }
  }

  // --- Main Popup Panel (Omarchy KeyboardPanel) ---
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: contentColumn
        width: parent.width
        spacing: Style.space(12)

        // 1. Header Card
        Row {
          width: parent.width
          spacing: Style.space(10)

          Rectangle {
            width: Style.space(36)
            height: Style.space(36)
            radius: Style.cornerRadius
            color: Qt.rgba(0.94, 0.35, 0.15, 0.15)
            border.width: 1
            border.color: Qt.rgba(0.94, 0.35, 0.15, 0.35)

            Text {
              anchors.centerIn: parent
              text: "󰍬"
              color: "#f97316"
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.title
            }
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, parent.width - Style.space(36) - Style.space(10) - closeBtn.width - Style.space(10))
            spacing: Style.space(2)

            Text {
              text: "Whisper AI Dictation"
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.subtitle
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              text: "Groq Whisper + Llama 3.3 AI"
              color: Qt.darker(root.contentForeground, 1.4)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              width: parent.width
            }
          }

          // Close button
          Rectangle {
            id: closeBtn
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(28)
            height: Style.space(28)
            radius: Style.cornerRadius
            color: closeMouse.containsMouse ? Style.normalFillFor(root.contentForeground, Color.accent) : "transparent"

            Text {
              anchors.centerIn: parent
              text: "󰅖"
              color: Qt.darker(root.contentForeground, 1.3)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
            }

            MouseArea {
              id: closeMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.close()
            }
          }
        }

        // Feedback toast banner
        Rectangle {
          visible: root.feedbackMessage !== ""
          width: parent.width
          height: Style.space(28)
          radius: Style.cornerRadius
          color: "#10b981"
          opacity: 0.25

          Text {
            anchors.centerIn: parent
            text: root.feedbackMessage
            color: Color.popups.text
            font.family: root.contentFontFamily
            font.bold: true
            font.pixelSize: Style.font.caption
          }
        }

        // 2. Main Action Buttons
        Row {
          width: parent.width
          spacing: Style.space(8)

          Button {
            width: (parent.width - Style.space(8)) * 0.7
            text: root.dictationState === "recording" ? "⏹️ หยุดและวางข้อความ" : "🎙️ เริ่มพูด (SUPER + H)"
            active: root.dictationState === "recording"
            onClicked: root.runCmd(["toggle"])
          }

          Button {
            width: (parent.width - Style.space(8)) * 0.3
            text: "❌ ยกเลิก"
            onClicked: root.runCmd(["cancel"])
          }
        }

        PanelSeparator {}

        // 3. Settings Card
        PanelSectionHeader {
          text: "การตั้งค่า (Settings)"
        }

        // Groq API Key Input
        Row {
          width: parent.width
          spacing: Style.space(8)

          TextField {
            id: keyField
            width: parent.width - saveKeyBtn.width - Style.space(8)
            password: true
            placeholderText: root.groqApiKey ? "••••••••••••••••••••" : "ใส่ Groq API Key (gsk_...)"
          }

          Button {
            id: saveKeyBtn
            text: "บันทึก Key"
            onClicked: {
              if (keyField.text.trim() !== "") {
                root.runCmd(["set-key", keyField.text.trim()])
                keyField.text = ""
                root.feedbackMessage = "บันทึก Groq API Key สำเร็จ!"
                feedbackTimer.restart()
              }
            }
          }
        }

        // Toggle LLM Correction
        Toggle {
          width: parent.width
          label: "เกลาภาษาด้วย AI (Llama 3.3)"
          description: "แก้คำสะกด วรรณยุกต์ และจัดวรรคตอนอัตโนมัติ"
          checked: root.correctText
          onClicked: {
            root.correctText = !root.correctText
            root.runCmd(["config", "set", "correct_text", root.correctText ? "true" : "false"])
          }
        }

        // Shortcut description
        Text {
          width: parent.width
          text: "⌨️ คีย์ลัด: กด SUPER + H ค้างเพื่อพูด หรือแตะสั้นเพื่อ Toggle\n❌ ยกเลิก: SUPER + ALT + ESCAPE"
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          color: Qt.darker(root.contentForeground, 1.4)
          wrapMode: Text.WordWrap
          lineHeight: 1.3
        }

        PanelSeparator {}

        // 4. Recent History Card
        PanelSectionHeader {
          text: "ประวัติข้อความล่าสุด"
        }

        Column {
          width: parent.width
          spacing: Style.space(4)

          Repeater {
            model: Math.min(5, root.historyList.length)

            Rectangle {
              width: contentColumn.width
              height: Style.space(38)
              radius: Style.cornerRadius
              color: histItemMouse.containsMouse ? Style.normalFillFor(root.contentForeground, Color.accent) : "transparent"

              Row {
                anchors.fill: parent
                anchors.margins: Style.space(6)
                spacing: Style.space(8)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "󰅍"
                  color: Qt.darker(root.contentForeground, 1.3)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                }

                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - Style.space(60)
                  spacing: 0

                  Text {
                    text: root.historyList[index].text || ""
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    color: root.contentForeground
                    elide: Text.ElideRight
                    width: parent.width
                  }

                  Text {
                    text: root.formatTimeAgo(root.historyList[index].timestamp)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption * 0.85
                    color: Qt.darker(root.contentForeground, 1.5)
                  }
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  visible: histItemMouse.containsMouse
                  text: "คัดลอก"
                  color: Color.accent
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              MouseArea {
                id: histItemMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.copyTextToClipboard(root.historyList[index].text)
              }
            }
          }

          Text {
            visible: root.historyList.length === 0
            text: "ยังไม่มีประวัติการพูด"
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            color: Qt.darker(root.contentForeground, 1.6)
            anchors.horizontalCenter: parent.horizontalCenter
          }
        }
      }
    }
  }
}
