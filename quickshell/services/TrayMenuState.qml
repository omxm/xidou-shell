pragma Singleton

import QtQuick
import Quickshell

// Which tray item's menu is showing (ROADMAP M7). Tray.qml sets it on a
// click; bar/TrayMenu.qml shows it as the "tray-menu" dock panel, so it
// gets the same focus, outside-click closing and lock refusal as every
// other panel (PanelManager, xidouwm's "xidou-panel" role).
Singleton {
    id: root

    property var menu: null   // the item's QsMenuHandle
    property var screen: null // the ShellScreen the clicked bar is on
    property real x: 0        // the icon's left edge, global coordinates

    // A second click on the same item closes its menu; a click on another
    // item switches to that one.
    function toggle(menu, screen, x) {
        if (PanelManager.isOpen("tray-menu") && root.menu === menu) {
            PanelManager.close("tray-menu");
            return;
        }
        root.menu = menu;
        root.screen = screen;
        root.x = x;
        PanelManager.open("tray-menu");
    }
}
