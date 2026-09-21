import QtQuick
import Quickshell
import Quickshell.Io
import "../config"
import "../services"
import "../controlcenter" as ControlCenter
import "appearance"
// Namespaced (not bare) -- multiple categories each have their own
// "General" sub-tab, and a bare import of both would collide on that
// identical type name.
import "screenshot" as ScreenshotTabs
import "osd" as OsdTabs

// Settings panel: toggled by `xidou msg settings toggle` (dwm's super+comma
// bind, dwm/config.h's settingstogglecmd -- already reserved there ahead of
// this panel existing) via its own dedicated "settings" IpcHandler in
// shell.qml, same as screenshot/theme/notifications each get their own
// target rather than sharing the generic "panels" one. Bridges straight
// into PanelManager.toggle("settings") so it still gets the same
// mutual-exclusion-with-every-other-dock-panel behavior as everything else.
//
// Same centered-floating-overlay window treatment as control-center
// (PanelWindow, PanelManager-gated visibility, xidou-focus-window for real
// X input focus, Theme.qml tokens throughout -- never a literal color/font).
// Structure follows a real Noctalia settings screenshot's LAYOUT only, not
// its visual skin, same rule already applied to control-center: search bar
// across the top, a left sidebar of categories, and the right side split
// into a sub-tab strip + an Overridden-only filter and a page-reset button.
//
// Categories start with just "Appearance" -- more get added as their
// underlying features are wired up (CLAUDE.md: "don't stub 15 empty
// categories"). Each category owns its own list of sub-tabs; Appearance's
// six are the ones はる specified, but every one of them (including Theme)
// is still a PlaceholderTab in this step -- real controls land in the next
// step, this one is just the shell/shape.
PanelWindow {
    id: root

    readonly property var cfg: Config.data.panels.settings
    readonly property int panelWidth: 860
    readonly property int panelHeight: 600
    readonly property int barReservedHeight: (Config.data.bar.position !== "bottom") ? Config.data.bar.height : 0

    readonly property var categories: ["Appearance", "Screenshot", "OSD"]
    property int selectedCategoryIndex: 0

    // Category name -> its sub-tab list. Categories not listed here would
    // just show no sub-tabs at all rather than erroring -- matches
    // Bar.qml's resolveModules()/ControlCenter's sectionComponents
    // convention of failing soft on anything not yet wired up.
    readonly property var subTabsByCategory: ({
        "Appearance": ["Theme", "Interface", "Accessibility", "Motion", "Borders", "Effects"],
        "Screenshot": ["General"],
        "OSD": ["General"]
    })
    readonly property var currentSubTabs: root.subTabsByCategory[root.categories[root.selectedCategoryIndex]] || []
    property int selectedSubTabIndex: 0

    // Wired for the next step's real controls to read/toggle -- with only
    // PlaceholderTabs underneath right now, there is nothing yet for either
    // one to actually filter or reset.
    property bool showOverriddenOnly: false
    property string searchText: searchField.text

    // Delegates to the loaded tab's own resetAll() when it has one (real
    // tabs like ThemeTab do; PlaceholderTab doesn't, so this is a silent
    // no-op there rather than needing every unbuilt tab to stub the
    // function out just to satisfy this call).
    function resetCurrentPage() {
        if (tabLoader.item && tabLoader.item.resetAll)
            tabLoader.item.resetAll();
    }

    visible: PanelManager.isOpen("settings") && root.cfg.enabled
    implicitWidth: panelWidth
    implicitHeight: panelHeight
    color: "transparent"

    // Same X-focus workaround as Launcher.qml/ControlCenter.qml --
    // PanelWindow.focusable does nothing on this X11 backend.
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
            root.selectedCategoryIndex = 0;
            root.selectedSubTabIndex = 0;
            root.showOverriddenOnly = false;
            searchField.text = "";
            searchField.forceActiveFocus();
            focusHelperTimer.start();
        }
    }

    onSelectedCategoryIndexChanged: root.selectedSubTabIndex = 0

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.surface
        border.width: 1
        border.color: Theme.border

        Column {
            anchors.fill: parent
            anchors.margins: Theme.fontSize
            spacing: Theme.fontSize / 2

            Rectangle {
                width: parent.width
                height: Theme.fontSize * 2.2
                radius: Theme.radius / 2
                color: Theme.surfaceAlt
                border.width: 1
                border.color: Theme.border

                TextInput {
                    id: searchField
                    anchors.fill: parent
                    anchors.margins: Theme.fontSize / 2
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    clip: true

                    Text {
                        anchors.fill: parent
                        visible: searchField.text.length === 0
                        verticalAlignment: Text.AlignVCenter
                        text: "Search settings…"
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Keys.onEscapePressed: PanelManager.close("settings")
                    Keys.onTabPressed: {
                        if (root.currentSubTabs.length > 0)
                            root.selectedSubTabIndex = (root.selectedSubTabIndex + 1) % root.currentSubTabs.length;
                    }
                }
            }

            Row {
                width: parent.width
                height: parent.height - parent.spacing - (Theme.fontSize * 2.2)
                spacing: Theme.fontSize

                ControlCenter.Sidebar {
                    id: sidebar
                    width: parent.width * 0.2
                    height: parent.height
                    sections: root.categories
                    selectedIndex: root.selectedCategoryIndex
                    onSectionClicked: (index) => root.selectedCategoryIndex = index
                }

                Column {
                    id: content
                    width: parent.width - sidebar.width - parent.spacing
                    height: parent.height
                    spacing: Theme.fontSize / 2

                    Row {
                        id: header
                        width: parent.width
                        height: Theme.fontSize * 2.2
                        spacing: Theme.fontSize / 2

                        // Horizontally scrollable rather than truncated or
                        // wrapped -- keeps the header a fixed height (so it
                        // doesn't grow the further sub-tabs push it) and
                        // stays legible as more categories/sub-tabs are
                        // added later, instead of clipping against
                        // Overridden/Reset Page the way a plain fixed-width
                        // Row did once the sub-tab strip's natural width
                        // (which grows with Theme.fontSize too) exceeded
                        // the space left after those two buttons.
                        Flickable {
                            id: subTabScroll
                            width: header.width - overriddenToggle.width - resetPageButton.width - (header.spacing * 2)
                            height: parent.height
                            contentWidth: subTabBar.width
                            contentHeight: height
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            flickableDirection: Flickable.HorizontalFlick

                            WheelHandler {
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                onWheel: function (event) {
                                    subTabScroll.contentX = Math.max(0, Math.min(
                                        Math.max(0, subTabScroll.contentWidth - subTabScroll.width),
                                        subTabScroll.contentX - event.angleDelta.y));
                                }
                            }

                            SubTabBar {
                                id: subTabBar
                                height: parent.height
                                tabs: root.currentSubTabs
                                selectedIndex: root.selectedSubTabIndex
                                onTabClicked: (index) => root.selectedSubTabIndex = index
                            }
                        }

                        Rectangle {
                            id: overriddenToggle
                            width: overriddenLabel.implicitWidth + Theme.fontSize * 1.5
                            height: parent.height
                            radius: Theme.radius / 2
                            color: root.showOverriddenOnly ? Theme.accent : Theme.surfaceAlt
                            border.width: 1
                            border.color: Theme.border

                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.fontSize / 3

                                Text {
                                    text: "" // tune (verified via fontTools)
                                    color: root.showOverriddenOnly ? Theme.background : Theme.textMuted
                                    font.family: Theme.iconFontFamily
                                    font.pixelSize: Theme.fontSize
                                }

                                Text {
                                    id: overriddenLabel
                                    text: "Overridden"
                                    color: root.showOverriddenOnly ? Theme.background : Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize * 0.9
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.showOverriddenOnly = !root.showOverriddenOnly
                            }
                        }

                        Rectangle {
                            id: resetPageButton
                            width: resetLabel.implicitWidth + Theme.fontSize * 1.5
                            height: parent.height
                            radius: Theme.radius / 2
                            color: Theme.surfaceAlt
                            border.width: 1
                            border.color: Theme.border

                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.fontSize / 3

                                Text {
                                    text: "" // restart_alt (verified via fontTools)
                                    color: Theme.textMuted
                                    font.family: Theme.iconFontFamily
                                    font.pixelSize: Theme.fontSize
                                }

                                Text {
                                    id: resetLabel
                                    text: "Reset Page"
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize * 0.9
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.resetCurrentPage()
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: parent.height - header.height - parent.spacing

                        // Category name -> sub-tab name -> Component, same
                        // string-keyed lookup pattern as ControlCenter.qml's
                        // sectionComponents -- an unresolved name falls back
                        // to the placeholder rather than needing every
                        // future sub-tab to extend a growing list here.
                        // Nested by category (not flat) since two real
                        // categories now exist and a flat map would risk a
                        // future sub-tab name collision across them.
                        readonly property var tabComponents: ({
                            "Appearance": {
                                "Theme": themeTabComponent,
                                "Interface": interfaceTabComponent,
                                "Borders": bordersTabComponent
                            },
                            "Screenshot": {
                                "General": screenshotGeneralTabComponent
                            },
                            "OSD": {
                                "General": osdGeneralTabComponent
                            }
                        })

                        readonly property var currentCategoryTabComponents: tabComponents[root.categories[root.selectedCategoryIndex]] || {}

                        Loader {
                            id: tabLoader
                            anchors.fill: parent
                            sourceComponent: parent.currentCategoryTabComponents[root.currentSubTabs[root.selectedSubTabIndex]] || placeholderComponent
                        }

                        Component {
                            id: themeTabComponent
                            ThemeTab {
                                showOverriddenOnly: root.showOverriddenOnly
                            }
                        }

                        Component {
                            id: interfaceTabComponent
                            InterfaceTab {
                                showOverriddenOnly: root.showOverriddenOnly
                            }
                        }

                        Component {
                            id: bordersTabComponent
                            BordersTab {
                                showOverriddenOnly: root.showOverriddenOnly
                            }
                        }

                        Component {
                            id: screenshotGeneralTabComponent
                            ScreenshotTabs.GeneralTab {
                                showOverriddenOnly: root.showOverriddenOnly
                            }
                        }

                        Component {
                            id: osdGeneralTabComponent
                            OsdTabs.GeneralTab {
                                showOverriddenOnly: root.showOverriddenOnly
                            }
                        }

                        Component {
                            id: placeholderComponent
                            PlaceholderTab {
                                tabName: root.currentSubTabs[root.selectedSubTabIndex] || ""
                            }
                        }
                    }
                }
            }
        }
    }
}
