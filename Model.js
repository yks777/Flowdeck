// Flowdeck Model — canonical state, validation, and pure data operations.
//
// The BarWidget owns persistence (single writer); Panel calls the BarWidget
// directly. Nothing here touches QML or the filesystem, so the logic can be
// tested with plain `node`.

var SCHEMA_VERSION = 2;

var COLUMNS = ["inbox", "ready", "focus", "done"];
var COLUMN_LABELS = {
  "inbox": "Inbox",
  "ready": "Ready",
  "focus": "Focus",
  "done": "Done"
};

var PRIORITIES = ["p0", "p1", "p2", "p3"];
var PRIORITY_LABELS = {
  "p0": "P0",
  "p1": "P1",
  "p2": "P2",
  "p3": "P3"
};

var MAX_SPACES = 20;
var MAX_TASKS = 500;
var MAX_SESSIONS = 2000;
var MAX_TITLE_CHARS = 200;

function defaultSettings() {
  return {
    technique: "pomodoro",
    workSec: 1500,
    shortBreakSec: 300,
    longBreakSec: 900,
    longBreakInterval: 4,
    flowBreakMode: "traditional",
    flowBreakPct: 0.2,
    flowBreakMinSec: 300,
    flowBreakMaxSec: 900,
    notificationsEnabled: true,
    soundEnabled: true,
    confirmDeleteTask: true,
    weekStartsOn: "monday",
    streakMinSec: 1500
  };
}

function defaultTimer() {
  return {
    technique: "pomodoro",
    phase: "idle",
    status: "stopped",
    deadlineMs: 0,
    remainingSec: 0,
    phaseDurationSec: 0,
    focusStartMs: 0,
    baseElapsedSec: 0,
    activeTaskId: null,
    interruptions: 0,
    completedInCycle: 0
  };
}

function defaultState() {
  return {
    schemaVersion: SCHEMA_VERSION,
    settings: defaultSettings(),
    spaces: [{ id: "sp-default", name: "Life", createdAt: new Date().toISOString() }],
    activeSpaceId: "sp-default",
    tasks: [],
    sessions: [],
    timer: defaultTimer()
  };
}

function genId(prefix) {
  return prefix + "-" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2, 8);
}

function isPlainObject(v) {
  return v !== null && typeof v === "object" && !Array.isArray(v);
}

function clampInt(v, fallback, min, max) {
  var n = Math.floor(Number(v));
  if (!isFinite(n)) return fallback;
  return Math.max(min, Math.min(max, n));
}

function sanitizeSettings(raw) {
  var d = defaultSettings();
  var s = isPlainObject(raw) ? raw : {};
  var out = {
    technique: s.technique === "flowtime" ? "flowtime" : "pomodoro",
    workSec: clampInt(s.workSec, d.workSec, 60, 14400),
    shortBreakSec: clampInt(s.shortBreakSec, d.shortBreakSec, 30, 3600),
    longBreakSec: clampInt(s.longBreakSec, d.longBreakSec, 60, 7200),
    longBreakInterval: clampInt(s.longBreakInterval, d.longBreakInterval, 1, 12),
    flowBreakMode: s.flowBreakMode === "proportional" ? "proportional" : "traditional",
    flowBreakMinSec: clampInt(s.flowBreakMinSec, d.flowBreakMinSec, 60, 3600),
    flowBreakMaxSec: clampInt(s.flowBreakMaxSec, d.flowBreakMaxSec, 60, 7200),
    streakMinSec: clampInt(s.streakMinSec, d.streakMinSec, 60, 28800)
  };
  var pct = Number(s.flowBreakPct);
  out.flowBreakPct = isFinite(pct) ? Math.max(0, Math.min(1, pct)) : d.flowBreakPct;
  if (out.flowBreakMaxSec < out.flowBreakMinSec) out.flowBreakMaxSec = out.flowBreakMinSec;
  out.notificationsEnabled = s.notificationsEnabled === undefined ? true : !!s.notificationsEnabled;
  out.soundEnabled = s.soundEnabled === undefined ? true : !!s.soundEnabled;
  out.confirmDeleteTask = s.confirmDeleteTask === undefined ? true : !!s.confirmDeleteTask;
  out.weekStartsOn = s.weekStartsOn === "sunday" ? "sunday" : "monday";
  return out;
}

