import QtQuick
import Quickshell.Services.Pipewire
import "../../config"
import ".." as ControlCenter

// Output/Input device selectors + a per-app volume mixer, both built directly
// on Quickshell's Pipewire service (Pipewire.nodes is a live ObjectModel;
// PwNodeType's Sink/Source/AudioOutStream flags distinguish device role).
// No project-authored Pipewire wrapper exists yet — bar/modules/Volume.qml
// only reads defaultAudioSink directly, same as this does.
Item {
    id: root

    readonly property int gap: Theme.fontSize

    readonly property var allNodes: Pipewire.nodes.values || []

    // PwNodeType's role constants are pre-combined exact values, not
    // independent bits to test with `&` — confirmed by dumping the real
    // values (AudioSink=17=Sink|Audio, AudioOutStream=21=Stream|Sink|Audio):
    // a bitwise AND against AudioOutStream also matches plain AudioSink
    // nodes since they share the Sink|Audio bits, which is what caused real
    // output devices to wrongly show up in the Applications mixer. Exact
    // equality against each named role is the correct check.
    readonly property var outputDevices: root.allNodes.filter(function (n) {
        return n.type === PwNodeType.AudioSink;
    })
    readonly property var inputDevices: root.allNodes.filter(function (n) {
        return n.type === PwNodeType.AudioSource;
    })
    readonly property var playbackStreams: root.allNodes.filter(function (n) {
        return n.type === PwNodeType.AudioOutStream;
    })

    // Keeps every node this section touches (devices + streams) live-bound —
    // without a tracker, PwNode properties are just a static snapshot (same
    // caveat bar/modules/Volume.qml documents for defaultAudioSink).
    PwObjectTracker {
        objects: root.outputDevices.concat(root.inputDevices).concat(root.playbackStreams)
    }

    Column {
        anchors.fill: parent
        spacing: root.gap

        Row {
            width: parent.width
            height: (parent.height - root.gap) * 0.4
            spacing: root.gap

            ControlCenter.Card {
                width: parent.width / 2 - root.gap / 2
                height: parent.height

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.fontSize
                    spacing: Theme.fontSize / 3

                    Text {
                        text: "Output"
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize * 0.85
                    }

                    Repeater {
                        model: root.outputDevices
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool isDefault: Pipewire.defaultAudioSink === modelData

                            width: parent.width
                            height: Theme.fontSize * 2
                            radius: Theme.radius / 2
                            color: isDefault ? Theme.accent : "transparent"

                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.fontSize / 2
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                text: modelData.description || modelData.name
                                color: isDefault ? Theme.background : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize * 0.9
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Pipewire.preferredDefaultAudioSink = modelData
                            }
                        }
                    }
                }
            }

            ControlCenter.Card {
                width: parent.width / 2 - root.gap / 2
                height: parent.height

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.fontSize
                    spacing: Theme.fontSize / 3

                    Text {
                        text: "Input"
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize * 0.85
                    }

                    Repeater {
                        model: root.inputDevices
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool isDefault: Pipewire.defaultAudioSource === modelData

                            width: parent.width
                            height: Theme.fontSize * 2
                            radius: Theme.radius / 2
                            color: isDefault ? Theme.accent : "transparent"

                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.fontSize / 2
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                text: modelData.description || modelData.name
                                color: isDefault ? Theme.background : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize * 0.9
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Pipewire.preferredDefaultAudioSource = modelData
                            }
                        }
                    }
                }
            }
        }

        ControlCenter.Card {
            width: parent.width
            height: parent.height - (parent.height * 0.4) - root.gap

            Column {
                anchors.fill: parent
                anchors.margins: Theme.fontSize
                spacing: Theme.fontSize / 2

                Text {
                    text: "Applications"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize * 0.85
                }

                Text {
                    visible: root.playbackStreams.length === 0
                    text: "No apps are playing audio right now"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize * 0.9
                }

                Repeater {
                    model: root.playbackStreams
                    delegate: Item {
                        required property var modelData

                        width: parent.width
                        height: Theme.fontSize * 2.4

                        Row {
                            anchors.fill: parent
                            spacing: Theme.fontSize / 2

                            Text {
                                width: parent.width * 0.3
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                text: (modelData.properties && modelData.properties["application.name"])
                                    || modelData.description || modelData.name
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize * 0.9
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.audio && modelData.audio.muted ? "" : "" // volume_off / volume_up
                                color: modelData.audio && modelData.audio.muted ? Theme.textMuted : Theme.text
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.fontSize

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (modelData.audio) modelData.audio.muted = !modelData.audio.muted
                                }
                            }

                            ControlCenter.VolumeSlider {
                                width: parent.width * 0.7 - Theme.fontSize * 2 - parent.spacing * 2
                                anchors.verticalCenter: parent.verticalCenter
                                value: modelData.audio ? modelData.audio.volume : 0
                                onMoved: (v) => { if (modelData.audio) modelData.audio.volume = v; }
                            }
                        }
                    }
                }
            }
        }
    }
}
