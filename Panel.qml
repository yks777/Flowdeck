import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "components"
import "Model.js" as Model
import "FocusEngine.js" as Focus
import "StatsEngine.js" as Stats

// Flowdeck popup — the whole app: Focus, Kanban and Stats tabs plus Settings
// behind the gear action (with a back button, same popup, no new window).
//
// Read-only locally: every action dispatches through sendOp() to hostWidget
// (the BarWidget, the single writer). Mouse-only UI: the key catcher
// handles just Esc (close, shell convention) and Tab (switch bar panel,
// shell convention).
Panel {
  id: root
  moduleName: "io.github.flowdeck"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  property string tab: "focus" // focus | kanban | stats | settings
  property string lastTab: "focus"
  property string selectedTaskId: ""
  property string searchText: ""
  property bool quickAddOpen: false
  property double tickNow: 0

  property string confirmKind: "" // "" | "task" | "space" | "reset"
  property string confirmId: ""
  property string confirmMessage: ""

  readonly property string gearIcon: "\uf013"

  readonly property var state: root.hostWidget ? root.hostWidget.state : null
  readonly property bool isRunning: root.state ? root.state.timer.status === "running" : false
  readonly property bool isPaused: root.state ? root.state.timer.status === "paused" : false
  readonly property bool isBreak: root.state ? root.state.timer.status === "break" : false
  readonly property bool isFlow: root.state ? root.state.timer.technique === "flowtime" : false
  readonly property bool inFlowFocus: root.state ? root.state.timer.technique === "flowtime" && root.state.timer.phase === "focus" : false
  readonly property string activeSpaceName: {
    if (!root.state) return "";
    for (var i = 0; i < root.state.spaces.length; i++) {
      if (root.state.spaces[i].id === root.state.activeSpaceId) return root.state.spaces[i].name;
    }
    return root.state.spaces.length > 0 ? root.state.spaces[0].name : "";
  }
  readonly property string activeBoardName: root.activeSpaceName
  readonly property string dataPath: root.hostWidget ? root.hostWidget.statePath : ""

  function sendOp(op) {
    var hw = root.hostWidget;
    if (!hw || !op || typeof op.op !== "string") return;
    var m = op;
    if (m.op === "toggle") hw.startPauseToggle();
    else if (m.op === "startWork") hw.startWork();
    else if (m.op === "startFlow") hw.startFlow();
    else if (m.op === "pause") hw.pauseTimer();
    else if (m.op === "resume") hw.resumeTimer();
    else if (m.op === "stop") hw.stopTimer();
    else if (m.op === "reset") hw.resetTimer();
    else if (m.op === "finishFlow") hw.finishFlow();
    else if (m.op === "finishFlowAndBreak") hw.finishFlowAndBreak();
    else if (m.op === "interrupt") hw.addInterruption();
    else if (m.op === "break") hw.startSuggestedBreak();
    else if (m.op === "setTechnique") hw.setTechnique(String(m.value || ""));
    else if (m.op === "setActiveTask") hw.setActiveTask(String(m.id || ""));
    else if (m.op === "startFocusOn") hw.startFocusOn(String(m.id || ""));
    else if (m.op === "addTask") hw.addTask(String(m.title || ""), String(m.columnId || "inbox"));
    else if (m.op === "updateTask") hw.updateTask(String(m.id || ""), m.changes || {});
    else if (m.op === "deleteTask") hw.deleteTask(String(m.id || ""));
    else if (m.op === "moveTask") hw.moveTask(String(m.id || ""), String(m.columnId || "inbox"));
    else if (m.op === "toggleDone") hw.toggleTaskDone(String(m.id || ""));
    else if (m.op === "createSpace") hw.createSpace(String(m.name || ""));
    else if (m.op === "renameSpace") hw.renameSpace(String(m.id || ""), String(m.name || ""));
    else if (m.op === "deleteSpace") hw.deleteSpace(String(m.id || ""));
    else if (m.op === "setSpace") hw.setSpace(String(m.id || ""));
    else if (m.op === "exportData") hw.exportData();
    else if (m.op === "importData") hw.importData();
    else if (m.op === "resetAll") hw.resetAll();
    else if (m.op === "set") hw.applySetting(String(m.key || ""), m.value);
  }

  function setTab(t) {
    if (["focus", "kanban", "stats"].indexOf(t) !== -1) {
      root.lastTab = t;
      root.tab = t;
    }
  }

  function openSettings() {
    if (root.tab !== "settings") root.lastTab = (root.tab === "settings") ? "focus" : root.tab;
    root.tab = "settings";
  }

  function openTab(t) {
    root.setTab(t === "board" ? "kanban" : t);
    root.open();
  }

  function openForQuickAdd() {
    root.setTab("kanban");
    root.quickAddOpen = true;
    root.open();
    Qt.callLater(function() { quickAddField.forceActiveFocus(); });
  }

  function requestConfirm(kind, id, message) {
    root.confirmKind = kind;
    root.confirmId = id;
    root.confirmMessage = message;
  }

  function clearConfirm() {
    root.confirmKind = "";
    root.confirmId = "";
    root.confirmMessage = "";
  }

  function requestDeleteTask(id, title) {
    if (!root.state || !root.state.settings.confirmDeleteTask) {
      root.sendOp({ op: "deleteTask", id: id });
      if (root.selectedTaskId === id) root.selectedTaskId = "";
      return;
    }
    root.requestConfirm("task", id, 'Delete task "' + title + '"? This cannot be undone.');
  }

  function requestDeleteSpace(id) {
    var name = "";
    if (root.state) {
      for (var i = 0; i < root.state.spaces.length; i++) {
        if (root.state.spaces[i].id === id) name = root.state.spaces[i].name;
      }
    }
    if (!root.state || !root.state.settings.confirmDeleteTask) {
      root.sendOp({ op: "deleteSpace", id: id });
      return;
    }
    root.requestConfirm("space", id, 'Delete board "' + name + '" and all its tasks? This cannot be undone.');
  }

  function confirmDelete() {
    var hw = root.hostWidget;
    if (root.confirmKind === "task" && hw) {
      hw.deleteTask(root.confirmId);
      if (root.selectedTaskId === root.confirmId) root.selectedTaskId = "";
    } else if (root.confirmKind === "space" && hw) {
      hw.deleteSpace(root.confirmId);
    } else if (root.confirmKind === "reset" && hw) {
      hw.resetAll();
      root.selectedTaskId = "";
      root.searchText = "";
    }
    root.clearConfirm();
  }

  function open() {
    root.controller.show();
  }

  function close() {
    root.controller.hide();
  }

  function toggle() {
    if (root.opened) root.close();
    else root.open();
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction);
    return false;
  }

  readonly property real navH: root.tab === "settings" ? backRow.height : tabsRow.height
  readonly property int prefWidth: root.tab === "kanban" ? Style.space(920)
    : root.tab === "stats" ? Style.space(640) : Style.space(440)
  readonly property int prefHeight: root.tab === "kanban" ? Style.space(600)
    : root.tab === "stats" ? Style.space(560) : Style.space(500)

  Timer {
    id: pulse
    interval: 1000
    repeat: true
    running: root.opened
    onTriggered: root.tickNow = Date.now()
  }

  onOpenedChanged: {
    if (root.opened) root.tickNow = Date.now();
    else root.clearConfirm();
  }

  KeyboardPanel {
    id: panel
    anchors.fill: parent
    bar: root.bar
    owner: root.barIdentity
    anchorItem: root.anchorItem
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(root.prefWidth)
    contentHeight: panel.fittedContentHeight(root.tab === "settings" ? settingsScroll.implicitHeight : content.implicitHeight)
    borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
    padding: Style.spacing.popupPadding
    radius: Style.cornerRadius
    open: root.opened
    popoutSwitching: root.popoutSwitching
    popoutSwitchClosing: root.popoutSwitchClosing

    onOpenChanged: {
      if (open) {
        focusPrimed = false
        beginFocusPrime()
        Qt.callLater(function() {
          if (panel.open && keyCatcher) keyCatcher.forceActiveFocus()
        })
      } else {
        focusPrimeTimer.stop()
        focusPrimed = false
      }
      if (!bar) return
      if (open) {
        popoutSwitchClosing = false
        popoutSwitching = bar.activePopout && bar.activePopout !== coordinatorKey
        bar.requestPopout(coordinatorKey)
        if (popoutSwitching) popoutSwitchTimer.restart()
      } else {
        popoutSwitchClosing = !!(owner && owner.popoutSwitchClosing)
        popoutSwitching = false
        if (bar.activePopout === coordinatorKey) bar.releasePopout(coordinatorKey)
        if (popoutSwitchClosing) closeSwitchTimer.restart()
      }
    }

    Timer {
      id: focusPrimeTimer
      interval: 75
      onTriggered: if (panel.open) panel.focusPrimed = true
    }

    Timer {
      id: popoutSwitchTimer
      interval: 150
      onTriggered: panel.popoutSwitching = false
    }

    Timer {
      id: closeSwitchTimer
      interval: 1
      onTriggered: panel.popoutSwitchClosing = false
    }

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: quickAddField.activeFocus || boardSearch.activeFocus || kanbanBar.editing || settingsScroll.interactive
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction); }
      onMoveRequested: function(dx, dy) {
        if (dx !== 0) {
          var tabs = ["focus", "kanban", "stats"];
          var ti = tabs.indexOf(root.tab);
          var ni = Math.max(0, Math.min(tabs.length - 1, ti + dx));
          root.setTab(tabs[ni]);
        }
      }
      onActivateRequested: function() {
        if (root.tab === "kanban" && root.selectedTaskId) {
          root.sendOp({ op: "startFocusOn", id: root.selectedTaskId });
          root.close();
        }
      }
      onTextKey: function(t) {
        if (t === "n" && root.tab === "kanban" && !root.quickAddOpen) {
          root.quickAddOpen = true;
          Qt.callLater(function() { quickAddField.forceActiveFocus(); });
        } else if (t === "/" && root.tab === "kanban") {
          boardSearch.forceActiveFocus();
        } else if (t === "Escape") {
          if (root.quickAddOpen) {
            root.quickAddOpen = false;
            quickAddField.text = "";
          } else if (root.tab === "settings") {
            root.setTab(root.lastTab);
          } else {
            root.close();
          }
        }
      }

      Item {
        id: content
        anchors.fill: parent
        spacing: Style.spacing.md

        Row {
          id: headerRow
          width: parent.width
          height: Math.max(titleGroup.height, gearBtn.height, closeBtn.height)
          spacing: Style.spacing.md
          Row {
            id: titleGroup
            spacing: Style.spacing.sm
            anchors.verticalCenter: parent.verticalCenter
            Text {
              textFormat: Text.PlainText
              text: "FLOWDECK"
              color: Color.popups.text
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
              font.letterSpacing: 2
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              textFormat: Text.PlainText
              text: root.activeSpaceName
              color: Qt.darker(Color.popups.text, 1.3)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
              anchors.verticalCenter: parent.verticalCenter
            }
          }
          Item {
            width: Math.max(0, parent.width - titleGroup.width - gearBtn.width - closeBtn.width - parent.spacing * 2)
            height: 1
          }
          Button {
            id: gearBtn
            text: root.gearIcon
            fontSize: Style.font.title
            selected: root.tab === "settings"
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.openSettings()
          }
          Button {
            id: closeBtn
            text: "\u2715"
            fontSize: Style.font.bodySmall
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.close()
          }
        }

        PanelSeparator {
          id: sep1
          foreground: root.bar ? root.bar.barForeground : Color.foreground
        }

        Row {
          id: tabsRow
          visible: root.tab !== "settings"
          width: parent.width
          height: visible ? implicitHeight : 0
          spacing: Style.spacing.sm
          Repeater {
            model: [["focus", "Focus"], ["kanban", "Kanban"], ["stats", "Stats"]]
            delegate: Button {
              required property var modelData
              width: (tabsRow.width - tabsRow.spacing * 2) / 3
              text: modelData[1]
              fontSize: Style.font.bodySmall
              selected: root.tab === modelData[0]
              onClicked: root.setTab(modelData[0])
            }
          }
        }

        Row {
          id: backRow
          visible: root.tab === "settings"
          width: parent.width
          height: visible ? implicitHeight : 0
          spacing: Style.space(6)
          Button {
            text: "\u2190 Settings"
            fontSize: Style.font.bodySmall
            selected: true
            onClicked: root.setTab(root.lastTab)
          }
        }

        Item {
          id: body
          width: parent.width
          height: parent.height - headerRow.height - root.navH - sep1.height - content.spacing * 3

          Flickable {
            id: focusFlick
            visible: root.tab === "focus"
            anchors.fill: parent
            contentHeight: focusView.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            FocusView {
              id: focusView
              width: parent.width
              store: root
            }
          }

          Column {
            visible: root.tab === "kanban"
            anchors.fill: parent
            spacing: Style.spacing.lg
            KanbanToolbar {
              id: kanbanBar
              width: parent.width
              store: root
            }
            Column {
              id: boardTools
              width: parent.width
              spacing: Style.spacing.md
              Row {
                id: searchRow
                width: parent.width
                spacing: Style.spacing.md
                TextField {
                  id: boardSearch
                  width: parent.width - addToggle.width - parent.spacing
                  placeholderText: "Search tasks\u2026"
                  font.pixelSize: Style.font.bodySmall
                  maximumLength: 100
                  onTextChanged: root.searchText = text.slice(0, 100)
                }
                Button {
                  id: addToggle
                  text: root.quickAddOpen ? "Cancel" : "+ Add task"
                  fontSize: Style.font.bodySmall
                  height: boardSearch.height
                  anchors.verticalCenter: parent.verticalCenter
                  onClicked: {
                    root.quickAddOpen = !root.quickAddOpen;
                    if (root.quickAddOpen) Qt.callLater(function() { quickAddField.forceActiveFocus(); });
                  }
                }
              }
              Row {
                visible: root.quickAddOpen
                width: parent.width
                height: visible ? implicitHeight : 0
                spacing: Style.spacing.md
                TextField {
                  id: quickAddField
                  width: parent.width - quickAddBtn.width - parent.spacing
                  placeholderText: "Task title... (Enter adds to Inbox, Esc cancels)"
                  font.pixelSize: Style.font.bodySmall
                  maximumLength: 200
                  onAccepted: {
                    if (text.trim() !== "") root.sendOp({ op: "addTask", title: text.trim(), columnId: "inbox" });
                    text = "";
                  }
                  Keys.onEscapePressed: {
                    text = "";
                    root.quickAddOpen = false;
                  }
                }
                Button {
                  id: quickAddBtn
                  text: "Add"
                  fontSize: Style.font.bodySmall
                  selected: true
                  height: quickAddField.height
                  anchors.verticalCenter: parent.verticalCenter
                  onClicked: {
                    if (quickAddField.text.trim() !== "") root.sendOp({ op: "addTask", title: quickAddField.text.trim(), columnId: "inbox" });
                    quickAddField.text = "";
                  }
                }
              }
            }
            TaskEditor {
              id: taskEditor
              visible: root.selectedTaskId !== ""
              width: parent.width
              height: visible ? Style.space(210) : 0
              store: root
              taskId: root.selectedTaskId
            }
            KanbanView {
              width: parent.width
              height: Math.max(0, parent.height - kanbanBar.height - boardTools.height - (taskEditor.visible ? taskEditor.height + parent.spacing : 0) - parent.spacing * 2)
              store: root
              searchText: root.searchText
              selectedTaskId: root.selectedTaskId
            }
          }

          Flickable {
            visible: root.tab === "stats"
            anchors.fill: parent
            contentHeight: statsView.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            StatsView {
              id: statsView
              width: parent.width
              store: root
            }
          }

          Flickable {
            id: settingsScroll
            visible: root.tab === "settings"
            anchors.fill: parent
            contentHeight: configCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: configCol.implicitHeight > height
            Column {
              id: configCol
              width: parent.width
              spacing: Style.space(8)

              Text {
                textFormat: Text.PlainText
                text: "FOCUS"
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                font.letterSpacing: 1
              }

              SettingRow {
                width: parent.width
                label: "Technique"
                Row {
                  spacing: Style.space(4)
                  Button {
                    text: "Pomodoro"
                    fontSize: Style.font.caption
                    selected: !root.isFlow
                    enabled: !(root.isRunning || root.isBreak)
                    onClicked: root.sendOp({ op: "setTechnique", value: "pomodoro" })
                  }
                  Button {
                    text: "Flowtime"
                    fontSize: Style.font.caption
                    selected: root.isFlow
                    enabled: !(root.isRunning || root.isBreak)
                    onClicked: root.sendOp({ op: "setTechnique", value: "flowtime" })
                  }
                }
              }

              Repeater {
                model: [
                  { key: "workSec", label: "Work", min: 1, max: 180 },
                  { key: "shortBreakSec", label: "Short break", min: 1, max: 60 },
                  { key: "longBreakSec", label: "Long break", min: 1, max: 60 }
                ]
                delegate: SettingRow {
                  required property var modelData
                  width: configCol.width
                  label: modelData.label
                  Row {
                    spacing: Style.space(4)
                    Button {
                      text: "\u2212"
                      fontSize: Style.font.caption
                      onClicked: {
                        var cur = Math.round((root.state.settings[modelData.key] || 1500) / 60);
                        root.sendOp({ op: "set", key: modelData.key, value: Math.max(modelData.min, cur - 1) * 60 });
                      }
                    }
                    NumberField {
                      value: Math.round((root.state ? root.state.settings[modelData.key] : 1500) / 60)
                      from: modelData.min
                      to: modelData.max
                      stepSize: 1
                      fieldWidth: Style.space(90)
                      onModified: function(v) { root.sendOp({ op: "set", key: modelData.key, value: v * 60 }); }
                    }
                    Button {
                      text: "+"
                      fontSize: Style.font.caption
                      onClicked: {
                        var cur = Math.round((root.state.settings[modelData.key] || 1500) / 60);
                        root.sendOp({ op: "set", key: modelData.key, value: Math.min(modelData.max, cur + 1) * 60 });
                      }
                    }
                    Text {
                      textFormat: Text.PlainText
                      text: "min"
                      color: Qt.darker(Color.popups.text, 1.4)
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }
                }
              }

              SettingRow {
                width: parent.width
                label: "Long break every"
                Row {
                  spacing: Style.space(4)
                  Button {
                    text: "\u2212"
                    fontSize: Style.font.caption
                    onClicked: {
                      var cur = root.state.settings.longBreakInterval || 4;
                      root.sendOp({ op: "set", key: "longBreakInterval", value: Math.max(1, cur - 1) });
                    }
                  }
                  NumberField {
                    value: root.state ? root.state.settings.longBreakInterval : 4
                    from: 1
                    to: 12
                    stepSize: 1
                    fieldWidth: Style.space(90)
                    onModified: function(v) { root.sendOp({ op: "set", key: "longBreakInterval", value: v }); }
                  }
                  Button {
                    text: "+"
                    fontSize: Style.font.caption
                    onClicked: {
                      var cur = root.state.settings.longBreakInterval || 4;
                      root.sendOp({ op: "set", key: "longBreakInterval", value: Math.min(12, cur + 1) });
                    }
                  }
                  Text {
                    textFormat: Text.PlainText
                    text: "sessions"
                    color: Qt.darker(Color.popups.text, 1.4)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
              }

              Text {
                textFormat: Text.PlainText
                text: "FLOWTIME"
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                font.letterSpacing: 1
              }

              SettingRow {
                width: parent.width
                label: "Break mode"
                Row {
                  spacing: Style.space(4)
                  Button {
                    text: "Traditional"
                    fontSize: Style.font.caption
                    selected: !root.state || root.state.settings.flowBreakMode !== "proportional"
                    onClicked: root.sendOp({ op: "set", key: "flowBreakMode", value: "traditional" })
                  }
                  Button {
                    text: "Proportional"
                    fontSize: Style.font.caption
                    selected: root.state && root.state.settings.flowBreakMode === "proportional"
                    onClicked: root.sendOp({ op: "set", key: "flowBreakMode", value: "proportional" })
                  }
                }
              }

              SettingRow {
                width: parent.width
                label: "Percentage"
                Row {
                  spacing: Style.space(4)
                  NumberField {
                    value: Math.round((root.state ? root.state.settings.flowBreakPct : 0.2) * 100)
                    from: 0
                    to: 100
                    stepSize: 5
                    fieldWidth: Style.space(90)
                    onModified: function(v) { root.sendOp({ op: "set", key: "flowBreakPct", value: v / 100 }); }
                  }
                  Text {
                    textFormat: Text.PlainText
                    text: "%"
                    color: Qt.darker(Color.popups.text, 1.4)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
              }

              SettingRow {
                width: parent.width
                label: "Break limits"
                Row {
                  spacing: Style.space(4)
                  NumberField {
                    value: Math.round((root.state ? root.state.settings.flowBreakMinSec : 300) / 60)
                    from: 1
                    to: 60
                    stepSize: 1
                    fieldWidth: Style.space(70)
                    onModified: function(v) { root.sendOp({ op: "set", key: "flowBreakMinSec", value: v * 60 }); }
                  }
                  Text {
                    textFormat: Text.PlainText
                    text: "\u2013"
                    color: Qt.darker(Color.popups.text, 1.4)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    anchors.verticalCenter: parent.verticalCenter
                  }
                  NumberField {
                    value: Math.round((root.state ? root.state.settings.flowBreakMaxSec : 900) / 60)
                    from: 1
                    to: 60
                    stepSize: 1
                    fieldWidth: Style.space(70)
                    onModified: function(v) { root.sendOp({ op: "set", key: "flowBreakMaxSec", value: v * 60 }); }
                  }
                  Text {
                    textFormat: Text.PlainText
                    text: "min"
                    color: Qt.darker(Color.popups.text, 1.4)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
              }

              Text {
                textFormat: Text.PlainText
                text: "BOARDS"
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                font.letterSpacing: 1
              }

              SettingRow {
                width: parent.width
                label: "Confirm delete"
                Button {
                  text: root.state && root.state.settings.confirmDeleteTask ? "\u2713 On" : "Off"
                  fontSize: Style.font.caption
                  selected: root.state && root.state.settings.confirmDeleteTask
                  onClicked: root.sendOp({ op: "set", key: "confirmDeleteTask", value: !(root.state && root.state.settings.confirmDeleteTask) })
                }
              }

              Text {
                textFormat: Text.PlainText
                text: "NOTIFICATIONS"
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                font.letterSpacing: 1
              }

              SettingRow {
                width: parent.width
                label: "Notify"
                Button {
                  text: root.state && root.state.settings.notificationsEnabled ? "\u2713 On" : "Off"
                  fontSize: Style.font.caption
                  selected: root.state && root.state.settings.notificationsEnabled
                  onClicked: root.sendOp({ op: "set", key: "notificationsEnabled", value: !(root.state && root.state.settings.notificationsEnabled) })
                }
              }

              SettingRow {
                width: parent.width
                label: "Sound"
                Button {
                  text: root.state && root.state.settings.soundEnabled ? "\u2713 On" : "Off"
                  fontSize: Style.font.caption
                  selected: root.state && root.state.settings.soundEnabled
                  onClicked: root.sendOp({ op: "set", key: "soundEnabled", value: !(root.state && root.state.settings.soundEnabled) })
                }
              }

              Text {
                textFormat: Text.PlainText
                width: configCol.width
                wrapMode: Text.WordWrap
                text: "Notifies when a Pomodoro or break ends. Flowtime never interrupts."
                color: Qt.darker(Color.popups.text, 1.5)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }

              Text {
                textFormat: Text.PlainText
                text: "STATS"
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                font.letterSpacing: 1
              }

              SettingRow {
                width: parent.width
                label: "Streak needs"
                Row {
                  spacing: Style.space(4)
                  NumberField {
                    value: Math.round((root.state ? root.state.settings.streakMinSec : 1500) / 60)
                    from: 1
                    to: 480
                    stepSize: 5
                    fieldWidth: Style.space(90)
                    onModified: function(v) { root.sendOp({ op: "set", key: "streakMinSec", value: v * 60 }); }
                  }
                  Text {
                    textFormat: Text.PlainText
                    text: "min/day"
                    color: Qt.darker(Color.popups.text, 1.4)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
              }

              SettingRow {
                width: parent.width
                label: "Week starts"
                Row {
                  spacing: Style.space(4)
                  Button {
                    text: "Monday"
                    fontSize: Style.font.caption
                    selected: !root.state || root.state.settings.weekStartsOn !== "sunday"
                    onClicked: root.sendOp({ op: "set", key: "weekStartsOn", value: "monday" })
                  }
                  Button {
                    text: "Sunday"
                    fontSize: Style.font.caption
                    selected: root.state && root.state.settings.weekStartsOn === "sunday"
                    onClicked: root.sendOp({ op: "set", key: "weekStartsOn", value: "sunday" })
                  }
                }
              }

              Text {
                textFormat: Text.PlainText
                text: "DATA"
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                font.letterSpacing: 1
              }

              Text {
                textFormat: Text.PlainText
                width: configCol.width
                elide: Text.ElideMiddle
                text: root.dataPath
                color: Qt.darker(Color.popups.text, 1.4)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }

              Row {
                width: configCol.width
                spacing: Style.space(6)
                Button {
                  text: "Export"
                  fontSize: Style.font.caption
                  onClicked: root.sendOp({ op: "exportData" })
                }
                Button {
                  text: "Import"
                  fontSize: Style.font.caption
                  onClicked: root.sendOp({ op: "importData" })
                }
                Button {
                  text: "Reset"
                  fontSize: Style.font.caption
                  onClicked: root.requestConfirm("reset", "", "Reset all Flowdeck data? Tasks, boards, sessions and settings will be wiped. This cannot be undone.")
                }
              }

              Text {
                textFormat: Text.PlainText
                width: configCol.width
                wrapMode: Text.WordWrap
                text: "Export copies data to Documents. Import reads Documents/flowdeck-import.json. Changes apply to the next session; a running session keeps its original timing."
                color: Qt.darker(Color.popups.text, 1.5)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
            }
          }
        }

        ConfirmDialog {
          anchors.fill: parent
          opened: root.confirmKind !== ""
          message: root.confirmMessage
          confirmText: root.confirmKind === "reset" ? "Reset" : "Delete"
          onConfirmed: root.confirmDelete()
          onCanceled: root.clearConfirm()
        }
      }
    }
  }
}