function sanitizeSpaces(raw) {
  var list = Array.isArray(raw) ? raw : [];
  var seen = {};
  var out = [];
  for (var i = 0; i < list.length && out.length < MAX_SPACES; i++) {
    var s = list[i];
    if (!isPlainObject(s)) continue;
    var id = String(s.id || "").slice(0, 64);
    var name = String(s.name || "").trim().slice(0, 30);
    if (!id || !name || seen[id]) continue;
    seen[id] = true;
    out.push({ id: id, name: name, createdAt: typeof s.createdAt === "string" ? s.createdAt : new Date().toISOString() });
  }
  if (out.length === 0) {
    var fb = defaultState();
    return fb.spaces;
  }
  return out;
}

function sanitizeTasks(raw, spaceIds) {
  var list = Array.isArray(raw) ? raw : [];
  var out = [];
  for (var i = 0; i < list.length && out.length < MAX_TASKS; i++) {
    var t = list[i];
    if (!isPlainObject(t)) continue;
    var title = String(t.title || "").trim().slice(0, MAX_TITLE_CHARS);
    if (!title) continue;
    var id = String(t.id || "").slice(0, 64) || genId("t");
    var boardId = spaceIds[String(t.boardId)] ? String(t.boardId) : Object.keys(spaceIds)[0];
    var columnId = COLUMNS.indexOf(t.columnId) !== -1 ? t.columnId : "inbox";
    out.push({
      id: id,
      title: title,
      description: String(t.description || "").slice(0, 2000),
      columnId: columnId,
      boardId: boardId,
      priority: PRIORITIES.indexOf(t.priority) !== -1 ? t.priority : "p2",
      createdAt: Number(t.createdAt) || Date.now(),
      updatedAt: Number(t.updatedAt) || Date.now(),
      completedAt: Number(t.completedAt) || 0,
      estimatedPomodoros: clampInt(t.estimatedPomodoros, 1, 0, 100),
      completedPomodoros: clampInt(t.completedPomodoros, 0, 0, 10000),
      totalFocusSeconds: clampInt(t.totalFocusSeconds, 0, 0, 100000000),
      flowSessions: clampInt(t.flowSessions, 0, 0, 100000),
      pomodoroSessions: clampInt(t.pomodoroSessions, 0, 0, 100000),
      interruptions: clampInt(t.interruptions, 0, 0, 100000)
    });
  }
  return out;
}

function sanitizeSessions(raw) {
  var list = Array.isArray(raw) ? raw : [];
  var out = [];
  for (var i = list.length - 1; i >= 0 && out.length < MAX_SESSIONS; i--) {
    var s = list[i];
    if (!isPlainObject(s)) continue;
    if (s.type !== "pomodoro" && s.type !== "flowtime") continue;
    var focusSeconds = clampInt(s.focusSeconds, 0, 0, 1000000);
    if (focusSeconds <= 0 && !s.completed) continue;
    out.unshift({
      id: String(s.id || "").slice(0, 64) || genId("s"),
      type: s.type,
      taskId: String(s.taskId || "").slice(0, 64),
      spaceId: String(s.spaceId || "").slice(0, 64),
      startedAt: Number(s.startedAt) || 0,
      endedAt: Number(s.endedAt) || 0,
      focusSeconds: focusSeconds,
      breakSeconds: clampInt(s.breakSeconds, 0, 0, 1000000),
      interruptions: clampInt(s.interruptions, 0, 0, 100000),
      completed: !!s.completed
    });
  }
  return out;
}

