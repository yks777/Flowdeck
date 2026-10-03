// Flowdeck Storage — path resolution and persistence helpers.

function statePath() {
  var stateHome = Quickshell.env("XDG_STATE_HOME");
  if (!stateHome) {
    var home = Quickshell.env("HOME") || "";
    stateHome = home + "/.local/state";
  }
  return stateHome + "/omarchy/flowdeck.json";
}

function corruptBackupPath() {
  var stateHome = Quickshell.env("XDG_STATE_HOME");
  if (!stateHome) {
    var home = Quickshell.env("HOME") || "";
    stateHome = home + "/.local/state";
  }
  return stateHome + "/omarchy/flowdeck-corrupt-" + Date.now() + ".json";
}

if (typeof module !== "undefined") {
  module.exports = {
    statePath: statePath,
    corruptBackupPath: corruptBackupPath
  };
}
