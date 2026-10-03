import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons

// Eisenhower matrix view: toolbar + four equal quadrant columns (linear).
// Mouse-first: every action is a click (card menu, column composers,
// toolbar). Completed tasks are hidden from the quadrants and listed in
// the Completed popup (with search); restoring returns the card to its
// original quadrant.
Item {
  id: root

  property var service: null

  property string menuTaskId: ""
  property bool completedOpen: false
  property string completedQuery: ""

  Layout.fillWidth: true
  Layout.fillHeight: true

  function toggleCardMenu(id) {
    root.menuTaskId = (root.menuTaskId === id ? "" : id);
  }

  readonly property var doneList: {
    if (!root.service) return [];
    void root.service.revision;
    return root.service.completedTasks(root.completedQuery);
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: Style.space(8)

    MatrixToolbar {
      id: toolbar
      service: root.service
      onAddTaskRequested: { col0.editorOpen = true; }
      onOpenCompleted: {
        root.completedQuery = "";
        root.completedOpen = true;
      }
    }

    RowLayout {
      spacing: Style.space(8)
      Layout.fillWidth: true
      Layout.fillHeight: true

      MatrixColumn {
        id: col0
        service: root.service
        columnId: "q1"
        title: "Q1 · DO"
        subtitle: "Urgent + Important"
        menuTaskId: root.menuTaskId
        onCardMenu: function(id) { root.toggleCardMenu(id); }
      }
      MatrixColumn {
        id: col1
        service: root.service
        columnId: "q2"
        title: "Q2 · SCHEDULE"
        subtitle: "Important, not urgent"
        menuTaskId: root.menuTaskId
        onCardMenu: function(id) { root.toggleCardMenu(id); }
      }
      MatrixColumn {
        id: col2
        service: root.service
        columnId: "q3"
        title: "Q3 · DELEGATE"
        subtitle: "Urgent, not important"
        menuTaskId: root.menuTaskId
        onCardMenu: function(id) { root.toggleCardMenu(id); }
      }
      MatrixColumn {
        id: col3
        service: root.service
        columnId: "q4"
        title: "Q4 · DELETE"
        subtitle: "Neither"
        menuTaskId: root.menuTaskId
        onCardMenu: function(id) { root.toggleCardMenu(id); }
      }
    }
  }

  // ---- Completed popup (overlay with search) ----
  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.55)
    visible: root.completedOpen
    MouseArea {
      anchors.fill: parent
      onClicked: root.completedOpen = false
    }
  }

  Rectangle {
    anchors.centerIn: parent
    width: Math.min(parent.width, Style.space(420))
    height: Math.min(parent.height, Style.space(380))
    radius: Style.cornerRadius
    color: Color.popups.background
    border.color: Color.popups.border
    border.width: Math.max(1, Style.space(1))
    visible: root.completedOpen

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.space(12)
      spacing: Style.space(8)

      RowLayout {
        spacing: Style.space(8)
        Layout.fillWidth: true

        Text {
          textFormat: Text.PlainText
          text: "COMPLETED (" + root.doneList.length + ")"
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
          Layout.fillWidth: true
        }

        FlowIconButton {
          glyph: "×"
          tip: "Close"
          onClicked: root.completedOpen = false
        }
      }

      FlowInput {
        id: doneSearch
        placeholder: "Search completed..."
        Layout.fillWidth: true
        onAccepted: {}
        onCancelled: { doneSearch.text = ""; root.completedQuery = ""; }
      }

      Connections {
        target: doneSearch
        function onTextChanged() { root.completedQuery = doneSearch.text; }
      }

      ListView {
        id: doneView
        model: root.doneList
        spacing: Style.space(6)
        clip: true
        Layout.fillWidth: true
        Layout.fillHeight: true

        delegate: Rectangle {
          required property var modelData
          width: doneView.width
          implicitHeight: doneRow.implicitHeight + Style.space(12)
          radius: Style.cornerRadius
          color: "transparent"
          border.color: Color.popups.border
          border.width: Math.max(1, Style.space(1))

          RowLayout {
            id: doneRow
            anchors.fill: parent
            anchors.margins: Style.space(8)
            spacing: Style.space(8)

            Text {
              textFormat: Text.PlainText
              text: parent.parent.modelData.title
              color: Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
              wrapMode: Text.Wrap
              maximumLineCount: 2
              Layout.fillWidth: true
            }

            FlowButton {
              text: "Restore"
              onClicked: {
                if (root.service) root.service.reopenTask(parent.parent.modelData.id);
              }
            }
            FlowIconButton {
              glyph: "×"
              tip: "Delete permanently"
              onClicked: {
                if (root.service) root.service.deleteTask(parent.parent.modelData.id);
              }
            }
          }
        }

        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: root.completedQuery !== "" ? "No matches" : "Nothing completed yet"
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          visible: root.doneList.length === 0
        }
      }
    }
  }
}
