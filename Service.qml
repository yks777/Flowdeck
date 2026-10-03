import QtQuick
import Quickshell
import Quickshell.Io
import "logic/Model.js" as Model
import "logic/TimerEngine.js" as TimerEngine
import "logic/StatsEngine.js" as StatsEngine
import "logic/Storage.js" as Storage

// Flowdeck Service — the single owner of all mutable state.
// BarWidget and Panel never keep competing copies: they read these
// properties and call these methods. Time always derives from wall-clock
// timestamps (never from the visual tick), so timers survive panel close,
// shell reload and suspend/resume.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property string omarchyPath: ""

  readonly property string pluginId: "io.github.flowdeck"

  // ---- canonical state (always replaced, never mutated in place) ----
  property var settings: Model.defaultSettings()
  property var boards: Model.defaultBoards()
  property var tasks: []
  property var sessions: []
  property string activeBoardId: "board-life"
  property string activeTaskId: ""
  property var timer: Model.blankTimer()
  property string pendingView: ""

  // Bumped on every data mutation so views recompute; bumped every second
  // while a timer runs so time labels refresh (~1 Hz, cheap bindings only).
  property int revision: 0
  property int tickVersion: 0

  property bool stateLoaded: false
  property string stateFilePath: ""
  property string stateDirPath: ""

  // ============================ time helpers ============================

  function nowMs() { return Date.now(); }

  function timerRemainingMs() {
    return TimerEngine.pomodoroRemainingMs(root.timer, root.nowMs());
  }

  function flowElapsedMs() {
    return TimerEngine.flowElapsedMs(root.timer, root.nowMs());
  }

  function isTicking() {
    return root.timer.phase === "running" || root.timer.phase === "break";
  }

  // ============================ timer actions ===========================

  function startPomodoro(taskId) {
    var now = root.nowMs();
    var t = Model.blankTimer();
    t.mode = "pomodoro";
    t.phase = "running";
    t.technique = "pomodoro";
    t.taskId = taskId !== undefined && taskId !== null ? String(taskId) : root.activeTaskId;
    t.startedAtMs = now;
    t.deadlineMs = now + root.settings.focusSec * 1000;
    root.timer = t;
    root.bump();
    root.saveSoon();
  }

  function startFlowtime(taskId) {
    var now = root.nowMs();
    var t = Model.blankTimer();
    t.mode = "flowtime";
    t.phase = "running";
    t.technique = "flowtime";
    t.taskId = taskId !== undefined && taskId !== null ? String(taskId) : root.activeTaskId;
    t.startedAtMs = now;
    t.accumulatedMs = 0;
    t.interruptions = 0;
    root.timer = t;
    root.bump();
    root.saveSoon();
  }

  function pauseTimer() {
    var t = root.timer;
    if (t.phase !== "running") return;
    var c = cloneTimer(t);
    if (c.mode === "pomodoro") {
      c.pausedRemainingMs = Math.max(0, c.deadlineMs - root.nowMs());
    } else if (c.mode === "flowtime") {
      c.accumulatedMs = TimerEngine.flowElapsedMs(c, root.nowMs());
    }
    c.phase = "paused";
    root.timer = c;
    root.bump();
    root.saveSoon();
  }

  function resumeTimer() {
    var t = root.timer;
    if (t.phase !== "paused") return;
    var c = cloneTimer(t);
    if (c.mode === "pomodoro") {
      c.deadlineMs = root.nowMs() + Math.max(0, c.pausedRemainingMs);
      c.pausedRemainingMs = 0;
    } else if (c.mode === "flowtime") {
      c.startedAtMs = root.nowMs();
    }
    c.phase = "running";
    root.timer = c;
    root.bump();
    root.saveSoon();
  }

  function stopTimer() {
    // Stop discards the in-progress stretch (no session is recorded).
    var blank = Model.blankTimer();
    // Keep the idle default aligned with the persisted Settings choice.
    blank.technique = (root.settings.focusAction === "flowtime") ? "flowtime" : "pomodoro";
    root.timer = blank;
    root.bump();
    root.saveSoon();
  }

  function skipBreak() {
    if (root.timer.phase !== "break") return;
    var c = cloneTimer(root.timer);
    c.phase = "stopped";
    c.breakKind = "";
    c.breakTotalMs = 0;
    root.timer = c;
    root.bump();
    root.saveSoon();
  }

  function addInterruption() {
    var t = root.timer;
    if (t.mode !== "flowtime" || (t.phase !== "running" && t.phase !== "paused")) return;
    var c = cloneTimer(t);
    c.interruptions = (c.interruptions || 0) + 1;
    root.timer = c;
    root.bump();
    root.saveSoon();
  }

  // finishKind: "focus" (record, stop) or "break" (record, start break).
  function finishFlowtime(finishKind) {
    var t = root.timer;
    if (t.mode !== "flowtime" || (t.phase !== "running" && t.phase !== "paused")) return;
    var elapsedSec = Math.floor(TimerEngine.flowElapsedMs(t, root.nowMs()) / 1000);
    var taskId = t.taskId;
    var interruptions = t.interruptions || 0;
    var c = Model.blankTimer();
    c.technique = "flowtime";
    if (elapsedSec >= 10) {
      root.recordSession("flow", taskId, elapsedSec, interruptions, t.startedAtMs);
    }
    if (finishKind === "break" && elapsedSec >= 10) {
      var suggested = TimerEngine.suggestedBreakSec(elapsedSec, root.settings);
      c.mode = "flowtime";
      c.phase = "break";
      c.taskId = taskId;
      c.breakKind = "flow";
      c.breakTotalMs = suggested * 1000;
      c.startedAtMs = root.nowMs();
      c.deadlineMs = root.nowMs() + suggested * 1000;
    }
    root.timer = c;
    root.bump();
    root.saveNow();
  }

  function onTick() {
    root.tickVersion++;
    var t = root.timer;
    if (t.phase !== "running" && t.phase !== "break") return;
    if (t.mode === "flowtime" && t.phase === "running") return; // counts up, nothing expires
    if ((t.deadlineMs || 0) > root.nowMs()) return;
    if (t.mode === "pomodoro" && t.phase === "running") root.completePomodoro();
    else if (t.phase === "break") root.completeBreak();
  }

  function completePomodoro() {
    var t = root.timer;
    var focusSec = root.settings.focusSec;
    var taskId = t.taskId;
    root.recordSession("pomo", taskId, focusSec, 0, t.startedAtMs);
    var done = (t.pomodorosDone || 0) + 1;
    var longEvery = Math.max(1, root.settings.longBreakInterval);
    var isLong = (done % longEvery) === 0;
    var breakSec = isLong ? root.settings.longBreakSec : root.settings.shortBreakSec;
    var c = Model.blankTimer();
    c.technique = "pomodoro";
    c.pomodorosDone = done;
    c.taskId = taskId;
    if (breakSec > 0) {
      c.mode = "pomodoro";
      c.phase = "break";
      c.breakKind = isLong ? "long" : "short";
      c.breakTotalMs = breakSec * 1000;
      c.startedAtMs = root.nowMs();
      c.deadlineMs = root.nowMs() + breakSec * 1000;
      root.notify("Pomodoro complete", isLong ? "Long break started — step away." : "Short break started — breathe.");
    } else {
      root.notify("Pomodoro complete", "Well done. Ready for the next one.");
    }
    root.timer = c;
    root.bump();
    root.saveNow();
  }

  function completeBreak() {
    var c = cloneTimer(root.timer);
    c.phase = "stopped";
    c.breakKind = "";
    c.breakTotalMs = 0;
    root.timer = c;
    root.notify("Break complete", "Time to get back into focus.");
    root.bump();
    root.saveNow();
  }

  function cloneTimer(t) {
    return {
      mode: t.mode, phase: t.phase, taskId: t.taskId,
      startedAtMs: t.startedAtMs, deadlineMs: t.deadlineMs,
      pausedRemainingMs: t.pausedRemainingMs, accumulatedMs: t.accumulatedMs,
      interruptions: t.interruptions, pomodorosDone: t.pomodorosDone,
      breakKind: t.breakKind, breakTotalMs: t.breakTotalMs, technique: t.technique
    };
  }

  function recordSession(kind, taskId, durationSec, interruptions, startedAt) {
    if (!(durationSec > 0)) return;
    var now = root.nowMs();
    var sess = {
      id: Model.uid("sess"), kind: kind,
      taskId: taskId ? String(taskId) : null,
      boardId: root.activeBoardId,
      startedAt: startedAt || (now - durationSec * 1000),
      endedAt: now, durationSec: Math.floor(durationSec),
      interruptions: interruptions || 0
    };
    var next = root.sessions.concat([sess]);
    if (next.length > 2000) next = next.slice(next.length - 2000);
    root.sessions = next;
    if (taskId) {
      var found = false;
      var tasks = root.tasks.map(function(task) {
        if (task.id !== taskId) return task;
        found = true;
        var c = {};
        for (var k in task) c[k] = task[k];
        c.totalFocusSeconds = (c.totalFocusSeconds || 0) + Math.floor(durationSec);
        if (kind === "pomo") c.pomodoroSessions = (c.pomodoroSessions || 0) + 1;
        else c.flowtimeSessions = (c.flowtimeSessions || 0) + 1;
        c.interruptions = (c.interruptions || 0) + (interruptions || 0);
        c.updatedAt = now;
        return c;
      });
      if (found) root.tasks = tasks;
    }
  }

  // ============================ boards ==================================

  function activeBoard() {
    for (var i = 0; i < root.boards.length; i++) {
      if (root.boards[i].id === root.activeBoardId) return root.boards[i];
    }
    return root.boards.length > 0 ? root.boards[0] : null;
  }

  function setActiveBoard(boardId) {
    root.activeBoardId = String(boardId);
    root.bump();
    root.saveSoon();
  }

  function createBoard(title) {
    var name = String(title || "").trim().slice(0, 48) || "Untitled";
    var now = root.nowMs();
    var b = { id: Model.uid("board"), title: name, createdAt: now, updatedAt: now };
    root.boards = root.boards.concat([b]);
    root.activeBoardId = b.id;
    root.bump();
    root.saveNow();
    return b.id;
  }

  function renameBoard(boardId, title) {
    var name = String(title || "").trim().slice(0, 48);
    if (name === "") return false;
    var now = root.nowMs();
    root.boards = root.boards.map(function(b) {
      if (b.id !== boardId) return b;
      var c = {};
      for (var k in b) c[k] = b[k];
      c.title = name;
      c.updatedAt = now;
      return c;
    });
    root.bump();
    root.saveNow();
    return true;
  }

  function deleteBoard(boardId) {
    if (root.boards.length <= 1) return false;
    var remaining = root.boards.filter(function(b) { return b.id !== boardId; });
    if (remaining.length === root.boards.length) return false;
    var target = remaining[0].id;
    var now = root.nowMs();
    root.tasks = root.tasks.map(function(t) {
      if (t.boardId !== boardId) return t;
      var c = {};
      for (var k in t) c[k] = t[k];
      c.boardId = target;
      c.updatedAt = now;
      return c;
    });
    root.boards = remaining;
    if (root.activeBoardId === boardId) root.activeBoardId = target;
    root.bump();
    root.saveNow();
    return true;
  }

  // ============================ tasks ===================================

  function boardTasks() {
    var out = [];
    for (var i = 0; i < root.tasks.length; i++) {
      if (root.tasks[i].boardId === root.activeBoardId) out.push(root.tasks[i]);
    }
    out.sort(function(a, b) { return a.createdAt - b.createdAt; });
    return out;
  }

  function tasksForColumn(columnId) {
    var out = [];
    for (var i = 0; i < root.tasks.length; i++) {
      var t = root.tasks[i];
      if (t.boardId !== root.activeBoardId || t.columnId !== columnId) continue;
      if (t.completedAt) continue; // completed live in the popup, not the matrix
      out.push(t);
    }
    out.sort(function(a, b) { return a.createdAt - b.createdAt; });
    return out;
  }

  function completedTasks(query) {
    var q = String(query || "").trim().toLowerCase();
    var out = [];
    for (var j = 0; j < root.tasks.length; j++) {
      var c = root.tasks[j];
      if (c.boardId !== root.activeBoardId || !c.completedAt) continue;
      if (q !== "" && c.title.toLowerCase().indexOf(q) === -1
          && String(c.description || "").toLowerCase().indexOf(q) === -1) continue;
      out.push(c);
    }
    out.sort(function(a, b) { return (b.completedAt || 0) - (a.completedAt || 0); });
    return out;
  }

  function completedCount() {
    var n = 0;
    for (var i = 0; i < root.tasks.length; i++) {
      if (root.tasks[i].boardId === root.activeBoardId && root.tasks[i].completedAt) n++;
    }
    return n;
  }

  function columnCount(columnId) {
    var n = 0;
    for (var i = 0; i < root.tasks.length; i++) {
      if (root.tasks[i].boardId === root.activeBoardId && root.tasks[i].columnId === columnId && !root.tasks[i].completedAt) n++;
    }
    return n;
  }

  function activeTask() {
    if (!root.activeTaskId) return null;
    for (var i = 0; i < root.tasks.length; i++) {
      if (root.tasks[i].id === root.activeTaskId) return root.tasks[i];
    }
    return null;
  }

  function setActiveTask(taskId) {
    root.activeTaskId = taskId ? String(taskId) : "";
    root.bump();
    root.saveSoon();
  }

  function createTask(title, columnId, description, priority) {
    var name = String(title || "").trim().slice(0, 200);
    if (name === "") return "";
    var col = columnId || "q1";
    if (Model.COLUMNS.indexOf(col) === -1) col = "q1";
    var now = root.nowMs();
    var t = {
      id: Model.uid("task"), boardId: root.activeBoardId, columnId: col,
      title: name, description: String(description || "").slice(0, 2000),
      priority: ["low", "normal", "high"].indexOf(priority) !== -1 ? priority : "normal",
      createdAt: now, updatedAt: now, completedAt: null,
      totalFocusSeconds: 0, pomodoroSessions: 0, flowtimeSessions: 0, interruptions: 0
    };
    root.tasks = root.tasks.concat([t]);
    root.bump();
    root.saveNow();
    return t.id;
  }

  function updateTask(taskId, fields) {
    var now = root.nowMs();
    var ok = false;
    root.tasks = root.tasks.map(function(t) {
      if (t.id !== taskId) return t;
      ok = true;
      var c = {};
      for (var k in t) c[k] = t[k];
      if (fields.title !== undefined) {
        var name = String(fields.title).trim().slice(0, 200);
        if (name !== "") c.title = name;
      }
      if (fields.description !== undefined) c.description = String(fields.description).slice(0, 2000);
      if (fields.priority !== undefined && ["low", "normal", "high"].indexOf(fields.priority) !== -1) {
        c.priority = fields.priority;
      }
      c.updatedAt = now;
      return c;
    });
    if (ok) { root.bump(); root.saveNow(); }
    return ok;
  }

  function moveTask(taskId, columnId) {
    if (Model.COLUMNS.indexOf(columnId) === -1) return false;
    var now = root.nowMs();
    var ok = false;
    root.tasks = root.tasks.map(function(t) {
      if (t.id !== taskId) return t;
      ok = true;
      var c = {};
      for (var k in t) c[k] = t[k];
      c.columnId = columnId;
      c.completedAt = null;
      c.updatedAt = now;
      return c;
    });
    if (ok) { root.bump(); root.saveNow(); }
    return ok;
  }

  function completeTask(taskId) {
    var now = root.nowMs();
    var ok = false;
    root.tasks = root.tasks.map(function(t) {
      if (t.id !== taskId) return t;
      ok = true;
      var c = {};
      for (var k in t) c[k] = t[k];
      c.completedAt = now;
      c.updatedAt = now;
      return c;
    });
    if (ok) { root.bump(); root.saveNow(); }
    return ok;
  }

  function reopenTask(taskId) {
    var now = root.nowMs();
    var ok = false;
    root.tasks = root.tasks.map(function(t) {
      if (t.id !== taskId) return t;
      ok = true;
      var c = {};
      for (var k in t) c[k] = t[k];
      if (Model.COLUMNS.indexOf(c.columnId) === -1) c.columnId = "q1";
      c.completedAt = null;
      c.updatedAt = now;
      return c;
    });
    if (ok) { root.bump(); root.saveNow(); }
    return ok;
  }

  function deleteTask(taskId) {
    var before = root.tasks.length;
    root.tasks = root.tasks.filter(function(t) { return t.id !== taskId; });
    if (root.tasks.length === before) return false;
    if (root.activeTaskId === taskId) root.activeTaskId = "";
    if (root.timer.taskId === taskId) {
      var c = cloneTimer(root.timer);
      c.taskId = null;
      root.timer = c;
    }
    root.bump();
    root.saveNow();
    return true;
  }

  // ============================ settings ================================

  function updateSettings(patch) {
    var next = {};
    for (var k in root.settings) next[k] = root.settings[k];
    for (var p in patch) next[p] = patch[p];
    root.settings = Model.sanitizeSettings(next);
    // Keep an idle timer aligned with the persisted choice so the Focus tab
    // and the Super+H shortcut start the chosen technique after a reload.
    if (patch && (patch.focusAction === "pomodoro" || patch.focusAction === "flowtime")) {
      var t = root.timer;
      if (t && t.phase === "stopped") {
        var c = cloneTimer(t);
        c.technique = root.settings.focusAction;
        root.timer = c;
      }
    }
    root.bump();
    root.saveSoon();
  }

  // ============================ stats ===================================

  function liveExtraSec() {
    // Live stretch counts toward today while running (stopped clock = exact).
    var t = root.timer;
    if (t.phase === "running" && t.mode === "pomodoro") {
      return Math.floor((root.nowMs() - t.startedAtMs) / 1000);
    }
    if (t.phase === "running" && t.mode === "flowtime") {
      return Math.floor(TimerEngine.flowElapsedMs(t, root.nowMs()) / 1000);
    }
    return 0;
  }

  function todaySummary() {
    var list = StatsEngine.filterSessions(root.sessions, "today", "both", root.nowMs());
    var s = StatsEngine.summarize(list);
    s.focusSec += root.liveExtraSec();
    s.tasksDone = StatsEngine.tasksDoneOnDay(root.tasks, root.nowMs());
    s.streak = StatsEngine.streak(root.sessions, root.settings.streakMinSec, root.nowMs());
    return s;
  }

  function weekData() {
    return StatsEngine.lastWeek(root.sessions, root.nowMs());
  }

  function history(range, kind) {
    return StatsEngine.filterSessions(root.sessions, range || "today", kind || "both", root.nowMs());
  }

  function bump() { root.revision++; }

  // ============================ panel IPC ===============================

  function targetId() {
    if (root.manifest && root.manifest.id) return String(root.manifest.id);
    return root.pluginId;
  }

  function togglePanel() {
    if (root.shell && typeof root.shell.toggle === "function") {
      root.shell.toggle(root.targetId(), "{}");
    }
  }

  function openView(view) {
    var v = String(view || "focus");
    if (v === "kanban") v = "matrix"; // legacy alias
    root.pendingView = v;
    if (root.shell && typeof root.shell.summon === "function") {
      root.shell.summon(root.targetId(), JSON.stringify({ view: root.pendingView }));
    }
  }

  function consumePendingView() {
    var v = root.pendingView;
    root.pendingView = "";
    return v;
  }

  // ============================ notifications ===========================

  function notify(title, body) {
    if (!root.settings.notificationsEnabled) return;
    notifyProc.title = String(title);
    notifyProc.body = String(body);
    notifyProc.running = true;
    if (root.settings.soundEnabled) soundProc.running = true;
  }

  Process {
    id: notifyProc
    property string title: ""
    property string body: ""
    command: ["omarchy-notification-send", "-g", "◷", title, body, "-t", "8000"]
  }

  // Best-effort completion blip; silently no-ops without a sound theme.
  Process {
    id: soundProc
    command: ["bash", "-c", "command -v canberra-gtk-play >/dev/null && canberra-gtk-play -i complete || true"]
  }

  // ============================ persistence =============================

  Timer {
    id: tick
    interval: 1000
    repeat: true
    running: root.isTicking()
    onTriggered: root.onTick()
  }

  Process {
    id: mkdirProc
  }

  FileView {
    id: stateFile
    watchChanges: false
    atomicWrites: true
    onLoaded: root.applyLoadedText(text())
    onLoadFailed: function(error) {
      root.applyBlank();
      console.warn("Flowdeck: state load failed, starting fresh: " + error);
    }
  }

  Timer {
    id: saveDebounce
    interval: 800
    onTriggered: root.saveNow()
  }

  function scheduleSave() { saveDebounce.restart(); }
  function saveSoon() {
    if (!root.stateLoaded) return;
    saveDebounce.restart();
  }

  function serializeState() {
    return JSON.stringify({
      schemaVersion: 1,
      settings: root.settings,
      boards: root.boards,
      tasks: root.tasks,
      sessions: root.sessions,
      activeBoardId: root.activeBoardId,
      activeTaskId: root.activeTaskId === "" ? null : root.activeTaskId,
      timer: root.timer
    }, null, 2) + "\n";
  }

  function saveNow() {
    if (!root.stateLoaded || root.stateFilePath === "") return;
    // A running pomodoro resumes (not restarts) after a shell reload because
    // the deadline timestamp is what gets persisted here.
    try {
      stateFile.setText(root.serializeState());
    } catch (e) {
      console.warn("Flowdeck: save failed: " + e);
    }
  }

  function applyBlank() {
    var clean = Model.blankState();
    root.applyState(clean);
    root.stateLoaded = true;
    root.saveNow();
  }

  function applyLoadedText(text) {
    var raw = null;
    try {
      raw = JSON.parse(text);
    } catch (e) {
      console.warn("Flowdeck: corrupt state, backing up and starting fresh");
      backupProc.running = true;
      root.applyBlank();
      return;
    }
    var res = Model.sanitizeState(raw);
    root.applyState(res.state);
    root.stateLoaded = true;
    if (res.repaired) root.saveNow();
  }

  function applyState(s) {
    root.settings = s.settings;
    root.boards = s.boards;
    root.tasks = s.tasks;
    root.sessions = s.sessions;
    root.activeBoardId = s.activeBoardId;
    root.activeTaskId = s.activeTaskId || "";
    root.timer = s.timer;
    // A timer that was running across a restart keeps its deadline and
    // resumes ticking; the tick reconciles completion on the next second.
    root.bump();
  }

  Process {
    id: backupProc
    command: ["bash", "-c", "cp -f \"$0\" \"$1\" 2>/dev/null || true", root.stateFilePath, ""]
  }

  function exportData() {
    exportProc.running = true;
  }

  // Import: desktop picker -> validate JSON -> replace state (never throws).
  function importData() {
    importProc.running = true;
  }

  Process {
    id: importProc
    stdout: StdioCollector {
      id: importOut
      onStreamFinished: root.applyImportPath(text)
    }
    command: ["omarchy", "file", "select", "--title", "Import Flowdeck backup"]
  }

  FileView {
    id: importFile
    watchChanges: false
    onLoaded: root.applyImportText(text())
    onLoadFailed: function(error) {
      console.warn("Flowdeck: import read failed: " + error);
    }
  }

  function applyImportPath(raw) {
    var p = String(raw || "").split("\n").map(function(line) { return line.trim(); })
      .filter(function(line) { return line !== ""; });
    if (p.length === 0) return;
    importFile.path = p[0];
  }

  function applyImportText(text) {
    var raw = null;
    try {
      raw = JSON.parse(text);
    } catch (e) {
      console.warn("Flowdeck: import is not valid JSON, ignored");
      return;
    }
    if (!raw || typeof raw !== "object" || !Array.isArray(raw.tasks) || !Array.isArray(raw.sessions)) {
      console.warn("Flowdeck: import is not a Flowdeck backup, ignored");
      return;
    }
    var res = Model.sanitizeState(raw);
    // Keep a backup of the pre-import state next to the data file.
    preImportBackup.running = true;
    root.applyState(res.state);
    root.saveNow();
    root.notify("Import complete", "Backup restored.");
  }

  Process {
    id: preImportBackup
    command: ["bash", "-c", "cp -f \"$0\" \"$0.pre-import-$(date +%s)\" 2>/dev/null || true", root.stateFilePath]
  }

  Process {
    id: exportProc
    command: ["bash", "-c", "cp -f \"$0\" \"$1\" 2>/dev/null || true", root.stateFilePath, ""]
  }

  function resetAll() {
    var clean = Model.blankState();
    // Keep the user's settings and boards on reset; wipe tasks/sessions/timer.
    clean.settings = root.settings;
    clean.boards = root.boards;
    clean.activeBoardId = root.activeBoardId;
    root.applyState(clean);
    root.saveNow();
  }

  Component.onCompleted: {
    var dir = Storage.dataDir(Quickshell.env);
    var path = Storage.statePath(Quickshell.env);
    root.stateDirPath = dir;
    root.stateFilePath = path;
    mkdirProc.command = ["mkdir", "-p", dir];
    mkdirProc.running = true;
    var stamp = String(Date.now());
    backupProc.command = ["bash", "-c", "cp -f \"$0\" \"$0.corrupt-" + stamp + "\" 2>/dev/null || true", path];
    exportProc.command = ["bash", "-c", "mkdir -p \"$(dirname \"$0\")\" && cp -f \"$1\" \"$0\" 2>/dev/null || true", Storage.exportPath(Quickshell.env), path];
    stateFile.path = path;
  }

  // ============================ plugin IPC ==============================
  // Super+H calls `omarchy-shell io.github.flowdeck togglePanel`; the shell
  // summon/hide/toggle verbs work through the panel entry automatically.

  IpcHandler {
    target: "io.github.flowdeck"
    function togglePanel(): string { root.togglePanel(); return "ok"; }
    function focus(): string { root.openView("focus"); return "ok"; }
    function matrix(): string { root.openView("matrix"); return "ok"; }
    function kanban(): string { root.openView("matrix"); return "ok"; }
    function stats(): string { root.openView("stats"); return "ok"; }
    function start(): string {
      if (root.timer.phase === "paused") root.resumeTimer();
      else if (root.timer.phase === "stopped") {
        if (root.settings.focusAction === "flowtime") root.startFlowtime();
        else root.startPomodoro();
      }
      return "ok";
    }
    function pause(): string { root.pauseTimer(); return "ok"; }
    function stop(): string { root.stopTimer(); return "ok"; }
    function finish(kind: string): string {
      root.finishFlowtime(kind === "break" ? "break" : "focus");
      return "ok";
    }
    function interrupt(): string { root.addInterruption(); return "ok"; }
    function skipBreak(): string { root.skipBreak(); return "ok"; }
    function status(): string {
      return JSON.stringify({
        mode: root.timer.mode, phase: root.timer.phase,
        remainingMs: root.timerRemainingMs(), elapsedMs: root.flowElapsedMs()
      });
    }
    function today(): string { return JSON.stringify(root.todaySummary()); }
    function isOpen(): string {
      if (root.shell && typeof root.shell.isPluginOpen === "function")
        return root.shell.isPluginOpen(root.targetId()) ? "true" : "false";
      return "unknown";
    }
    function ping(): string { return "ok"; }
  }
}
