import QtQuick
import Quickshell
import Quickshell.Io
import "../config"
import "../services"
import "sections"

// Control-center ("Home") panel: toggled by `xidou msg panel-toggle
// control-center` (dwm's super+e bind, dwm/config.h) or a right-click on the
// bar's dead zone (Bar.qml), via PanelManager.isOpen() — which also ensures
// opening this closes any other dock panel (Launcher, etc.) instead of
// leaving both stacked.
//
// Deliberately NOT a Noctalia clone: real Noctalia renders these as
// edge-docked windows with concave corners against the screen edge. This
// renders as a centered floating overlay instead — same window type, same
// centering approach, same corner style as Launcher.qml, just larger.
PanelWindow {
    id: root

    readonly property var cfg: Config.data.panels.control_center
    readonly property int panelWidth: 820
    readonly property int panelHeight: 560
    readonly property int barReservedHeight: (Config.data.bar.position !== "bottom") ? Config.data.bar.height : 0

    readonly property var sections: [
        "Home", "Media", "Audio", "System", "Power", "Network",
        "Bluetooth", "Weather", "Calendar", "Notifications", "Screen Time"
    ]
    property int selectedIndex: 0

    visible: PanelManager.isOpen("control-center") && root.cfg.enabled
    implicitWidth: panelWidth
    implicitHeight: panelHeight
    color: "transparent"

    // Same X-focus workaround as Launcher.qml (PanelWindow.focusable does
    // nothing on this X11 backend — see that file's header comment for the
    // full investigation) — xidou-focus-window matches by size, so passing
    // this panel's own width/height is all that's needed to reuse it here.
    focusable: true

    Process {
        id: focusHelper
        command: ["xidou-focus-window", String(root.panelWidth), String(root.panelHeight)]
    }

    Timer {
        id: focusHelperTimer
        interval: 50
        onTriggered: {
            focusHelper.running = false;
            focusHelper.running = true;
        }
    }

    anchors.top: true
    anchors.left: true
    margins.top: Math.round((screen.height - barReservedHeight - panelHeight) / 2)
    margins.left: Math.round((screen.width - panelWidth) / 2)

    onVisibleChanged: {
        if (visible) {
            selectedIndex = 0;
            keyHandler.forceActiveFocus();
            focusHelperTimer.start();
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.surface
        border.width: 1
        border.color: Theme.border

        // Holds keyboard focus for the whole panel — there's no single text
        // field to anchor it to the way Launcher.qml has its search box,
        // since Home/Audio are read/click driven, not typed into.
        Item {
            id: keyHandler
            anchors.fill: parent
            focus: true

            Keys.onEscapePressed: PanelManager.close("control-center")
            Keys.onTabPressed: root.selectedIndex = (root.selectedIndex + 1) % root.sections.length
            // Up/Down cycle sections the same way Tab does, alongside it
            // (not replacing it) — same wraparound math as dwm's own
            // cycletag(), computed directly rather than tracking "visited"
            // sections.
            Keys.onDownPressed: root.selectedIndex = (root.selectedIndex + 1) % root.sections.length
            Keys.onUpPressed: root.selectedIndex = (root.selectedIndex - 1 + root.sections.length) % root.sections.length

            Row {
                anchors.fill: parent
                anchors.margins: Theme.fontSize
                spacing: Theme.fontSize

                Sidebar {
                    id: sidebar
                    width: parent.width * 0.2
                    height: parent.height
                    sections: root.sections
                    selectedIndex: root.selectedIndex
                    onSectionClicked: (index) => root.selectedIndex = index
                }

                Item {
                    width: parent.width - sidebar.width - parent.spacing
                    height: parent.height

                    HomeSection {
                        anchors.fill: parent
                        visible: root.selectedIndex === 0
                    }

                    AudioSection {
                        anchors.fill: parent
                        visible: root.selectedIndex === 2
                    }

                    PlaceholderSection {
                        anchors.fill: parent
                        visible: root.selectedIndex !== 0 && root.selectedIndex !== 2
                        sectionName: root.sections[root.selectedIndex]
                    }
                }
            }
        }
    }
}
