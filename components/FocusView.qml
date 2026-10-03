import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "FocusEngine.js" as Focus

Item {
  id: root
  property var store: null
  readonly property var state: store ? store.state : null
  readonly property var timer: state ? state.timer : null
  readonly property var settings: state ? state.settings : null
  readonly property bool isRunning: timer ? timer.status === Focus.STATUS_RUNNING : false
  readonly property bool isPaused: timer ? timer.status === Focus.STATUS_PAUSED : false
  readonly property bool isBreak: timer ? timer.status === Focus.STATUS_BREAK : false
  readonly property bool isFlow: timer ? timer.technique === Focus.TECHNIQUE_FLOWTIME : false
  readonly property bool inFlowFocus: timer ? timer.technique === Focus.TECHNIQUE_FLOWTIME && timer.phase === Focus.PHASE_FOCUS : false
  readonly property int displaySec: timer ? Focus.displaySeconds(state) : 0
  readonly property string displayText: inFlowFocus ? Focus.formatCompact(displaySec) : Focus.formatClock(displaySec)
  readonly property var activeTask: {
    if (!state || !timer || !timer.activeTaskId) return null;
    for (var i = 0; i < state.tasks.length; i++) {
      if (state.tasks[i].id === timer.activeTaskId) return state.tasks[i];
    }
    return null;
  }
  readonly property int flowElapsed: timer ? Focus.flowElapsedSec(state) : 0
  readonly property int suggestedBreak: inFlowFocus ? Focus.suggestedBreakSeconds(flowElapsed, settings) : 0

  width: parent ? parent.width : 400
  height: implicitHeight

  Column {
    id: content
    width: parent.width
    spacing: Style.spacing.md
    anchors.horizontalCenter: parent.horizontalCenter

    // Timer display
    Item {
      width: parent.width
      height: Style.space(80)
      anchors.horizontalCenter: parent.horizontalCenter

      Text {
        id: timerText
        textFormat: Text.PlainText
        text: root.displayText
        color: root.isBreak ? Color.urgent : Color.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.display
        font.bold: true
        anchors.centerIn: parent
      }

      Text {
        textFormat: Text.PlainText
        text: root.inFlowFocus ? "FLOWTIME" : root.isBreak ? "BREAK" : root.isPaused ? "PAUSED" : root.isRunning ? (root.timer.phase === Focus.PHASE_WORK ? "WORK" : "FOCUS") : "READY"
        color: Qt.darker(Color.popups.text, 1.5)
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        anchors.top: timerText.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Style.space(4)
      }
    }

    // Active task
    Item {
      width: parent.width
      height: root.activeTask ? Style.space(48) : 0
      visible: root.activeTask

      Column {
        anchors.centerIn: parent
        spacing: Style.space(2)

        Text {
          textFormat: Text.PlainText
          text: "Working on"
          color: Qt.darker(Color.popups.text, 1.6)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
          textFormat: Text.PlainText
          text: root.activeTask.title
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.bold: true
          anchors.horizontalCenter: parent.horizontalCenter
          elide: Text.ElideRight
          width: Math.min(parent.width, Style.space(300))
          horizontalAlignment: Text.AlignHCenter
        }

        Text {
          textFormat: Text.PlainText
          text: (root.timer.interruptions > 0 ? root.timer.interruptions + " interruption" + (root.timer.interruptions > 1 ? "s" : "") + " \u00b7 " : "") + "Suggested break " + Focus.formatDuration(root.suggestedBreak)
          color: Qt.darker(Color.popups.text, 1.4)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          anchors.horizontalCenter: parent.horizontalCenter
          visible: root.inFlowFocus
        }
      }
    }

    // Actions
    Row {
      width: parent.width
      spacing: Style.space(6)
      anchors.horizontalCenter: parent.horizontalCenter

      Button {
        text: root.isPaused ? "Resume" : (root.isRunning || root.isBreak ? "Pause" : "Start")
        fontSize: Style.font.caption
        selected: root.isRunning || root.isBreak
        onClicked: store.sendOp({ op: "toggle" })
      }

      Button {
        text: "+ Interruption"
        fontSize: Style.font.caption
        enabled: root.inFlowFocus
        onClicked: store.sendOp({ op: "interrupt" })
        visible: root.inFlowFocus
      }
    }

    Row {
      width: parent.width
      spacing: Style.space(6)
      anchors.horizontalCenter: parent.horizontalCenter

      Button {
        text: "Finish"
        fontSize: Style.font.caption
        enabled: root.inFlowFocus
        onClicked: store.sendOp({ op: "finishFlow" })
        visible: root.inFlowFocus
      }

      Button {
        text: "Finish + break"
        fontSize: Style.font.caption
        enabled: root.inFlowFocus
        onClicked: store.sendOp({ op: "finishFlowAndBreak" })
        visible: root.inFlowFocus
      }

      Button {
        text: "Stop"
        fontSize: Style.font.caption
        enabled: root.isRunning || root.isBreak || root.isPaused
        onClicked: store.sendOp({ op: "stop" })
        visible: root.isRunning || root.isBreak || root.isPaused
      }

      Button {
        text: "Reset"
        fontSize: Style.font.caption
        enabled: !root.isRunning && !root.isBreak && !root.isPaused
        onClicked: store.sendOp({ op: "reset" })
        visible: !root.isRunning && !root.isBreak && !root.isPaused
      }
    }

    // Today summary
    Row {
      width: parent.width
      spacing: Style.space(8)
      anchors.horizontalCenter: parent.horizontalCenter

      Text {
        textFormat: Text.PlainText
        text: "Today: " + Focus.formatDuration(Stats.todaySummary(state).totalFocusSec)
        color: Qt.darker(Color.popups.text, 1.3)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }

      Text {
        textFormat: Text.PlainText
        text: "\u00b7"
        color: Qt.darker(Color.popups.text, 1.5)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }

      Text {
        textFormat: Text.PlainText
        text: Stats.todaySummary(state).pomodoroCount + " pomo"
        color: Qt.darker(Color.popups.text, 1.3)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }

      Text {
        textFormat: Text.PlainText
        text: "\u00b7"
        color: Qt.darker(Color.popups.text, 1.5)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }

      Text {
        textFormat: Text.PlainText
        text: Stats.todaySummary(state).flowCount + " flow"
        color: Qt.darker(Color.popups.text, 1.3)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }
}
