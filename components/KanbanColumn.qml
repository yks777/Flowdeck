import QtQuick
import qs.Commons

Item {
  id: root
  property string columnId: "inbox"
  property var store: null
  property string searchText: ""
  property string selectedTaskId: ""

  readonly property var state: store ? store.state : null
  readonly property var tasks: state ? Model.tasksByColumn(state, columnId, state.activeSpaceId) : []
  readonly property string label: Model.COLUMN_LABELS[columnId] || columnId

  width: parent ? parent.width : 200
  height: parent ? parent.height : 400

  Column {
    id: col
    anchors.fill: parent
    spacing: Style.spacing.sm

    Text {
      textFormat: Text.PlainText
      text: root.label
      color: Qt.darker(Color.popups.text, 1.5)
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.bold: true
      letterSpacing: 1
      width: parent.width
    }

    Rectangle {
      width: parent.width
      height: Style.spacing.hairline
      color: Qt.darker(Color.popups.text, 2.5)
    }

    Column {
      width: parent.width
      spacing: Style.spacing.xs
      Repeater {
        model: root.tasks.filter(function(t) {
          if (!root.searchText) return true;
          var q = root.searchText.toLowerCase();
          return t.title.toLowerCase().indexOf(q) !== -1 || t.description.toLowerCase().indexOf(q) !== -1;
        })
        delegate: TaskCard {
          width: parent.width
          task: modelData
          selected: root.selectedTaskId === modelData.id
          store: root.store
        }
      }
    }
  }
}
