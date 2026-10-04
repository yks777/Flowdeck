// Model.js — canonical factories, defaults and validation for Flowdeck state.
// Pure JavaScript (no QML imports) so it can be unit-checked by inspection.
.pragma library

var SCHEMA_VERSION = 1;

var COLUMNS = ["q1", "q2", "q3", "q4"];

// Legacy kanban ids -> Eisenhower quadrants (single migration path).
// READY (was doing) -> Q1 Do, INBOX (was backlog) -> Q2 Schedule,
// FOCUS (was blocked) -> Q3 Delegate, DONE -> completed, hidden from matrix.
var LEGACY_COLUMN_MAP = {
  ready: "q1",
  inbox: "q2",
  focus: "q3",
  done: "q1"
};

var DEFAULT_COLUMN_LABELS = {
  q1: "Do",
  q2: "Schedule",
  q3: "Delegate",
  q4: "Delete"
};

function columnLabel(columnId, columnsMap) {
  if (isPlainObject(columnsMap)) {
    var v = String(columnsMap[columnId] || "").trim();
    if (v !== "") return v.slice(0, 24);
  }
  return DEFAULT_COLUMN_LABELS[columnId] || columnId;
}

function defaultSettings() {
  return {
    // Card Focus button technique
    focusAction: "pomodoro", // "pomodoro" | "flowtime"
    // Pomodoro (seconds)
    focusSec: 25 * 60,
    shortBreakSec: 5 * 60,
    longBreakSec: 15 * 60,
    longBreakInterval: 4,
    // Flowtime break
    flowBreakMode: "traditional", // "traditional" | "proportional"
    flowBreakPct: 0.2,
    flowBreakMinSec: 5 * 60,
    flowBreakMaxSec: 15 * 60,
    // Stats
    streakMinSec: 25 * 60,
    // Notifications
    notificationsEnabled: true,
    soundEnabled: true,
    // Shortcuts
    toggleShortcut: "super+h"
  };
}

function uid(prefix) {
  return (prefix || "id") + "-" + Math.floor(Date.now()).toString(36)
    + "-" + Math.floor(Math.random() * 0xffffff).toString(36);
}

function defaultBoards() {
  var now = Date.now();
  return [{ id: "board-life", title: "Stay Hard", createdAt: now, updatedAt: now }];
}

function blankState() {
  return {
    schemaVersion: SCHEMA_VERSION,
    settings: defaultSettings(),
    boards: defaultBoards(),
    tasks: [],
    sessions: [],
    activeBoardId: "board-life",
    activeTaskId: null,
    timer: blankTimer()
  };
}

function blankTimer() {
  return {
    mode: "idle", // "idle" | "pomodoro" | "flowtime"
    phase: "stopped", // "stopped" | "running" | "paused" | "break"
    taskId: null,
    startedAtMs: 0,
    deadlineMs: 0,
    pausedRemainingMs: 0,
    accumulatedMs: 0,
    interruptions: 0,
    pomodorosDone: 0,
    breakKind: "", // "" | "short" | "long" | "flow"
    breakTotalMs: 0,
    technique: "pomodoro" // last-used technique for the Focus tab default
  };
}

function isPlainObject(v) {
  return v !== null && typeof v === "object" && !Array.isArray(v);
}

function cloneWith(raw, patch) {
  var c = {};
  for (var k in raw) c[k] = raw[k];
  for (var p in patch) c[p] = patch[p];
  return c;
}

function toInt(v, fallback, min, max) {
  var n = Math.floor(Number(v));
  if (isNaN(n)) return fallback;
  if (min !== undefined) n = Math.max(min, n);
  if (max !== undefined) n = Math.min(max, n);
  return n;
}

function sanitizeSettings(raw) {
  var d = defaultSettings();
  if (!isPlainObject(raw)) return d;
  var s = {};
  s.focusAction = (raw.focusAction === "flowtime") ? "flowtime" : "pomodoro";
  s.focusSec = toInt(raw.focusSec, d.focusSec, 60, 8 * 3600);
  s.shortBreakSec = toInt(raw.shortBreakSec, d.shortBreakSec, 0, 2 * 3600);
  s.longBreakSec = toInt(raw.longBreakSec, d.longBreakSec, 0, 4 * 3600);
  s.longBreakInterval = toInt(raw.longBreakInterval, d.longBreakInterval, 1, 24);
  s.flowBreakMode = (raw.flowBreakMode === "proportional") ? "proportional" : "traditional";
  var pct = Number(raw.flowBreakPct);
  s.flowBreakPct = (isNaN(pct) || pct < 0 || pct > 1) ? d.flowBreakPct : pct;
  s.flowBreakMinSec = toInt(raw.flowBreakMinSec, d.flowBreakMinSec, 0, 2 * 3600);
  s.flowBreakMaxSec = toInt(raw.flowBreakMaxSec, d.flowBreakMaxSec, 60, 4 * 3600);
  if (s.flowBreakMaxSec < s.flowBreakMinSec) s.flowBreakMaxSec = s.flowBreakMinSec;
  s.streakMinSec = toInt(raw.streakMinSec, d.streakMinSec, 0, 16 * 3600);
  s.notificationsEnabled = raw.notificationsEnabled !== false;
  s.soundEnabled = raw.soundEnabled !== false;
  var shortcut = String(raw.toggleShortcut || "").trim().toLowerCase();
  if (!shortcut) shortcut = d.toggleShortcut;
  s.toggleShortcut = shortcut.length <= 64 ? shortcut : d.toggleShortcut;
  return s;
}

