import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../../config"
import "../../services"

// Tag/workspace switcher, driven by real dwm state over DwmIpc (dwm-ipc via
// dwm-msg) rather than mock data. Tags are switched by explicit bit mask
// (dwm's `view` ipc command), never by a next/prev abstraction — see the
// dwm tag-cycling lesson in CLAUDE.md.
//
// [bar_widgets.workspaces] adds three real options on top of that: hiding
// empty tags, a 3-way Style preset (regular/minimal/focus_hint), and
// Show Icons (only visible in practice under focus_hint, which is the only
// style with an icon slot at all).
//
// focus_hint's icon needs the focused window's app icon, which dwm-ipc
// itself cannot provide -- confirmed against its real source (dwm/ipc.c,
// dwm/yajl_dumps.c): get_dwm_client exposes window title and a tags
// bitmask, but no WM_CLASS or PID anywhere. The real fix, verified
// empirically against a live window: shell out to `xdotool
// getwindowclassname <id>` (same "shell out to a real tool" convention as
// date/maim/xclip elsewhere), then match that against DesktopEntries the
// same three ways real WM-integration tools do, most-specific first:
// startupClass (StartupWMClass=, the dedicated field for exactly this),
// then id (the .desktop file's own basename), then icon (Icon= happening
// to equal the WM_CLASS, which is common but not guaranteed -- confirmed
// true for cmake-gui specifically while testing this).
Item {
    id: root

    property int monitorNum: 0

    readonly property var cfg: Config.data.bar_widgets.workspaces
    readonly property var tagState: DwmIpc.tagStateFor(monitorNum)
    readonly property int selectedMask: tagState ? tagState.selected : 0
    readonly property int occupiedMask: tagState ? tagState.occupied : 0
    readonly property int urgentMask: tagState ? tagState.urgent : 0

    readonly property var visibleTags: {
        if (!root.cfg.hide_when_empty)
            return DwmIpc.tags;
        return DwmIpc.tags.filter(function (t) {
            return (root.occupiedMask & t.bitMask) !== 0 || (root.selectedMask & t.bitMask) !== 0;
        });
    }

    // --- Focus Hint's icon resolution (only ever runs for this monitor's
    // currently-focused window, only when it could actually be shown) ---

    readonly property int focusedWinId: DwmIpc.focusedWinIdByMonitor[root.monitorNum] || 0
    readonly property bool wantsIcon: root.cfg.style === "focus_hint" && root.cfg.show_icons
    property string focusedWmClass: ""

    function refreshFocusedIcon() {
        if (!root.wantsIcon || root.focusedWinId <= 0) {
            root.focusedWmClass = "";
            return;
        }
        wmClassProc.command = ["xdotool", "getwindowclassname", String(root.focusedWinId)];
        wmClassProc.running = false;
        wmClassProc.running = true;
    }

    onFocusedWinIdChanged: root.refreshFocusedIcon()
    onWantsIconChanged: root.refreshFocusedIcon()

    Process {
        id: wmClassProc
        stdout: StdioCollector {
            onStreamFinished: root.focusedWmClass = text.trim()
        }
    }

    readonly property var matchedDesktopEntry: {
        if (!root.focusedWmClass)
            return null;
        var wc = root.focusedWmClass.toLowerCase();
        var list = DesktopEntries.applications.values;
        var i;
        for (i = 0; i < list.length; i++)
            if (list[i].startupClass && list[i].startupClass.toLowerCase() === wc)
                return list[i];
        for (i = 0; i < list.length; i++)
            if (list[i].id && list[i].id.toLowerCase().replace(/\.desktop$/, "") === wc)
                return list[i];
        for (i = 0; i < list.length; i++)
            if (list[i].icon && list[i].icon.toLowerCase() === wc)
                return list[i];
        return null;
    }

    readonly property string focusedIconSource: root.matchedDesktopEntry ? Quickshell.iconPath(root.matchedDesktopEntry.icon) : ""

    implicitWidth: row.implicitWidth
    implicitHeight: parent ? parent.height : Theme.fontSize * 2

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.cfg.style === "minimal" ? Theme.fontSize / 2 : 2

        Repeater {
            model: root.visibleTags

            Item {
                id: tagDelegate
                required property var modelData

                readonly property bool isSelected: (root.selectedMask & modelData.bitMask) !== 0
                readonly property bool isOccupied: (root.occupiedMask & modelData.bitMask) !== 0
                readonly property bool isUrgent: (root.urgentMask & modelData.bitMask) !== 0
                readonly property bool isDot: root.cfg.style === "focus_hint" && !isSelected

                readonly property real dotSize: Theme.fontSize * 0.4

                width: {
                    if (root.cfg.style === "minimal")
                        return minimalLabel.implicitWidth;
                    if (isDot)
                        return dotSize + Theme.fontSize / 2;
                    return pillLabel.implicitWidth + (pillIcon.visible ? pillIcon.width + Theme.fontSize / 4 : 0) + Theme.fontSize;
                }
                height: root.height > 0 ? root.height : Theme.fontSize * 1.8

                // regular/focus_hint's expanded pill share this background;
                // minimal never shows one, and a focus_hint dot draws its
                // own small circle below instead.
                Rectangle {
                    anchors.fill: parent
                    visible: root.cfg.style === "regular" || (root.cfg.style === "focus_hint" && !tagDelegate.isDot)
                    radius: Theme.radius / 2
                    color: tagDelegate.isSelected ? Theme.accent : (tagDelegate.isUrgent ? Theme.accent : "transparent")
                    border.width: tagDelegate.isOccupied && !tagDelegate.isSelected ? 1 : 0
                    border.color: Theme.border
                }

                Rectangle {
                    anchors.centerIn: parent
                    visible: tagDelegate.isDot
                    width: tagDelegate.dotSize
                    height: tagDelegate.dotSize
                    radius: width / 2
                    color: tagDelegate.isUrgent ? Theme.accent : (tagDelegate.isOccupied ? Theme.textMuted : Theme.border)
                }

                Text {
                    id: minimalLabel
                    anchors.centerIn: parent
                    visible: root.cfg.style === "minimal"
                    text: tagDelegate.modelData.name
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.bold: tagDelegate.isSelected
                    color: tagDelegate.isSelected ? Theme.accent : (tagDelegate.isUrgent ? Theme.accent : Theme.textMuted)
                }

                Row {
                    anchors.centerIn: parent
                    visible: (root.cfg.style === "regular") || (root.cfg.style === "focus_hint" && !tagDelegate.isDot)
                    spacing: Theme.fontSize / 4

                    IconImage {
                        id: pillIcon
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: Theme.fontSize * 1.1
                        visible: root.cfg.style === "focus_hint" && tagDelegate.isSelected && root.wantsIcon && root.focusedIconSource !== ""
                        source: root.focusedIconSource
                    }

                    Text {
                        id: pillLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: tagDelegate.modelData.name
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        color: tagDelegate.isSelected ? Theme.background : (tagDelegate.isUrgent ? Theme.background : Theme.textMuted)
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: DwmIpc.viewTag(tagDelegate.modelData.bitMask)
                }
            }
        }
    }
}