function sanitizeTimer(raw, taskIds) {
  var d = defaultTimer();
  var t = isPlainObject(raw) ? raw : {};
  var technique = t.technique === "flowtime" ? "flowtime" : "pomodoro";
  var validPhases = technique === "flowtime"
    ? ["idle", "focus", "flowBreak"]
    : ["idle", "work", "shortBreak", "longBreak"];
  var phase = validPhases.indexOf(t.phase) !== -1 ? t.phase : "idle";
  var validStatus = ["stopped", "running", "paused", "break"];
  var status = validStatus.indexOf(t.status) !== -1 ? t.status : "stopped";
  var activeTaskId = String(t.activeTaskId || "");
  if (activeTaskId && !taskIds[activeTaskId]) activeTaskId = "";
  return {
    technique: technique,
    phase: phase,
    status: status,
    deadlineMs: clampInt(t.deadlineMs, 0, 0, 4102444800000),
    remainingSec: clampInt(t.remainingSec, 0, 0, 86400),
    phaseDurationSec: clampInt(t.phaseDurationSec, 0, 0, 86400),
    focusStartMs: clampInt(t.focusStartMs, 0, 0, 4102444800000),
    baseElapsedSec: clampInt(t.baseElapsedSec, 0, 0, 86400),
    activeTaskId: activeTaskId || null,
    interruptions: clampInt(t.interruptions, 0, 0, 100000),
    completedInCycle: clampInt(t.completedInCycle, 0, 0, 100000)
  };
}

function mergeDefaults(parsed, fallback) {
  var spaces = sanitizeSpaces(parsed.spaces);
  var spaceIds = {};
  for (var i = 0; i < spaces.length; i++) spaceIds[spaces[i].id] = true;
  var activeSpaceId = spaceIds[String(parsed.activeSpaceId)] ? String(parsed.activeSpaceId) : spaces[0].id;
  var tasks = sanitizeTasks(parsed.tasks, spaceIds);
  var taskIds = {};
  for (var j = 0; j < tasks.length; j++) taskIds[tasks[j].id] = true;
  return {
    schemaVersion: SCHEMA_VERSION,
    settings: sanitizeSettings(parsed.settings),
    spaces: spaces,
    activeSpaceId: activeSpaceId,
    tasks: tasks,
    sessions: sanitizeSessions(parsed.sessions),
    timer: sanitizeTimer(parsed.timer, taskIds)
  };
}

function parse(raw) {
  var fallback = defaultState();
  if (!raw) return fallback;
  try {
    var parsed = JSON.parse(String(raw));
    if (!parsed || typeof parsed !== "object") return fallback;
    return mergeDefaults(parsed, fallback);
  } catch (e) {
    return fallback;
  }
}

function parseOrNull(raw) {
  if (!raw) return null;
  try {
    var parsed = JSON.parse(String(raw));
    if (!parsed || typeof parsed !== "object") return null;
    if (!isPlainObject(parsed.timer) || !isPlainObject(parsed.settings)) return null;
    if (!Array.isArray(parsed.tasks) || !Array.isArray(parsed.sessions)) return null;
    if (!Array.isArray(parsed.spaces)) return null;
    return mergeDefaults(parsed, defaultState());
  } catch (e) {
    return null;
  }
}

function serialize(state) {
  return JSON.stringify(state, null, 2) + "\n";
}

// ---- Spaces ----

function getSpace(state, id) {
  for (var i = 0; i < state.spaces.length; i++) {
    if (state.spaces[i].id === id) return state.spaces[i];
  }
  return null;
}

function getActiveSpace(state) {
  return getSpace(state, state.activeSpaceId) || state.spaces[0];
}

function createSpace(state, name) {
  var cleaned = String(name || "").trim().slice(0, 30);
  if (!cleaned) cleaned = "Untitled";
  if (state.spaces.length >= MAX_SPACES) return state;
  var space = { id: genId("sp"), name: cleaned, createdAt: new Date().toISOString() };
  state.spaces.push(space);
  state.activeSpaceId = space.id;
  return state;
}

