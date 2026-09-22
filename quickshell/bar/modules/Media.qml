import QtQuick
import Quickshell.Services.Mpris
import "../../config"

// Now-playing title/artist for the first MPRIS player found. Collapses to
// zero width when nothing is playing, rather than showing an empty label.
//
// [bar_widgets.media]'s three options are all real, reusing MPRIS data
// this file (and control-center's MediaSection.qml, independently --
// same self-contained-per-module convention as Weather/Clock) already has
// access to: trackArtUrl for album_art_only (MediaSection.qml already
// renders it as an Image with a music_note fallback icon; this reuses that
// exact pattern), and hide_artist/artist_first just changing how the
// existing trackTitle/trackArtist strings get joined.
Item {
    id: root

    readonly property var cfg: Config.data.bar_widgets.media
    // Mpris.players is an UntypedObjectModel, not a plain array -- .values is
    // the real accessor (same pattern DesktopEntries.applications.values
    // already uses in Launcher.qml). The old Mpris.players.length/[0] here
    // silently evaluated to undefined/false, so this widget always read "no
    // player" regardless of any real MPRIS source -- a Phase 1 bug, not
    // something today's Stage 3 work introduced. Confirmed via quickshell's
    // own verbose Mpris debug logging, which showed its backend correctly
    // discovering and updating a real player the whole time; this was
    // purely a QML-side bug (same one fixed in NowPlayingCard.qml).
    readonly property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null

    // Material Symbols Outlined codepoints for "pause" / "play_arrow", from
    // Google's upstream codepoints file.
    readonly property string icon: root.player && root.player.isPlaying ? "" : ""

    readonly property string labelText: {
        if (!root.player)
            return "";
        var title = root.player.trackTitle || "";
        var artist = root.cfg.hide_artist ? "" : (root.player.trackArtist || "");
        if (!artist)
            return title;
        return root.cfg.artist_first ? (artist + " — " + title) : (title + " — " + artist);
    }

    readonly property bool hasArt: root.player && root.player.trackArtUrl !== ""

    implicitWidth: {
        if (!root.player)
            return 0;
        if (root.cfg.album_art_only)
            return Theme.fontSize * 1.6 + Theme.fontSize / 2;
        return Math.min(icon_.implicitWidth + label.implicitWidth + Theme.fontSize * 1.5, 260);
    }
    implicitHeight: parent ? parent.height : Theme.fontSize * 2
    visible: root.player !== null
    clip: true

    // Album Art Only: a small square thumbnail (or the same music_note
    // fallback MediaSection.qml uses when trackArtUrl is empty) in place
    // of the icon+text row entirely.
    Rectangle {
        anchors.centerIn: parent
        visible: root.cfg.album_art_only
        width: Theme.fontSize * 1.6
        height: Theme.fontSize * 1.6
        radius: Theme.radius / 2
        color: Theme.surfaceAlt
        clip: true

        Image {
            anchors.fill: parent
            visible: root.hasArt
            source: root.hasArt ? root.player.trackArtUrl : ""
            fillMode: Image.PreserveAspectCrop
        }

        Text {
            anchors.centerIn: parent
            visible: !root.hasArt
            text: "" // music_note
            color: Theme.textMuted
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.fontSize
        }
    }

    Row {
        anchors.centerIn: parent
        width: parent.width - Theme.fontSize
        visible: !root.cfg.album_art_only
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
            text: root.labelText
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
