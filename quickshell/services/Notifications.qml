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

    // trackedNotifications doubles as "currently visible popups" -- a
    // DND-suppressed notification is simply never tracked rather than
    // tracked-but-hidden.
    readonly property alias active: server.trackedNotifications

    // Phase 5's Notifications tab is the history/center this file's own
    // comment used to flag as a future extension point -- plain {summary,
    // body, appName, urgency, time} objects, not live Notification
    // references, since those get destroyed once dismissed/expired and
    // history needs to survive that. Capped so it can't grow unbounded
    // over a long session.
    readonly property int historyLimit: 50
    property var history: []

    function toggleDnd() {
        root.dnd = !root.dnd;
    }

    function clearHistory() {
        if (root.history.length > 0)
            SoundFx.play("notify_clear");
        root.history = [];
    }

    // Section 7: critical -> warning, a message (`category` hint
    // im.received) -> receive, low urgency -> info (off by default),
    // everything else -> notification.
    function soundFor(notification) {
        if (notification.urgency === NotificationUrgency.Critical)
            return "notify_critical";
        var hints = notification.hints || {};
        if (hints.category === "im.received")
            return "notify_message";
        if (notification.urgency === NotificationUrgency.Low)
            return "notify_low";
        return "notify";
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
            var entry = {
                summary: notification.summary || "",
                body: notification.body || "",
                appName: notification.appName || "",
                urgency: notification.urgency,
                time: Date.now()
            };
            root.history = [entry].concat(root.history).slice(0, root.historyLimit);

            // SoundFx silences these incoming sounds under DND itself
            // (SoundMap's `incoming`), so no DND check here.
            SoundFx.play(root.soundFor(notification));

            if (root.dnd)
                return;
            notification.tracked = true;
        }
    }
}