function renameSpace(state, id, name) {
  var cleaned = String(name || "").trim().slice(0, 30);
  if (!cleaned) return state;
  var s = getSpace(state, id);
  if (s) s.name = cleaned;
  return state;
}

function deleteSpace(state, id) {
  if (state.spaces.length <= 1) return state;
  state.spaces = state.spaces.filter(function (s) { return s.id !== id; });
  state.tasks = state.tasks.filter(function (t) { return t.boardId !== id; });
  if (state.activeSpaceId === id) state.activeSpaceId = state.spaces[0].id;
  return state;
}

// ---- Tasks ----

function tasksForSpace(state, spaceId) {
  var sid = spaceId || state.activeSpaceId;
  return state.tasks.filter(function (t) { return t.boardId === sid; });
}

function tasksByColumn(state, columnId, spaceId) {
  var sid = spaceId || state.activeSpaceId;
  return state.tasks.filter(function (t) { return t.columnId === columnId && t.boardId === sid; });
}

function getTask(state, id) {
  for (var i = 0; i < state.tasks.length; i++) {
    if (state.tasks[i].id === id) return state.tasks[i];
  }
  return null;
}

function addTask(state, title, columnId, spaceId) {
  var cleaned = String(title || "").trim().slice(0, MAX_TITLE_CHARS);
  if (!cleaned) return state;
  if (state.tasks.length >= MAX_TASKS) return state;
  var col = COLUMNS.indexOf(columnId) !== -1 ? columnId : "inbox";
  var sid = getSpace(state, spaceId) ? spaceId : state.activeSpaceId;
  var now = Date.now();
  state.tasks.push({
    id: genId("t"),
    title: cleaned,
    description: "",
    columnId: col,
    boardId: sid,
    priority: "p2",
    createdAt: now,
    updatedAt: now,
    completedAt: 0,
    estimatedPomodoros: 1,
    completedPomodoros: 0,
    totalFocusSeconds: 0,
    flowSessions: 0,
    pomodoroSessions: 0,
    interruptions: 0
  });
  return state;
}

function updateTask(state, id, changes) {
  var t = getTask(state, id);
  if (!t || !isPlainObject(changes)) return state;
  if (changes.title !== undefined) {
    var title = String(changes.title).trim().slice(0, MAX_TITLE_CHARS);
    if (title) t.title = title;
  }
  if (changes.description !== undefined) t.description = String(changes.description).slice(0, 2000);
  if (changes.priority !== undefined && PRIORITIES.indexOf(changes.priority) !== -1) t.priority = changes.priority;
  if (changes.estimatedPomodoros !== undefined) t.estimatedPomodoros = clampInt(changes.estimatedPomodoros, t.estimatedPomodoros, 0, 100);
  t.updatedAt = Date.now();
  return state;
}

function deleteTask(state, id) {
  state.tasks = state.tasks.filter(function (t) { return t.id !== id; });
  if (state.timer.activeTaskId === id) state.timer.activeTaskId = null;
  return state;
}

function moveTask(state, id, columnId) {
  if (COLUMNS.indexOf(columnId) === -1) return state;
  var t = getTask(state, id);
  if (!t) return state;
  t.columnId = columnId;
  t.updatedAt = Date.now();
  if (columnId === "done") {
    if (!t.completedAt) t.completedAt = Date.now();
  } else {
    t.completedAt = 0;
  }
  return state;
}

function toggleTaskDone(state, id) {
  var t = getTask(state, id);
  if (!t) return state;
  return moveTask(state, id, t.columnId === "done" ? "inbox" : "done");
}

function setActiveTask(state, id) {
  if (id && !getTask(state, id)) return state;
  state.timer.activeTaskId = (id === state.timer.activeTaskId) ? null : (id || null);
  return state;
}

function nextTask(state, spaceId) {
  var open = tasksForSpace(state, spaceId).filter(function (t) { return t.columnId !== "done"; });
  if (open.length === 0) return null;
  var focus = open.filter(function (t) { return t.columnId === "focus"; });
  if (focus.length > 0) return focus[0];
  var ready = open.filter(function (t) { return t.columnId === "ready"; });
  if (ready.length > 0) return ready[0];
  return open[0];
}

