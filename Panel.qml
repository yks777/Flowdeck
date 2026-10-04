import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "components"

// Flowdeck panel: entry point "panel" do manifest, carregado pelo
// panel-loader da shell (padrão menu, como omarchy.menu). A shell injeta
// shell/manifest/service/omarchyPath (declarados abaixo) e entrega o
// payload via open(payloadJson): summon "… '{"view":"matrix"}'".
// NÃO recriar Loader deste arquivo no BarWidget — era o painel fantasma.
Panel {
  id: root
  moduleName: "io.github.yks777.flowdeck"
  manageIpc: false

  // Injetados pela shell no onLoaded do panel-loader.
  property var shell: null
  property var manifest: null
  property var service: null
  property string omarchyPath: ""

  property var anchorItem: null
  property var hostWidget: null
  // Identidade que a barra usa para o dot de painel aberto e Tab-switch.
  readonly property var barIdentity: hostWidget || root

  // Sem barra viva no painel standalone (o loader não injeta `bar`), o
  // KeyboardPanel precisa de `anchorItem` + `bar` não-nulos para sair do
  // canto: `centerOnBar` centraliza em X na tela; `barPos "bottom"` prende
  // o Y no topo e o `gap` reativo desce o card para logo abaixo da barra.
  // O shim cobre os membros que o KeyboardPanel lê no caminho do open
  // (position/barSize/activePopout/requestPopout/releasePopout).
  readonly property QtObject barShim: QtObject {
    property string position: "bottom"
    property int barSize: 0
    property var activePopout: null
    function requestPopout(owner) {}
    function releasePopout(owner) {}
  }

  // `opened` vem da base (panelController.open) — nunca redeclarar.
  property string currentView: "focus"
  property string returnView: "focus"

  function pluginId() {
    if (root.manifest && root.manifest.id) return String(root.manifest.id);
    return "io.github.yks777.flowdeck";
  }

  // Chamado pela shell: open() sem arg (botão da barra) ou
  // open('{"view":"matrix|stats|focus"}') via summon.
  function open(payloadJson) {
    var payload = {};
    try { payload = JSON.parse(payloadJson || "{}") || {}; } catch (e) {}
    var view = String(payload.view || "");
    if (root.service) {
      var pending = "";
      try { pending = String(root.service.consumePendingView() || ""); } catch (e2) {}
      if (view === "") view = pending;
    }
    if (view === "kanban") view = "matrix"; // alias legado
    if (view === "focus" || view === "matrix" || view === "stats" || view === "settings") root.currentView = view;
    root.controller.show();
    Qt.callLater(function() {
      if (root.opened) keyCatcher.forceActiveFocus();
    });
  }

  function close() {
    root.controller.hide();
  }

  function toggle() {
    if (root.opened) root.close();
    else root.open();
  }

  function dismiss() {
    root.close();
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction);
    return false;
  }

  function goSettings() {
    if (root.currentView !== "settings") root.returnView = root.currentView;
    root.currentView = "settings";
  }

  function backFromSettings() {
    root.currentView = (root.returnView === "settings") ? "focus" : root.returnView;
  }

  function boardTitle() {
    if (!root.service) return "";
    try {
      var b = root.service.activeBoard();
      return b ? String(b.title) : "";
    } catch (e) { return ""; }
  }

  readonly property int cardWidth: {
    if (root.currentView === "matrix") return Style.space(880);
    if (root.currentView === "stats") return Style.space(480);
    if (root.currentView === "settings") return Style.space(440);
    return Style.space(400);
  }

  readonly property int contentHeight: {
    if (root.currentView === "matrix") return Style.space(500);
    if (root.currentView === "stats") return Style.space(460);
    if (root.currentView === "settings") return Style.space(460);
    return Math.max(Style.space(300), focusHost.contentH);
  }

  KeyboardPanel {
    id: panel
    anchorItem: centerAnchor
    owner: root.barIdentity
    bar: root.barShim
    open: root.opened
    centerOnBar: true
    // Centro real da tela nos dois eixos (X vem do centerOnBar). Sem âncora
    // viva na barra, barH = altura da própria janela (fullscreen); o Y da
    // fórmula (screenH - barH - C - gap) é resolvido com este gap reativo
    // para y = screenH/2 - C/2. Termos livres de loop: availableCardHeight
    // é o único consumidor de `gap` no KeyboardPanel e não é mais usado
    // (a altura abaixo é manual).
    gap: panel.screenH / 2 - panel.barH - (cardContent.implicitHeight + panel.verticalContentInset) / 2
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(root.cardWidth)
    // Altura manual = conteúdo inteiro (sem corte): o availableCardHeight do
    // KeyboardPanel fica envenenado pelo barH fullscreen e cortaria o card.
    // O min() impede overflow em telas baixas. screenH não depende de `gap`.
    contentHeight: Math.min(cardContent.implicitHeight + panel.verticalContentInset,
      Math.max(120, panel.screenH - (Style.bar.sizeHorizontal + Style.gapsOut * 2)))

    Item {
      id: centerAnchor
      anchors.fill: parent
    }

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.dismiss()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      ColumnLayout {
        id: cardContent
        width: parent.width
        spacing: Style.space(8)

        Header {
          boardTitle: root.boardTitle()
          onOpenSettings: root.goSettings()
          onClosePanel: root.dismiss()
        }

        NavigationTabs {
          currentView: root.currentView === "settings" ? root.returnView : root.currentView
          visible: root.currentView !== "settings"
          onSelectView: function(view) {
            root.currentView = view;
          }
        }

        Item {
          id: focusHost
          property int contentH: focusView.implicitHeight
          Layout.fillWidth: true
          Layout.preferredHeight: root.contentHeight
          visible: root.currentView === "focus"

          FocusView {
            id: focusView
            anchors.fill: parent
            service: root.service
          }
        }

        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: root.contentHeight
          visible: root.currentView === "matrix"

          MatrixView {
            anchors.fill: parent
            service: root.service
          }
        }

        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: root.contentHeight
          visible: root.currentView === "stats"

          Flickable {
            anchors.fill: parent
            clip: true
            contentWidth: width
            contentHeight: statsView.implicitHeight
            interactive: contentHeight > height

            StatsView {
              id: statsView
              width: parent.width
              service: root.service
            }
          }
        }

        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: root.contentHeight
          visible: root.currentView === "settings"

          Flickable {
            anchors.fill: parent
            clip: true
            contentWidth: width
            contentHeight: settingsView.implicitHeight
            interactive: contentHeight > height

            SettingsView {
              id: settingsView
              width: parent.width
              service: root.service
              onBack: root.backFromSettings()
            }
          }
        }
      }
    }
  }
}
