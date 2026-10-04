import QtQuick
import QtQuick.Layouts
import qs.Commons
import "../logic/Model.js" as Model
import "../logic/TimerEngine.js" as TimerEngine

// Flowtime technique: count-up focus with manual finish and interruptions.
ColumnLayout {
  id: root

  property var service: null

  spacing: Style.space(10)
  Layout.fillWidth: true

  readonly property string phase: service ? String(service.timer.phase) : "stopped"
  readonly property bool live: root.phase === "running" || root.phase === "paused"

  function elapsedText() {
    if (!root.service) return Model.formatClock(0);
    void root.service.tickVersion;
    if (root.live) return Model.formatClock(Math.floor(root.service.flowElapsedMs() / 1000));
    return Model.formatClock(0);
  }

  function breakHint() {
    if (!root.service || !root.live) return "";
    var el = Math.floor(root.service.flowElapsedMs() / 1000);
    var sug = TimerEngine.suggestedBreakSec(el, root.service.settings);
    return "Suggested break: " + Model.formatDur(sug);
  }

  function interruptionsText() {
    if (!root.service) return "";
    var n = root.service.timer.interruptions || 0;
    return n === 1 ? "1 interruption" : n + " interruptions";
  }

  Text {
    textFormat: Text.PlainText
    text: root.elapsedText()
    color: Color.popups.text
    font.family: Style.font.family
    font.pixelSize: Style.font.displayLarge
    horizontalAlignment: Text.AlignHCenter
    Layout.fillWidth: true
  }

  Text {
    textFormat: Text.PlainText
    text: root.live ? (root.interruptionsText() + "  ·  " + root.breakHint()) : "Count up. Finish when focus ends."
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    horizontalAlignment: Text.AlignHCenter
    Layout.fillWidth: true
  }

  RowLayout {
    spacing: Style.space(8)
    Layout.alignment: Qt.AlignHCenter
    visible: !root.live

    FlowButton {
      text: "Start"
      primary: true
      onClicked: root.service.startFlowtime()
    }
  }

  ColumnLayout {
    spacing: Style.space(8)
    Layout.alignment: Qt.AlignHCenter
    Layout.fillWidth: true
    visible: root.live

    RowLayout {
      spacing: Style.space(8)
      Layout.alignment: Qt.AlignHCenter
      visible: root.phase === "running"

      FlowButton { text: "Pause"; onClicked: root.service.pauseTimer() }
      FlowButton { text: "+ Interruption"; onClicked: root.service.addInterruption() }
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

      FlowButton {
        text: "Finish focus"
        primary: true
        onClicked: root.service.finishFlowtime("focus")
      }
      FlowButton {
        text: "Finish + break"
        onClicked: root.service.finishFlowtime("break")
      }
    }
  }
}
