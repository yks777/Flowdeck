// Storage.js — data-file location + export/import helpers (pure JS).
// Canonical file: $XDG_DATA_HOME/flowdeck/state.json, falling back to
// ~/.local/share/flowdeck/state.json. Nothing is ever stored inside the
// plugin source directory.
.pragma library

function dataDir(env) {
  var xdg = env("XDG_DATA_HOME") || "";
  if (xdg !== "") return xdg.replace(/\/$/, "") + "/flowdeck";
  var home = env("HOME") || "";
  return home + "/.local/share/flowdeck";
}

function statePath(env) {
  return dataDir(env) + "/state.json";
}

function backupPath(env) {
  return dataDir(env) + "/state.json.corrupt-" + Date.now();
}

function exportPath(env) {
  var docs = env("XDG_DOCUMENTS_DIR") || "";
  var base = docs !== "" ? docs : ((env("HOME") || "") + "/Documents");
  return base + "/flowdeck-backup-" + new Date().toISOString().slice(0, 10) + ".json";
}
