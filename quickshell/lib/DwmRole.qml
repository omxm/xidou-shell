import QtQuick

// Sets the enclosing window's real X11 title (WM_NAME/_NET_WM_NAME), which is
// how dwm tells Quickshell's windows apart -- they are otherwise all just
// "quickshell". dwm matches "xidou-panel" (PANELWINNAME in dwm/dwm.c) to give
// a panel input focus when it maps and keep it there until it closes.
//
// PanelWindow has no title property; QtQuick's Window attached property
// reaches the real window instead (same approach as session/LockScreen.qml).
Item {
    property string title

    readonly property var backingWindow: Window.window

    function apply() {
        if (backingWindow && title)
            backingWindow.setTitle(title);
    }

    onBackingWindowChanged: apply()
    onTitleChanged: apply()
}
