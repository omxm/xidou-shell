import QtQuick
import "../config"

// One labeled setting row: a label on the left, the actual control (dropped
// in via the default `data` property by whatever uses this) in the middle,
// and an "Overridden" badge + per-row reset button on the right that only
// appear once the live value actually differs from config.toml's built-in
// default. `showOverriddenOnly` (set by the page from Settings.qml's
// top-right toggle) hides the whole row instead of just the badge when true
// and this row isn't overridden -- the toggle filters *rows*, the badge
// just marks state within a visible one.
//
// tableHeader/settingKey/defaultValue describe exactly what Config.setValue()
// would take to write this row's value, so reset() can call it directly
// without whatever placed this row needing to duplicate that wiring. That
// model assumes one row = one literal config key, which doesn't fit
// something like a bar module's on/off state (derived from *membership* in
// one of three array keys, not a key of its own) -- customOverridden/
// customReset let a caller override just the "is this different from
// default" check and the reset action while still getting the same
// label/control-slot/badge chrome as every other row.
Item {
    id: root

    property string label: ""
    property string tableHeader: ""
    property string settingKey: ""
    property var defaultValue: undefined
    property bool showOverriddenOnly: false
    // Override for a control taller than one line -- e.g. OSD/Notification
    // Position, which stacks a vertical and a horizontal picker rather than
    // needing a new composite-position widget shape.
    property real rowHeight: Theme.fontSize * 2.6

    property var customOverridden: undefined // set a bool to bypass the tableHeader/settingKey/defaultValue comparison entirely
    property var customReset: null // set a function to bypass the default Config.setValue(tableHeader, settingKey, defaultValue) reset

    readonly property var currentValue: (Config.data[tableHeader] || {})[settingKey]
    readonly property bool overridden: root.customOverridden !== undefined ? root.customOverridden : (JSON.stringify(root.currentValue) !== JSON.stringify(root.defaultValue))

    default property alias controlContent: controlSlot.data

    function reset() {
        if (!root.overridden)
            return;
        if (root.customReset) {
            root.customReset();
            return;
        }
        Config.setValue(root.tableHeader, root.settingKey, root.defaultValue);
    }

    visible: !root.showOverriddenOnly || root.overridden
    height: visible ? root.rowHeight : 0
    width: parent ? parent.width : 0

    Row {
        anchors.fill: parent
        spacing: Theme.fontSize

        Text {
            width: parent.width * 0.4
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            wrapMode: Text.WordWrap
        }

        Item {
            id: controlSlot
            width: parent.width * 0.4
            height: parent.height
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.fontSize / 3
            visible: root.overridden

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Overridden"
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 0.75
            }

            Rectangle {
                width: Theme.fontSize * 1.6
                height: Theme.fontSize * 1.6
                radius: Theme.radius / 2
                color: Theme.surfaceAlt
                border.width: 1
                border.color: Theme.border

                Text {
                    anchors.centerIn: parent
                    text: "" // restart_alt (verified via fontTools, same codepoint as Settings.qml's Reset Page)
                    color: Theme.textMuted
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fontSize * 0.9
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.reset()
                }
            }
        }
    }
}