function sanitizeBoard(raw) {
  if (!isPlainObject(raw)) return null;
  var now = Date.now();
  var title = String(raw.title || "").trim().slice(0, 48) || "Untitled";
  return {
    id: String(raw.id || uid("board")),
    title: title,
    createdAt: toInt(raw.createdAt, now, 0),
    updatedAt: toInt(raw.updatedAt, now, 0)
  };
}

function sanitizeTask(raw, boardIds) {
  if (!isPlainObject(raw)) return null;
  if (typeof raw.title !== "string" || raw.title.trim() === "") return null;
  var now = Date.now();
  var col = String(raw.columnId || "q1");
  // Migrate legacy kanban columns once; unknown ids fall back to Q1.
  if (LEGACY_COLUMN_MAP[col]) {
    if (col === "done" && !raw.completedAt) {
      // Completed without a stamp: use updatedAt/now so Stats still count it.
      raw = cloneWith(raw, { completedAt: raw.updatedAt || now });
    }
    col = LEGACY_COLUMN_MAP[col];
  }
  if (COLUMNS.indexOf(col) === -1) col = "q1";
  var prio = String(raw.priority || "normal");
  if (["low", "normal", "high"].indexOf(prio) === -1) prio = "normal";
  var boardId = String(raw.boardId || "");
  if (boardIds && boardIds.indexOf(boardId) === -1) boardId = boardIds[0] || "board-life";
  return {
    id: String(raw.id || uid("task")),
    boardId: boardId,
    columnId: col,
    title: raw.title.trim().slice(0, 200),
    description: String(raw.description || "").slice(0, 2000),
    priority: prio,
    createdAt: toInt(raw.createdAt, now, 0),
    updatedAt: toInt(raw.updatedAt, now, 0),
    completedAt: raw.completedAt ? toInt(raw.completedAt, 0, 0) : null,
    totalFocusSeconds: toInt(raw.totalFocusSeconds, 0, 0),
    pomodoroSessions: toInt(raw.pomodoroSessions, 0, 0),
    flowtimeSessions: toInt(raw.flowtimeSessions, 0, 0),
    interruptions: toInt(raw.interruptions, 0, 0)
  };
}

function sanitizeSession(raw) {
  if (!isPlainObject(raw)) return null;
  var kind = String(raw.kind || "");
  if (kind !== "pomo" && kind !== "flow") return null;
  var dur = toInt(raw.durationSec, 0, 1, 16 * 3600);
  if (!dur) return null;
  return {
    id: String(raw.id || uid("sess")),
    kind: kind,
    taskId: raw.taskId ? String(raw.taskId) : null,
    boardId: raw.boardId ? String(raw.boardId) : null,
    startedAt: toInt(raw.startedAt, Date.now(), 0),
    endedAt: toInt(raw.endedAt, Date.now(), 0),
    durationSec: dur,
    interruptions: toInt(raw.interruptions, 0, 0)
  };
}

// Validate + migrate a parsed state object. Returns { state, repaired }.
// Never throws: corrupt input yields a safe blank state.
function sanitizeState(raw) {
  var repaired = false;
  try {
    if (!isPlainObject(raw)) return { state: blankState(), repaired: true };
    var sv = toInt(raw.schemaVersion, 0, 0);
    if (sv !== SCHEMA_VERSION) repaired = true; // future versions: reset safely
    var state = blankState();
    state.settings = sanitizeSettings(raw.settings);
    var boards = [];
    if (Array.isArray(raw.boards)) {
      for (var i = 0; i < raw.boards.length; i++) {
        var b = sanitizeBoard(raw.boards[i]);
        if (b) boards.push(b);
      }
    }
    if (boards.length === 0) { boards = defaultBoards(); repaired = true; }
    // Single-board simplification: collapse legacy multi-board states into
    // the first board so the matrix UI stays simple.
    var primaryBoard = boards[0];
    if (boards.length > 1) {
      boards = [primaryBoard];
      repaired = true;
    }
    state.boards = boards;
    var boardIds = boards.map(function(b) { return b.id; });
    var tasks = [];
    if (Array.isArray(raw.tasks)) {
      for (var t = 0; t < raw.tasks.length; t++) {
        var rawTask = raw.tasks[t];
        // Force legacy tasks from deleted boards into the primary board.
        if (isPlainObject(rawTask) && boardIds.indexOf(String(rawTask.boardId || "")) === -1) {
          rawTask = cloneWith(rawTask, { boardId: primaryBoard.id });
          repaired = true;
        }
        var task = sanitizeTask(rawTask, boardIds);
        if (task) {
          task.boardId = primaryBoard.id;
          tasks.push(task);
        }
      }
    }
    state.tasks = tasks;
    var sessions = [];
    if (Array.isArray(raw.sessions)) {
      var cutoff = Date.now() - 400 * 86400000; // keep ~13 months
      for (var s = 0; s < raw.sessions.length; s++) {
        var sess = sanitizeSession(raw.sessions[s]);
        if (sess && sess.startedAt >= cutoff) sessions.push(sess);
      }
    }
    // Cap history so the file stays small in a long-lived shell process.
    if (sessions.length > 2000) sessions = sessions.slice(sessions.length - 2000);
    state.sessions = sessions;
    state.activeBoardId = String(raw.activeBoardId || "");
    if (boardIds.indexOf(state.activeBoardId) === -1) {
      state.activeBoardId = boardIds[0];
      repaired = true;
    }
    state.activeTaskId = raw.activeTaskId ? String(raw.activeTaskId) : null;
    var taskIds = {};
    for (var k = 0; k < tasks.length; k++) taskIds[tasks[k].id] = true;
    if (state.activeTaskId && !taskIds[state.activeTaskId]) {
      state.activeTaskId = null;
      repaired = true;
    }
    // A timer restored across a shell restart resumes as paused when it was
    // running (deadline math stays valid); corrupt timers stop safely.
    state.timer = sanitizeTimer(raw.timer);
    return { state: state, repaired: repaired };
  } catch (e) {
    return { state: blankState(), repaired: true };
  }
}

