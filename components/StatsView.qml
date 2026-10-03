import QtQuick
import qs.Commons
import "StatsEngine.js" as Stats
import "FocusEngine.js" as Focus

Item {
  id: root
  property var store: null
  readonly property var state: store ? store.state : null

  width: parent ? parent.width : 400
  height: parent ? parent.height : 400

  Column {
    id: content
    width: parent.width
    spacing: Style.spacing.lg
    anchors.horizontalCenter: parent.horizontalCenter

    // Today
    Text {
      textFormat: Text.PlainText
      text: "TODAY"
      color: Color.accent
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.bold: true
      letterSpacing: 1
    }

    Grid {
      id: todayGrid
      width: parent.width
      columns: 2
      columnSpacing: Style.space(8)
      rowSpacing: Style.space(4)

      Text {
        textFormat: Text.PlainText
        text: "Focus"
        color: Qt.darker(Color.popups.text, 1.4)
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
      Text {
        textFormat: Text.PlainText
        text: Focus.formatDuration(Stats.todaySummary(state).totalFocusSec)
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.bold: true
      }

      Text {
        textFormat: Text.PlainText
        text: "Pomodoro"
        color: Qt.darker(Color.popups.text, 1.4)
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
      Text {
        textFormat: Text.PlainText
        text: Stats.todaySummary(state).pomodoroCount
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }

      Text {
        textFormat: Text.PlainText
        text: "Flowtime"
        color: Qt.darker(Color.popups.text, 1.4)
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
      Text {
        textFormat: Text.PlainText
        text: Stats.todaySummary(state).flowCount
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }

      Text {
        textFormat: Text.PlainText
        text: "Tasks done"
        color: Qt.darker(Color.popups.text, 1.4)
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
      Text {
        textFormat: Text.PlainText
        text: Stats.todaySummary(state).tasksDone
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }

      Text {
        textFormat: Text.PlainText
        text: "Interruptions"
        color: Qt.darker(Color.popups.text, 1.4)
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
      Text {
        textFormat: Text.PlainText
        text: Stats.todaySummary(state).interruptions
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }

      Text {
        textFormat: Text.PlainText
        text: "Streak"
        color: Qt.darker(Color.popups.text, 1.4)
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
      Text {
        textFormat: Text.PlainText
        text: Stats.streakDays(state.sessions, state.settings.streakMinSec) + " days"
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.bold: true
      }
    }

    // Week bars
    Text {
      textFormat: Text.PlainText
      text: "THIS WEEK"
      color: Color.accent
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.bold: true
      letterSpacing: 1
    }

    Row {
      id: weekBars
      width: parent.width
      height: Style.space(80)
      spacing: Style.space(4)

      Repeater {
        model: Stats.weekSummary(state.sessions, state.activeSpaceId, state.settings.weekStartsOn)
        delegate: Item {
          width: (weekBars.width - weekBars.spacing * 6) / 7
          height: parent.height
          anchors.verticalCenter: parent.verticalCenter

          Column {
            anchors.centerIn: parent
            spacing: Style.space(2)

            Text {
              textFormat: Text.PlainText
              text: modelData.label
              color: Qt.darker(Color.popups.text, 1.4)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              anchors.horizontalCenter: parent.horizontalCenter
            }

            Rectangle {
              width: Style.space(16)
              height: Math.max(Style.space(2), Math.min(parent.height - Style.space(20), modelData.seconds > 0 ? Math.max(Style.space(2), Math.log10(modelData.seconds + 1) * Style.space(6)) : 0))
              color: modelData.seconds > 0 ? Color.accent : Qt.darker(Color.popups.text, 2.5)
              radius: Style.cornerRadius > 0 ? width / 2 : 0
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom
              anchors.bottomMargin: Style.space(4)
            }

            Text {
              textFormat: Text.PlainText
              text: Focus.formatDuration(modelData.seconds)
              color: Qt.darker(Color.popups.text, 1.3)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              anchors.horizontalCenter: parent.horizontalCenter
            }
          }
        }
      }
    }
  }
}
