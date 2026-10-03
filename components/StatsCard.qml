import QtQuick
import QtQuick.Layouts
import qs.Commons

// One stat cell: big value over a caption label.
Rectangle {
  id: root

  property string value: ""
  property string label: ""

  Layout.fillWidth: true
  implicitHeight: Style.space(64)
  radius: Style.cornerRadius
  color: "transparent"
  border.color: Color.popups.border
  border.width: Math.max(1, Style.space(1))
  opacity: 1.0

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.space(6)
    spacing: 0

    Text {
      textFormat: Text.PlainText
      text: root.value
      color: Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.title
      Layout.alignment: Qt.AlignHCenter
    }
    Text {
      textFormat: Text.PlainText
      text: root.label
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      Layout.alignment: Qt.AlignHCenter
    }
  }
}
