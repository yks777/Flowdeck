import QtQuick
import qs.Commons

// Square icon button with a comfortable hitbox. Glyph must come from the
// system icon font (Nerd Font); no images, no hardcoded colors.
Item {
  id: root

  property string glyph: ""
  property int boxSize: 32
  property bool highlighted: false
  property string tip: ""
  signal clicked()

  implicitWidth: boxSize
  implicitHeight: boxSize

  Rectangle {
    id: bg
    anchors.fill: parent
    radius: Style.cornerRadius
    color: Color.accent
    opacity: (hover.containsMouse || root.highlighted) ? 0.18 : 0.0
  }

  Text {
    anchors.centerIn: parent
    textFormat: Text.PlainText
    text: root.glyph
    color: root.highlighted ? Color.accent : Color.popups.text
    font.family: Style.font.family
    font.pixelSize: Style.font.title
  }

  MouseArea {
    id: hover
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
