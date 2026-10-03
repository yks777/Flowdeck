// StatsEngine.js — session aggregation. Views call these with plain arrays;
// nothing here touches QML state, so results are cheap to recompute on
// data change (never on the 1 Hz timer tick).
.pragma library

function startOfDay(ts) {
  var d = new Date(ts);
  d.setHours(0, 0, 0, 0);
  return d.getTime();
}

function sameDay(a, b) {
  return startOfDay(a) === startOfDay(b);
}

function matchKind(sess, kindFilter) {
  if (!kindFilter || kindFilter === "both") return true;
  return sess.kind === kindFilter;
}

// range: "today" | "yesterday" | "all"
function filterSessions(sessions, range, kindFilter, now) {
  now = now || Date.now();
  var out = [];
  for (var i = 0; i < sessions.length; i++) {
    var s = sessions[i];
    if (!matchKind(s, kindFilter)) continue;
    if (range === "today" && !sameDay(s.startedAt, now)) continue;
    if (range === "yesterday" && !sameDay(s.startedAt, now - 86400000)) continue;
    out.push(s);
  }
  out.sort(function(a, b) { return b.startedAt - a.startedAt; });
  return out;
}

function summarize(sessions) {
  var focusSec = 0, pomo = 0, flow = 0, interruptions = 0;
  var tasks = {};
  for (var i = 0; i < sessions.length; i++) {
    var s = sessions[i];
    focusSec += s.durationSec || 0;
    interruptions += s.interruptions || 0;
    if (s.kind === "pomo") pomo++;
    else if (s.kind === "flow") flow++;
    if (s.taskId) tasks[s.taskId] = true;
  }
  return {
    focusSec: focusSec,
    pomoCount: pomo,
    flowCount: flow,
    sessionCount: sessions.length,
    interruptions: interruptions,
    taskCount: Object.keys(tasks).length
  };
}

function tasksDoneOnDay(tasks, dayTs) {
  var n = 0;
  for (var i = 0; i < tasks.length; i++) {
    if (tasks[i].completedAt && sameDay(tasks[i].completedAt, dayTs)) n++;
  }
  return n;
}

// Consecutive-day streak ending today (or yesterday if today has no focus
// yet). A day counts when focusSec >= minSec.
function streak(sessions, minSec, now) {
  now = now || Date.now();
  var byDay = {};
  for (var i = 0; i < sessions.length; i++) {
    var s = sessions[i];
    var k = startOfDay(s.startedAt);
    byDay[k] = (byDay[k] || 0) + (s.durationSec || 0);
  }
  var cursor = startOfDay(now);
  if (!(byDay[cursor] >= minSec)) cursor -= 86400000;
  var n = 0;
  while (byDay[cursor] >= minSec) { n++; cursor -= 86400000; }
  return n;
}

// Last 7 days (oldest first): [{ label, focusSec }]. Label is weekday short.
function lastWeek(sessions, now) {
  now = now || Date.now();
  var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  var out = [];
  for (var d = 6; d >= 0; d--) {
    var dayStart = startOfDay(now - d * 86400000);
    var sec = 0;
    for (var i = 0; i < sessions.length; i++) {
      if (startOfDay(sessions[i].startedAt) === dayStart) sec += sessions[i].durationSec || 0;
    }
    out.push({ label: days[new Date(dayStart).getDay()], focusSec: sec });
  }
  return out;
}
