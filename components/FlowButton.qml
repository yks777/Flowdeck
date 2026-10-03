import QtQuick
import qs.Commons

// Primary/secondary button. Theme-safe: translucent fill, no hardcoded colors.
Rectangle {
  id: root

  property string text: ""
  property bool primary: false
  property bool enabledButton: true
  signal clicked()

  implicitWidth: Math.max(64, label.implicitWidth + Style.space(24))
  implicitHeight: Style.space(32)
  radius: Style.cornerRadius
  opacity: root.enabledButton ? 1.0 : 0.45

  color: "transparent"
  border.color: root.primary ? Color.accent : Color.popups.border
  border.width: Math.max(1, Style.space(1))

  Rectangle {
    anchors.fill: parent
    anchors.margins: parent.border.width
    radius: Math.max(0, parent.radius - parent.border.width)
    color: Color.accent
    opacity: root.primary ? 0.22 : 0.0
    visible: root.primary
  }

  Text {
    id: label
    anchors.centerIn: parent
    textFormat: Text.PlainText
    text: root.text
    color: root.primary ? Color.accent : Color.popups.text
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
  }

  MouseArea {
    anchors.fill: parent
    enabled: root.enabledButton
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
