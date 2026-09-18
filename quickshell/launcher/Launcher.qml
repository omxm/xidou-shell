import QtQuick
import Quickshell
import Quickshell.Io
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

    // PanelWindow.focusable (the documented, intended lever for asking the
    // platform for real X input focus) is set, but empirically does nothing
    // on this system's X11 backend — verified via XGetInputFocus staying on
    // the root window after showing the panel, with neither
    // Window.requestActivate() nor ProxyWindowBase's _backingWindow
    // producing any different result either. dwm itself is uninvolved: this
    // window is unmanaged (see the _NET_WM_WINDOW_TYPE_DOCK handling in
    // manage()), so dwm's focus()/setfocus()/unfocus() never target it
    // regardless. Falls back to explicitly forcing focus via a small
    // external helper (bin/xidou-focus-window) that does exactly what a
    // direct XSetInputFocus was confirmed to do reliably — find this
    // window by its size (PanelWindow has no title/id exposed to QML) and
    // force focus onto it.
    focusable: true

    Process {
        id: focusHelper
        command: ["xidou-focus-window", String(root.panelWidth), String(root.panelHeight)]
    }

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
            // Give the window a moment to actually map before trying to
            // focus it by title — xidou-focus-window can't find a window
            // that isn't on screen yet.
            focusHelperTimer.start();
        }
    }

    Timer {
        id: focusHelperTimer
        interval: 50
        onTriggered: {
            focusHelper.running = false;
            focusHelper.running = true;
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
