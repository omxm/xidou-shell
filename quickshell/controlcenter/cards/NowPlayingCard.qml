import QtQuick
import Quickshell.Services.Mpris
import "../../config"
import ".." as ControlCenter

// Larger now-playing display than the bar's compact Media.qml, but the same
// data source (Mpris.players[0] — there's no separate project-authored MPRIS
// service to share; Mpris itself is the shared singleton both already read).
ControlCenter.Card {
    id: root

    readonly property var player: Mpris.players.length > 0 ? Mpris.players[0] : null

    // Material Symbols Outlined codepoints: play_arrow / pause / skip_next / skip_previous.
    readonly property string playIcon: root.player && root.player.isPlaying ? "" : ""

    Column {
        anchors.fill: parent
        anchors.margins: Theme.fontSize
        spacing: Theme.fontSize / 2
        visible: root.player !== null

        Text {
            text: root.player ? (root.player.trackTitle || "Unknown title") : ""
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize * 1.1
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
        }

        Text {
            text: root.player ? (root.player.trackArtist || "") : ""
            visible: text.length > 0
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize * 0.9
            elide: Text.ElideRight
            width: parent.width
        }

        Row {
            spacing: Theme.fontSize
            topPadding: Theme.fontSize / 2

            Text {
                text: "" // skip_previous
                color: root.player && root.player.canGoPrevious ? Theme.text : Theme.textMuted
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.fontSize * 1.3

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.player && root.player.canGoPrevious) root.player.previous()
                }
            }

            Text {
                text: root.playIcon
                color: Theme.accent
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.fontSize * 1.3

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
                font.pixelSize: Theme.fontSize * 1.3

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.player && root.player.canGoNext) root.player.next()
                }
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
