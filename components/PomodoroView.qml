import QtQuick
import QtQuick.Layouts
import qs.Commons
import "../logic/Model.js" as Model

// Pomodoro technique: timestamp-based countdown with auto breaks.
ColumnLayout {
  id: root

  property var service: null

  spacing: Style.space(10)
  Layout.fillWidth: true

  readonly property string phase: service ? String(service.timer.phase) : "stopped"
  readonly property string mode: service ? String(service.timer.mode) : "idle"
  readonly property bool isBreak: root.phase === "break"

  function timeText() {
    if (!root.service) return Model.formatClock(25 * 60);
    void root.service.tickVersion;
    if (root.phase === "running" || root.phase === "paused" || root.phase === "break") {
      var rem = Math.floor(root.service.timerRemainingMs() / 1000);
      return Model.formatClock(rem);
    }
    return Model.formatClock(root.service.settings.focusSec);
  }

  function stateLabel() {
    if (!root.service) return "IDLE";
    if (root.phase === "break") {
      return root.service.timer.breakKind === "long" ? "LONG BREAK" : "SHORT BREAK";
    }
    if (root.phase === "running") return "FOCUS";
    if (root.phase === "paused") return "PAUSED";
    return "READY";
  }

  function cycleLabel() {
    if (!root.service) return "";
    var every = Math.max(1, root.service.settings.longBreakInterval);
    var done = root.service.timer.pomodorosDone % every;
    return "Session " + (done + 1) + " of " + every;
  }

  Text {
    textFormat: Text.PlainText
    text: root.timeText()
    color: root.isBreak ? Color.accent : Color.popups.text
    font.family: Style.font.family
    font.pixelSize: Style.font.displayLarge
    horizontalAlignment: Text.AlignHCenter
    Layout.fillWidth: true
  }

  Text {
    textFormat: Text.PlainText
    text: root.stateLabel() + "  ·  " + root.cycleLabel()
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.letterSpacing: 1
    horizontalAlignment: Text.AlignHCenter
    Layout.fillWidth: true
  }

  RowLayout {
    spacing: Style.space(8)
    Layout.alignment: Qt.AlignHCenter
    visible: root.phase === "stopped"

    FlowButton {
      text: "Start"
      primary: true
      onClicked: root.service.startPomodoro()
    }
  }

  RowLayout {
    spacing: Style.space(8)
    Layout.alignment: Qt.AlignHCenter
    visible: root.phase === "running" && !root.isBreak

    FlowButton { text: "Pause"; onClicked: root.service.pauseTimer() }
    FlowButton { text: "Stop"; onClicked: root.service.stopTimer() }
  }

  RowLayout {
    spacing: Style.space(8)
    Layout.alignment: Qt.AlignHCenter
    visible: root.phase === "paused"

    FlowButton {
      text: "Resume"
      primary: true
      onClicked: root.service.resumeTimer()
    }
    FlowButton { text: "Stop"; onClicked: root.service.stopTimer() }
  }

  RowLayout {
    spacing: Style.space(8)
    Layout.alignment: Qt.AlignHCenter
    visible: root.isBreak

    FlowButton {
      text: "Skip break"
      primary: true
      onClicked: root.service.skipBreak()
    }
  }
}
