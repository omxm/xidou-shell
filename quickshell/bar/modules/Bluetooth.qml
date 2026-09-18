import QtQuick
import Quickshell.Bluetooth
import "../../config"

// Adapter power state + connected-device count, via Quickshell's Bluez
// service (talks to bluez over D-Bus directly, no bluetoothctl shelling).
Item {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool enabled: adapter ? adapter.enabled : false
    readonly property int connectedCount: {
        if (!adapter || !adapter.devices)
            return 0;
        var n = 0;
        for (var i = 0; i < adapter.devices.length; i++)
            if (adapter.devices[i].connected)
                n++;
        return n;
    }

    // Material Symbols Outlined codepoints for "bluetooth" /
    // "bluetooth_disabled", from Google's upstream codepoints file.
    readonly property string icon: root.enabled ? "" : ""

    implicitWidth: row.implicitWidth + Theme.fontSize
    implicitHeight: parent ? parent.height : Theme.fontSize * 2

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.fontSize / 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            color: root.enabled ? Theme.text : Theme.textMuted
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.fontSize
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: !root.adapter ? "--" : (root.enabled ? String(root.connectedCount) : "")
            visible: text.length > 0
            color: root.enabled ? Theme.text : Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }
}
