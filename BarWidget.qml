import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Flowdeck bar widget: a clock that reflects timer state.
// Left click toggles the panel through the Service (single state owner).
BarWidget {
  id: root
  moduleName: "yks.flowdeck"

  readonly property var flowService: {
    if (root.bar && root.bar.shell) {
      var s = null;
      try { s = root.bar.shell.serviceFor(root.moduleName); } catch (e) { s = null; }
      if (s) return s;
      try { s = root.bar.shell.serviceFor("yks.flowdeck"); } catch (e2) { s = null; }
      return s;
    }
    return null;
  }

  // Binds the 1 Hz service tick so the label refreshes while running.
  readonly property int tick: flowService ? flowService.tickVersion : 0
  readonly property int rev: flowService ? flowService.revision : 0

  readonly property string mode: flowService ? String(flowService.timer.mode) : "idle"
  readonly property string phase: flowService ? String(flowService.timer.phase) : "stopped"

  // Nerd Font clock glyph (fa-clock-o): the button that opens the popup.
  readonly property string clockGlyph: ""

  function clockText() {
    if (!root.flowService) return root.clockGlyph;
    var parts = [];
    void root.tick; void root.rev;
    if (root.phase === "running" || root.phase === "paused" || root.phase === "break") {
      if (root.mode === "pomodoro" || root.phase === "break") {
        var rem = Math.max(0, Math.floor(root.flowService.timerRemainingMs() / 1000));
        parts.push(formatMS(rem));
      } else if (root.mode === "flowtime") {
        var el = Math.max(0, Math.floor(root.flowService.flowElapsedMs() / 1000));
        parts.push(formatShort(el));
      }
    }
    return parts.length > 0 ? root.clockGlyph + " " + parts.join(" ") : root.clockGlyph;
  }

  function formatMS(totalSeconds) {
    var m = Math.floor(totalSeconds / 60);
    var s = totalSeconds % 60;
    return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
  }

  function formatShort(totalSeconds) {
    var m = Math.floor(totalSeconds / 60);
    if (m < 60) return m + "m";
    var h = Math.floor(m / 60);
    return h + "h " + (m % 60) + "m";
  }

  readonly property bool active: root.phase === "running" || root.phase === "break"

  implicitWidth: label.implicitWidth + Style.space(16)
  implicitHeight: barSize

  Text {
    id: label
    anchors.centerIn: parent
    textFormat: Text.PlainText
    text: root.clockText()
    color: root.active ? (root.bar ? root.bar.barForeground : Color.foreground) : (root.bar ? Qt.darker(root.bar.barForeground, 1.25) : Color.muted)
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.body
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton
    onClicked: function(mouse) {
      if (mouse.button === Qt.LeftButton && root.flowService) root.flowService.togglePanel();
    }
  }
}
