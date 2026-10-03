import QtQuick
import QtQuick.Layouts
import qs.Commons

// Inline task composer: [ title... ] [ Add ] [ x ]. Enter saves, Esc cancels.
RowLayout {
  id: root

  signal saved(string title)
  signal cancelled()

  spacing: Style.space(6)
  Layout.fillWidth: true

  FlowInput {
    id: input
    placeholder: "Task title..."
    Layout.fillWidth: true
    onAccepted: {
      if (input.text.trim() !== "") root.saved(input.text);
    }
    onCancelled: root.cancelled()
  }

  FlowButton {
    text: "Add"
    primary: true
    onClicked: {
      if (input.text.trim() !== "") root.saved(input.text);
    }
  }

  FlowIconButton {
    glyph: "×"
    boxSize: 32
    onClicked: root.cancelled()
  }

  function focusInput() { input.focusInput(); }
}
