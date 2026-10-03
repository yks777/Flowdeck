// Flowdeck FocusEngine — pure timer logic for Pomodoro and Flowtime.
//
// No UI, no persistence. Operates on `state` (Model shape) and returns the
// mutated state plus small result objects. All wall-clock math uses absolute
// timestamps (deadlineMs / focusStartMs), never a blind per-second
// decrement, so reloads, suspend and shell restarts cannot drift the timer.

var TECHNIQUE_POMODORO = "pomodoro";
var TECHNIQUE_FLOWTIME = "flowtime";

var PHASE_IDLE = "idle";
var PHASE_WORK = "work";
var PHASE_SHORT_BREAK = "shortBreak";
var PHASE_LONG_BREAK = "longBreak";
var PHASE_FOCUS = "focus";
var PHASE_FLOW_BREAK = "flowBreak";

var STATUS_STOPPED = "stopped";
var STATUS_RUNNING = "running";
var STATUS_PAUSED = "paused";
var STATUS_BREAK = "break";

function nowMs() {
  return Date.now();
}

function isBreakPhase(phase) {
  return phase === PHASE_SHORT_BREAK || phase === PHASE_LONG_BREAK || phase === PHASE_FLOW_BREAK;
}

// ---- Pomodoro ----

function startWork(state) {
  var t = state.timer;
  var dur = state.settings.workSec;
  t.technique = TECHNIQUE_POMODORO;
  t.phase = PHASE_WORK;
  t.status = STATUS_RUNNING;
  t.phaseDurationSec = dur;
  t.remainingSec = dur;
  t.deadlineMs = nowMs() + dur * 1000;
  return state;
}

function startPomodoroBreak(state, long) {
  var t = state.timer;
  var dur = long ? state.settings.longBreakSec : state.settings.shortBreakSec;
  t.technique = TECHNIQUE_POMODORO;
  t.phase = long ? PHASE_LONG_BREAK : PHASE_SHORT_BREAK;
  t.status = STATUS_BREAK;
  t.phaseDurationSec = dur;
  t.remainingSec = dur;
  t.deadlineMs = nowMs() + dur * 1000;
  return state;
}

// ---- Flowtime ----

function startFlow(state) {
  var t = state.timer;
  t.technique = TECHNIQUE_FLOWTIME;
  t.phase = PHASE_FOCUS;
  t.status = STATUS_RUNNING;
  t.focusStartMs = nowMs();
  t.baseElapsedSec = 0;
  t.interruptions = 0;
  t.phaseDurationSec = 0;
  t.remainingSec = 0;
  t.deadlineMs = 0;
  return state;
}

function startFlowBreak(state, breakSec) {
  var t = state.timer;
  var dur = Math.max(60, Math.floor(Number(breakSec) || 300));
  t.technique = TECHNIQUE_FLOWTIME;
  t.phase = PHASE_FLOW_BREAK;
  t.status = STATUS_BREAK;
  t.phaseDurationSec = dur;
  t.remainingSec = dur;
  t.deadlineMs = nowMs() + dur * 1000;
  return state;
}

function addInterruption(state) {
  if (state.timer.technique === TECHNIQUE_FLOWTIME && state.timer.phase === PHASE_FOCUS) {
    state.timer.interruptions++;
  }
  return state;
}

// ---- Shared controls ----

function pauseTimer(state) {
  var t = state.timer;
  if (t.technique === TECHNIQUE_FLOWTIME && t.phase === PHASE_FOCUS) {
    if (t.status !== STATUS_RUNNING) return state;
    t.baseElapsedSec = flowElapsedSec(state);
    t.focusStartMs = 0;
    t.status = STATUS_PAUSED;
    return state;
  }
  if (t.status !== STATUS_RUNNING && t.status !== STATUS_BREAK) return state;
  t.remainingSec = remainingFromDeadline(t.deadlineMs, t.remainingSec);
  t.deadlineMs = 0;
  t.status = STATUS_PAUSED;
  return state;
}

function resumeTimer(state) {
  var t = state.timer;
  if (t.status !== STATUS_PAUSED) return state;
  if (t.technique === TECHNIQUE_FLOWTIME && t.phase === PHASE_FOCUS) {
    t.focusStartMs = nowMs();
    t.status = STATUS_RUNNING;
    return state;
  }
  t.deadlineMs = nowMs() + Math.max(0, t.remainingSec) * 1000;
  t.status = isBreakPhase(t.phase) ? STATUS_BREAK : STATUS_RUNNING;
  return state;
}

function stopTimer(state) {
  var t = state.timer;
  t.phase = PHASE_IDLE;
  t.status = STATUS_STOPPED;
  t.deadlineMs = 0;
  t.remainingSec = 0;
  t.phaseDurationSec = 0;
  t.focusStartMs = 0;
  t.baseElapsedSec = 0;
  t.interruptions = 0;
  return state;
}

