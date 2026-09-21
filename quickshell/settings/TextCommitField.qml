import QtQuick
import "../config"

// A single-line text field that commits on Return/focus-loss rather than
// every keystroke, and explicitly resyncs its displayed text from
// `value` (rather than staying live-bound to it) so an external change --
// a Reset, another write -- still reflects into the field afterward. A
// plain `text: value` binding would be silently and permanently severed
// the moment the user types a single character, since a TextInput's own
// edits always win over its property binding; this is the general shape
// InterfaceTab's Font Family field first built. `isValid` gates both the
// border color (red when false) and whether a commit actually happens --
// callers that don't need validation just leave it true.
Rectangle {
    id: root

    property string value: ""
    // Live-typed content, exposed so a caller can compute `isValid` (e.g. a
    // hex-color regex) against what's actually being typed right now, not
    // just the last committed `value`.
    property alias text: input.text
    property bool isValid: true
    property string placeholder: ""

    signal committed(string text)

    implicitHeight: Theme.fontSize * 1.8
    radius: Theme.radius / 2
    color: Theme.surfaceAlt
    border.width: 1
    border.color: root.isValid ? Theme.border : "#e05a5a"

    function syncFromValue() {
        if (!input.activeFocus)
            input.text = root.value;
    }

    onValueChanged: root.syncFromValue()
    Component.onCompleted: root.syncFromValue()

    TextInput {
        id: input
        anchors.fill: parent
        anchors.margins: Theme.fontSize / 2
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize * 0.85
        clip: true

        Text {
            anchors.fill: parent
            visible: input.text.length === 0
            verticalAlignment: Text.AlignVCenter
            text: root.placeholder
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize * 0.85
        }

        Keys.onReturnPressed: input.focus = false
        Keys.onEnterPressed: input.focus = false
        onEditingFinished: {
            if (root.isValid)
                root.committed(input.text);
            else
                root.syncFromValue(); // discard the bad input, revert to the last real value
        }
    }
}
