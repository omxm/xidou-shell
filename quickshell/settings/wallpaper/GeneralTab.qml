import QtQuick
import "../../config"
import "../../services"
import ".." as Settings

// Wallpaper > General: panels.wallpaper.directories, the one real
// config-backed wallpaper setting (Phase 6) -- Wallpaper.qml's
// refreshWallpapers() reads it directly to build the thumbnail grid, and
// already re-scans on every panel open (onVisibleChanged), so no extra
// live-refresh trigger is needed here the way Weather needed one.
//
// Favorites (~/.config/xidou/favorites.json) has nothing to wire up: it's
// a real, working feature, but its own separate file with a hardcoded
// path, not a config.toml key -- confirmed while scoping this category,
// not something this tab was scaled back from. The picker's Built-in/
// Community tabs are confirmed stubs (no bundled wallpapers, no online
// source decided) from the Theme scope-check; still nothing there either.
//
// directories is the first array-of-strings setting in this settings
// panel, so it gets a real add/remove list (StringListEditor) rather than
// a delimited single text field -- per はる's explicit call, since a fixed
// set of options (OptionRow) or a single scalar (TextCommitField) don't
// fit an open-ended list of paths.
Item {
    id: root

    property bool showOverriddenOnly: false

    function resetAll() {
        directoriesRow.reset();
    }

    Column {
        anchors.fill: parent
        spacing: Theme.fontSize / 2

        Settings.SettingRow {
            id: directoriesRow
            label: "Wallpaper Directories"
            tableHeader: "panels.wallpaper"
            settingKey: "directories"
            defaultValue: Config.defaults.panels.wallpaper.directories
            showOverriddenOnly: root.showOverriddenOnly
            rowHeight: Theme.fontSize * 2.6 + (Config.data.panels.wallpaper.directories.length + 1) * (Theme.fontSize * 1.8 + Theme.fontSize / 4)

            Settings.StringListEditor {
                width: parent.width
                items: Config.data.panels.wallpaper.directories
                // Deliberately not "~/Pictures/Wallpapers" -- that's the
                // real shipped default, and using it as the empty-field
                // placeholder made a fresh install's add-row look like a
                // second, duplicate entry of the one real row above it.
                placeholder: "Add a directory path…"
                onCommitted: (newItems) => Config.setValue("panels.wallpaper", "directories", newItems)
            }
        }
    }
}
