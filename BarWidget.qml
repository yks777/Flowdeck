import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "FocusEngine.js" as Focus
import "Storage.js" as Storage

// Flowdeck bar widget — the SINGLE WRITER of the state file.
//
// All mutations (timer, tasks, spaces, sessions, settings) run here and are
// persisted with saveState(). Panel.qml (the popup, loaded inside this
// widget) calls these functions directly. This keeps one canonical writer
// and avoids races.
BarWidget {
  id: root
  moduleName: "io.github.flowdeck"

  // ---- Paths ----
  readonly property string statePath: Storage.statePath()
  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace("file://", "").replace(/\/+$/, "")
  readonly property string homeDir: Quickshell.env("HOME") || ""

  // Nerd Font glyph: clock icon. Centralized so a missing/tofu glyph is a
  // one-line swap.
  readonly property string clockIcon: "\uf017"

  // ---- State ----
  property var state: Model.defaultState()
  property bool loaded: false
  property double workStartMs: 0
  property int bootRetries: 0
  property int tickCount: 0

  // ---- Derived timer values ----
  readonly property var timer: state.timer
  readonly property var fdSettings: state.settings
  readonly property bool isRunning: timer.status === Focus.STATUS_RUNNING
  readonly property bool isPaused: timer.status === Focus.STATUS_PAUSED
  readonly property bool isBreak: timer.status === Focus.STATUS_BREAK
  readonly property bool isActive: isRunning || isBreak
  readonly property bool inFlowFocus: timer.technique === Focus.TECHNIQUE_FLOWTIME && timer.phase === Focus.PHASE_FOCUS
  readonly property int displaySec: Focus.displaySeconds(state)
  readonly property real timerProgress: Focus.progress(state)
  readonly property string phaseName: Focus.phaseLabel(timer)
  readonly property string displayText: inFlowFocus ? Focus.formatCompact(displaySec) : Focus.formatClock(displaySec)
  readonly property var activeTask: {
    var id = timer.activeTaskId;
    if (!id) return null;
    for (var i = 0; i < state.tasks.length; i++) {
      if (state.tasks[i].id === id) return state.tasks[i];
    }
    return null;
  }
  readonly property string buttonText: {
    if (timer.status === Focus.STATUS_STOPPED && timer.phase === Focus.PHASE_IDLE) return root.clockIcon;
    return root.clockIcon + " " + displayText;
  }

  // ---- Persistence (only writer) ----
  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    // atomicWrites stays OFF: an atomic rename swaps the inode and detaches
    // the inotify watcher (frozen display + lost updates).
    atomicWrites: false
    printErrors: false
    onLoaded: {
      var content = text();
      if (!content || !String(content).trim()) {
        if (root.bootRetries < 8) {
          root.bootRetries++;
          bootRetry.restart();
          return;
        }
      }
      root.bootRetries = 0;
      root.state = Focus.settleLoadedTimer(Model.parse(content));
      root.loaded = true;
      root.syncSettingsFromShellJson();
      root.saveState();
      root.refreshState();
    }
    onTextChanged: {
      if (root.loaded) {
        var ext = Model.parseOrNull(text());
        if (ext) root.state = ext;
      }
    }
    onFileChanged: reload()

    onLoadFailed: {
      root.state = Model.defaultState();
      root.loaded = true;
      root.syncSettingsFromShellJson();
      root.saveState();
      root.refreshState();
    }
  }

  function saveState() {
    if (!root.loaded) return;
    stateFile.setText(Model.serialize(root.state));
  }

  function refreshState() {
    root.state = JSON.parse(JSON.stringify(root.state));
  }

  function commit() {
    root.saveState();
    root.refreshState();
  }

  function syncSettingsFromShellJson() {
    var keys = ["workSec", "shortBreakSec", "longBreakSec", "longBreakInterval",
      "technique", "flowBreakMode", "flowBreakPct", "flowBreakMinSec",
      "flowBreakMaxSec", "notificationsEnabled", "streakMinSec"];
    var changed = false;
    for (var i = 0; i < keys.length; i++) {
      var key = keys[i];
      var val = root.setting(key, undefined);
      if (val === undefined || val === null) continue;
      if (key === "flowBreakMode" || key === "technique") val = String(val);
      else if (key === "flowBreakPct") val = Number(val);
      else if (key === "notificationsEnabled" || key === "soundEnabled") val = !!val;
      else val = Math.floor(Number(val));
      var before = JSON.stringify(root.state.settings);
      if (Model.applySetting(root.state, key, val)) {
        if (JSON.stringify(root.state.settings) !== before) changed = true;
      }
    }
    if (changed) root.commit();
  }

  // Boot-retry: re-read the state file shortly after an empty boot read.
  Timer {
    id: bootRetry
    interval: 500
    repeat: false
    onTriggered: stateFile.reload()
  }

  // ---- 1s tick (visual refresh + countdown) ----
  Timer {
    id: tickTimer
    interval: 1000
    repeat: true
    running: root.loaded && (root.isRunning || root.isBreak)
    onTriggered: root.onTick()
  }

  function onTick() {
    var result = Focus.tick(root.state);
    root.state = result.state;
    if (result.phaseEnded) {
      root.onPhaseEnded(result.finishedPhase);
      root.commit();
      return;
    }
    root.tickCount++;
    root.refreshState();
    if (root.tickCount % 5 === 0) root.saveState();
  }

  function onPhaseEnded(finishedPhase) {
    if (finishedPhase === Focus.PHASE_WORK) {
      var done = Focus.completeWorkPhase(root.state, root.workStartMs || 0);
      done.session.id = Model.genId("s");
      root.state = Model.appendSession(root.state, done.session);
      root.state = Model.recordTaskFocus(root.state, done.session.taskId, done.session.focusSeconds, "pomodoro", 0);
      var t = Model.getTask(root.state, done.session.taskId);
      if (t) t.completedPomodoros++;
      root.notify(done.breakLong ? "Long break — well earned" : "Work complete", done.breakLong ? "Take a long break." : "Time for a short break.");
      root.playFinish();
    } else if (Focus.isBreakPhase(finishedPhase)) {
      root.state = Focus.stopTimer(root.state);
      root.notify("Break over", "Ready for the next session?");
      root.playFinish();
    }
  }

  // ---- Timer controls ----
  function startPauseToggle() {
    if (root.isRunning || root.isBreak) root.pauseTimer();
    else if (root.isPaused) root.resumeTimer();
    else if (root.state.settings.technique === Focus.TECHNIQUE_FLOWTIME) root.startFlow();
    else root.startWork();
  }

  function startWork() {
    root.workStartMs = Date.now();
    root.state = Focus.startWork(root.state);
    root.commit();
  }

  function startFlow() {
    root.state = Focus.startFlow(root.state);
    root.commit();
  }

  function startSuggestedBreak() {
    var secs = Focus.suggestedBreakSeconds(Focus.flowElapsedSec(root.state), root.state.settings);
    root.state = Focus.startFlowBreak(root.state, secs);
    root.commit();
  }

  function pauseTimer() {
    root.state = Focus.pauseTimer(root.state);
    root.commit();
  }

  function resumeTimer() {
    root.state = Focus.resumeTimer(root.state);
    if (root.timer.phase === Focus.PHASE_WORK && !root.workStartMs) root.workStartMs = Date.now();
    root.commit();
  }

  function stopTimer() {
    root.state = Focus.stopTimer(root.state);
    root.workStartMs = 0;
    root.commit();
  }

  function resetTimer() {
    root.state = Focus.resetTimer(root.state);
    root.commit();
  }

  function finishFlow() {
    if (!(root.timer.technique === Focus.TECHNIQUE_FLOWTIME && root.timer.phase === Focus.PHASE_FOCUS)) return 0;
    var done = Focus.finishFlow(root.state);
    done.session.id = Model.genId("s");
    var secs = done.session.focusSeconds;
    root.state = Model.appendSession(root.state, done.session);
    root.state = Model.recordTaskFocus(root.state, done.session.taskId, secs, "flowtime", done.session.interruptions);
    root.state = Focus.stopTimer(root.state);
    root.commit();
    return secs;
  }

  function finishFlowAndBreak() {
    var before = root.state;
    var elapsed = Focus.flowElapsedSec(before);
    var interruptions = before.timer.interruptions;
    var taskId = before.timer.activeTaskId;
    var secs = root.finishFlow();
    if (secs > 0) {
      var brk = Focus.suggestedBreakSeconds(elapsed, root.state.settings);
      root.state = Focus.startFlowBreak(root.state, brk);
      root.commit();
    }
    return { focusSeconds: elapsed, interruptions: interruptions, taskId: taskId };
  }

  function addInterruption() {
    root.state = Focus.addInterruption(root.state);
    root.commit();
  }

  function setTechnique(mode) {
    if (mode !== Focus.TECHNIQUE_FLOWTIME && mode !== Focus.TECHNIQUE_POMODORO) return;
    if (root.isRunning || root.isBreak) return;
    root.state.settings.technique = mode;
    root.state = Focus.stopTimer(root.state);
    root.state.timer.technique = mode;
    root.commit();
  }

  // ---- Task / space ops ----
  function addTask(title, columnId) {
    root.state = Model.addTask(root.state, title, columnId, root.state.activeSpaceId);
    root.commit();
  }

  function updateTask(id, changes) {
    root.state = Model.updateTask(root.state, id, changes);
    root.commit();
  }

  function deleteTask(id) {
    root.state = Model.deleteTask(root.state, id);
    root.commit();
  }

  function moveTask(id, columnId) {
    root.state = Model.moveTask(root.state, id, columnId);
    root.commit();
  }

  function toggleTaskDone(id) {
    root.state = Model.toggleTaskDone(root.state, id);
    root.commit();
  }

  function setActiveTask(id) {
    root.state = Model.setActiveTask(root.state, id);
    root.commit();
  }

  function startFocusOn(id) {
    if (id) {
      var t = Model.getTask(root.state, id);
      if (t && root.state.timer.activeTaskId !== id) root.state = Model.setActiveTask(root.state, id);
    }
    if (root.state.settings.technique === Focus.TECHNIQUE_FLOWTIME) root.startFlow();
    else root.startWork();
  }

  function createSpace(name) {
    root.state = Model.createSpace(root.state, name);
    root.commit();
  }

  function renameSpace(id, name) {
    root.state = Model.renameSpace(root.state, id, name);
    root.commit();
  }

  function deleteSpace(id) {
    root.state = Model.deleteSpace(root.state, id);
    root.commit();
  }

  function setSpace(id) {
    if (Model.getSpace(root.state, id)) {
      root.state.activeSpaceId = id;
      root.commit();
    }
  }

  function applySetting(key, value) {
    var ok = Model.applySetting(root.state, key, value);
    if (ok) {
      if (!root.isRunning && !root.isBreak
        && root.state.settings.technique === Focus.TECHNIQUE_POMODORO
        && (key === "workSec" || key === "shortBreakSec" || key === "longBreakSec")) {
        root.state = Focus.resetTimer(root.state);
      }
      root.commit();
    }
    return ok;
  }

  // ---- Notifications + sound (both honor settings) ----
  function notify(title, body) {
    if (!root.state.settings.notificationsEnabled) return;
    var omarchyPath = Quickshell.env("OMARCHY_PATH") || "";
    if (omarchyPath) {
      Quickshell.execDetached([omarchyPath + "/bin/omarchy-notification-send", "--app-name", "Flowdeck", String(title), String(body || "")]);
    } else {
      Quickshell.execDetached(["/usr/bin/notify-send", "--app-name", "Flowdeck", String(title), String(body || "")]);
    }
  }

  function playFinish() {
    if (!root.state.settings.soundEnabled) return;
    var wav = root.pluginDir + "/sounds/finish.wav";
    Quickshell.execDetached(["/usr/bin/bash", "-c",
      'F="$1"; [ -f "$F" ] && (/usr/bin/pw-play "$F" 2>/dev/null || /usr/bin/paplay "$F" 2>/dev/null || true)',
      "flowdeck-sound", wav]);
  }

  // ---- Data: export / import / reset ----
  function exportPath() {
    var d = new Date();
    function pad(n) { return (n < 10 ? "0" : "") + n; }
    return root.homeDir + "/Documents/flowdeck-backup-"
      + d.getFullYear() + pad(d.getMonth() + 1) + pad(d.getDate())
      + "-" + pad(d.getHours()) + pad(d.getMinutes()) + pad(d.getSeconds()) + ".json";
  }

  function exportData() {
    if (!root.loaded || !root.homeDir) return "";
    var dest = root.exportPath();
    root.saveState();
    Quickshell.execDetached(["/usr/bin/bash", "-c",
      'mkdir -p -- "$(/usr/bin/dirname -- "$2")" && /usr/bin/cp -- "$1" "$2"',
      "flowdeck-export", root.statePath, dest]);
    return dest;
  }

  function importData() {
    importFile.reload();
  }

  function resetAll() {
    root.state = Model.defaultState();
    root.workStartMs = 0;
    root.commit();
  }

  FileView {
    id: importFile
    path: (Quickshell.env("HOME") || "") + "/Documents/flowdeck-import.json"
    watchChanges: false
    printErrors: false
    onLoaded: {
      var ext = Model.parseOrNull(text());
      if (!ext) {
        root.notify("Import failed", "flowdeck-import.json is missing or invalid.");
        return;
      }
      root.state = Focus.settleLoadedTimer(ext);
      root.loaded = true;
      root.workStartMs = 0;
      root.commit();
      root.notify("Import complete", "Flowdeck data restored.");
    }
  }

  // ---- Panel lifecycle ----
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open();
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close();
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle();
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch();
  }

  function openTab(tab) {
    if (panelLoader.item) panelLoader.item.openTab(tab);
  }

  function openForQuickAdd() {
    if (panelLoader.item) panelLoader.item.openForQuickAdd();
  }

  function injectPanel() {
    var target = panelLoader.item;
    if (!target) return;
    if ("bar" in target) target.bar = root.bar;
    if ("settings" in target) target.settings = root.settings;
    if ("anchorItem" in target) target.anchorItem = button;
    if ("hostWidget" in target) target.hostWidget = root;
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: if (root.loaded) root.syncSettingsFromShellJson()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel();
      Qt.callLater(root.injectPanel);
    }
  }

  IpcHandler {
    target: "io.github.flowdeck"

    function toggle(): void { root.startPauseToggle(); }
    function togglePanel(): void { root.togglePanel(); }
    function show(): void { root.open(); }
    function hide(): void { root.close(); }
    function open(): void { root.open(); }
    function close(): void { root.close(); }
    function start(): void { root.startPauseToggle(); }
    function pause(): void { root.pauseTimer(); }
    function stop(): void { root.stopTimer(); }
    function quickAdd(): void { root.openForQuickAdd(); }
    function openBoard(): void { root.openTab("board"); }
    function openFocus(): void { root.openTab("focus"); }

    function mutate(payload: string): bool {
      var m = null;
      try {
        m = JSON.parse(String(payload || ""));
      } catch (e) {
        return false;
      }
      if (!m || typeof m.op !== "string") return false;
      var op = m.op;
      if (op === "toggle") root.startPauseToggle();
      else if (op === "startWork") root.startWork();
      else if (op === "startFlow") root.startFlow();
      else if (op === "pause") root.pauseTimer();
      else if (op === "resume") root.resumeTimer();
      else if (op === "stop") root.stopTimer();
      else if (op === "reset") root.resetTimer();
      else if (op === "finishFlow") root.finishFlow();
      else if (op === "finishFlowAndBreak") root.finishFlowAndBreak();
      else if (op === "interrupt") root.addInterruption();
      else if (op === "break") root.startSuggestedBreak();
      else if (op === "setTechnique") root.setTechnique(String(m.value || ""));
      else if (op === "setActiveTask") root.setActiveTask(String(m.id || ""));
      else if (op === "startFocusOn") root.startFocusOn(String(m.id || ""));
      else if (op === "addTask") root.addTask(String(m.title || ""), String(m.columnId || "inbox"));
      else if (op === "updateTask") root.updateTask(String(m.id || ""), m.changes || {});
      else if (op === "deleteTask") root.deleteTask(String(m.id || ""));
      else if (op === "moveTask") root.moveTask(String(m.id || ""), String(m.columnId || "inbox"));
      else if (op === "toggleDone") root.toggleTaskDone(String(m.id || ""));
      else if (op === "createSpace") root.createSpace(String(m.name || ""));
      else if (op === "renameSpace") root.renameSpace(String(m.id || ""), String(m.name || ""));
      else if (op === "deleteSpace") root.deleteSpace(String(m.id || ""));
      else if (op === "setSpace") root.setSpace(String(m.id || ""));
      else if (op === "exportData") root.exportData();
      else if (op === "importData") root.importData();
      else if (op === "resetAll") root.resetAll();
      else if (op === "set") { if (!root.applySetting(String(m.key || ""), m.value)) return false; }
      else return false;
      return true;
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.buttonText
    active: root.isActive
    activeColor: root.isBreak ? Color.urgent : Color.accent
    useActiveColor: true
    horizontalMargin: 8.75
    verticalPadding: 8.75
    tooltipText: root.phaseName + (root.activeTask ? " — " + root.activeTask.title : "")
      + (root.isPaused ? " (paused)" : root.isActive ? "" : " (stopped)")

    onPressed: function(b) {
      if (b === Qt.RightButton) root.startPauseToggle();
      else if (b === Qt.MiddleButton) root.stopTimer();
      else root.togglePanel();
    }
  }
}
