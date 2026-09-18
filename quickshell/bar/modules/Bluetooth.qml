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

    implicitWidth: label.implicitWidth + Theme.fontSize
    implicitHeight: parent ? parent.height : Theme.fontSize * 2

    Text {
        id: label
        anchors.centerIn: parent
        text: !root.adapter ? "BT --" : (root.enabled ? ("BT " + root.connectedCount) : "BT off")
        color: root.enabled ? Theme.text : Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }
}
