import QtQuick
import QtQuick.Layouts
import qs.Commons

// FLOWDECK  <board>                    gear  close
RowLayout {
  id: root

  property string boardTitle: ""
  signal openSettings()
  signal closePanel()

  spacing: Style.space(8)
  Layout.fillWidth: true

  Text {
    textFormat: Text.PlainText
    text: "FLOWDECK"
    color: Color.popups.text
    font.family: Style.font.family
    font.pixelSize: Style.font.title
    font.letterSpacing: 2
  }

  Text {
    textFormat: Text.PlainText
    text: root.boardTitle
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    elide: Text.ElideRight
    Layout.fillWidth: true
  }

  FlowIconButton {
    glyph: ""
    tip: "Settings"
    highlighted: false
    onClicked: root.openSettings()
  }

  FlowIconButton {
    glyph: "×"
    tip: "Close"
    onClicked: root.closePanel()
  }
}
