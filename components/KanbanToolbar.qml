import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root
  property var store: null
  property bool editing: false
  property string editSpaceId: ""
  property string editName: ""
  property bool menuOpen: false

  width: parent ? parent.width : 800
  height: implicitHeight

  readonly property var state: store ? store.state : null
  readonly property var spaces: state ? state.spaces : []
  readonly property int activeIndex: {
    if (!state) return 0;
    for (var i = 0; i < spaces.length; i++) {
      if (spaces[i].id === state.activeSpaceId) return i;
    }
    return 0;
  }

  Row {
    id: toolbar
    width: parent.width
    height: implicitHeight + Style.space(8)
    spacing: Style.space(6)

    Text {
      textFormat: Text.PlainText
      text: "KANBAN"
      color: Color.accent
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.bold: true
      letterSpacing: 1
      anchors.verticalCenter: parent.verticalCenter
    }

    Item {
      width: Style.space(8)
      height: 1
    }

    Button {
      id: boardSelect
      text: root.state ? (root.spaces[root.activeIndex] ? root.spaces[root.activeIndex].name : "Board") : "Board"
      fontSize: Style.font.caption
      anchors.verticalCenter: parent.verticalCenter
      onClicked: {
        root.menuOpen = !root.menuOpen;
      }
    }

    Item {
      width: Style.space(4)
      height: 1
    }

    Button {
      text: "\u22EE"
      fontSize: Style.font.bodySmall
      anchors.verticalCenter: parent.verticalCenter
      onClicked: {
        root.menuOpen = !root.menuOpen;
      }
    }
  }

  // Custom dropdown menu
  Rectangle {
    id: dropdown
    width: Style.space(200)
    height: menuCol.implicitHeight + Style.space(8)
    color: Color.popups.background
    border.color: Color.popups.border
    border.width: 1
    radius: Style.cornerRadius
    visible: root.menuOpen
    anchors.top: toolbar.bottom
    anchors.topMargin: Style.space(4)
    anchors.left: boardSelect.left

    Column {
      id: menuCol
      anchors.fill: parent
      anchors.margins: Style.space(4)
      spacing: Style.space(2)

      Repeater {
        model: root.spaces
        delegate: Item {
          width: parent.width
          height: Style.space(28)
          Rectangle {
            anchors.fill: parent
            color: mouseArea.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent, Color.urgent) : "transparent"
            radius: Style.cornerRadius
          }
          Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: modelData.name
            color: modelData.id === (root.state ? root.state.activeSpaceId : "") ? Color.accent : Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: modelData.id === (root.state ? root.state.activeSpaceId : "")
          }
          MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
              root.store.sendOp({ op: "setSpace", id: modelData.id });
              root.menuOpen = false;
            }
          }
        }
      }

      Rectangle {
        width: parent.width
        height: Style.spacing.hairline
        color: Qt.darker(Color.popups.text, 2.5)
      }

      Item {
        width: parent.width
        height: Style.space(28)
        Rectangle {
          anchors.fill: parent
          color: mouseArea.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent, Color.urgent) : "transparent"
          radius: Style.cornerRadius
        }
        Text {
          anchors.left: parent.left
          anchors.leftMargin: Style.space(6)
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: "New board"
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }
        MouseArea {
          id: mouseArea
          anchors.fill: parent
          hoverEnabled: true
          onClicked: {
            root.editing = true;
            root.editSpaceId = "";
            root.editName = "";
            root.menuOpen = false;
            Qt.callLater(function() { nameField.forceActiveFocus(); });
          }
        }
      }

      Item {
        width: parent.width
        height: Style.space(28)
        enabled: root.state && root.spaces.length > 0
        Rectangle {
          anchors.fill: parent
          color: mouseArea.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent, Color.urgent) : "transparent"
          radius: Style.cornerRadius
          opacity: parent.enabled ? 1 : 0.5
        }
        Text {
          anchors.left: parent.left
          anchors.leftMargin: Style.space(6)
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: "Rename board"
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          opacity: parent.enabled ? 1 : 0.5
        }
        MouseArea {
          id: mouseArea
          anchors.fill: parent
          hoverEnabled: true
          enabled: parent.enabled
          onClicked: {
            if (root.state && root.spaces[root.activeIndex]) {
              root.editing = true;
              root.editSpaceId = root.spaces[root.activeIndex].id;
              root.editName = root.spaces[root.activeIndex].name;
              root.menuOpen = false;
              Qt.callLater(function() { nameField.forceActiveFocus(); });
            }
          }
        }
      }

      Item {
        width: parent.width
        height: Style.space(28)
        enabled: root.state && root.spaces.length > 1
        Rectangle {
          anchors.fill: parent
          color: mouseArea.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent, Color.urgent) : "transparent"
          radius: Style.cornerRadius
          opacity: parent.enabled ? 1 : 0.5
        }
        Text {
          anchors.left: parent.left
          anchors.leftMargin: Style.space(6)
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: "Delete board"
          color: Color.urgent
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          opacity: parent.enabled ? 1 : 0.5
        }
        MouseArea {
          id: mouseArea
          anchors.fill: parent
          hoverEnabled: true
          enabled: parent.enabled
          onClicked: {
            if (root.state && root.spaces[root.activeIndex]) {
              root.store.requestDeleteSpace(root.spaces[root.activeIndex].id);
              root.menuOpen = false;
            }
          }
        }
      }
    }
  }

  TextField {
    id: nameField
    visible: root.editing
    width: parent.width
    placeholderText: "Board name"
    text: root.editName
    font.pixelSize: Style.font.bodySmall
    maximumLength: 30
    onAccepted: {
      var name = text.trim();
      if (!name) {
        root.editing = false;
        return;
      }
      if (root.editSpaceId) {
        root.store.sendOp({ op: "renameSpace", id: root.editSpaceId, name: name });
      } else {
        root.store.sendOp({ op: "createSpace", name: name });
      }
      root.editing = false;
      text = "";
    }
    Keys.onEscapePressed: {
      root.editing = false;
      text = "";
    }
  }
}
