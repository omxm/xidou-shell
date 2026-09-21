import QtQuick
import Quickshell
import "../config"
import "../services"

// Static full-desktop backdrop shown while `slop` runs on top during a
// frozen region selection (Screenshot.freezeDuringSelection). This window
// has no interactivity of its own -- slop is a separate X window that grabs
// the pointer directly; this just keeps a still frame visible underneath it
// so what the user drags over can't change mid-selection. See
// Screenshot.qml's cropBackdrop()/startFrozenSelection() for the rest of
// the flow.
PanelWindow {
    id: root

    visible: Screenshot.backdropVisible
    color: Theme.background

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    Image {
        anchors.fill: parent
        // Each capture uses a fresh timestamped path (see Screenshot.qml),
        // so a plain source binding is enough -- no cache-busting needed
        // since the URL itself always changes.
        source: Screenshot.backdropImagePath ? "file://" + Screenshot.backdropImagePath : ""
        fillMode: Image.Stretch
        cache: false
        asynchronous: true
    }
}
