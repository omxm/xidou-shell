import QtQuick
import Quickshell
import "../config"
import "../services"
import "../lib"

// A tray item's own menu (ROADMAP M7), drawn in the shell's theme rather
// than as a Qt platform menu (which needs QApplication mode and Qt's widget
// style). It's a dock panel ("tray-menu" in PanelManager, "xidou-panel" to
// xidouwm), so xidouwm focuses it and anything done outside closes it, like
// every other panel. Opened by Tray.qml through TrayMenuState.
//
// Entries come from the app's dbusmenu (QsMenuOpener). A submenu replaces
// the list (with a Back row) instead of opening beside it. Keys: Up/Down,
// Return, Left or Escape to go back/close.
PanelWindow {
    id: root

    readonly property bool onTop: Config.data.bar.position !== "bottom"
    // Below the bar's reserved space, or below the bar itself when it
    // reserves none (auto-hide or Reserve Space off).
    readonly property bool barReserves: Config.data.bar.reserve_space && Config.data.bar.auto_hide === "off"
    readonly property real gap: Theme.fontSize / 3
    readonly property real edgeOffset: (root.barReserves ? 0 : Config.data.bar.layout.edge_margin + Config.data.bar.height) + root.gap
    readonly property real pad: Theme.fontSize / 3
    readonly property real rowHeight: Theme.fontSize * 2
    readonly property real separatorHeight: Theme.fontSize * 0.8

    // Submenus drill in: entries pushed here, the last one shown.
    property var stack: []
    readonly property var currentMenu: root.stack.length > 0 ? root.stack[root.stack.length - 1] : TrayMenuState.menu
    property int highlighted: -1

    QsMenuOpener {
        id: opener
        menu: root.currentMenu
    }
    readonly property var entries: opener.children ? opener.children.values : []

    function cleanLabel(text) {
        // dbusmenu mnemonics: "_File" -> "File", "__" -> "_".
        return String(text || "").replace(/__/g, "\u0000").replace(/_/g, "").replace(/\u0000/g, "_");
    }

    function selectable(entry) {
        return !!entry && !entry.isSeparator && entry.enabled;
    }

    function activate(entry) {
        if (!root.selectable(entry))
            return;
        if (entry.hasChildren) {
            SoundFx.play("option_select");
            root.stack = root.stack.concat([entry]);
            root.highlighted = -1;
            return;
        }
        entry.triggered();
        PanelManager.close("tray-menu");
    }

    function back() {
        if (root.stack.length > 0) {
            root.stack = root.stack.slice(0, -1);
            root.highlighted = -1;
        } else {
            PanelManager.close("tray-menu");
        }
    }

    function moveHighlight(delta) {
        var n = root.entries.length;
        for (var step = 1; step <= n; step++) {
            var i = ((root.highlighted < 0 && delta < 0 ? n : root.highlighted) + delta * step + n * 2) % n;
            if (root.selectable(root.entries[i])) {
                root.highlighted = i;
                SoundFx.play("launcher_move");
                return;
            }
        }
    }

    FontMetrics {
        id: metrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize * 0.9
    }

    // Widest label plus room for the check/radio column and the submenu
    // chevron.
    readonly property real contentWidth: {
        var widest = metrics.advanceWidth("Back");
        for (var i = 0; i < root.entries.length; i++)
            widest = Math.max(widest, metrics.advanceWidth(root.cleanLabel(root.entries[i].text)));
        return Math.max(Theme.fontSize * 10, widest + Theme.fontSize * 4);
    }

    visible: PanelManager.isOpen("tray-menu") && TrayMenuState.menu !== null
    screen: TrayMenuState.screen ? TrayMenuState.screen : Quickshell.screens[0]
    color: "transparent"
    focusable: true
    implicitWidth: root.contentWidth + root.pad * 2
    implicitHeight: menuColumn.implicitHeight + root.pad * 2

    anchors.top: root.onTop
    anchors.bottom: !root.onTop
    anchors.left: true
    margins.top: root.edgeOffset
    margins.bottom: root.edgeOffset
    margins.left: Math.max(0, Math.min(TrayMenuState.x - root.screen.x, root.screen.width - root.implicitWidth))

    DwmRole {
        title: "xidou-panel"
    }

    onVisibleChanged: {
        if (visible) {
            root.stack = [];
            root.highlighted = -1;
            keyHandler.forceActiveFocus();
        }
    }

    Connections {
        target: TrayMenuState
        function onMenuChanged() {
            root.stack = [];
            root.highlighted = -1;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius / 2
        color: Theme.surface
        border.width: 1
        border.color: Theme.border

        Item {
            id: keyHandler
            anchors.fill: parent
            focus: true

            Keys.onEscapePressed: root.back()
            Keys.onLeftPressed: root.back()
            Keys.onUpPressed: root.moveHighlight(-1)
            Keys.onDownPressed: root.moveHighlight(1)
            Keys.onRightPressed: {
                var entry = root.entries[root.highlighted];
                if (entry && entry.hasChildren)
                    root.activate(entry);
            }
            Keys.onReturnPressed: root.activate(root.entries[root.highlighted])
            Keys.onEnterPressed: root.activate(root.entries[root.highlighted])
        }

        Column {
            id: menuColumn
            x: root.pad
            y: root.pad
            width: root.contentWidth

            // Back row, inside a submenu.
            Rectangle {
                visible: root.stack.length > 0
                width: parent.width
                height: visible ? root.rowHeight : 0
                radius: Theme.radius / 3
                color: backHover.hovered ? Theme.surfaceAlt : "transparent"

                HoverHandler {
                    id: backHover
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.fontSize / 2
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.fontSize / 3

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "" // chevron_left (verified via fontTools)
                        color: Theme.textMuted
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Back"
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize * 0.9
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.back()
                }
            }

            Repeater {
                model: root.entries

                delegate: Item {
                    id: entryRow
                    required property var modelData
                    required property int index

                    width: menuColumn.width
                    height: modelData.isSeparator ? root.separatorHeight : root.rowHeight

                    Rectangle {
                        visible: entryRow.modelData.isSeparator
                        anchors.verticalCenter: parent.verticalCenter
                        x: Theme.fontSize / 2
                        width: parent.width - Theme.fontSize
                        height: 1
                        color: Theme.border
                    }

                    Rectangle {
                        visible: !entryRow.modelData.isSeparator
                        anchors.fill: parent
                        radius: Theme.radius / 3
                        color: root.highlighted === entryRow.index && root.selectable(entryRow.modelData) ? Theme.surfaceAlt : "transparent"

                        // Check/radio column: a check for a checked
                        // checkbox, a filled dot for a selected radio.
                        Text {
                            id: indicator
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.fontSize / 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.fontSize * 1.2
                            visible: entryRow.modelData.buttonType !== 0 && entryRow.modelData.checkState === Qt.Checked
                            text: entryRow.modelData.buttonType === 2 ? "●" : "" // ● / check (verified via fontTools)
                            color: Theme.accent
                            font.family: entryRow.modelData.buttonType === 2 ? Theme.fontFamily : Theme.iconFontFamily
                            font.pixelSize: entryRow.modelData.buttonType === 2 ? Theme.fontSize * 0.6 : Theme.fontSize
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.fontSize * 2
                            anchors.right: chevron.left
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: root.cleanLabel(entryRow.modelData.text)
                            color: entryRow.modelData.enabled ? Theme.text : Theme.textMuted
                            opacity: entryRow.modelData.enabled ? 1 : 0.6
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize * 0.9
                        }

                        Text {
                            id: chevron
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.fontSize / 3
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.fontSize * 1.2
                            visible: entryRow.modelData.hasChildren
                            text: "" // chevron_right (verified via fontTools)
                            color: Theme.textMuted
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.fontSize
                        }
                    }

                    HoverHandler {
                        enabled: root.selectable(entryRow.modelData)
                        onHoveredChanged: {
                            if (hovered)
                                root.highlighted = entryRow.index;
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.selectable(entryRow.modelData)
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activate(entryRow.modelData)
                    }
                }
            }
        }
    }
}
