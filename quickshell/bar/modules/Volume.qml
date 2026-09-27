import QtQuick
import Quickshell.Services.Pipewire
import "../../config"

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

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            color: root.muted ? Theme.textMuted : (Config.data.bar.widgets.icon_color || Theme.text)
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.fontSize * Config.data.bar.layout.font_scale
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.sink ? (root.muted ? "" : (root.volumePercent + "%")) : "--"
            visible: root.cfg.show_percentage && text.length > 0
            color: root.muted ? Theme.textMuted : (Config.data.bar.widgets.color || Theme.text)
            font.family: (Config.data.bar.widgets.font_family || Theme.fontFamily)
            font.weight: Config.data.bar.widgets.font_weight === "bold" ? Font.Bold : (Config.data.bar.widgets.font_weight === "medium" ? Font.Medium : Font.Normal)
            font.pixelSize: Theme.fontSize * Config.data.bar.layout.font_scale
        }
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
