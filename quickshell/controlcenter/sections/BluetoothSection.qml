import QtQuick
import Quickshell.Bluetooth
import "../../config"
import ".." as ControlCenter

// Adapter power/scan controls + device list, all on Quickshell's Bluez
// service directly (same Bluetooth.defaultAdapter the Home toggle and the
// bar's Bluetooth.qml module already read) — no project wrapper exists.
Item {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []

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
                    text: root.adapter ? (root.adapter.enabled ? "Bluetooth is on" : "Bluetooth is off") : "No adapter found"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.fontSize * 5
                    height: Theme.fontSize * 1.6
                    radius: height / 2
                    visible: root.adapter !== null
                    color: root.adapter && root.adapter.enabled ? Theme.accent : Theme.surfaceAlt
                    border.width: 1
                    border.color: Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: root.adapter && root.adapter.enabled ? "On" : "Off"
                        color: root.adapter && root.adapter.enabled ? Theme.background : Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize * 0.85
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.fontSize * 5
                    height: Theme.fontSize * 1.6
                    radius: height / 2
                    visible: root.adapter !== null && root.adapter.enabled
                    color: root.adapter && root.adapter.discovering ? Theme.accent : Theme.surfaceAlt
                    border.width: 1
                    border.color: Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: root.adapter && root.adapter.discovering ? "Scanning…" : "Scan"
                        color: root.adapter && root.adapter.discovering ? Theme.background : Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize * 0.85
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.adapter) root.adapter.discovering = !root.adapter.discovering
                    }
                }
            }

            Text {
                visible: root.adapter && root.adapter.enabled && root.devices.length === 0
                text: "No devices found yet"
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 0.9
            }

            Repeater {
                model: root.adapter && root.adapter.enabled ? root.devices : []
                delegate: Item {
                    required property var modelData

                    width: parent.width
                    height: Theme.fontSize * 2.6

                    Row {
                        anchors.fill: parent
                        spacing: Theme.fontSize / 2

                        Column {
                            width: parent.width * 0.55
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: modelData.name || modelData.deviceName || "Unknown device"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize * 0.95
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Text {
                                text: (modelData.connected ? "Connected" : (modelData.paired ? "Paired" : "Available"))
                                    + (modelData.batteryAvailable ? " · " + Math.round(modelData.battery * 100) + "%" : "")
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize * 0.8
                            }
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
                                text: modelData.pairing ? "Pairing…"
                                    : modelData.connected ? "Disconnect"
                                    : modelData.paired ? "Connect" : "Pair"
                                color: modelData.connected ? Theme.background : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize * 0.8
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.connected)
                                        modelData.disconnect();
                                    else if (modelData.paired)
                                        modelData.connect();
                                    else
                                        modelData.pair();
                                }
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: modelData.paired
                            text: "Forget"
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize * 0.8

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: modelData.forget()
                            }
                        }
                    }
                }
            }
        }
    }
}
