import QtQuick
import QtQuick.Layouts
import qs.Commons
import "../logic/Model.js" as Model

// Session history list (newest first). Pure display, no heavy widgets.
ColumnLayout {
  id: root

  property var sessions: []
  property int tickVersion: 0

  spacing: Style.space(4)
  Layout.fillWidth: true
  visible: root.sessions.length > 0

  Repeater {
    model: root.sessions.slice(0, 30)
    delegate: RowLayout {
      required property var modelData
      spacing: Style.space(8)
      Layout.fillWidth: true

      Rectangle {
        width: Style.space(8)
        height: Style.space(8)
        radius: width / 2
        color: modelData.kind === "pomo" ? Color.accent : Color.muted
        Layout.alignment: Qt.AlignVCenter
      }
      Text {
        textFormat: Text.PlainText
        text: (modelData.kind === "pomo" ? "Pomodoro" : "Flowtime") + " · " + Model.formatDur(modelData.durationSec)
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        Layout.fillWidth: true
        elide: Text.ElideRight
      }
      Text {
        textFormat: Text.PlainText
        text: timeAgo(modelData.startedAt)
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }

  function timeAgo(ts) {
    void root.tickVersion;
    var mins = Math.max(0, Math.floor((Date.now() - ts) / 60000));
    if (mins < 1) return "now";
    if (mins < 60) return mins + "m ago";
    var h = Math.floor(mins / 60);
    if (h < 24) return h + "h ago";
    return Math.floor(h / 24) + "d ago";
  }
}
