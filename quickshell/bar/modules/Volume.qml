import QtQuick
import Quickshell.Services.Pipewire
import "../../config"
import "../widgets"

// Default sink volume/mute, via Quickshell's Pipewire service. PwObjectTracker
// is required to keep the node's properties bound/updating — without it
// defaultAudioSink is just a static snapshot.
Item {
    id: root

    readonly property var cfg: Config.data.bar_widgets.volume
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property int volumePercent: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0

    // Material Symbols Outlined codepoints for "volume_up" / "volume_off",
    // from Google's upstream codepoints file.
    readonly property string icon: root.muted ? "" : ""

    implicitWidth: row.implicitWidth + Theme.fontSize
    implicitHeight: parent ? parent.height : Theme.fontSize * 2

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.fontSize / 4

        BarIcon {
            text: root.icon
            stateColor: root.muted ? Theme.textMuted : undefined
        }

        BarLabel {
            text: root.sink ? (root.muted ? "" : (root.volumePercent + "%")) : "--"
            visible: root.cfg.show_percentage && text.length > 0
            stateColor: root.muted ? Theme.textMuted : undefined
        }
    }

    // Tooltip slot for Bar.qml's widget wrapper (ROADMAP F5).
    readonly property string tooltip: root.sink
        ? ((root.sink.description || root.sink.name || "Output") + " · " + (root.muted ? "muted" : root.volumePercent + "%"))
        : ""
}
