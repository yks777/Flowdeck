import QtQuick
import qs.Commons

Item {
  id: root
  property var task: null
  property bool selected: false
  property bool compact: true

  width: parent ? parent.width : 200
  height: compact ? Style.space(36) : Style.space(52)

  Rectangle {
    id: bg
    anchors.fill: parent
    color: root.selected ? Style.selectedFillFor(Color.popups.text, Color.accent, Color.urgent) : "transparent"
    border.color: root.selected ? Color.accent : Qt.darker(Color.popups.text, 2.5)
    border.width: root.selected ? 1 : Style.spacing.hairline
    radius: Style.cornerRadius
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: {
      if (root.task) {
        root.parent.parent.parent.selectedTaskId = root.selected ? "" : root.task.id;
      }
    }
    onDoubleClicked: {
      if (root.task && root.store) {
        root.store.sendOp({ op: "startFocusOn", id: root.task.id });
        root.store.togglePanel();
      }
    }
  }

  Row {
    id: row
    anchors.fill: parent
    anchors.leftMargin: Style.space(8)
    anchors.rightMargin: Style.space(8)
    spacing: Style.space(6)

    Text {
      textFormat: Text.PlainText
      text: root.task ? root.task.title : ""
      color: Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
      width: parent.width - Style.space(60)
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      textFormat: Text.PlainText
      text: root.task && root.task.priority === "p0" ? "!" : root.task && root.task.priority === "p1" ? "!" : ""
      color: Color.urgent
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.bold: true
      anchors.verticalCenter: parent.verticalCenter
      visible: root.task && (root.task.priority === "p0" || root.task.priority === "p1")
    }

    Text {
      textFormat: Text.PlainText
      text: root.task ? root.task.totalFocusSeconds + "s" : ""
      color: Qt.darker(Color.popups.text, 1.4)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      anchors.verticalCenter: parent.verticalCenter
    }
  }
}
