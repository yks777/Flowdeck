import QtQuick
import qs.Commons

// Reusable chip/toggle button. Used by SettingsView (ModeChip) and
// StatsView (FilterChip). Active state drives fill opacity and border color.
Item {
  id: root
  property string label: ""
  property bool active: false
  signal clicked()

  implicitWidth: Math.max(72, chipLabel.implicitWidth + Style.space(16))
  implicitHeight: Style.space(26)

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: Color.accent
    opacity: root.active ? 0.22 : 0.0
    border.color: root.active ? Color.accent : Color.popups.border
    border.width: Math.max(1, Style.space(1))
  }
  Text {
    id: chipLabel
    anchors.centerIn: parent
    textFormat: Text.PlainText
    text: root.label
    color: root.active ? Color.accent : Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
  }
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
