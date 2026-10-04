import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons

// One Eisenhower quadrant: header with count, vertical task scroll, inline add.
ColumnLayout {
  id: root

  property var service: null
  property string columnId: "q1"
  property string title: "Q1 · DO"
  property string subtitle: ""
  property bool editorOpen: false
  property string menuTaskId: ""
  property bool dropHighlight: false
  property bool listFrozen: false

  signal cardMenu(string taskId)

  spacing: Style.space(6)
  Layout.fillWidth: true
  Layout.fillHeight: true

  readonly property var columnTasks: {
    if (!root.service) return [];
    void root.service.revision;
    return root.service.tasksForColumn(root.columnId);
  }

  ColumnLayout {
    spacing: 0
    Layout.fillWidth: true

    RowLayout {
      spacing: Style.space(6)
      Layout.alignment: Qt.AlignHCenter

      Text {
        textFormat: Text.PlainText
        text: root.title
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.letterSpacing: 1
      }
      Text {
        textFormat: Text.PlainText
        text: String(root.columnTasks.length)
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }

    Text {
      textFormat: Text.PlainText
      text: root.subtitle
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      visible: root.subtitle !== ""
      horizontalAlignment: Text.AlignHCenter
      Layout.fillWidth: true
    }
  }

  Rectangle {
    height: Math.max(1, Style.space(1))
    color: root.dropHighlight ? Color.accent : Color.popups.border
    opacity: root.dropHighlight ? 1.0 : 0.5
    Layout.fillWidth: true
  }

  ListView {
    id: list
    model: root.columnTasks
    spacing: Style.space(6)
    clip: true
    interactive: !root.listFrozen
    Layout.fillWidth: true
    Layout.fillHeight: true
    ScrollBar.vertical: ScrollBar {
      policy: ScrollBar.AsNeeded
      visible: list.contentHeight > list.height + 1
      background: Item {
        implicitWidth: Style.space(6)
      }
      contentItem: Rectangle {
        implicitWidth: Style.space(6)
        radius: width / 2
        color: Color.muted
      }
    }

    // Drop target for dragged cards. A plain (non-delegate) child: it
    // fills the list, stays transparent to mouse clicks and only reacts
    // to active drags.
    DropArea {
      id: dropZone
      anchors.fill: parent
      onEntered: { root.dropHighlight = true; }
      onExited: { root.dropHighlight = false; }
      onDropped: function(drop) {
        root.dropHighlight = false;
        if (!root.service || !drop || !drop.source || !drop.source.task) return;
        var taskId = String(drop.source.task.id);
        var fromCol = String(drop.source.task.columnId || "");
        if (fromCol === root.columnId) return;
        root.service.moveTask(taskId, root.columnId);
      }
    }

    // Full-column tint while a drag hovers: impossible to miss.
    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: Color.accent
      opacity: root.dropHighlight ? 0.10 : 0.0
    }

    delegate: TaskCard {
      required property var modelData
      required property int index
      task: modelData
      width: list.width
      isActive: root.service ? root.service.activeTaskId === modelData.id : false
      menuOpen: root.menuTaskId === modelData.id
      timerLive: root.service ? (root.service.timer.phase === "running" || root.service.timer.phase === "paused" || root.service.timer.phase === "break") : false
      focusAction: root.service ? String(root.service.settings.focusAction || "pomodoro") : "pomodoro"
      onToggleMenu: root.cardMenu(modelData.id)
      onStartFocus: {
        if (!root.service) return;
        root.service.setActiveTask(modelData.id);
        if (String(root.service.settings.focusAction || "pomodoro") === "flowtime") root.service.startFlowtime(modelData.id);
        else root.service.startPomodoro(modelData.id);
      }
      onDone: { if (root.service) root.service.completeTask(modelData.id); }
      onEditSave: function(title) { if (root.service) root.service.updateTask(modelData.id, { title: title }); }
      onRemove: { if (root.service) root.service.deleteTask(modelData.id); }
      onDragStarted: { root.listFrozen = true; }
      onDragFinished: { root.listFrozen = false; }
    }

    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: "Empty"
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      visible: root.columnTasks.length === 0 && !root.editorOpen
    }
  }

  TaskEditor {
    id: editor
    visible: root.editorOpen
    Layout.fillWidth: true
    onSaved: function(title) {
      if (root.service) root.service.createTask(title, root.columnId);
      root.editorOpen = false;
    }
    onCancelled: { root.editorOpen = false; }
  }

  onEditorOpenChanged: {
    if (root.editorOpen) Qt.callLater(function() { editor.focusInput(); });
  }

  FlowButton {
    text: "+ Add task"
    visible: !root.editorOpen
    Layout.fillWidth: true
    onClicked: {
      root.editorOpen = true;
      Qt.callLater(function() { editor.focusInput(); });
    }
  }
}
