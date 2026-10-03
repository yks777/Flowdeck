import QtQuick
import QtQuick.Layouts
import qs.Commons

// Focus | Matrix | Stats — Settings is NOT a tab (gear in the header).
RowLayout {
  id: root

  property string currentView: "focus"
  signal selectView(string view)

  spacing: Style.space(4)
  Layout.fillWidth: true

  Repeater {
    model: [
      { id: "focus", label: "Focus" },
      { id: "matrix", label: "Matrix" },
      { id: "stats", label: "Stats" }
    ]
    delegate: Item {
      id: tab
      required property var modelData
      Layout.fillWidth: true
      implicitHeight: Style.space(32)

      Rectangle {
        anchors.fill: parent
        radius: Style.cornerRadius
        color: Color.accent
        opacity: root.currentView === tab.modelData.id ? 0.20 : 0.0
      }
      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.max(1, Style.space(2))
        color: Color.accent
        visible: root.currentView === tab.modelData.id
      }
      Text {
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: tab.modelData.label
        color: root.currentView === tab.modelData.id ? Color.accent : Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.selectView(tab.modelData.id)
      }
    }
  }
}
