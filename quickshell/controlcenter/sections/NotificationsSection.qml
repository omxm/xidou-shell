import QtQuick
import "../../config"
import "../../services"
import ".." as ControlCenter

// History list for services/Notifications.qml's `history` array -- that
// file's own header comment flagged itself as "the seam a future
// notification-center/history phase extends", this is that phase.
Item {
    id: root

    // Re-evaluates relative "time ago" text periodically rather than only
    // when history changes, so an entry doesn't freeze at "1m ago" forever.
    property int tick: 0
    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: root.tick++
    }

    function timeAgo(ms) {
        var diff = Math.max(0, Date.now() - ms) / 1000;
        if (diff < 60) return "Just now";
        if (diff < 3600) return Math.floor(diff / 60) + "m ago";
        if (diff < 86400) return Math.floor(diff / 3600) + "h ago";
        return Math.floor(diff / 86400) + "d ago";
    }

    ControlCenter.Card {
        anchors.fill: parent

        Column {
            anchors.fill: parent
            anchors.margins: Theme.fontSize
            spacing: Theme.fontSize / 2

            Item {
                width: parent.width
                height: Theme.fontSize * 1.6

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: Notifications.history.length + " notification" + (Notifications.history.length === 1 ? "" : "s")
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize * 0.9
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Notifications.history.length > 0
                    text: "Clear all"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize * 0.9

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifications.clearHistory()
                    }
                }
            }

            Text {
                visible: Notifications.history.length === 0
                text: "No notifications yet"
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            ListView {
                width: parent.width
                height: parent.height - Theme.fontSize * 2.1
                clip: true
                spacing: Theme.fontSize / 3
                model: Notifications.history

                delegate: Rectangle {
                    required property var modelData

                    width: ListView.view.width
                    height: bodyCol.implicitHeight + Theme.fontSize
                    radius: Theme.radius / 2
                    color: Theme.surfaceAlt
                    border.width: 1
                    border.color: Theme.border

                    Column {
                        id: bodyCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Theme.fontSize / 2
                        spacing: Theme.fontSize / 4

                        Item {
                            width: parent.width
                            height: Theme.fontSize * 1.1

                            Text {
                                anchors.left: parent.left
                                text: modelData.appName || "Notification"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize * 0.9
                                font.bold: true
                            }

                            Text {
                                anchors.right: parent.right
                                text: root.tick >= 0 ? root.timeAgo(modelData.time) : ""
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize * 0.75
                            }
                        }

                        Text {
                            width: parent.width
                            text: modelData.summary
                            visible: text.length > 0
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize * 0.85
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            width: parent.width
                            text: modelData.body
                            visible: text.length > 0
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize * 0.8
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
