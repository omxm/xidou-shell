import QtQuick
import Quickshell.Services.Mpris
import "../../config"

// Now-playing title/artist for the first MPRIS player found. Collapses to
// zero width when nothing is playing, rather than showing an empty label.
Item {
    id: root

    readonly property var player: Mpris.players.length > 0 ? Mpris.players[0] : null

    // Material Symbols Outlined codepoints for "pause" / "play_arrow", from
    // Google's upstream codepoints file.
    readonly property string icon: root.player && root.player.isPlaying ? "" : ""

    implicitWidth: root.player ? Math.min(icon_.implicitWidth + label.implicitWidth + Theme.fontSize * 1.5, 260) : 0
    implicitHeight: parent ? parent.height : Theme.fontSize * 2
    visible: root.player !== null
    clip: true

    Row {
        anchors.centerIn: parent
        width: parent.width - Theme.fontSize
        spacing: Theme.fontSize / 4

        Text {
            id: icon_
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            color: Theme.text
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.fontSize
        }

        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - icon_.implicitWidth - parent.spacing
            elide: Text.ElideRight
            text: root.player
                ? (root.player.trackTitle || "") + (root.player.trackArtist ? " — " + root.player.trackArtist : "")
                : ""
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.player && root.player.canTogglePlaying)
                root.player.togglePlaying();
        }
    }
}
