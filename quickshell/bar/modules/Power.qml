import QtQuick
import Quickshell.Services.UPower
import "../../config"
import "../widgets"
import "../../services"

// Battery percentage from UPower's composite "display device" (the one
// UPower itself picks as representative — the laptop battery here).
// Quickshell normalizes percentage to a 0-1 fraction (confirmed empirically:
// `upower -i` reports 93%, Quickshell reports 0.93), consistent with how
// Pipewire's audio.volume is also 0-1 rather than 0-100.
Item {
    id: root

    readonly property var cfg: Config.data.bar_widgets.power
    readonly property var device: UPower.displayDevice
    readonly property int percent: device ? Math.round(device.percentage * 100) : 0
    readonly property bool charging: device ? (device.state === UPowerDeviceState.Charging) : false

    // Material Symbols Outlined codepoints for "battery_charging_full" /
    // "battery_alert" / "battery_full", from Google's upstream codepoints
    // file. Deliberately coarse (three states, not the full battery_NN_bar
    // ladder) — fine-grained battery iconography is visual polish, deferred
    // along with rounding/spacing/animations until the functional phases
    // are done.
    readonly property string icon: root.charging
        ? ""
        : (root.percent <= root.cfg.low_battery_threshold ? "" : "")

    readonly property bool hasBattery: device && device.isLaptopBattery

    implicitWidth: row.implicitWidth + Theme.fontSize
    implicitHeight: parent ? parent.height : Theme.fontSize * 2

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.fontSize / 4

        BarIcon {
            text: root.icon
            visible: root.hasBattery
        }

        BarLabel {
            text: root.hasBattery ? (root.cfg.show_percentage ? (root.percent + "%") : "") : "--"
            visible: !root.hasBattery || root.cfg.show_percentage
        }
    }

    // Click slot for Bar.qml's widget wrapper (ROADMAP F5): left opens
    // control-center at Power (M8, D6). Right click isn't declared, so it
    // falls through to the bar's dead zone.
    function leftClicked() {
        PanelManager.open("control-center", "Power");
    }
}