function resetTimer(state) {
  var t = state.timer;
  if (t.technique === TECHNIQUE_FLOWTIME && t.phase === PHASE_FOCUS) {
    return startFlow(state);
  }
  if (t.technique === TECHNIQUE_FLOWTIME && t.phase === PHASE_FLOW_BREAK) {
    t.remainingSec = t.phaseDurationSec;
    t.deadlineMs = nowMs() + t.phaseDurationSec * 1000;
    return state;
  }
  if (t.technique === TECHNIQUE_FLOWTIME && t.phase === PHASE_IDLE) {
    t.phase = PHASE_IDLE;
    t.status = STATUS_STOPPED;
    t.deadlineMs = 0;
    t.remainingSec = 0;
    t.phaseDurationSec = 0;
    t.focusStartMs = 0;
    t.baseElapsedSec = 0;
    t.interruptions = 0;
    return state;
  }
  var dur = t.phase === PHASE_SHORT_BREAK ? state.settings.shortBreakSec
    : t.phase === PHASE_LONG_BREAK ? state.settings.longBreakSec
    : state.settings.workSec;
  if (t.phase === PHASE_IDLE) t.phase = PHASE_WORK;
  t.phaseDurationSec = dur;
  t.remainingSec = dur;
  t.deadlineMs = 0;
  t.status = STATUS_STOPPED;
  return state;
}

// ---- Readouts ----

function remainingFromDeadline(deadlineMs, fallbackSec) {
  if (!deadlineMs) return Math.max(0, Math.floor(fallbackSec || 0));
  return Math.max(0, Math.round((deadlineMs - nowMs()) / 1000));
}

function flowElapsedSec(state) {
  var t = state.timer;
  var base = Math.max(0, Math.floor(t.baseElapsedSec || 0));
  if (t.status === STATUS_RUNNING && t.focusStartMs) {
    base += Math.max(0, Math.floor((nowMs() - t.focusStartMs) / 1000));
  }
  return base;
}

function displaySeconds(state) {
  var t = state.timer;
  if (t.technique === TECHNIQUE_FLOWTIME && t.phase === PHASE_FOCUS) {
    return flowElapsedSec(state);
  }
  if (t.status === STATUS_RUNNING || t.status === STATUS_BREAK) {
    return remainingFromDeadline(t.deadlineMs, t.remainingSec);
  }
  return Math.max(0, Math.floor(t.remainingSec || 0));
}

function progress(state) {
  var t = state.timer;
  if (t.technique === TECHNIQUE_FLOWTIME && t.phase === PHASE_FOCUS) return 0;
  var dur = Math.max(1, t.phaseDurationSec || 1);
  return Math.max(0, Math.min(1, 1 - (displaySeconds(state) / dur)));
}

function tick(state) {
  var t = state.timer;
  if (t.technique === TECHNIQUE_FLOWTIME && t.phase === PHASE_FOCUS) {
    return { state: state, phaseEnded: false };
  }
  if (t.status !== STATUS_RUNNING && t.status !== STATUS_BREAK) {
    return { state: state, phaseEnded: false };
  }
  var rem = remainingFromDeadline(t.deadlineMs, t.remainingSec);
  t.remainingSec = rem;
  if (rem <= 0) {
    return { state: state, phaseEnded: true, finishedPhase: t.phase };
  }
  return { state: state, phaseEnded: false };
}

function completeWorkPhase(state, startedAtMs) {
  var t = state.timer;
  var now = nowMs();
  var dur = t.phaseDurationSec || state.settings.workSec;
  var session = {
    id: "",
    type: "pomodoro",
    taskId: t.activeTaskId || "",
    spaceId: state.activeSpaceId,
    startedAt: startedAtMs || (now - dur * 1000),
    endedAt: now,
    focusSeconds: dur,
    breakSeconds: 0,
    interruptions: 0,
    completed: true
  };
  t.completedInCycle++;
  var long = (t.completedInCycle % state.settings.longBreakInterval) === 0;
  session.breakSeconds = long ? state.settings.longBreakSec : state.settings.shortBreakSec;
  startPomodoroBreak(state, long);
  return { session: session, breakLong: long };
}

function finishFlow(state) {
  var t = state.timer;
  var now = nowMs();
  var elapsed = flowElapsedSec(state);
  var session = {
    id: "",
    type: "flowtime",
    taskId: t.activeTaskId || "",
    spaceId: state.activeSpaceId,
    startedAt: t.focusStartMs ? (now - (elapsed - (t.baseElapsedSec || 0)) * 1000) : (now - elapsed * 1000),
    endedAt: now,
    focusSeconds: elapsed,
    breakSeconds: 0,
    interruptions: t.interruptions,
    completed: true,
    suggestedBreakSeconds: suggestedBreakSeconds(elapsed, state.settings)
  };
  return { session: session };
}