function searchTasks(state, query, spaceId) {
  var q = String(query || "").trim().toLowerCase();
  if (!q) return [];
  var pool = spaceId ? tasksForSpace(state, spaceId) : state.tasks;
  return pool.filter(function (t) {
    return t.title.toLowerCase().indexOf(q) !== -1
      || t.description.toLowerCase().indexOf(q) !== -1;
  }).slice(0, 50);
}

// ---- Sessions ----

function appendSession(state, session) {
  if (!isPlainObject(session)) return state;
  var sanitized = sanitizeSessions([session]);
  if (!sanitized.length) return state;
  state.sessions.push(sanitized[0]);
  if (state.sessions.length > MAX_SESSIONS) {
    state.sessions = state.sessions.slice(state.sessions.length - MAX_SESSIONS);
  }
  return state;
}

function recordTaskFocus(state, taskId, focusSeconds, type, interruptions) {
  var t = taskId ? getTask(state, taskId) : null;
  if (!t) return state;
  t.totalFocusSeconds += Math.max(0, Math.floor(focusSeconds));
  t.interruptions += Math.max(0, Math.floor(interruptions || 0));
  if (type === "flowtime") t.flowSessions++;
  else t.pomodoroSessions++;
  t.updatedAt = Date.now();
  return state;
}

// ---- Settings bridge ----

var INT_KEYS = ["workSec", "shortBreakSec", "longBreakSec", "longBreakInterval",
  "flowBreakMinSec", "flowBreakMaxSec", "streakMinSec"];
var REAL_KEYS = ["flowBreakPct"];
var BOOL_KEYS = ["notificationsEnabled", "soundEnabled", "confirmDeleteTask"];
var STRING_KEYS = ["technique", "flowBreakMode", "weekStartsOn"];

function applySetting(state, key, value) {
  var s = state.settings;
  if (INT_KEYS.indexOf(key) !== -1) {
    var n = Math.floor(Number(value));
    if (!isFinite(n)) return false;
    s[key] = n;
  } else if (REAL_KEYS.indexOf(key) !== -1) {
    var r = Number(value);
    if (!isFinite(r)) return false;
    s[key] = r;
  } else if (BOOL_KEYS.indexOf(key) !== -1) {
    s[key] = (value === true || value === "true" || value === 1 || value === "1");
  } else if (STRING_KEYS.indexOf(key) !== -1) {
    s[key] = String(value || "").slice(0, 32);
  } else {
    return false;
  }
  state.settings = sanitizeSettings(s);
  return true;
}

if (typeof module !== "undefined") {
  module.exports = {
    SCHEMA_VERSION: SCHEMA_VERSION,
    COLUMNS: COLUMNS,
    COLUMN_LABELS: COLUMN_LABELS,
    PRIORITIES: PRIORITIES,
    PRIORITY_LABELS: PRIORITY_LABELS,
    defaultState: defaultState,
    defaultSettings: defaultSettings,
    defaultTimer: defaultTimer,
    parse: parse,
    parseOrNull: parseOrNull,
    serialize: serialize,
    genId: genId,
    getSpace: getSpace,
    getActiveSpace: getActiveSpace,
    createSpace: createSpace,
    renameSpace: renameSpace,
    deleteSpace: deleteSpace,
    tasksForSpace: tasksForSpace,
    tasksByColumn: tasksByColumn,
    getTask: getTask,
    addTask: addTask,
    updateTask: updateTask,
    deleteTask: deleteTask,
    moveTask: moveTask,
    toggleTaskDone: toggleTaskDone,
    setActiveTask: setActiveTask,
    nextTask: nextTask,
    searchTasks: searchTasks,
    appendSession: appendSession,
    recordTaskFocus: recordTaskFocus,
    applySetting: applySetting
  };
}
