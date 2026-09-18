pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Owns the org.freedesktop.Notifications DBus service and the shared
// "do not disturb" flag (Phase 4). NotificationPopups.qml reads `active` to
// render the stack; the bar's Dnd module and shell.qml's "notifications" IPC
// target both read/drive `dnd`. Nothing else should touch NotificationServer
// directly -- this is the one seam a future notification-center/history
// phase extends instead of reaching around it, and the show/dismiss
// mechanism here stays generic (not volume/brightness-specific, unlike
// OsdState) since more triggers are expected to land on top of it later.
Singleton {
    id: root

    property bool dnd: false

    // trackedNotifications doubles as "currently visible popups" for now --
    // there's no notification history/center yet (not in Phase 4's scope),
    // so a DND-suppressed notification is simply never tracked rather than
    // tracked-but-hidden.
    readonly property alias active: server.trackedNotifications

    function toggleDnd() {
        root.dnd = !root.dnd;
    }

    NotificationServer {
        id: server
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        actionsSupported: false
        actionIconsSupported: false
        imageSupported: false
        inlineReplySupported: false
        persistenceSupported: false

        onNotification: function (notification) {
            if (root.dnd)
                return;
            notification.tracked = true;
        }
    }
}
