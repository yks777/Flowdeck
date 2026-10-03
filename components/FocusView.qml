import QtQuick
import QtQuick.Layouts
import qs.Commons
import "../logic/Model.js" as Model

// Focus tab: compact, centered. Timer (technique comes from Settings) + active task + day.
ColumnLayout {
  id: root

  property var service: null

  spacing: Style.space(10)
  Layout.fillWidth: true

  readonly property string technique: {
    if (!root.service) return "pomodoro";
    void root.service.revision;
    var t = root.service.timer;
    // A live session (running/paused/break) always shows its own mode.
    if (t && (t.phase === "running" || t.phase === "paused" || t.phase === "break")
        && (t.mode === "pomodoro" || t.mode === "flowtime")) return t.mode;
    // Idle: the Settings choice (persisted) is the single source of truth.
    if (root.service.settings && root.service.settings.focusAction === "flowtime") return "flowtime";
    if (t && t.technique === "flowtime") return "flowtime";
    return "pomodoro";
  }

  function taskLine() {
    if (!root.service) return "No active task";
    void root.service.revision;
    var t = root.service.activeTask();
    return t ? t.title : "No active task — pick one in Matrix";
  }

  function dayLine() {
    if (!root.service) return "";
    void root.service.revision;
    void root.service.tickVersion;
    var s = root.service.todaySummary();
    return "Today " + Model.formatDur(s.focusSec) + "  ·  " + s.sessionCount + " sessions  ·  "
      + s.tasksDone + " done  ·  streak " + s.streak;
  }

  PomodoroView {
    service: root.service
    visible: root.technique === "pomodoro"
    Layout.fillWidth: true
  }

  FlowtimeView {
    service: root.service
    visible: root.technique === "flowtime"
    Layout.fillWidth: true
  }

  ColumnLayout {
    spacing: Style.space(4)
    Layout.fillWidth: true

    Text {
      textFormat: Text.PlainText
      text: "FOCUS"
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.letterSpacing: 2
      Layout.alignment: Qt.AlignHCenter
    }

    Text {
      textFormat: Text.PlainText
      text: "Working on:\n" + root.taskLine()
      color: Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
      elide: Text.ElideRight
      maximumLineCount: 2
      Layout.fillWidth: true
    }

    Text {
      textFormat: Text.PlainText
      text: root.dayLine()
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignHCenter
      Layout.fillWidth: true
    }
  }
}
