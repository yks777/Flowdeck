import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "components"

// Flowdeck panel: a true Omarchy `panel` entry point. Centered popup card
// (never fullscreen UI, never a second Quickshell instance). Size follows
// the active view; the scrim outside dismisses without blocking the desktop
// (ExclusionMode.Ignore).
Item {
  id: root

  property var shell: null
  property var manifest: null
  property var service: null
  property string omarchyPath: ""

  property bool opened: false
  property string currentView: "focus" // focus | matrix | stats | settings
  property string returnView: "focus"

  function pluginId() {
    if (root.manifest && root.manifest.id) return String(root.manifest.id);
    return "yks.flowdeck";
  }

  function open(payloadJson) {
    var payload = {};
    try { payload = JSON.parse(payloadJson || "{}") || {}; } catch (e) {}
    var view = String(payload.view || "");
    if (root.service) {
      var pending = "";
      try { pending = String(root.service.consumePendingView() || ""); } catch (e2) {}
      if (view === "") view = pending;
    }
    if (view === "kanban") view = "matrix"; // legacy alias
    if (view === "focus" || view === "matrix" || view === "stats") root.currentView = view;
    root.opened = true;
    Qt.callLater(function() {
      if (root.opened) keyCatcher.forceActiveFocus();
    });
  }

  function close() {
    root.opened = false;
  }

  function dismiss() {
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide(root.pluginId());
    else root.close();
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

  // ---- per-view card size (never a universal 900x600) ----
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

  PanelWindow {
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-flowdeck"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.55)
      MouseArea {
        anchors.fill: parent
        onClicked: root.dismiss()
      }
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: root.dismiss()

      Item {
        anchors.centerIn: parent
        width: Math.max(1, surface.implicitWidth)
        height: Math.max(1, surface.implicitHeight)
        // Small outputs: shrink the whole card instead of clipping it.
        scale: Math.min(1,
          (keyCatcher.width - Style.space(32)) / Math.max(1, width),
          (keyCatcher.height - Style.space(32)) / Math.max(1, height))

        MouseArea { anchors.fill: parent; onClicked: {} }

        BorderSurface {
          id: surface
          anchors.fill: parent
          color: Color.popups.background
          radius: Style.cornerRadius
          borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(1)))

          implicitWidth: root.cardWidth
          implicitHeight: mainCol.implicitHeight + Style.space(32)

          ColumnLayout {
            id: mainCol
            anchors.fill: parent
            anchors.margins: Style.space(16)
            spacing: Style.space(10)

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

            // ---- content (never behind/above the header: strict column) ----
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
  }
}
