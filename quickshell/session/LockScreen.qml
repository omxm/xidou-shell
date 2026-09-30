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
//
// One PamContext for the whole lock, one window per screen (same Variants
// approach as the bar in shell.qml) so no monitor is left uncovered. Each
// window has its own password field; whichever one has focus submits.
Scope {
    id: root

    property string statusText: ""
    property bool statusIsError: false
    property bool authenticating: false

    // Tells every screen's password field to clear itself and take focus.
    signal resetInput()

    Timer {
        id: retryTimer
        interval: 1000
        onTriggered: pam.start()
    }

    PamContext {
        id: pam
        config: "system-login"
        user: Quickshell.env("USER")

        onPamMessage: {
            root.statusText = pam.message;
            root.statusIsError = pam.messageIsError;
            if (pam.responseRequired) {
                root.authenticating = false;
                root.resetInput();
            }
        }

        onCompleted: function (result) {
            root.authenticating = false;
            if (result === PamResult.Success) {
                root.resetInput();
                root.statusText = "";
                SessionActions.unlock();
            } else {
                root.statusText = "Incorrect password";
                root.statusIsError = true;
                root.resetInput();
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

    Connections {
        target: SessionActions

        function onLockedChanged() {
            if (SessionActions.locked) {
                root.statusText = "";
                root.statusIsError = false;
                pam.start();
            } else {
                pam.abort();
            }
        }
    }

    function submit(password) {
        if (!password.length || root.authenticating)
            return;
        root.authenticating = true;
        pam.respond(password);
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: lockWindow

            required property var modelData
            readonly property bool isPrimary: Quickshell.screens.indexOf(modelData) === 0

            screen: modelData
            visible: SessionActions.locked
            color: Theme.background

            // Full-screen coverage, not a centered overlay like every other
            // panel -- anchoring all four sides spans the whole monitor. Ignore
            // other panels' exclusive zones, or the window is shrunk to leave
            // the bar's reserved strip uncovered (and clickable).
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            exclusionMode: ExclusionMode.Ignore

            focusable: true

            // dwm keeps windows with this title above every other dock (see
            // LOCKWINNAME in dwm/dwm.c) -- all Quickshell windows are
            // otherwise just "quickshell". PanelWindow has no title property,
            // but QtQuick's Window attached property reaches the real window.
            Item {
                readonly property var backingWindow: Window.window
                onBackingWindowChanged: {
                    if (backingWindow)
                        backingWindow.setTitle("xidou-lock");
                }
            }

            Process {
                id: focusHelper
                command: ["xidou-focus-window", String(Math.round(lockWindow.width)), String(Math.round(lockWindow.height))]
            }

            Timer {
                id: focusHelperTimer
                interval: 50
                onTriggered: {
                    focusHelper.running = false;
                    focusHelper.running = true;
                }
            }

            onVisibleChanged: {
                if (visible && isPrimary)
                    focusHelperTimer.start();
            }

            Connections {
                target: root

                function onResetInput() {
                    passwordField.text = "";
                    passwordField.forceActiveFocus();
                }
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

                        Keys.onReturnPressed: root.submit(passwordField.text)
                        Keys.onEnterPressed: root.submit(passwordField.text)
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
    }
}
