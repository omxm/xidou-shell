import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import "../config"
import "../services"

// Real PAM-authenticated lock screen, via Quickshell's own PamContext --
// there's no external X11 locker installed on this machine at all (checked:
// i3lock/slock/betterlockscreen/xsecurelock/physlock all absent), and
// building this natively is the same architecture Noctalia-style shells
// use for exactly this, matching Theme.qml instead of an unthemed external
// tool. Deliberately has no Escape-to-close or click-outside-to-dismiss
// path anywhere in this file -- the only way out is a correct password.
PanelWindow {
    id: root

    visible: SessionActions.locked
    color: Theme.background

    // Full-screen coverage, not a centered overlay like every other panel --
    // anchoring all four sides with no margins spans the whole monitor.
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    focusable: true

    Process {
        id: focusHelper
        command: ["xidou-focus-window", String(Math.round(root.width)), String(Math.round(root.height))]
    }

    Timer {
        id: retryTimer
        interval: 1000
        onTriggered: pam.start()
    }

    Timer {
        id: focusHelperTimer
        interval: 50
        onTriggered: {
            focusHelper.running = false;
            focusHelper.running = true;
        }
    }

    property string passwordBuffer: ""
    property string statusText: ""
    property bool statusIsError: false
    property bool authenticating: false

    PamContext {
        id: pam
        config: "system-login"
        user: Quickshell.env("USER")

        onPamMessage: {
            root.statusText = pam.message;
            root.statusIsError = pam.messageIsError;
            if (pam.responseRequired) {
                root.authenticating = false;
                passwordField.text = "";
                passwordField.forceActiveFocus();
            }
        }

        onCompleted: function (result) {
            root.authenticating = false;
            if (result === PamResult.Success) {
                passwordField.text = "";
                root.statusText = "";
                SessionActions.unlock();
            } else {
                root.statusText = "Incorrect password";
                root.statusIsError = true;
                passwordField.text = "";
                // Delay the retry so "Incorrect password" is actually seen --
                // an immediate pam.start() re-fires onPamMessage with the
                // fresh "Password:" prompt in the same tick, silently
                // clobbering this text before it ever renders.
                retryTimer.start();
            }
        }

        onError: function (error) {
            root.authenticating = false;
            root.statusText = "Authentication error: " + PamError.toString(error);
            root.statusIsError = true;
        }
    }

    onVisibleChanged: {
        if (visible) {
            statusText = "";
            statusIsError = false;
            focusHelperTimer.start();
            pam.start();
        } else {
            pam.abort();
        }
    }

    function submit() {
        if (!passwordField.text.length || root.authenticating)
            return;
        root.authenticating = true;
        pam.respond(passwordField.text);
    }

    Column {
        anchors.centerIn: parent
        spacing: Theme.fontSize

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "" // lock
            color: Theme.textMuted
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.fontSize * 3
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Quickshell.env("USER")
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize * 1.3
            font.bold: true
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.fontSize * 16
            height: Theme.fontSize * 2.2
            radius: Theme.radius / 2
            color: Theme.surface
            border.width: 1
            border.color: Theme.border
            clip: true

            TextInput {
                id: passwordField
                anchors.fill: parent
                anchors.margins: Theme.fontSize / 2
                clip: true
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                echoMode: TextInput.Password
                enabled: !root.authenticating

                Keys.onReturnPressed: root.submit()
                Keys.onEnterPressed: root.submit()
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.authenticating ? "Checking…" : root.statusText
            visible: text.length > 0
            color: root.statusIsError ? Theme.accent : Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize * 0.9
        }
    }
}
