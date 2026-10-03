import QtQuick
import QtQuick.Layouts
import qs.Commons
import "../logic/Model.js" as Model
import "../logic/StatsEngine.js" as StatsEngine

// Stats view: TODAY grid, THIS WEEK bars, HISTORY with filters.
ColumnLayout {
  id: root

  property var service: null

  property string range: "today" // today | yesterday | all
  property string kind: "both" // both | pomo | flow

  spacing: Style.space(10)
  Layout.fillWidth: true

  readonly property var today: {
    if (!root.service) return null;
    void root.service.revision;
    void root.service.tickVersion;
    return root.service.todaySummary();
  }

  readonly property var week: {
    if (!root.service) return [];
    void root.service.revision;
    return root.service.weekData();
  }

  readonly property var hist: {
    if (!root.service) return [];
    void root.service.revision;
    return root.service.history(root.range, root.kind);
  }

  readonly property int weekMax: {
    var m = 60;
    for (var i = 0; i < root.week.length; i++) m = Math.max(m, root.week[i].focusSec);
    return m;
  }

  Text {
    textFormat: Text.PlainText
    text: "TODAY"
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.letterSpacing: 1
  }

  GridLayout {
    columns: 3
    rowSpacing: Style.space(6)
    columnSpacing: Style.space(6)
    Layout.fillWidth: true

    StatsCard { value: root.today ? Model.formatDur(root.today.focusSec) : "—"; label: "Focus" }
    StatsCard { value: root.today ? String(root.today.pomoCount) : "—"; label: "Pomodoro" }
    StatsCard { value: root.today ? String(root.today.flowCount) : "—"; label: "Flowtime" }
    StatsCard { value: root.today ? String(root.today.tasksDone) : "—"; label: "Tasks done" }
    StatsCard { value: root.today ? String(root.today.interruptions) : "—"; label: "Interruptions" }
    StatsCard { value: root.today ? String(root.today.streak) : "—"; label: "Streak" }
  }

  Text {
    textFormat: Text.PlainText
    text: "THIS WEEK"
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.letterSpacing: 1
  }

  ColumnLayout {
    spacing: Style.space(3)
    Layout.fillWidth: true

    Repeater {
      model: root.week
      delegate: RowLayout {
        required property var modelData
        spacing: Style.space(8)
        Layout.fillWidth: true

        Text {
          textFormat: Text.PlainText
          text: modelData.label
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          Layout.preferredWidth: Style.space(32)
        }
        Rectangle {
          height: Style.space(10)
          radius: height / 2
          color: Color.accent
          opacity: modelData.focusSec > 0 ? 0.85 : 0.15
          Layout.fillWidth: true
          // Proportional fill via a nested bar would need a second rect;
          // width factor on the fill container keeps one node per row.
          Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * Math.max(0.04, Math.min(1, modelData.focusSec / root.weekMax))
            radius: parent.radius
            color: Color.accent
            opacity: 0.9
          }
        }
        Text {
          textFormat: Text.PlainText
          text: Model.formatDur(modelData.focusSec)
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          Layout.preferredWidth: Style.space(52)
          horizontalAlignment: Text.AlignRight
        }
      }
    }
  }

  Text {
    textFormat: Text.PlainText
    text: "HISTORY"
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.letterSpacing: 1
  }

  RowLayout {
    spacing: Style.space(4)
    Layout.fillWidth: true

    Repeater {
      model: [
        { id: "today", label: "Today" },
        { id: "yesterday", label: "Yesterday" },
        { id: "all", label: "All" }
      ]
      delegate: Chip {
        required property var modelData
        label: modelData.label
        active: root.range === modelData.id
        onClicked: root.range = modelData.id
      }
    }
    Item { Layout.fillWidth: true }
    Repeater {
      model: [
        { id: "both", label: "Both" },
        { id: "pomo", label: "Pomo" },
        { id: "flow", label: "Flow" }
      ]
      delegate: Chip {
        required property var modelData
        label: modelData.label
        active: root.kind === modelData.id
        onClicked: root.kind = modelData.id
      }
    }
  }

  SessionHistory { sessions: root.hist; tickVersion: root.service ? root.service.tickVersion : 0 }

  Text {
    textFormat: Text.PlainText
    text: "No sessions yet — start a Pomodoro or Flowtime."
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    Layout.alignment: Qt.AlignHCenter
    visible: root.hist.length === 0
  }
}
