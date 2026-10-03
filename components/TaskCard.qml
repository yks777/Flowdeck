import QtQuick
import QtQuick.Layouts
import qs.Commons
import "../logic/Model.js" as Model

// Compact task card, mouse-first. Click toggles the action menu; press and
// hold starts a drag that can be dropped on any quadrant. Destructive actions
// always ask first.
Rectangle {
  id: root

  property var task: null
  property bool isActive: false
  property bool menuOpen: false
  property bool timerLive: false
  property string focusAction: "pomodoro"
  signal toggleMenu()
  signal startFocus()
  signal done()
  signal editSave(string title)
  signal remove()
  signal dragStarted()
  signal dragFinished()

  property bool confirmingDelete: false
  property bool confirmingSwitch: false
  property bool editing: false
  property bool dragging: false
  property string dragImage: ""

  implicitWidth: 200
  implicitHeight: main.implicitHeight + Style.space(16)
  radius: Style.cornerRadius
  color: "transparent"
  border.color: root.dragging ? Color.accent : (root.menuOpen ? Color.accent : (hover.containsMouse ? Color.popups.border : Qt.rgba(0, 0, 0, 0)))
  border.width: Math.max(1, Style.space(1))
  opacity: root.dragging ? 0.7 : 1.0

  Drag.active: root.dragging
  Drag.source: root
  Drag.imageSource: root.dragImage
  Drag.hotSpot.x: width / 2
  Drag.hotSpot.y: Style.space(16)

  function endDrag() {
    if (root.dragging) {
      root.dragging = false;
      root.dragImage = "";
      root.dragFinished();
    }
  }

  // Snapshot the card so a ghost pixmap follows the cursor while dragging.
  // Started only from the grab callback (a frame later): if the snapshot
  // fails we still drag with translucency as fallback.
  function beginDrag() {
    if (root.editing || root.dragging) return;
    if (root.menuOpen) root.toggleMenu();
    try {
      root.grabToImage(function(result) {
        if (result && result.url) root.dragImage = String(result.url);
        root.dragging = true;
        root.dragStarted();
      });
    } catch (e) {
      root.dragging = true;
      root.dragStarted();
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: parent.radius
    color: Color.accent
    opacity: root.isActive ? 0.10 : 0.0
  }

  // Click/drag catcher BELOW the content so buttons receive events first.
  // preventStealing keeps the ListView from hijacking the press: a hold
  // always reaches pressAndHold (deterministic drag start), while list
  // scrolling stays available via wheel, empty gaps and the ScrollBar.
  MouseArea {
    id: clickCatcher
    anchors.fill: parent
    pressAndHoldInterval: 350
    preventStealing: true
    cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    onClicked: {
      if (root.editing || root.dragging) return;
      root.confirmingSwitch = false;
      root.toggleMenu();
    }
    onPressAndHold: root.beginDrag()
    onReleased: root.endDrag()
    onCanceled: root.endDrag()
  }

  ColumnLayout {
    id: main
    anchors.fill: parent
    anchors.margins: Style.space(8)
    spacing: Style.space(6)

    RowLayout {
      spacing: Style.space(6)
      Layout.fillWidth: true

      Rectangle {
        width: Style.space(8)
        height: Style.space(8)
        radius: width / 2
        color: !root.task ? Color.muted
          : root.task.priority === "high" ? Color.urgent
          : root.task.priority === "low" ? Color.muted : Color.accent
        Layout.alignment: Qt.AlignVCenter
      }

      Text {
        textFormat: Text.PlainText
        text: root.task ? root.task.title : ""
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
        maximumLineCount: 2
        wrapMode: Text.Wrap
        Layout.fillWidth: true
        visible: !root.editing
      }

      FlowInput {
        id: titleEditor
        text: root.task ? root.task.title : ""
        placeholder: "Task title..."
        visible: root.editing
        Layout.fillWidth: true
        onAccepted: { root.editing = false; root.editSave(titleEditor.text); }
        onCancelled: { root.editing = false; }
      }

      Text {
        textFormat: Text.PlainText
        text: root.task ? Model.formatDur(root.task.totalFocusSeconds) : ""
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        visible: root.task && root.task.totalFocusSeconds > 0 && !root.editing
      }

      Text {
        textFormat: Text.PlainText
        text: "●"
        color: Color.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        visible: root.isActive
      }
    }

    ColumnLayout {
      spacing: Style.space(4)
      Layout.fillWidth: true
      visible: (hover.containsMouse || root.menuOpen) && !root.editing

      RowLayout {
        spacing: Style.space(4)
        Layout.fillWidth: true

        MiniAction {
          label: root.confirmingSwitch ? "Switch?" : "Focus"
          accent: true
          onClicked: {
            if (root.timerLive && !root.confirmingSwitch) {
              root.confirmingSwitch = true;
            } else {
              root.confirmingSwitch = false;
              root.startFocus();
            }
          }
        }
        MiniAction {
          label: "Done"
          onClicked: { root.confirmingSwitch = false; root.done(); }
        }
      }

      RowLayout {
        spacing: Style.space(4)
        Layout.fillWidth: true

        MiniAction {
          label: "Edit"
          onClicked: {
            root.confirmingSwitch = false;
            root.editing = true;
            Qt.callLater(function() { titleEditor.focusInput(); });
          }
        }
        MiniAction {
          label: root.confirmingDelete ? "Confirm delete" : "Delete"
          danger: true
          onClicked: {
            root.confirmingSwitch = false;
            if (root.confirmingDelete) { root.confirmingDelete = false; root.remove(); }
            else root.confirmingDelete = true;
          }
        }
      }
    }
  }

  component MiniAction: Item {
    id: mini
    property string label: ""
    property bool accent: false
    property bool danger: false
    signal clicked()
    implicitWidth: Math.max(56, miniLabel.implicitWidth + Style.space(16))
    implicitHeight: Style.space(28)

    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: mini.danger ? Color.urgent : Color.accent
      opacity: hoverMini.containsMouse ? 0.25 : 0.10
    }
    Text {
      id: miniLabel
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: mini.label
      color: mini.danger ? Color.urgent : (mini.accent ? Color.accent : Color.popups.text)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
    MouseArea {
      id: hoverMini
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: mini.clicked()
    }
  }

  // Hover detector stays on TOP but never accepts buttons, so it reveals
  // the actions without swallowing their clicks.
  MouseArea {
    id: hover
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
  }
}
