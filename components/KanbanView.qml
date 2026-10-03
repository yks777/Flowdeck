import QtQuick
import qs.Commons

Item {
  id: root
  property var store: null
  property string searchText: ""
  property string selectedTaskId: ""

  width: parent ? parent.width : 800
  height: parent ? parent.height : 400

  Row {
    id: board
    anchors.fill: parent
    spacing: Style.spacing.md

    Repeater {
      model: ["inbox", "ready", "focus", "done"]
      delegate: Item {
        id: colWrapper
        width: (board.width - board.spacing * 3) / 4
        height: parent.height
        clip: true

        Flickable {
          id: colFlick
          anchors.fill: parent
          contentHeight: column.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          interactive: column.implicitHeight > height

          KanbanColumn {
            id: column
            width: parent.width
            columnId: modelData
            store: root.store
            searchText: root.searchText
            selectedTaskId: root.selectedTaskId
          }
        }
      }
    }
  }
}
