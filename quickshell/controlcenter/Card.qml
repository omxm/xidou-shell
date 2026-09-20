import QtQuick
import "../config"

// Shared rounded-card wrapper — the same outer Rectangle (radius/color/border)
// that Osd.qml, NotificationCard.qml, and Launcher.qml each already reimplement
// ad hoc. Factored out here because this panel alone uses it 6+ times across
// Home and Audio, not as a speculative abstraction.
Rectangle {
    radius: Theme.radius
    color: Theme.surface
    border.width: 1
    border.color: Theme.border
}
