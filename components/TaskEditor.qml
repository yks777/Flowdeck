import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root
  property var store: null
  property string taskId: ""
  readonly property var task: taskId && store ? Model.getTask(store.state, taskId) : null

  width: parent ? parent.width : 400
  height: implicitHeight

  Column {
    width: parent.width
    spacing: Style.space(6)
    visible: root.task

    TextField {
      id: titleField
      width: parent.width
      placeholderText: "Task title"
      text: root.task ? root.task.title : ""
      font.pixelSize: Style.font.bodySmall
      onAccepted: {
        if (text.trim() !== "" && root.store) {
          root.store.sendOp({ op: "updateTask", id: root.taskId, changes: { title: text.trim() } });
        }
      }
    }

    TextField {
      id: descField
      width: parent.width
      placeholderText: "Description (optional)"
      text: root.task ? root.task.description : ""
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WordWrap
      maximumLength: 2000
      onAccepted: {
        if (root.store) {
          root.store.sendOp({ op: "updateTask", id: root.taskId, changes: { description: text } });
        }
      }
    }

    Row {
      width: parent.width
      spacing: Style.space(4)

      Button {
        text: "Inbox"
        fontSize: Style.font.caption
        selected: root.task && root.task.columnId === "inbox"
        onClicked: root.store.sendOp({ op: "moveTask", id: root.taskId, columnId: "inbox" })
      }

      Button {
        text: "Ready"
        fontSize: Style.font.caption
        selected: root.task && root.task.columnId === "ready"
        onClicked: root.store.sendOp({ op: "moveTask", id: root.taskId, columnId: "ready" })
      }

      Button {
        text: "Focus"
        fontSize: Style.font.caption
        selected: root.task && root.task.columnId === "focus"
        onClicked: root.store.sendOp({ op: "moveTask", id: root.taskId, columnId: "focus" })
      }

      Button {
        text: "Done"
        fontSize: Style.font.caption
        selected: root.task && root.task.columnId === "done"
        onClicked: root.store.sendOp({ op: "moveTask", id: root.taskId, columnId: "done" })
      }

      Item { width: Style.space(8); height: 1 }

      Button {
        text: "Delete"
        fontSize: Style.font.caption
        onClicked: root.store.requestDeleteTask(root.taskId, root.task ? root.task.title : "")
      }
    }
  }
}
