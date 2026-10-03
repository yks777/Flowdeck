// TimerEngine.js — pure time math. The visual tick is NEVER the source of
// truth: remaining time always derives from wall-clock timestamps so the
// timer survives panel close, shell reload and suspend/resume.
.pragma library

function pomodoroRemainingMs(timer, now) {
  if (!timer || timer.phase === "stopped") return 0;
  if (timer.phase === "paused") return Math.max(0, timer.pausedRemainingMs || 0);
  return Math.max(0, (timer.deadlineMs || 0) - (now || Date.now()));
}

function flowElapsedMs(timer, now) {
  if (!timer || timer.mode !== "flowtime") return 0;
  var acc = timer.accumulatedMs || 0;
  if (timer.phase === "running") acc += (now || Date.now()) - (timer.startedAtMs || 0);
  return Math.max(0, acc);
}

// Traditional flowtime break suggestion (seconds of focus -> seconds of break).
function traditionalBreakSec(focusSec) {
  if (focusSec <= 25 * 60) return 5 * 60;
  if (focusSec <= 50 * 60) return 8 * 60;
  if (focusSec <= 90 * 60) return 10 * 60;
  return 15 * 60;
}

function proportionalBreakSec(focusSec, pct, minSec, maxSec) {
  var b = Math.round(focusSec * pct);
  if (b < minSec) b = minSec;
  if (b > maxSec) b = maxSec;
  return b;
}

function suggestedBreakSec(focusSec, settings) {
  if (settings && settings.flowBreakMode === "proportional") {
    return proportionalBreakSec(focusSec, settings.flowBreakPct,
      settings.flowBreakMinSec, settings.flowBreakMaxSec);
  }
  return traditionalBreakSec(focusSec);
}
