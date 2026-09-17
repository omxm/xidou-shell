import QtQuick
import Quickshell
import "../../config"

Item {
    implicitWidth: label.implicitWidth + Theme.fontSize
    implicitHeight: parent ? parent.height : Theme.fontSize * 2

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: clock.date.toLocaleTimeString(Qt.locale(), "HH:mm")
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }
}
