import QtQuick
import qs.Commons

// Single-line text field. Exposes the inner TextInput value via `text`.
Rectangle {
  id: root

  property alias text: input.text
  property string placeholder: ""
  property bool numbersOnly: false
  signal accepted()
  signal cancelled()

  implicitWidth: 160
  implicitHeight: Style.space(32)
  radius: Style.cornerRadius
  color: "transparent"
  border.color: input.activeFocus ? Color.accent : Color.popups.border
  border.width: Math.max(1, Style.space(1))

  Text {
    anchors.fill: parent
    anchors.leftMargin: Style.space(10)
    anchors.rightMargin: Style.space(10)
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText
    text: root.placeholder
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    visible: input.text === "" && !input.activeFocus
    elide: Text.ElideRight
  }

  TextInput {
    id: input
    anchors.fill: parent
    anchors.leftMargin: Style.space(10)
    anchors.rightMargin: Style.space(10)
    verticalAlignment: TextInput.AlignVCenter
    color: Color.popups.text
    selectionColor: Color.accent
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    inputMethodHints: root.numbersOnly ? Qt.ImhDigitsOnly : Qt.ImhNone
    validator: root.numbersOnly ? intValidator : null
    onAccepted: { input.focus = false; root.accepted(); }
    Keys.onEscapePressed: { input.focus = false; root.cancelled(); }
  }

  IntValidator { id: intValidator; bottom: 0; top: 1000000; }

  function focusInput() {
    input.forceActiveFocus();
    input.selectAll();
  }
}
