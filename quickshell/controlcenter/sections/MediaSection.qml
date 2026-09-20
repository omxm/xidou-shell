import QtQuick
import Quickshell.Services.Mpris
import "../../config"
import ".." as ControlCenter

// Fuller player view than Home's compact NowPlayingCard: album art, seek bar,
// per-player volume, shuffle/loop, and a player switcher when more than one
// MPRIS source is active. Same Mpris.players singleton every other Mpris
// consumer in this repo already reads (bar's Media.qml, shell.qml's mpris
// IpcHandler, Home's NowPlayingCard) — there is no separate service to share.
Item {
    id: root

    property int selectedPlayerIndex: 0
    readonly property var players: Mpris.players ? Mpris.players.values : []
    readonly property var player: root.players.length > root.selectedPlayerIndex ? root.players[root.selectedPlayerIndex] : null

    onPlayersChanged: {
        if (root.selectedPlayerIndex >= root.players.length)
            root.selectedPlayerIndex = 0;
    }

    ControlCenter.Card {
        anchors.fill: parent
        visible: root.player !== null

        Column {
            anchors.fill: parent
            anchors.margins: Theme.fontSize
            spacing: Theme.fontSize / 2

            Row {
                width: parent.width
                spacing: Theme.fontSize / 3
                visible: root.players.length > 1

                Repeater {
                    model: root.players
                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: Math.min(120, nameText.implicitWidth + Theme.fontSize)
                        height: Theme.fontSize * 1.6
                        radius: height / 2
                        color: index === root.selectedPlayerIndex ? Theme.accent : Theme.surfaceAlt
                        border.width: 1
                        border.color: Theme.border

                        Text {
                            id: nameText
                            anchors.centerIn: parent
                            text: modelData.identity || "Player"
                            color: index === root.selectedPlayerIndex ? Theme.background : Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize * 0.8
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectedPlayerIndex = index
                        }
                    }
                }
            }

            Row {
                width: parent.width
                height: Theme.fontSize * 6
                spacing: Theme.fontSize

                Rectangle {
                    width: height
                    height: parent.height
                    radius: Theme.radius / 2
                    color: Theme.surfaceAlt
                    border.width: 1
                    border.color: Theme.border
                    clip: true

                    Image {
                        anchors.fill: parent
                        visible: root.player && root.player.trackArtUrl
                        source: root.player ? root.player.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !root.player || !root.player.trackArtUrl
                        text: "" // music_note
                        color: Theme.textMuted
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.fontSize * 2
                    }
                }

                Column {
                    width: parent.width - parent.height - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.fontSize / 4

                    Text {
                        width: parent.width
                        text: root.player ? (root.player.trackTitle || "Unknown title") : ""
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize * 1.2
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: root.player ? (root.player.trackArtist || "") : ""
                        visible: text.length > 0
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize * 0.95
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: root.player ? (root.player.trackAlbum || "") : ""
                        visible: text.length > 0
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize * 0.85
                        elide: Text.ElideRight
                    }
                }
            }

            ControlCenter.VolumeSlider {
                width: parent.width
                visible: root.player && root.player.positionSupported && root.player.length > 0
                value: root.player && root.player.length > 0 ? root.player.position / root.player.length : 0
                onMoved: (v) => { if (root.player) root.player.position = v * root.player.length; }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.fontSize * 1.5
                topPadding: Theme.fontSize / 4

                Text {
                    text: "" // shuffle
                    color: root.player && root.player.shuffle ? Theme.accent : Theme.textMuted
                    visible: root.player && root.player.shuffleSupported
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fontSize * 1.2
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.player.shuffle = !root.player.shuffle
                    }
                }

                Text {
                    text: "" // skip_previous
                    color: root.player && root.player.canGoPrevious ? Theme.text : Theme.textMuted
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fontSize * 1.4
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.player && root.player.canGoPrevious) root.player.previous()
                    }
                }

                Text {
                    text: root.player && root.player.isPlaying ? "" : ""
                    color: Theme.accent
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fontSize * 1.8
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.player && root.player.canTogglePlaying) root.player.togglePlaying()
                    }
                }

                Text {
                    text: "" // skip_next
                    color: root.player && root.player.canGoNext ? Theme.text : Theme.textMuted
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fontSize * 1.4
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.player && root.player.canGoNext) root.player.next()
                    }
                }

                Text {
                    text: "" // repeat
                    color: root.player && root.player.loopState !== MprisLoopState.None ? Theme.accent : Theme.textMuted
                    visible: root.player && root.player.loopSupported
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fontSize * 1.2
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.player.loopState = root.player.loopState === MprisLoopState.None
                                ? MprisLoopState.Playlist : MprisLoopState.None;
                        }
                    }
                }
            }

            ControlCenter.VolumeSlider {
                width: parent.width * 0.5
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.player && root.player.volumeSupported
                value: root.player ? root.player.volume : 0
                onMoved: (v) => { if (root.player) root.player.volume = v; }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.player === null
        text: "Nothing playing"
        color: Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }
}