function suggestedBreakSeconds(focusSeconds, settings) {
  var f = Math.max(0, Math.floor(focusSeconds));
  if (settings.flowBreakMode === "proportional") {
    var raw = Math.round(f * settings.flowBreakPct);
    return Math.max(settings.flowBreakMinSec, Math.min(settings.flowBreakMaxSec, raw));
  }
  if (f <= 25 * 60) return 5 * 60;
  if (f <= 50 * 60) return 8 * 60;
  if (f <= 90 * 60) return 10 * 60;
  return 15 * 60;
}

function settleLoadedTimer(state) {
  var t = state.timer;
  if ((t.status === STATUS_RUNNING || t.status === STATUS_BREAK) && t.phase !== PHASE_FOCUS) {
    if (!t.deadlineMs || t.deadlineMs <= nowMs()) {
      t.status = STATUS_PAUSED;
      t.deadlineMs = 0;
      if (!(t.remainingSec > 0)) t.remainingSec = t.phaseDurationSec || 0;
    }
  }
  return state;
}

// ---- Formatting ----

function formatClock(totalSec) {
  var sec = Math.max(0, Math.floor(totalSec));
  var m = Math.floor(sec / 60);
  var s = sec % 60;
  return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
}

function formatHMS(totalSec) {
  var sec = Math.max(0, Math.floor(totalSec));
  var h = Math.floor(sec / 3600);
  var m = Math.floor((sec % 3600) / 60);
  var s = sec % 60;
  function pad(n) { return (n < 10 ? "0" : "") + n; }
  return pad(h) + ":" + pad(m) + ":" + pad(s);
}

function formatDuration(totalSec) {
  var sec = Math.max(0, Math.floor(totalSec));
  var h = Math.floor(sec / 3600);
  var m = Math.floor((sec % 3600) / 60);
  if (h > 0) return h + "h " + m + "m";
  if (m > 0) return m + "m";
  return sec + "s";
}

function formatCompact(totalSec) {
  var sec = Math.max(0, Math.floor(totalSec));
  var h = Math.floor(sec / 3600);
  var m = Math.floor((sec % 3600) / 60);
  if (h > 0) return h + "h" + (m > 0 ? " " + m + "m" : "");
  if (m > 0) return m + "m";
  return sec + "s";
}

function phaseLabel(timer) {
  if (timer.technique === TECHNIQUE_FLOWTIME) {
    if (timer.phase === PHASE_FLOW_BREAK) return "Flow break";
    if (timer.phase === PHASE_FOCUS) return "Flowtime";
    return "Flowtime";
  }
  if (timer.phase === PHASE_WORK) return "Work";
  if (timer.phase === PHASE_SHORT_BREAK) return "Short break";
  if (timer.phase === PHASE_LONG_BREAK) return "Long break";
  return "Pomodoro";
}

if (typeof module !== "undefined") {
  module.exports = {
    TECHNIQUE_POMODORO: TECHNIQUE_POMODORO,
    TECHNIQUE_FLOWTIME: TECHNIQUE_FLOWTIME,
    PHASE_IDLE: PHASE_IDLE,
    PHASE_WORK: PHASE_WORK,
    PHASE_SHORT_BREAK: PHASE_SHORT_BREAK,
    PHASE_LONG_BREAK: PHASE_LONG_BREAK,
    PHASE_FOCUS: PHASE_FOCUS,
    PHASE_FLOW_BREAK: PHASE_FLOW_BREAK,
    STATUS_STOPPED: STATUS_STOPPED,
    STATUS_RUNNING: STATUS_RUNNING,
    STATUS_PAUSED: STATUS_PAUSED,
    STATUS_BREAK: STATUS_BREAK,
    nowMs: nowMs,
    isBreakPhase: isBreakPhase,
    startWork: startWork,
    startPomodoroBreak: startPomodoroBreak,
    startFlow: startFlow,
    startFlowBreak: startFlowBreak,
    addInterruption: addInterruption,
    pauseTimer: pauseTimer,
    resumeTimer: resumeTimer,
    stopTimer: stopTimer,
    resetTimer: resetTimer,
    remainingFromDeadline: remainingFromDeadline,
    flowElapsedSec: flowElapsedSec,
    displaySeconds: displaySeconds,
    progress: progress,
    tick: tick,
    completeWorkPhase: completeWorkPhase,
    finishFlow: finishFlow,
    suggestedBreakSeconds: suggestedBreakSeconds,
    settleLoadedTimer: settleLoadedTimer,
    formatClock: formatClock,
    formatHMS: formatHMS,
    formatDuration: formatDuration,
    formatCompact: formatCompact,
    phaseLabel: phaseLabel
  };
}