function sanitizeTimer(raw) {
  var t = blankTimer();
  if (!isPlainObject(raw)) return t;
  if (["idle", "pomodoro", "flowtime"].indexOf(raw.mode) !== -1) t.mode = raw.mode;
  if (["stopped", "running", "paused", "break"].indexOf(raw.phase) !== -1) t.phase = raw.phase;
  t.taskId = raw.taskId ? String(raw.taskId) : null;
  t.startedAtMs = toInt(raw.startedAtMs, 0, 0);
  t.deadlineMs = toInt(raw.deadlineMs, 0, 0);
  t.pausedRemainingMs = toInt(raw.pausedRemainingMs, 0, 0);
  t.accumulatedMs = toInt(raw.accumulatedMs, 0, 0);
  t.interruptions = toInt(raw.interruptions, 0, 0);
  t.pomodorosDone = toInt(raw.pomodorosDone, 0, 0, 100000);
  if (["", "short", "long", "flow"].indexOf(raw.breakKind) !== -1) t.breakKind = raw.breakKind;
  t.breakTotalMs = toInt(raw.breakTotalMs, 0, 0);
  if (raw.technique === "flowtime" || raw.technique === "pomodoro") t.technique = raw.technique;
  // Stale running timers (deadline long past) collapse to stopped on load;
  // completion accounting happens live in the Service tick instead.
  if (t.phase === "running" && t.mode === "pomodoro" && t.deadlineMs > 0
      && Date.now() - t.deadlineMs > 24 * 3600000) {
    return blankTimer();
  }
  if (t.mode === "idle") t.phase = "stopped";
  return t;
}

function formatHMS(totalSeconds) {
  totalSeconds = Math.max(0, Math.floor(totalSeconds));
  var h = Math.floor(totalSeconds / 3600);
  var m = Math.floor((totalSeconds % 3600) / 60);
  var s = totalSeconds % 60;
  function p(n) { return (n < 10 ? "0" : "") + n; }
  return p(h) + ":" + p(m) + ":" + p(s);
}

function formatMS(totalSeconds) {
  totalSeconds = Math.max(0, Math.floor(totalSeconds));
  var m = Math.floor(totalSeconds / 60);
  var s = totalSeconds % 60;
  function p(n) { return (n < 10 ? "0" : "") + n; }
  return p(m) + ":" + p(s);
}

// Adaptive clock for the bar/panel timers: SS under one minute (05),
// MM:SS under one hour (01:20), HH:MM:SS at/over one hour (01:20:20).
function formatClock(totalSeconds) {
  totalSeconds = Math.max(0, Math.floor(totalSeconds));
  var h = Math.floor(totalSeconds / 3600);
  var m = Math.floor((totalSeconds % 3600) / 60);
  var s = totalSeconds % 60;
  function p(n) { return (n < 10 ? "0" : "") + n; }
  if (h > 0) return p(h) + ":" + p(m) + ":" + p(s);
  if (m > 0) return p(m) + ":" + p(s);
  return p(s);
}

function formatDur(totalSeconds) {
  totalSeconds = Math.max(0, Math.floor(totalSeconds));
  if (totalSeconds < 60) return totalSeconds + "s";
  var m = Math.floor(totalSeconds / 60);
  if (m < 60) return m + "m";
  var h = Math.floor(m / 60);
  var rm = m % 60;
  return rm === 0 ? h + "h" : h + "h " + rm + "m";
}

function dayKey(ts) {
  var d = new Date(ts);
  return d.getFullYear() + "-" + (d.getMonth() + 1) + "-" + d.getDate();
}
