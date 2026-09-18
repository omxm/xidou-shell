import QtQuick
import Quickshell
import "../config"
import "../services"
import "../lib/Position.js" as Position

// Stacked notification popups (Phase 4), fed by services/Notifications.qml's
// NotificationServer. Unlike Osd.qml (a fixed-size box), this window's
// height grows and shrinks with the number of active notifications -- "how
// many are showing" is inherently variable, only the card width is fixed.
// Position is config-driven ([notification].position/margin, default
// top-right) via the same Position.js resolver Osd.qml uses, kept apart
// from the OSD's default (top-center) so the two never visually collide.
PanelWindow {
    id: root

    readonly property var cfg: Config.data.notification

    readonly property var pos: Position.resolve(root.cfg.position, screen.width, root.cfg.width, root.cfg.margin)

    visible: repeater.count > 0
    implicitWidth: root.cfg.width
    implicitHeight: column.implicitHeight
    color: "transparent"
    focusable: false

    anchors.top: pos.anchorTop
    anchors.bottom: pos.anchorBottom
    anchors.left: pos.anchorLeft
    anchors.right: pos.anchorRight
    margins.top: pos.marginTop
    margins.bottom: pos.marginBottom
    margins.left: pos.marginLeft
    margins.right: pos.marginRight

    Column {
        id: column
        width: root.cfg.width
        spacing: root.cfg.spacing

        Repeater {
            id: repeater
            model: Notifications.active

            NotificationCard {
                required property var modelData
                width: column.width
                notification: modelData
            }
        }
    }
}
