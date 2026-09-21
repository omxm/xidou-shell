import QtQuick
import "../../config"
import "../../services"
import ".." as Settings

// Weather > General: the real, standalone [weather] table from Phase 1
// (auto_locate, city, latitude, longitude, units). Unlike every category
// built so far, changing these alone has no live effect -- all three
// weather displays (bar/modules/Weather.qml, control-center's
// WeatherSection.qml/ClockWeatherCard.qml) resolve location and fetch the
// forecast exactly once at their own startup, by this codebase's own
// deliberate "self-contained per-module" convention (kept as-is here --
// consolidating that duplication is its own separate refactor, not part of
// wiring up settings for it). "Refresh Now" below calls the same
// WeatherRefresh.trigger() `xidou msg weather refresh` does, which is what
// actually makes a location change visible without a full shell restart.
//
// City/Latitude/Longitude only take effect when Auto-Locate is off (see
// bar/modules/Weather.qml's own resolution priority comment) -- dimmed and
// disabled while it's on instead of left editable with no effect, same
// "don't let the user edit a value that currently does nothing" call
// ThemeTab.qml already made for Wallpaper Generation Scheme.
Item {
    id: root

    property bool showOverriddenOnly: false

    readonly property var numberPattern: /^-?\d+(\.\d+)?$/

    function resetAll() {
        autoLocateRow.reset();
        cityRow.reset();
        latitudeRow.reset();
        longitudeRow.reset();
        unitsRow.reset();
    }

    Column {
        anchors.fill: parent
        spacing: Theme.fontSize / 2

        Settings.SettingRow {
            id: autoLocateRow
            label: "Auto-Locate"
            tableHeader: "weather"
            settingKey: "auto_locate"
            defaultValue: Config.defaults.weather.auto_locate
            showOverriddenOnly: root.showOverriddenOnly

            Settings.OptionRow {
                width: parent.width
                options: [
                    { value: true, label: "On" },
                    { value: false, label: "Off" }
                ]
                currentValue: Config.data.weather.auto_locate
                onOptionSelected: (value) => Config.setValue("weather", "auto_locate", value)
            }
        }

        Settings.SettingRow {
            id: cityRow
            label: "City"
            tableHeader: "weather"
            settingKey: "city"
            defaultValue: Config.defaults.weather.city
            showOverriddenOnly: root.showOverriddenOnly

            Settings.TextCommitField {
                width: parent.width
                enabled: !Config.data.weather.auto_locate
                opacity: enabled ? 1 : 0.5
                value: Config.data.weather.city
                placeholder: "e.g. Tokyo"
                onCommitted: (text) => Config.setValue("weather", "city", text)
            }
        }

        Settings.SettingRow {
            id: latitudeRow
            label: "Latitude"
            tableHeader: "weather"
            settingKey: "latitude"
            defaultValue: Config.defaults.weather.latitude
            showOverriddenOnly: root.showOverriddenOnly

            Settings.TextCommitField {
                id: latitudeField
                width: parent.width
                enabled: !Config.data.weather.auto_locate
                opacity: enabled ? 1 : 0.5
                value: String(Config.data.weather.latitude)
                isValid: root.numberPattern.test(latitudeField.text)
                onCommitted: (text) => Config.setValue("weather", "latitude", parseFloat(text))
            }
        }

        Settings.SettingRow {
            id: longitudeRow
            label: "Longitude"
            tableHeader: "weather"
            settingKey: "longitude"
            defaultValue: Config.defaults.weather.longitude
            showOverriddenOnly: root.showOverriddenOnly

            Settings.TextCommitField {
                id: longitudeField
                width: parent.width
                enabled: !Config.data.weather.auto_locate
                opacity: enabled ? 1 : 0.5
                value: String(Config.data.weather.longitude)
                isValid: root.numberPattern.test(longitudeField.text)
                onCommitted: (text) => Config.setValue("weather", "longitude", parseFloat(text))
            }
        }

        Settings.SettingRow {
            id: unitsRow
            label: "Units"
            tableHeader: "weather"
            settingKey: "units"
            defaultValue: Config.defaults.weather.units
            showOverriddenOnly: root.showOverriddenOnly

            Settings.OptionRow {
                width: parent.width
                options: [
                    { value: "celsius", label: "Celsius" },
                    { value: "fahrenheit", label: "Fahrenheit" }
                ]
                currentValue: Config.data.weather.units
                onOptionSelected: (value) => Config.setValue("weather", "units", value)
            }
        }

        Rectangle {
            width: refreshLabel.implicitWidth + Theme.fontSize * 2
            height: Theme.fontSize * 2.2
            radius: Theme.radius / 2
            color: Theme.accent

            Row {
                anchors.centerIn: parent
                spacing: Theme.fontSize / 3

                Text {
                    text: "" // refresh (verified via fontTools)
                    color: Theme.background
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fontSize
                }

                Text {
                    id: refreshLabel
                    text: "Refresh Now"
                    color: Theme.background
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize * 0.9
                    font.bold: true
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: WeatherRefresh.trigger()
            }
        }
    }
}
