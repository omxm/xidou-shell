import QtQuick
import Quickshell.Networking
import "../../config"
import ".." as ControlCenter

// Wi-Fi enable/scan toggle + network list, on Quickshell's Networking
// service directly (NetworkManager-backed) — no project wrapper exists
// anywhere in the repo yet (bar has no network module at all).
Item {
    id: root

    readonly property var wifiDevice: {
        var devices = Networking.devices ? Networking.devices.values : [];
        for (var i = 0; i < devices.length; i++)
            if (devices[i].type === DeviceType.Wifi)
                return devices[i];
        return null;
    }
    readonly property var networks: root.wifiDevice && root.wifiDevice.networks ? root.wifiDevice.networks.values : []

    ControlCenter.Card {
        anchors.fill: parent

        Column {
            anchors.fill: parent
            anchors.margins: Theme.fontSize
            spacing: Theme.fontSize / 2

            Row {
                width: parent.width
                height: Theme.fontSize * 2
                spacing: Theme.fontSize

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Networking.wifiHardwareEnabled === false ? "Wi-Fi is disabled in hardware (rfkill)"
                        : (Networking.wifiEnabled ? "Wi-Fi is on" : "Wi-Fi is off")
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.fontSize * 5
                    height: Theme.fontSize * 1.6
                    radius: height / 2
                    visible: Networking.wifiHardwareEnabled !== false
                    color: Networking.wifiEnabled ? Theme.accent : Theme.surfaceAlt
                    border.width: 1
                    border.color: Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: Networking.wifiEnabled ? "On" : "Off"
                        color: Networking.wifiEnabled ? Theme.background : Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize * 0.85
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.fontSize * 5
                    height: Theme.fontSize * 1.6
                    radius: height / 2
                    visible: Networking.wifiEnabled && root.wifiDevice !== null
                    color: root.wifiDevice && root.wifiDevice.scannerEnabled ? Theme.accent : Theme.surfaceAlt
                    border.width: 1
                    border.color: Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: root.wifiDevice && root.wifiDevice.scannerEnabled ? "Scanning…" : "Scan"
                        color: root.wifiDevice && root.wifiDevice.scannerEnabled ? Theme.background : Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize * 0.85
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.wifiDevice) root.wifiDevice.scannerEnabled = !root.wifiDevice.scannerEnabled
                    }
                }
            }

            Text {
                visible: Networking.wifiEnabled && root.networks.length === 0
                text: "No networks found yet"
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 0.9
            }

            Repeater {
                model: Networking.wifiEnabled ? root.networks : []
                delegate: Item {
                    required property var modelData

                    width: parent.width
                    height: Theme.fontSize * 2.4

                    Row {
                        anchors.fill: parent
                        spacing: Theme.fontSize / 2

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            // Material Symbols Outlined "signal_wifi_4_bar" /
                            // "signal_wifi_0_bar", coarse two-state icon —
                            // fine-grained signal-strength iconography is
                            // visual polish, same call as bar/Power.qml's
                            // three-state battery icon.
                            text: (modelData.signalStrength || 0) >= 50 ? "" : ""
                            color: modelData.connected ? Theme.accent : Theme.text
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.fontSize
                        }

                        Text {
                            width: parent.width * 0.5
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name || "Unknown network"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize * 0.95
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.fontSize * 5.5
                            height: Theme.fontSize * 1.6
                            radius: height / 2
                            color: modelData.connected ? Theme.accent : Theme.surfaceAlt
                            border.width: 1
                            border.color: Theme.border

                            Text {
                                anchors.centerIn: parent
                                text: modelData.stateChanging ? "…"
                                    : modelData.connected ? "Disconnect"
                                    : modelData.known ? "Connect"
                                    : (modelData.security !== undefined && modelData.security !== WifiSecurityType.Open)
                                        ? "Needs password" : "Connect"
                                color: modelData.connected ? Theme.background : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize * 0.8
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.connected) {
                                        modelData.disconnect();
                                    } else if (modelData.known || modelData.security === WifiSecurityType.Open) {
                                        modelData.connect();
                                    } else {
                                        console.warn("[xidou] control-center network: password entry for new secured networks isn't built yet");
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
