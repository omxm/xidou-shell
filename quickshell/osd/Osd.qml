import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../config"
import "../services"

// Transient volume/brightness pop-up (Phase 3). Volume changes are observed
// passively via Pipewire's live sink state -- the same state Volume.qml's
// bar module already tracks -- so any source of a volume change (media
// keys, pavucontrol, etc.) shows the OSD, not just dwm's own wpctl
// keybinds. Brightness has no equivalent live signal to watch (plain sysfs
// writes don't notify listeners), so it's nudged explicitly: dwm's
// brightness keybinds run bin/xidou-brightness, which writes the new value
// then calls `xidou msg osd brightness` -- see shell.qml's "osd"
// IpcHandler and services/Brightness.qml's refreshAndShow().
//
// Not anchored to a screen edge (see Launcher.qml's comment on the same
// centering approach) -- margins are measured from the *available* area,
// so the bar's reserved height has to be subtracted before halving.
PanelWindow {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property int volumePercent: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0

    // Guards against showing the OSD the moment the default sink first
    // attaches at shell startup, which would otherwise fire a spurious
    // "volume changed" the instant volumePercent goes from its initial 0
    // to the sink's real level.
    property bool volumeReady: false

    onVolumePercentChanged: {
        if (root.volumeReady)
            OsdState.show("volume");
        root.volumeReady = true;
    }
    onMutedChanged: {
        if (root.volumeReady)
            OsdState.show("volume");
    }

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    readonly property int barReservedHeight: (Config.data.bar.position !== "bottom") ? Config.data.bar.height : 0
    readonly property int panelWidth: Config.data.osd.width
    readonly property int panelHeight: Config.data.osd.height

    visible: OsdState.visible
    implicitWidth: panelWidth
    implicitHeight: panelHeight
    color: "transparent"
    focusable: false

    anchors.top: true
    anchors.left: true
    margins.top: root.barReservedHeight + Theme.fontSize * 2
    margins.left: Math.round((screen.width - panelWidth) / 2)

    readonly property string icon: {
        if (OsdState.kind === "brightness")
            return "";
        return root.muted ? "" : "";
    }

    readonly property int percent: OsdState.kind === "brightness" ? Brightness.percent : root.volumePercent

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.surface
        border.width: 1
        border.color: Theme.border

        Row {
            anchors.fill: parent
            anchors.leftMargin: Theme.fontSize * 0.75
            anchors.rightMargin: Theme.fontSize * 0.75
            anchors.topMargin: Theme.fontSize * 0.3
            anchors.bottomMargin: Theme.fontSize * 0.3
            spacing: Theme.fontSize * 0.6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.icon
                color: Theme.text
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.fontSize * 1.4
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - parent.spacing - Theme.fontSize * 1.4
                spacing: Theme.fontSize * 0.3

                Rectangle {
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Theme.surfaceAlt

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(100, root.percent)) / 100
                        height: parent.height
                        radius: 3
                        color: Theme.accent

                        Behavior on width {
                            NumberAnimation { duration: 120 }
                        }
                    }
                }

                Text {
                    text: root.percent + "%"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize * 0.8
                }
            }
        }
    }
}
