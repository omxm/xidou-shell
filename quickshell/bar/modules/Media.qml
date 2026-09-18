import QtQuick
import Quickshell.Services.Mpris
import "../../config"

// Now-playing title/artist for the first MPRIS player found. Collapses to
// zero width when nothing is playing, rather than showing an empty label.
Item {
    id: root

    readonly property var player: Mpris.players.length > 0 ? Mpris.players[0] : null

    implicitWidth: root.player ? Math.min(label.implicitWidth + Theme.fontSize, 260) : 0
    implicitHeight: parent ? parent.height : Theme.fontSize * 2
    visible: root.player !== null
    clip: true

    Text {
        id: label
        anchors.centerIn: parent
        width: parent.width - Theme.fontSize
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: root.player
            ? (root.player.trackTitle || "") + (root.player.trackArtist ? " — " + root.player.trackArtist : "")
            : ""
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
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
