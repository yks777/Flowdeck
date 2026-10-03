import QtQuick
import qs.Commons

Item {
  id: root
  property string label: ""
  property alias content: contentItem

  width: parent ? parent.width : 200
  height: contentItem.implicitHeight + Style.space(8)

  Row {
    id: contentItem
    width: parent.width
    spacing: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter

    Text {
      textFormat: Text.PlainText
      text: root.label
      color: Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      width: Style.space(100)
      elide: Text.ElideRight
      anchors.verticalCenter: parent.verticalCenter
    }
  }
}
