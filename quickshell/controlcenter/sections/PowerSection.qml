import QtQuick
import Quickshell.Services.UPower
import "../../config"
import ".." as ControlCenter

// Battery detail, on the same UPower.displayDevice bar/modules/Power.qml
// already reads. No power-profile switching here: power-profiles-daemon
// isn't running on this machine (it uses TLP instead), so
// Quickshell.Services.UPower's PowerProfiles API would just sit inert —
// scoped to real, working battery info instead of a dead control.
Item {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool hasBattery: root.device && root.device.isLaptopBattery
    readonly property int percent: root.device ? Math.round(root.device.percentage * 100) : 0

    function formatSeconds(s) {
        if (!s || s <= 0)
            return "";
        var h = Math.floor(s / 3600);
        var m = Math.round((s % 3600) / 60);
        return h > 0 ? (h + "h " + m + "m") : (m + "m");
    }

    ControlCenter.Card {
        anchors.fill: parent

        Column {
            anchors.fill: parent
            anchors.margins: Theme.fontSize
            spacing: Theme.fontSize / 2
            visible: root.hasBattery

            Text {
                text: root.percent + "%"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 2.2
                font.bold: true
            }

            Text {
                text: {
                    if (!root.device) return "";
                    var status = UPowerDeviceState.toString(root.device.state);
                    if (root.device.state === UPowerDeviceState.Charging && root.device.timeToFull > 0)
                        return status + " · " + root.formatSeconds(root.device.timeToFull) + " until full";
                    if (root.device.state === UPowerDeviceState.Discharging && root.device.timeToEmpty > 0)
                        return status + " · " + root.formatSeconds(root.device.timeToEmpty) + " remaining";
                    return status;
                }
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 0.95
            }

            Rectangle {
                width: parent.width
                height: Theme.fontSize / 2
                radius: height / 2
                color: Theme.surfaceAlt

                Rectangle {
                    width: parent.width * (root.percent / 100)
                    height: parent.height
                    radius: height / 2
                    color: Theme.accent
                }
            }

            Text {
                visible: root.device && root.device.healthSupported
                text: root.device ? ("Battery health: " + Math.round(root.device.healthPercentage) + "%") : ""
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 0.85
            }

            Text {
                visible: root.device && root.device.model
                text: root.device ? root.device.model : ""
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 0.85
            }
        }

        Text {
            anchors.centerIn: parent
            visible: !root.hasBattery
            text: "No battery found"
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }
}
