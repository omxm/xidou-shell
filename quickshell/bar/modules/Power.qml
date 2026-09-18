import QtQuick
import Quickshell.Services.UPower
import "../../config"

// Battery percentage from UPower's composite "display device" (the one
// UPower itself picks as representative — the laptop battery here).
// Quickshell normalizes percentage to a 0-1 fraction (confirmed empirically:
// `upower -i` reports 93%, Quickshell reports 0.93), consistent with how
// Pipewire's audio.volume is also 0-1 rather than 0-100.
Item {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property int percent: device ? Math.round(device.percentage * 100) : 0
    readonly property bool charging: device ? (device.state === UPowerDeviceState.Charging) : false

    implicitWidth: label.implicitWidth + Theme.fontSize
    implicitHeight: parent ? parent.height : Theme.fontSize * 2

    Text {
        id: label
        anchors.centerIn: parent
        text: root.device && root.device.isLaptopBattery
            ? (root.percent + "%" + (root.charging ? " +" : ""))
            : "--"
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }
}
