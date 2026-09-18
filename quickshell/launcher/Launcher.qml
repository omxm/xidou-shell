import QtQuick
import Quickshell
import "../config"
import "../services"

// App launcher: toggled by `xidou msg panel-toggle launcher` (see
// dwm/config.h's super+d bind and bin/xidou), via PanelState.launcherVisible
// rather than dwm-ipc — this is shell UI state, not window-manager state.
// Not anchored to any screen edge (unlike Bar, which reserves strut space):
// PanelWindow has no native "centered floating window" concept since it's
// modeled on layer-shell's edge-anchoring, so centering is done by anchoring
// top+left with margins computed from the screen size.
//
// Quickshell positions anchored panels the same way a Wayland compositor
// positions layer-shell surfaces: margins are measured from the edge of the
// *available* area, not the raw screen — confirmed empirically (a
// margins.top of 204 on a 768px screen landed the window at y=236, exactly
// the bar's 32px exclusiveZone added on top). So centering has to subtract
// the bar's own reservation before halving, not the raw screen size, or
// Quickshell's automatic offset double-counts it. Only accounts for a
// top-positioned bar for now — CLAUDE.md's bar.position: "bottom" option
// would need the same treatment against the bottom anchor.
PanelWindow {
    id: root

    readonly property var cfg: Config.data.panels.launcher
    readonly property int panelWidth: 480
    readonly property int panelHeight: 360
    readonly property int barReservedHeight: (Config.data.bar.position !== "bottom") ? Config.data.bar.height : 0

    visible: PanelState.launcherVisible && root.cfg.enabled
    implicitWidth: panelWidth
    implicitHeight: panelHeight
    color: "transparent"

    anchors.top: true
    anchors.left: true
    margins.top: Math.round((screen.height - barReservedHeight - panelHeight) / 2)
    margins.left: Math.round((screen.width - panelWidth) / 2)

    // DesktopEntries only needs filtering, not re-fetching, so the model is
    // computed once here rather than re-queried per keystroke.
    readonly property var allApps: {
        var apps = [];
        var list = DesktopEntries.applications.values;
        for (var i = 0; i < list.length; i++) {
            if (!list[i].noDisplay)
                apps.push(list[i]);
        }
        apps.sort(function (a, b) { return a.name.localeCompare(b.name); });
        return apps;
    }

    readonly property var filteredApps: {
        var q = searchField.text.trim().toLowerCase();
        if (!q)
            return root.allApps;
        var out = [];
        for (var i = 0; i < root.allApps.length; i++) {
            if (root.allApps[i].name.toLowerCase().indexOf(q) !== -1)
                out.push(root.allApps[i]);
        }
        return out;
    }

    property int selectedIndex: 0

    onFilteredAppsChanged: selectedIndex = 0
    onVisibleChanged: {
        if (visible) {
            searchField.text = "";
            selectedIndex = 0;
            searchField.forceActiveFocus();
        }
    }

    function launchSelected() {
        if (selectedIndex >= 0 && selectedIndex < filteredApps.length) {
            filteredApps[selectedIndex].execute();
            PanelState.launcherVisible = false;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.surface
        border.width: 1
        border.color: Theme.border

        Column {
            anchors.fill: parent
            anchors.margins: Theme.fontSize
            spacing: Theme.fontSize / 2

            Rectangle {
                width: parent.width
                height: Theme.fontSize * 2.2
                radius: Theme.radius / 2
                color: Theme.surfaceAlt
                border.width: 1
                border.color: Theme.border

                TextInput {
                    id: searchField
                    anchors.fill: parent
                    anchors.margins: Theme.fontSize / 2
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    clip: true

                    Keys.onEscapePressed: PanelState.launcherVisible = false
                    Keys.onReturnPressed: root.launchSelected()
                    Keys.onEnterPressed: root.launchSelected()
                    Keys.onDownPressed: {
                        if (root.selectedIndex < root.filteredApps.length - 1)
                            root.selectedIndex++;
                    }
                    Keys.onUpPressed: {
                        if (root.selectedIndex > 0)
                            root.selectedIndex--;
                    }
                }
            }

            ListView {
                id: resultsList
                width: parent.width
                height: parent.height - parent.spacing - (Theme.fontSize * 2.2)
                clip: true
                model: root.filteredApps
                currentIndex: root.selectedIndex

                delegate: Rectangle {
                    id: delegateRoot
                    required property var modelData
                    required property int index

                    width: resultsList.width
                    height: Theme.fontSize * 2.2
                    radius: Theme.radius / 2
                    color: index === root.selectedIndex ? Theme.accent : "transparent"

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.fontSize / 2
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        text: delegateRoot.modelData.name
                        color: index === root.selectedIndex ? Theme.background : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedIndex = delegateRoot.index;
                            root.launchSelected();
                        }
                    }
                }
            }
        }
    }
}
