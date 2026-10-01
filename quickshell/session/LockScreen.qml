import QtQuick
import QtQuick.Effects
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
// path anywhere in this file -- the only way out is a correct password
// (Escape only clears the field).
//
// One PamContext for the whole lock, one window per screen (same Variants
// approach as the bar in shell.qml) so no monitor is left uncovered. Each
// window shows the full UI and has its own password field; whichever one
// has focus submits.
//
// Layout: an opaque background, and a centered surface container holding a
// wallpaper card (current wallpaper, clock and date) on the left and the
// password form on the right.
Scope {
    id: root

    property string statusText: ""
    property bool statusIsError: false
    property bool authenticating: false

    // The current wallpaper, as last set by the wallpaper picker. The
    // picker applies it with `feh --bg-fill`, and feh records that command
    // in ~/.fehbg (also what session/xidou-xinitrc restores from), so that
    // file is the one place the current path lives.
    property string wallpaperPath: ""

    // Tells every screen's password field to clear itself and take focus.
    signal resetInput()

    // Last argument of the feh command line in ~/.fehbg, with feh's shell
    // quoting ('...' chunks and "'"-style escapes) undone.
    function parseFehbg(text) {
        var lines = text.split("\n");
        for (var i = lines.length - 1; i >= 0; i--) {
            var line = lines[i].trim();
            if (line.indexOf("feh") < 0 || line.indexOf("--bg-") < 0)
                continue;
            var args = [];
            var cur = "";
            var inArg = false;
            for (var j = 0; j < line.length; j++) {
                var ch = line[j];
                if (ch === "'" || ch === "\"") {
                    var end = line.indexOf(ch, j + 1);
                    if (end < 0)
                        end = line.length;
                    cur += line.substring(j + 1, end);
                    inArg = true;
                    j = end;
                } else if (ch === " " || ch === "\t") {
                    if (inArg)
                        args.push(cur);
                    cur = "";
                    inArg = false;
                } else {
                    cur += ch;
                    inArg = true;
                }
            }
            if (inArg)
                args.push(cur);
            return args.length ? args[args.length - 1] : "";
        }
        return "";
    }

    FileView {
        id: fehbg
        path: Quickshell.env("HOME") + "/.fehbg"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.wallpaperPath = root.parseFehbg(text())
        onLoadFailed: root.wallpaperPath = ""
    }

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
            if (pam.responseRequired) {
                // The prompt itself ("Password: ") isn't shown -- the form's
                // subtitle already says what to do -- and it mustn't clobber
                // an "Incorrect password" still on screen from the last try.
                root.authenticating = false;
                root.resetInput();
            } else {
                root.statusText = pam.message;
                root.statusIsError = pam.messageIsError;
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
                SoundFx.play("wrong_password");
                root.resetInput();
                // Delay the restart a little so a burst of Enter presses
                // doesn't hammer PAM.
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
                fehbg.reload();
                pam.start();
            } else {
                pam.abort();
            }
        }
    }

    function submit(password) {
        if (!password.length || root.authenticating)
            return;
        root.statusText = "";
        root.statusIsError = false;
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
            // An opaque (non-ARGB) X visual: nothing under the lock screen
            // can show through, whatever alpha the theme color carries or
            // the compositor is configured to do with translucent windows.
            surfaceFormat.opaque: true

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
            // LOCKWINNAME in xidouwm/dwm.c) -- all Quickshell windows are
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
                if (visible) {
                    passwordField.text = "";
                    passwordField.forceActiveFocus();
                    if (isPrimary)
                        focusHelperTimer.start();
                }
            }

            Connections {
                target: root

                function onResetInput() {
                    passwordField.text = "";
                    passwordField.forceActiveFocus();
                }
            }

            SystemClock {
                id: clock
                enabled: lockWindow.visible
                precision: SystemClock.Minutes
            }

            // Container: ~62% of the screen width at ~1.54:1, clamped to a
            // font-relative min/max and to the screen itself so it fits
            // anything from 1366x768 up.
            Rectangle {
                id: container

                readonly property real aspect: 1.54
                readonly property real minWidth: Theme.fontSize * 56
                readonly property real maxWidth: Theme.fontSize * 100
                readonly property real fitWidth: Math.min(lockWindow.width * 0.94, lockWindow.height * 0.9 * aspect)
                readonly property real inset: width * 0.01

                anchors.centerIn: parent
                width: Math.min(Math.max(lockWindow.width * 0.62, minWidth), maxWidth, fitWidth)
                height: width / aspect
                radius: Theme.radius * 2
                color: Theme.surface

                // Wallpaper card: left ~49%, inset ~1%, corners a little
                // tighter than the container's.
                Item {
                    id: card

                    readonly property real cornerRadius: container.radius * 0.75

                    x: container.inset
                    y: container.inset
                    width: container.width * 0.49
                    height: container.height - container.inset * 2

                    // Shown when there's no wallpaper, or while it loads.
                    Rectangle {
                        anchors.fill: parent
                        radius: card.cornerRadius
                        color: Theme.surfaceAlt
                    }

                    Image {
                        id: wallpaper
                        anchors.fill: parent
                        visible: false
                        source: root.wallpaperPath ? "file://" + root.wallpaperPath : ""
                        fillMode: Image.PreserveAspectCrop
                        // Decode at card size, not the file's (often 4K+).
                        sourceSize.width: card.width * lockWindow.devicePixelRatio
                        sourceSize.height: card.height * lockWindow.devicePixelRatio
                        asynchronous: true
                        smooth: true
                        mipmap: true
                    }

                    // Rounded-corner clip for the wallpaper; the mask only
                    // uses alpha, so the fill is just any opaque theme color.
                    Item {
                        id: cardMask
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        layer.smooth: true

                        Rectangle {
                            anchors.fill: parent
                            radius: card.cornerRadius
                            color: Theme.background
                        }
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: wallpaper
                        visible: wallpaper.status === Image.Ready
                        maskEnabled: true
                        maskSource: cardMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                    }

                    // Scrim under the clock, fading from clear to the theme
                    // background so the text reads on any wallpaper.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: parent.height * 0.5
                        radius: card.cornerRadius
                        gradient: Gradient {
                            GradientStop {
                                position: 0.0
                                color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0)
                            }
                            GradientStop {
                                position: 0.55
                                color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.55)
                            }
                            GradientStop {
                                position: 1.0
                                color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.85)
                            }
                        }
                    }

                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: card.height * 0.07
                        spacing: card.height * 0.01

                        // Same format switch as the bar's Clock module
                        // ([bar_widgets.clock] time_format).
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: clock.date.toLocaleTimeString(Qt.locale(),
                                Config.data.bar_widgets.clock.time_format === "12h" ? "hh:mm AP" : "HH:mm")
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.weight: Font.Light
                            font.pixelSize: card.height * 0.15
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: clock.date.toLocaleDateString(Qt.locale(), "dddd, MMMM d")
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.weight: Font.Medium
                            font.pixelSize: Math.max(card.height * 0.035, Theme.fontSize)
                        }
                    }
                }

                // Form column: ~30% of the container, centered in the space
                // right of the card.
                Column {
                    id: form

                    readonly property real fieldHeight: Theme.fontSize * 3

                    width: container.width * 0.30
                    x: card.x + card.width + (container.width - card.x - card.width - width) / 2
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.fontSize

                    Text {
                        width: parent.width
                        text: Quickshell.env("USER")
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize * 1.8
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: "Enter your password to unlock"
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize * 0.9
                        wrapMode: Text.WordWrap
                    }

                    // Extra breathing room between the heading and the field.
                    Item {
                        width: 1
                        height: Theme.fontSize * 0.5
                    }

                    Rectangle {
                        id: fieldBox
                        width: parent.width
                        height: form.fieldHeight
                        radius: Theme.radius
                        color: Theme.surfaceAlt
                        border.width: passwordField.activeFocus ? 2 : 1
                        border.color: passwordField.activeFocus ? Theme.accent : Theme.border
                        opacity: passwordField.enabled ? 1 : 0.6

                        TextInput {
                            id: passwordField
                            anchors.fill: parent
                            anchors.leftMargin: Theme.fontSize
                            anchors.rightMargin: Theme.fontSize
                            clip: true
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            echoMode: TextInput.Password
                            passwordCharacter: "•"
                            enabled: !root.authenticating

                            Keys.onReturnPressed: root.submit(passwordField.text)
                            Keys.onEnterPressed: root.submit(passwordField.text)
                            Keys.onEscapePressed: passwordField.text = ""
                        }

                        Text {
                            anchors.fill: passwordField
                            verticalAlignment: Text.AlignVCenter
                            visible: !passwordField.text.length
                            text: "Password"
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                    }

                    Rectangle {
                        id: unlockButton

                        readonly property bool canSubmit: !root.authenticating && passwordField.text.length > 0

                        width: parent.width
                        height: form.fieldHeight
                        radius: Theme.radius
                        color: Theme.accent
                        opacity: root.authenticating ? 0.6 : (unlockArea.containsMouse && canSubmit ? 0.9 : 1)

                        Text {
                            anchors.centerIn: parent
                            text: root.authenticating ? "Checking…" : "Unlock"
                            // Same on-accent convention as every other panel
                            // (Sidebar, ToggleTile, OptionRow...): the theme
                            // background sits opposite the accent in both
                            // light and dark modes.
                            color: Theme.background
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: unlockArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: unlockButton.canSubmit ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (unlockButton.canSubmit)
                                    root.submit(passwordField.text);
                                passwordField.forceActiveFocus();
                            }
                        }
                    }

                    // Fixed height whether or not there's a message, so the
                    // form never jumps.
                    Item {
                        width: parent.width
                        height: Theme.fontSize * 2.6

                        Text {
                            anchors.fill: parent
                            text: root.statusText
                            color: root.statusIsError ? Theme.warning : Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize * 0.9
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
