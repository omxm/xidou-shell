import QtQuick
import "../config"

// An editable list of plain strings -- one row per entry with its own
// remove button, plus an "Add" row at the bottom. Built for
// panels.wallpaper.directories (the first array-of-strings setting that
// needed a real add/remove UI rather than a fixed set of options an
// OptionRow fits, or a single scalar a TextCommitField fits), but kept
// generic/reusable the same way OptionRow/NumberStepper/TextCommitField are
// -- any future list-of-paths-or-names setting can reuse this directly.
Item {
    id: root

    property var items: []
    property string placeholder: ""

    // Named `committed`, not e.g. a plain "changed" signal -- `items` is a
    // property, so QML already auto-generates `itemsChanged` for when the
    // caller rebinds it (a fresh Config.data value); this is the distinct
    // "the user asked to add/remove an entry, please persist this" signal,
    // matching TextCommitField's own `committed` naming.
    signal committed(var newItems)

    function commitItems(newItems) {
        root.committed(newItems);
    }

    function removeAt(index) {
        var next = root.items.slice();
        next.splice(index, 1);
        root.commitItems(next);
    }

    function addItem(value) {
        var trimmed = String(value).trim();
        if (trimmed.length === 0)
            return;
        var next = root.items.slice();
        next.push(trimmed);
        root.commitItems(next);
        newItemField.text = "";
    }

    implicitHeight: column.height

    Column {
        id: column
        width: root.width
        spacing: Theme.fontSize / 4

        Repeater {
            model: root.items

            delegate: Row {
                id: itemRow
                required property string modelData
                required property int index

                width: column.width
                spacing: Theme.fontSize / 3

                Rectangle {
                    width: parent.width - removeButton.width - parent.spacing
                    height: Theme.fontSize * 1.8
                    radius: Theme.radius / 2
                    color: Theme.surfaceAlt
                    border.width: 1
                    border.color: Theme.border

                    Text {
                        anchors.fill: parent
                        anchors.margins: Theme.fontSize / 2
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideMiddle
                        text: itemRow.modelData
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize * 0.85
                    }
                }

                Rectangle {
                    id: removeButton
                    width: Theme.fontSize * 1.8
                    height: Theme.fontSize * 1.8
                    radius: Theme.radius / 2
                    color: Theme.surfaceAlt
                    border.width: 1
                    border.color: Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: "" // close (verified via fontTools, same codepoint as ScreenshotConfirm.qml's Cancel)
                        color: Theme.textMuted
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.fontSize * 0.9
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.removeAt(itemRow.index)
                    }
                }
            }
        }

        Row {
            width: column.width
            spacing: Theme.fontSize / 3

            Rectangle {
                width: parent.width - addButton.width - parent.spacing
                height: Theme.fontSize * 1.8
                radius: Theme.radius / 2
                color: Theme.surfaceAlt
                border.width: 1
                border.color: Theme.border

                TextInput {
                    id: newItemField
                    anchors.fill: parent
                    anchors.margins: Theme.fontSize / 2
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize * 0.85
                    clip: true

                    Text {
                        anchors.fill: parent
                        visible: newItemField.text.length === 0
                        verticalAlignment: Text.AlignVCenter
                        text: root.placeholder
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize * 0.85
                    }

                    Keys.onReturnPressed: root.addItem(newItemField.text)
                    Keys.onEnterPressed: root.addItem(newItemField.text)
                }
            }

            Rectangle {
                id: addButton
                width: Theme.fontSize * 1.8
                height: Theme.fontSize * 1.8
                radius: Theme.radius / 2
                color: Theme.accent

                Text {
                    anchors.centerIn: parent
                    text: "" // add (verified via fontTools)
                    color: Theme.background
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fontSize
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.addItem(newItemField.text)
                }
            }
        }
    }
}
