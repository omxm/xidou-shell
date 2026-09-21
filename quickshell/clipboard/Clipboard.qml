import QtQuick
import Quickshell
import Quickshell.Io
import "../config"
import "../services"

// Clipboard history: toggled by `xidou msg panel-toggle clipboard` (dwm's
// super+v bind, see dwm/config.h's clipboardtogglecmd) via PanelManager,
// same centered-floating window pattern as Launcher.qml/ScreenshotConfirm.qml.
// Selecting an entry restores it to the live CLIPBOARD selection
// (ClipboardHistory.copy()) rather than auto-typing it -- same as
// clipmenu/CopyQ, the next Ctrl+V anywhere picks it up.
//
// No search box (CLAUDE.md's "smallest first" phasing) -- just the
// recent-entries list, same minimal shape as ScreenshotConfirm.qml. Add
// filtering later if the plain list turns out not to be enough.
PanelWindow {
    id: root

    readonly property var cfg: Config.data.panels.clipboard
    readonly property int panelWidth: 420
    readonly property int panelHeight: 480
    readonly property int barReservedHeight: (Config.data.bar.position !== "bottom") ? Config.data.bar.height : 0

    visible: PanelManager.isOpen("clipboard") && root.cfg.enabled
    implicitWidth: panelWidth
    implicitHeight: panelHeight
    color: "transparent"

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

    property int selectedIndex: 0

    onVisibleChanged: {
        if (visible) {
            root.selectedIndex = 0;
            keyHandler.forceActiveFocus();
            focusHelperTimer.start();
        }
    }

    function selectEntryAt(index) {
        if (index < 0 || index >= ClipboardHistory.entries.length)
            return;
        ClipboardHistory.copy(index);
        PanelManager.close("clipboard");
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.surface
        border.width: 1
        border.color: Theme.border

        Item {
            id: keyHandler
            anchors.fill: parent
            focus: true

            Keys.onEscapePressed: PanelManager.close("clipboard")
            Keys.onReturnPressed: root.selectEntryAt(root.selectedIndex)
            Keys.onEnterPressed: root.selectEntryAt(root.selectedIndex)
            Keys.onDownPressed: {
                if (root.selectedIndex < ClipboardHistory.entries.length - 1)
                    root.selectedIndex++;
            }
            Keys.onUpPressed: {
                if (root.selectedIndex > 0)
                    root.selectedIndex--;
            }

            ListView {
                id: resultsList
                anchors.fill: parent
                anchors.margins: Theme.fontSize
                clip: true
                spacing: Theme.fontSize / 4
                model: ClipboardHistory.entries
                currentIndex: root.selectedIndex

                Text {
                    anchors.centerIn: parent
                    visible: resultsList.count === 0
                    text: "No clipboard history yet"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                delegate: Rectangle {
                    id: delegateRoot
                    required property var modelData
                    required property int index

                    width: resultsList.width
                    height: delegateRoot.modelData.type === "image" ? Theme.fontSize * 4.5 : Theme.fontSize * 2.2
                    radius: Theme.radius / 2
                    color: index === root.selectedIndex ? Theme.accent : Theme.surfaceAlt

                    // Text entries are read lazily per-delegate rather than
                    // pre-loaded into ClipboardHistory.entries -- the
                    // manifest only carries type+timestamp (see
                    // ClipboardHistory.qml), so a preview needs its own
                    // small reactive read of the backing file, same pattern
                    // Config.qml uses for a single central file.
                    FileView {
                        id: textPreview
                        path: delegateRoot.modelData.type === "text" ? delegateRoot.modelData.path : ""
                        printErrors: false
                    }

                    Row {
                        anchors.fill: parent
                        anchors.margins: Theme.fontSize / 3
                        spacing: Theme.fontSize / 2

                        Image {
                            id: thumb
                            visible: delegateRoot.modelData.type === "image"
                            width: visible ? height : 0
                            height: parent.height
                            source: visible ? "file://" + delegateRoot.modelData.path : ""
                            fillMode: Image.PreserveAspectFit
                            cache: false
                            asynchronous: true
                        }

                        Text {
                            width: parent.width - (thumb.visible ? thumb.width + parent.spacing : 0)
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            text: delegateRoot.modelData.type === "image" ? "[image]" : textPreview.text().replace(/\s+/g, " ")
                            color: index === root.selectedIndex ? Theme.background : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedIndex = delegateRoot.index;
                            root.selectEntryAt(delegateRoot.index);
                        }
                    }
                }
            }
        }
    }
}
