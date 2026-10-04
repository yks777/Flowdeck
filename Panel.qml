import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "components"

// Flowdeck panel: true Omarchy panel entry point.
Panel {
  id: root
  moduleName: "io.github.yks777.flowdeck"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  function open() {
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  property bool opened: false
  property string currentView: "focus"
  property string returnView: "focus"

  function pluginId() {
    if (root.manifest && root.manifest.id) return String(root.manifest.id);
    return "io.github.yks777.flowdeck";
  }

  function openView(payloadJson) {
    var payload = {};
    try { payload = JSON.parse(payloadJson || "{}") || {}; } catch (e) {}
    var view = String(payload.view || "");
    if (root.service) {
      var pending = "";
      try { pending = String(root.service.consumePendingView() || ""); } catch (e2) {}
      if (view === "") view = pending;
    }
    if (view === "kanban") view = "matrix";
    if (view === "focus" || view === "matrix" || view === "stats") root.currentView = view;
    root.opened = true;
    Qt.callLater(function() {
      if (root.opened) keyCatcher.forceActiveFocus();
    });
  }

  function dismiss() {
    root.opened = false;
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
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.dismiss()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
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
          width: parent.width
          height: root.contentHeight
          visible: root.currentView === "focus"

          FocusView {
            id: focusView
            anchors.fill: parent
            service: root.service
          }
        }

        Item {
          width: parent.width
          height: root.contentHeight
          visible: root.currentView === "matrix"

          MatrixView {
            anchors.fill: parent
            service: root.service
          }
        }

        Item {
          width: parent.width
          height: root.contentHeight
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
          width: parent.width
          height: root.contentHeight
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