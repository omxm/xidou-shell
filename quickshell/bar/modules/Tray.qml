import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../../config"
import "../widgets"
import "../../services"

// StatusNotifierItem tray icons, via Quickshell's built-in SystemTray
// service (owns the org.kde.StatusNotifierWatcher registration itself —
// no separate tray daemon needed).
//
// Clicks (ROADMAP M7): left activates (or opens the menu for a menu-only
// item), right opens the item's own menu when it has one (mozc, blueman
// and most apps put everything there) and secondary-activates otherwise,
// middle secondary-activates. The menu is the app's dbusmenu, drawn by
// bar/TrayMenu.qml under the icon.
//
// Drawer (M7): [bar_widgets.tray] drawer lists item ids that sit behind a
// chevron, hidden lists ids never shown; everything else shows as before.
// The chevron opens/closes the drawer for this session; drawer_open is how
// it starts. Ids and the three states are set in the Tray gear panel.
Item {
    id: root

    readonly property var cfg: Config.data.bar_widgets.tray
    readonly property int iconSize: root.cfg.icon_size > 0 ? root.cfg.icon_size : (Theme.fontSize + 4)

    readonly property var items: SystemTray.items.values
    readonly property var shownItems: root.items.filter(function (item) {
        return root.cfg.drawer.indexOf(item.id) === -1 && root.cfg.hidden.indexOf(item.id) === -1;
    })
    readonly property var drawerItems: root.items.filter(function (item) {
        return root.cfg.drawer.indexOf(item.id) !== -1 && root.cfg.hidden.indexOf(item.id) === -1;
    })

    property bool drawerOpen: root.cfg.drawer_open

    implicitWidth: row.implicitWidth
    implicitHeight: parent ? parent.height : Theme.fontSize * 2

    // bar/TrayMenu.qml shows it, under the icon.
    function showMenu(icon) {
        TrayMenuState.toggle(icon.modelData.menu, icon.QsWindow.window.screen, icon.mapToGlobal(0, 0).x);
    }

    Component {
        id: trayIconComponent

        IconImage {
            id: trayIcon
            required property var modelData

            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            implicitSize: root.iconSize
            source: modelData.icon

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: mouse => {
                    var item = trayIcon.modelData;
                    if (mouse.button === Qt.LeftButton) {
                        if (item.onlyMenu && item.hasMenu)
                            root.showMenu(trayIcon);
                        else
                            item.activate();
                    } else if (mouse.button === Qt.RightButton) {
                        if (item.hasMenu)
                            root.showMenu(trayIcon);
                        else
                            item.secondaryActivate();
                    } else {
                        item.secondaryActivate();
                    }
                }
            }
        }
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.fontSize / 2

        // The chevron sits on the drawer's outer side, pointing the way it
        // opens.
        BarIcon {
            visible: root.drawerItems.length > 0
            text: root.drawerOpen ? "" : "" // chevron_right / chevron_left (verified via fontTools)
            stateColor: Theme.textMuted

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    SoundFx.play(root.drawerOpen ? "panel_close" : "panel_open");
                    root.drawerOpen = !root.drawerOpen;
                }
            }
        }

        Repeater {
            model: root.drawerOpen ? root.drawerItems : []
            delegate: trayIconComponent
        }

        Repeater {
            model: root.shownItems
            delegate: trayIconComponent
        }
    }
}
