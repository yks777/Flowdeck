// Flowdeck StatsEngine — pure productivity statistics.
//
// No UI, no I/O. Computed on demand (when the Stats view opens or a session
// closes), never on every timer tick.

function dayKey(ms) {
  var d = new Date(ms);
  var m = d.getMonth() + 1;
  var day = d.getDate();
  return d.getFullYear() + "-" + (m < 10 ? "0" : "") + m + "-" + (day < 10 ? "0" : "") + day;
}

function startOfDay(ms) {
  var d = new Date(ms);
  d.setHours(0, 0, 0, 0);
  return d.getTime();
}

function sessionsOnDay(sessions, dayMs) {
  var start = startOfDay(dayMs);
  var end = start + 86400000;
  return sessions.filter(function (s) {
    var t = s.endedAt || s.startedAt;
    return t >= start && t < end;
  });
}

function summarize(sessions) {
  var out = {
    totalFocusSec: 0,
    pomodoroCount: 0,
    flowCount: 0,
    interruptions: 0,
    sessions: sessions.length
  };
  for (var i = 0; i < sessions.length; i++) {
    out.totalFocusSec += sessions[i].focusSeconds || 0;
    out.interruptions += sessions[i].interruptions || 0;
    if (sessions[i].type === "flowtime") out.flowCount++;
    else out.pomodoroCount++;
  }
  return out;
}

function todaySummary(state, nowMs) {
  var now = typeof nowMs === "number" ? nowMs : Date.now();
  var list = sessionsOnDay(state.sessions, now);
  if (state.activeSpaceId) {
    list = list.filter(function (s) { return !s.spaceId || s.spaceId === state.activeSpaceId; });
  }
  var sum = summarize(list);
  sum.tasksDone = state.tasks.filter(function (t) {
    if (t.boardId !== state.activeSpaceId) return false;
    if (t.columnId !== "done" || !t.completedAt) return false;
    return dayKey(t.completedAt) === dayKey(now);
  }).length;
  return sum;
}

function streakDays(sessions, minSec, nowMs) {
  var now = typeof nowMs === "number" ? nowMs : Date.now();
  var min = Math.max(1, minSec || 1500);
  var byDay = {};
  for (var i = 0; i < sessions.length; i++) {
    var t = sessions[i].endedAt || sessions[i].startedAt;
    if (!t) continue;
    var k = dayKey(t);
    byDay[k] = (byDay[k] || 0) + (sessions[i].focusSeconds || 0);
  }
  var cursor = startOfDay(now);
  var todayK = dayKey(now);
  if (!(byDay[todayK] >= min)) cursor -= 86400000;
  var streak = 0;
  for (var d = 0; d < 3650; d++) {
    var key = dayKey(cursor - d * 86400000);
    if ((byDay[key] || 0) >= min) streak++;
    else break;
  }
  return streak;
}

function startOfWeek(nowMs, weekStartsOn) {
  var start = startOfDay(nowMs);
  var dow = new Date(start).getDay();
  var offset = weekStartsOn === "sunday" ? dow : (dow + 6) % 7;
  return start - offset * 86400000;
}

function weekSummary(sessions, spaceId, weekStartsOn, nowMs) {
  var now = typeof nowMs === "number" ? nowMs : Date.now();
  var names = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"];
  var start = startOfWeek(now, weekStartsOn);
  var first = weekStartsOn === "sunday" ? 0 : 1;
  var out = [];
  for (var i = 0; i < 7; i++) {
    var dayMs = start + i * 86400000;
    var dow = (first + i) % 7;
    var total = 0;
    var list = sessionsOnDay(sessions, dayMs);
    for (var j = 0; j < list.length; j++) {
      if (spaceId && list[j].spaceId && list[j].spaceId !== spaceId) continue;
      total += list[j].focusSeconds || 0;
    }
    out.push({ label: names[dow], seconds: total });
  }
  return out;
}

if (typeof module !== "undefined") {
  module.exports = {
    dayKey: dayKey,
    startOfDay: startOfDay,
    startOfWeek: startOfWeek,
    sessionsOnDay: sessionsOnDay,
    summarize: summarize,
    todaySummary: todaySummary,
    streakDays: streakDays,
    weekSummary: weekSummary
  };
}
