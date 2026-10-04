import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "logic/Model.js" as Model

// Flowdeck bar button (padrão menu): só o botão vive aqui. O popup é o
// Panel.qml standalone, carregado pelo panel-loader da shell — summon/hide/
// toggle com payload {view} chegam via Panel.open(payloadJson).
// Sem Loader aninhado: ele criava um segundo painel fantasma sem service.
BarWidget {
  id: root
  moduleName: "io.github.yks777.flowdeck"

  readonly property var flowService: {
    try {
      if (root.bar && root.bar.shell && typeof root.bar.shell.serviceFor === "function")
        return root.bar.shell.serviceFor(root.moduleName);
    } catch (e) {}
    return null;
  }

  // Relógio local: força os bindings de texto/tooltip a cada segundo.
  // O tempo em si nunca vem daqui — Service usa wall-clock (deadlineMs).
  property int nowTick: 0
  Timer {
    interval: 1000
    repeat: true
    running: true
    onTriggered: root.nowTick++
  }

  // Contagem viva adaptativa (MM:SS < 1h, HH:MM:SS >= 1h) com relógio
  // à esquerda. Parado = só o ícone. Semântica mantida: Pomodoro = restante,
  // Flowtime = decorrido (wall-clock no Service).
  readonly property string displayText: {
    var svc = root.flowService;
    if (!svc || !svc.timer) return "";
    void root.nowTick;
    try { void svc.tickVersion; } catch (e) {}
    var t = svc.timer;
    var ms = 0;
    if (t.phase === "running" || t.phase === "break") {
      if (t.mode === "flowtime" && t.phase === "running") ms = svc.flowElapsedMs();
      else ms = svc.timerRemainingMs();
    } else if (t.phase === "paused") {
      if (t.mode === "flowtime") ms = svc.flowElapsedMs();
      else ms = Math.max(0, t.pausedRemainingMs || 0);
    } else {
      return "";
    }
    return " " + Model.formatClock(Math.floor(ms / 1000));
  }

  readonly property string tooltipText: {
    var svc = root.flowService;
    if (!svc || !svc.timer) return "Open Flowdeck";
    void root.nowTick;
    try { void svc.revision; } catch (e) {}
    var t = svc.timer;
    if (t.phase === "running") {
      var what = t.mode === "flowtime" ? "Flowtime" : "Pomodoro";
      return what + " running — click to open";
    }
    if (t.phase === "break") return "Break — click to open";
    if (t.phase === "paused") return "Timer paused — middle-click resumes";
    return "Open Flowdeck (right-click: stats, middle-click: start/pause)";
  }

  function togglePanel() {
    try {
      if (root.bar && root.bar.shell && typeof root.bar.shell.toggle === "function") {
        root.bar.shell.toggle(root.moduleName, "{}");
        return;
      }
    } catch (e) {}
    if (root.bar && typeof root.bar.run === "function")
      root.bar.run("omarchy-shell shell toggle " + root.moduleName + " '{}'");
  }

  function openStats() {
    try {
      if (root.bar && root.bar.shell && typeof root.bar.shell.summon === "function") {
        root.bar.shell.summon(root.moduleName, JSON.stringify({ view: "stats" }));
        return;
      }
    } catch (e) {}
    if (root.bar && typeof root.bar.run === "function")
      root.bar.run("omarchy-shell shell summon " + root.moduleName + " '{\"view\":\"stats\"}'");
  }

  function toggleTimer() {
    var svc = root.flowService;
    if (!svc) return;
    try {
      if (svc.timer.phase === "running" || svc.timer.phase === "break") svc.pauseTimer();
      else if (svc.timer.phase === "paused") svc.resumeTimer();
      else {
        if (svc.settings && svc.settings.focusAction === "flowtime") svc.startFlowtime();
        else svc.startPomodoro();
      }
    } catch (e) {}
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.displayText
    tooltipText: root.tooltipText
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.openStats();
      else if (buttonCode === Qt.MiddleButton) root.toggleTimer();
      else root.togglePanel();
    }
  }
}
