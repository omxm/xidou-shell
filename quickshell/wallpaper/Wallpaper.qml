import QtQuick
import Quickshell
import Quickshell.Io
import "../config"
import "../services"

// Wallpaper picker: toggled by `xidou msg panel-toggle wallpaper` (dwm's
// super+y bind, dwm/config.h) via PanelManager.isOpen("wallpaper"). Same
// window type/centering/corner style/focus workaround as Launcher.qml and
// control-center, but sized to match control-center specifically (820x560,
// not Launcher's 480x360) -- the two content-heavy panels share a footprint
// rather than each picking its own size.
PanelWindow {
    id: root

    readonly property var cfg: Config.data.panels.wallpaper
    // Matches control-center's size (not Launcher's) so this panel and
    // control-center -- the two content-heavy "centered overlay" panels --
    // share a consistent footprint.
    readonly property int panelWidth: 820
    readonly property int panelHeight: 560
    readonly property int barReservedHeight: (Config.data.bar.position !== "bottom") ? Config.data.bar.height : 0

    readonly property var tabs: ["Built-in", "Wallpaper", "Community"]
    property int selectedTab: 1 // "Wallpaper" is the real, working tab

    property var wallpapers: []
    property string searchText: ""
    readonly property var filteredWallpapers: {
        var q = root.searchText.trim().toLowerCase();
        if (!q)
            return root.wallpapers;
        return root.wallpapers.filter(function (p) {
            return p.toLowerCase().indexOf(q) !== -1;
        });
    }

    // Runtime-only: this codebase has no config.toml *writer* (Toml.js is
    // parse-only, see its own header comment), so these reflect config.toml's
    // defaults at panel-open time but are session-only overrides, not
    // persisted back to the file. Flagged here rather than silently assumed.
    property string uiMode: Config.data.theme.mode === "auto" ? "auto" : Config.data.theme.mode
    property string schemeType: Config.data.theme.scheme_type

    readonly property var schemePresetNames: Object.keys(Config.data.theme.scheme_presets)
    readonly property string schemePresetLabel: {
        var names = root.schemePresetNames;
        for (var i = 0; i < names.length; i++)
            if (Config.data.theme.scheme_presets[names[i]] === root.schemeType)
                return names[i];
        return names.length > 0 ? names[0] : "";
    }

    function cycleSchemePreset() {
        var names = root.schemePresetNames;
        if (names.length === 0)
            return;
        var currentIndex = names.indexOf(root.schemePresetLabel);
        var next = names[(currentIndex + 1) % names.length];
        root.schemeType = Config.data.theme.scheme_presets[next];
    }

    function expandHome(p) {
        return p.indexOf("~") === 0 ? (Quickshell.env("HOME") + p.slice(1)) : p;
    }

    function shQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function basename(p) {
        var parts = p.split("/");
        return parts[parts.length - 1];
    }

    Process {
        id: listProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.wallpapers = text.trim().length > 0 ? text.trim().split("\n") : [];
            }
        }
    }

    function refreshWallpapers() {
        var dirs = (root.cfg.directories || []).map(root.expandHome);
        if (dirs.length === 0) {
            root.wallpapers = [];
            return;
        }
        var quoted = dirs.map(root.shQuote).join(" ");
        listProc.command = ["sh", "-c",
            "find " + quoted + " -maxdepth 1 -type f "
            + "\\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.bmp' \\) "
            + "2>/dev/null | sort"];
        listProc.running = false;
        listProc.running = true;
    }

    Process {
        id: setWallpaperProc
    }

    // Sets the real X11 background via feh (this repo's chosen X11
    // wallpaper tool -- CLAUDE.md's lessons doc explicitly warns off
    // reaching for Wayland tools like swaybg out of habit) and, only when
    // the shell is actually configured to derive its palette from the
    // wallpaper, kicks off the matugen pipeline from services/ColorScheme.qml.
    // matugen's mode flag ("smart") isn't spelled the same as config's own
    // "auto" even though they mean the same thing.
    function selectWallpaper(path) {
        setWallpaperProc.command = ["feh", "--bg-fill", path];
        setWallpaperProc.running = false;
        setWallpaperProc.running = true;

        if (Config.data.theme.source === "wallpaper") {
            var matugenMode = root.uiMode === "auto" ? "smart" : root.uiMode;
            ColorScheme.regenerate(path, matugenMode, root.schemeType);
        }
    }

    visible: PanelManager.isOpen("wallpaper") && root.cfg.enabled
    implicitWidth: panelWidth
    implicitHeight: panelHeight
    color: "transparent"

    // Same X-focus workaround as Launcher.qml/ControlCenter.qml -- see
    // Launcher.qml's header comment for the full investigation.
    focusable: true

    Process {
        id: focusHelper
        command: ["xidou-focus-window", String(root.panelWidth), String(root.panelHeight)]
    }

    Timer {
        id: focusHelperTimer
        interval: 50
        onTriggered: {
            focusHelper.running = false;
            focusHelper.running = true;
        }
    }

    anchors.top: true
    anchors.left: true
    margins.top: Math.round((screen.height - barReservedHeight - panelHeight) / 2)
    margins.left: Math.round((screen.width - panelWidth) / 2)

    onVisibleChanged: {
        if (visible) {
            searchText = "";
            // Wallpaper (index 1) is the default/most-used tab and is the
            // only one with a text field -- focus it directly (matching
            // Launcher.qml's searchField.forceActiveFocus() convention) so
            // typing actually reaches it instead of the inert keyHandler
            // wrapper, which is only meant as the fallback for the other
            // two (text-input-less) tabs.
            if (root.selectedTab === 1)
                searchField.forceActiveFocus();
            else
                keyHandler.forceActiveFocus();
            focusHelperTimer.start();
            root.refreshWallpapers();
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.surface
        border.width: 1
        border.color: Theme.border

        Item {
            id: keyHandler
            anchors.fill: parent
            focus: true

            Keys.onEscapePressed: PanelManager.close("wallpaper")

            Column {
                anchors.fill: parent
                anchors.margins: Theme.fontSize / 2
                spacing: Theme.fontSize / 3

                Row {
                    width: parent.width
                    height: Theme.fontSize * 1.6
                    spacing: Theme.fontSize / 3

                    Repeater {
                        model: root.tabs
                        delegate: Rectangle {
                            required property string modelData
                            required property int index

                            width: (parent.width - 2 * (Theme.fontSize / 3)) / 3
                            height: parent.height
                            radius: Theme.radius / 2
                            color: index === root.selectedTab ? Theme.accent : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: index === root.selectedTab ? Theme.background : Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize * 0.85
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedTab = index
                            }
                        }
                    }
                }

                // --- Built-in (stub: no bundled wallpapers exist yet) ---
                Item {
                    width: parent.width
                    height: parent.height - Theme.fontSize * 1.6 - (parent.spacing * 2)
                    visible: root.selectedTab === 0

                    Text {
                        anchors.centerIn: parent
                        text: "No built-in wallpapers yet"
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize * 0.9
                    }
                }

                // --- Wallpaper (real) ---
                Column {
                    width: parent.width
                    height: parent.height - Theme.fontSize * 1.6 - (parent.spacing * 2)
                    spacing: Theme.fontSize / 3
                    visible: root.selectedTab === 1

                    Rectangle {
                        width: parent.width
                        height: Theme.fontSize * 1.6
                        radius: Theme.radius / 2
                        color: Theme.surfaceAlt
                        border.width: 1
                        border.color: Theme.border

                        TextInput {
                            id: searchField
                            anchors.fill: parent
                            anchors.margins: Theme.fontSize / 3
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize * 0.85
                            clip: true
                            onTextChanged: root.searchText = text
                            Keys.onEscapePressed: PanelManager.close("wallpaper")

                            Text {
                                anchors.fill: parent
                                visible: parent.text.length === 0
                                verticalAlignment: Text.AlignVCenter
                                text: "Search wallpapers…"
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize * 0.85
                            }
                        }
                    }

                    GridView {
                        id: grid
                        width: parent.width
                        height: parent.height - Theme.fontSize * 1.6 * 2 - parent.spacing * 2
                        clip: true
                        cellWidth: width / 3
                        cellHeight: cellWidth * 0.68
                        model: root.filteredWallpapers

                        Text {
                            anchors.centerIn: parent
                            visible: root.filteredWallpapers.length === 0
                            text: root.wallpapers.length === 0
                                ? "No wallpapers found in the configured directories"
                                : "No matches"
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize * 0.8
                            width: parent.width * 0.8
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                        }

                        delegate: Item {
                            id: delegateRoot
                            required property string modelData

                            width: grid.cellWidth
                            height: grid.cellHeight

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2
                                radius: Theme.radius / 3
                                color: Theme.surfaceAlt
                                border.width: 1
                                border.color: Theme.border
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: "file://" + delegateRoot.modelData
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }

                                // Declared before the star below so the star's own
                                // MouseArea (a later sibling) hit-tests on top of this
                                // one where they overlap in the corner -- this being
                                // declared last previously swallowed every click meant
                                // for the star before it ever reached it.
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectWallpaper(delegateRoot.modelData)
                                }

                                Text {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 2
                                    // Material Symbols has no separate "outline star" codepoint --
                                    // filled vs outline is normally a variable-font FILL axis, not
                                    // a different glyph, and QML's Text doesn't expose that axis
                                    // easily. Same glyph both states, color carries the meaning.
                                    text: "" // star
                                    color: Favorites.isFavorite(delegateRoot.modelData) ? Theme.accent : Theme.text
                                    font.family: Theme.iconFontFamily
                                    font.pixelSize: Theme.fontSize

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Favorites.toggle(delegateRoot.modelData)
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        height: Theme.fontSize * 1.6
                        spacing: Theme.fontSize / 3

                        Repeater {
                            model: ["dark", "light", "auto"]
                            delegate: Rectangle {
                                required property string modelData

                                width: (parent.width * 0.5 - 2 * (Theme.fontSize / 3)) / 3
                                height: parent.height
                                radius: Theme.radius / 2
                                color: root.uiMode === modelData ? Theme.accent : Theme.surfaceAlt
                                border.width: 1
                                border.color: Theme.border

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: root.uiMode === modelData ? Theme.background : Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize * 0.75
                                    font.capitalization: Font.Capitalize
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.uiMode = modelData
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width * 0.5 - Theme.fontSize / 3
                            height: parent.height
                            radius: Theme.radius / 2
                            color: Theme.surfaceAlt
                            border.width: 1
                            border.color: Theme.border

                            Text {
                                anchors.centerIn: parent
                                text: root.schemePresetLabel
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize * 0.8
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.cycleSchemePreset()
                            }
                        }
                    }
                }

                // --- Community (stub: no online source decided yet) ---
                Item {
                    width: parent.width
                    height: parent.height - Theme.fontSize * 1.6 - (parent.spacing * 2)
                    visible: root.selectedTab === 2

                    Text {
                        anchors.centerIn: parent
                        text: "Community wallpapers aren't available yet"
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize * 0.9
                    }
                }
            }
        }
    }
}
