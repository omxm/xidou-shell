import QtQuick
import Quickshell.Services.Pipewire
import "../../config"

// Default sink volume/mute, via Quickshell's Pipewire service. PwObjectTracker
// is required to keep the node's properties bound/updating — without it
// defaultAudioSink is just a static snapshot.
Item {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property int volumePercent: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0

    implicitWidth: label.implicitWidth + Theme.fontSize
    implicitHeight: parent ? parent.height : Theme.fontSize * 2

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.sink ? (root.muted ? "MUTE" : ("VOL " + root.volumePercent + "%")) : "VOL --"
        color: root.muted ? Theme.textMuted : Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.sink && root.sink.audio)
                root.sink.audio.muted = !root.sink.audio.muted;
        }
    }
}
