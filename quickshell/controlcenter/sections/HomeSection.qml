import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Quickshell.Networking
import "../../config"
import "../../services"
import ".." as ControlCenter
import "../cards"

// Home tab: profile card (primary, top-left) + now-playing card (secondary,
// top-right), then a clock+weather card and the quick-toggle grid as two
// smaller cards in a row below — loosely following the reference dashboard's
// rail/primary/secondary/row-of-smaller-cards shape without copying it.
Item {
    id: root

    readonly property int gap: Theme.fontSize

    Column {
        anchors.fill: parent
        spacing: root.gap

        Row {
            width: parent.width
            height: (parent.height - root.gap) * 0.55
            spacing: root.gap

            ProfileCard {
                width: parent.width * 0.45
                height: parent.height
            }

            NowPlayingCard {
                width: parent.width * 0.55 - root.gap
                height: parent.height
            }
        }

        Row {
            width: parent.width
            height: parent.height - (parent.height) * 0.55 - root.gap
            spacing: root.gap

            ClockWeatherCard {
                width: parent.width * 0.5
                height: parent.height
            }

            ControlCenter.Card {
                width: parent.width * 0.5 - root.gap
                height: parent.height

                GridLayout {
                    id: grid
                    anchors.fill: parent
                    anchors.margins: Theme.fontSize / 2
                    columns: 3
                    rowSpacing: Theme.fontSize / 2
                    columnSpacing: Theme.fontSize / 2

                    ControlCenter.ToggleTile {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        icon: "" // wifi
                        label: "Wi-Fi"
                        active: Networking.wifiEnabled
                        onTriggered: Networking.wifiEnabled = !Networking.wifiEnabled
                    }

                    ControlCenter.ToggleTile {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        icon: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? "" : ""
                        label: "Bluetooth"
                        active: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
                        onTriggered: {
                            if (Bluetooth.defaultAdapter)
                                Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled;
                        }
                    }

                    ControlCenter.ToggleTile {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        icon: "" // coffee (caffeine / inhibit sleep)
                        label: "Caffeine"
                        active: CaffeineService.active
                        onTriggered: CaffeineService.toggle()
                    }

                    ControlCenter.ToggleTile {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        icon: "" // dark_mode (night light)
                        label: "Night Light"
                        active: NightLightService.active
                        onTriggered: NightLightService.toggle()
                    }

                    ControlCenter.ToggleTile {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        icon: Notifications.dnd ? "" : ""
                        label: "DND"
                        active: Notifications.dnd
                        onTriggered: Notifications.toggleDnd()
                    }

                    ControlCenter.ToggleTile {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        icon: "" // power_settings_new
                        label: "Power"
                        implemented: false
                    }
                }
            }
        }
    }
}
