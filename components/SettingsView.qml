import QtQuick
import QtQuick.Layouts
import qs.Commons

// Settings: replaces the content view, offers a back action. Sections:
// Focus, Flowtime, Stats, Notifications, Shortcuts, Data.
ColumnLayout {
  id: root

  property var service: null
  signal back()

  property bool confirmingReset: false

  spacing: Style.space(12)
  Layout.fillWidth: true

  RowLayout {
    spacing: Style.space(10)
    Layout.fillWidth: true

    FlowIconButton {
      glyph: "‹"
      tip: "Back"
      onClicked: root.back()
    }
    Text {
      textFormat: Text.PlainText
      text: "SETTINGS"
      color: Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.letterSpacing: 2
      Layout.fillWidth: true
    }
  }

  Section {
    title: "Focus"
    ColumnLayout {
      spacing: Style.space(10)
      Layout.fillWidth: true
      RowLayout {
        spacing: Style.space(8)
        Layout.fillWidth: true
        SettingLabel { text: "Technique" }
        Item { Layout.fillWidth: true }
        Chip { label: "Pomodoro"; active: root.service && root.service.settings.focusAction === "pomodoro"; onClicked: root.service.updateSettings({ focusAction: "pomodoro" }) }
        Chip { label: "Flowtime"; active: root.service && root.service.settings.focusAction === "flowtime"; onClicked: root.service.updateSettings({ focusAction: "flowtime" }) }
      }
      NumberRow { label: "Focus duration"; unit: "min"; value: root.service ? root.service.settings.focusSec / 60 : 25; onCommit: function(v) { root.service.updateSettings({ focusSec: v * 60 }); } }
      NumberRow { label: "Short break"; unit: "min"; value: root.service ? root.service.settings.shortBreakSec / 60 : 5; onCommit: function(v) { root.service.updateSettings({ shortBreakSec: v * 60 }); } }
      NumberRow { label: "Long break"; unit: "min"; value: root.service ? root.service.settings.longBreakSec / 60 : 15; onCommit: function(v) { root.service.updateSettings({ longBreakSec: v * 60 }); } }
      NumberRow { label: "Sessions per long break"; unit: ""; value: root.service ? root.service.settings.longBreakInterval : 4; onCommit: function(v) { root.service.updateSettings({ longBreakInterval: v }); } }
    }
  }

  Section {
    title: "Flowtime"
    ColumnLayout {
      spacing: Style.space(10)
      Layout.fillWidth: true
      RowLayout {
        spacing: Style.space(8)
        Layout.fillWidth: true
        SettingLabel { text: "Break mode" }
        Item { Layout.fillWidth: true }
        Chip { label: "Traditional"; active: root.service && root.service.settings.flowBreakMode === "traditional"; onClicked: root.service.updateSettings({ flowBreakMode: "traditional" }) }
        Chip { label: "Proportional"; active: root.service && root.service.settings.flowBreakMode === "proportional"; onClicked: root.service.updateSettings({ flowBreakMode: "proportional" }) }
      }
      NumberRow { label: "Break percentage"; unit: "%"; value: root.service ? Math.round(root.service.settings.flowBreakPct * 100) : 20; onCommit: function(v) { root.service.updateSettings({ flowBreakPct: v / 100 }); } }
      NumberRow { label: "Minimum break"; unit: "min"; value: root.service ? root.service.settings.flowBreakMinSec / 60 : 5; onCommit: function(v) { root.service.updateSettings({ flowBreakMinSec: v * 60 }); } }
      NumberRow { label: "Maximum break"; unit: "min"; value: root.service ? root.service.settings.flowBreakMaxSec / 60 : 15; onCommit: function(v) { root.service.updateSettings({ flowBreakMaxSec: v * 60 }); } }
    }
  }

  Section {
    title: "Stats"
    ColumnLayout {
      spacing: Style.space(10)
      Layout.fillWidth: true
      NumberRow { label: "Daily streak minimum"; unit: "min"; value: root.service ? root.service.settings.streakMinSec / 60 : 25; onCommit: function(v) { root.service.updateSettings({ streakMinSec: v * 60 }); } }
    }
  }

  Section {
    title: "Notifications"
    ColumnLayout {
      spacing: Style.space(10)
      Layout.fillWidth: true
      ToggleRow {
        label: "Enabled"
        checked: root.service ? root.service.settings.notificationsEnabled : true
        onToggled: function(v) { root.service.updateSettings({ notificationsEnabled: v }); }
      }
      ToggleRow {
        label: "Sound"
        checked: root.service ? root.service.settings.soundEnabled : true
        onToggled: function(v) { root.service.updateSettings({ soundEnabled: v }); }
      }
    }
  }

  Section {
    title: "Shortcuts"
    ColumnLayout {
      spacing: Style.space(10)
      Layout.fillWidth: true
      RowLayout {
        spacing: Style.space(8)
        Layout.fillWidth: true
        SettingLabel { text: "Open Flowdeck" }
        Item { Layout.fillWidth: true }
        Chip { label: "Off"; active: root.service && root.service.settings.toggleShortcut === ""; onClicked: root.service.updateSettings({ toggleShortcut: "" }) }
        Chip { label: "Super+H"; active: root.service && root.service.settings.toggleShortcut === "super+h"; onClicked: root.service.updateSettings({ toggleShortcut: "super+h" }) }
        Chip { label: "Super+Shift+H"; active: root.service && root.service.settings.toggleShortcut === "super+shift+h"; onClicked: root.service.updateSettings({ toggleShortcut: "super+shift+h" }) }
      }
      RowLayout {
        spacing: Style.space(8)
        Layout.alignment: Qt.AlignHCenter
        Chip { label: "Alt+H"; active: root.service && root.service.settings.toggleShortcut === "alt+h"; onClicked: root.service.updateSettings({ toggleShortcut: "alt+h" }) }
        Chip { label: "Ctrl+Shift+H"; active: root.service && root.service.settings.toggleShortcut === "ctrl+shift+h"; onClicked: root.service.updateSettings({ toggleShortcut: "ctrl+shift+h" }) }
      }
    }
  }

  Section {
    title: "Data"
    ColumnLayout {
      spacing: Style.space(10)
      Layout.fillWidth: true
      Text {
        textFormat: Text.PlainText
        text: root.service ? ("Stored at " + root.service.stateFilePath) : ""
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true
      }
      RowLayout {
        spacing: Style.space(8)
        Layout.alignment: Qt.AlignHCenter
        FlowButton { text: "Export"; onClicked: { if (root.service) root.service.exportData(); } }
        FlowButton { text: "Import"; onClicked: { if (root.service) root.service.importData(); } }
        FlowButton {
          text: root.confirmingReset ? "Confirm reset" : "Reset"
          onClicked: {
            if (root.confirmingReset) {
              if (root.service) root.service.resetAll();
              root.confirmingReset = false;
            } else {
              root.confirmingReset = true;
            }
          }
        }
      }
      Text {
        textFormat: Text.PlainText
        text: "Import replaces all tasks, sessions and timer state. Reset wipes tasks and history but keeps settings."
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true
      }
    }
  }

  // ---- building blocks (local, theme-token only) ----

  component Section: ColumnLayout {
    id: sec
    property string title: ""
    spacing: Style.space(8)
    Layout.fillWidth: true
    Layout.leftMargin: Style.space(4)
    Layout.rightMargin: Style.space(4)
    Text {
      textFormat: Text.PlainText
      text: sec.title.toUpperCase()
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.letterSpacing: 1
      horizontalAlignment: Text.AlignHCenter
      Layout.fillWidth: true
    }
    Rectangle {
      height: Math.max(1, Style.space(1))
      color: Color.popups.border
      opacity: 0.5
      Layout.fillWidth: true
    }
  }

  component SettingLabel: Text {
    color: Color.popups.text
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    Layout.fillWidth: true
  }

  component NumberRow: RowLayout {
    id: num
    property string label: ""
    property string unit: ""
    property real value: 0
    signal commit(real v)
    spacing: Style.space(10)
    Layout.fillWidth: true
    SettingLabel { text: num.label }
    Text {
      textFormat: Text.PlainText
      text: num.unit
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      visible: num.unit !== ""
    }
    FlowInput {
      id: numInput
      numbersOnly: true
      text: String(Math.round(num.value))
      implicitWidth: Style.space(72)
      Layout.preferredWidth: Style.space(72)
      onAccepted: {
        var v = parseInt(numInput.text, 10);
        if (!isNaN(v) && v >= 0) num.commit(v);
        else numInput.text = String(Math.round(num.value));
      }
      onCancelled: { numInput.text = String(Math.round(num.value)); }
    }
  }

  component ToggleRow: RowLayout {
    id: tog
    property string label: ""
    property bool checked: false
    signal toggled(bool v)
    spacing: Style.space(10)
    Layout.fillWidth: true
    SettingLabel { text: tog.label }
    Item { Layout.fillWidth: true }
    Rectangle {
      width: Style.space(44)
      height: Style.space(24)
      radius: height / 2
      color: "transparent"
      border.color: tog.checked ? Color.accent : Color.popups.border
      border.width: Math.max(1, Style.space(1))
      Rectangle {
        width: Style.space(16)
        height: Style.space(16)
        radius: width / 2
        color: tog.checked ? Color.accent : Color.muted
        anchors.verticalCenter: parent.verticalCenter
        x: tog.checked ? parent.width - width - Style.space(4) : Style.space(4)
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: tog.toggled(!tog.checked)
      }
    }
  }

}

