import QtQuick
import "../config"

// One notification popup card (Phase 4). Visual structure -- bell icon,
// title/body, X dismiss top-right, app-name label bottom-right, a thin
// auto-dismiss progress line -- matches the real Noctalia screenshots はる
// shared, for visual reference only per CLAUDE.md (not copied code; there
// is no Noctalia source here). Styled entirely off Theme.qml tokens.
Item {
    id: root

    required property var notification

    // expireTimeout is spec'd as: <0 means "let the server decide", 0 means
    // "never auto-expire", >0 is an explicit sender-requested timeout in ms.
    readonly property bool autoExpire: root.notification.expireTimeout !== 0
    readonly property int timeoutMs: root.notification.expireTimeout > 0
        ? root.notification.expireTimeout
        : Config.data.notification.timeout_ms

    // Drives the progress-fill width as a 1.0 -> 0.0 fraction rather than
    // animating a pixel width directly -- animating "on width" from
    // progressTrack.width raced the layout pass (progressTrack.width could
    // still be 0 when the animation's `from` was evaluated at creation),
    // which silently collapsed the fill to permanently-invisible instead of
    // counting down.
    property real remaining: 1.0

    NumberAnimation {
        target: root
        property: "remaining"
        from: 1.0
        to: 0.0
        duration: root.timeoutMs
        easing.type: Easing.Linear
        running: root.autoExpire
    }

    implicitHeight: card.implicitHeight

    readonly property real progressGap: Theme.fontSize * 0.4
    readonly property real progressHeight: 2

    Rectangle {
        id: card
        width: parent.width
        implicitHeight: content.implicitHeight + Theme.fontSize * 1.2 + root.progressGap + root.progressHeight
        radius: Theme.radius
        color: Theme.surface
        border.width: 1
        border.color: Theme.border

        Column {
            id: content
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Theme.fontSize * 0.6
            spacing: Theme.fontSize * 0.3

            Item {
                width: parent.width
                height: Math.max(bellIcon.implicitHeight, closeIcon.implicitHeight, summaryText.implicitHeight)

                Text {
                    id: bellIcon
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "" // Material Symbols "notifications"
                    color: Theme.accent
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fontSize * 1.3
                }

                Text {
                    id: summaryText
                    anchors.left: bellIcon.right
                    anchors.leftMargin: Theme.fontSize * 0.5
                    anchors.right: closeIcon.left
                    anchors.rightMargin: Theme.fontSize * 0.5
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.notification.summary
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    id: closeIcon
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "" // Material Symbols "close"
                    color: closeArea.containsMouse ? Theme.text : Theme.textMuted
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fontSize

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        anchors.margins: -Theme.fontSize * 0.4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.notification.dismiss()
                    }
                }
            }

            Text {
                width: parent.width
                text: root.notification.body
                visible: text.length > 0
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 0.9
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignRight
                text: root.notification.appName
                visible: text.length > 0
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 0.75
            }
        }

        // Inset from the card's own rounded+clipped edges rather than flush
        // against them -- a sharp-cornered rectangle butted right up against
        // a rounded, clipped parent leaves an anti-aliasing sliver where the
        // clip mask doesn't quite match the child's square corner, showing
        // the transparent window background (near-black) through the gap.
        Rectangle {
            id: progressTrack
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: Theme.fontSize * 0.6
            anchors.rightMargin: Theme.fontSize * 0.6
            anchors.bottomMargin: root.progressGap
            height: root.progressHeight
            radius: height / 2
            color: Theme.surfaceAlt
            visible: root.autoExpire

            Rectangle {
                id: progressFill
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * root.remaining
                radius: parent.radius
                color: Theme.accent
            }
        }
    }

    Timer {
        interval: root.timeoutMs
        running: root.autoExpire
        onTriggered: root.notification.expire()
    }
}
