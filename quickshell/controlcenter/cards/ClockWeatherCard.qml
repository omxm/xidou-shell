import QtQuick
import Quickshell
import Quickshell.Io
import "../../config"
import "../../services"
import ".." as ControlCenter

// Clock: same SystemClock idiom as bar/modules/Clock.qml. Weather: the same
// Open-Meteo curl-based fetch as bar/modules/Weather.qml, kept inline/
// self-contained rather than pulled into a shared service — matches this
// codebase's existing convention of self-contained per-module logic.
ControlCenter.Card {
    id: root

    readonly property var cfg: Config.data.weather

    property real latitude: cfg.latitude
    property real longitude: cfg.longitude
    property string tempText: ""
    property string conditionText: ""
    property string weatherIcon: ""

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    function wmoDescription(code) {
        if (code === 0) return "Clear";
        if (code <= 3) return "Cloudy";
        if (code === 45 || code === 48) return "Fog";
        if (code >= 51 && code <= 67) return "Rain";
        if (code >= 71 && code <= 77) return "Snow";
        if (code >= 80 && code <= 82) return "Showers";
        if (code >= 95) return "Storm";
        return "";
    }

    // Material Symbols Outlined codepoints for clear_day / cloudy / foggy /
    // rainy / ac_unit (snow) / thunderstorm — same set as the bar's Weather.qml.
    function wmoIcon(code) {
        if (code === 0) return "";
        if (code <= 3) return "";
        if (code === 45 || code === 48) return "";
        if (code >= 51 && code <= 67) return "";
        if (code >= 71 && code <= 77) return "";
        if (code >= 80 && code <= 82) return "";
        if (code >= 95) return "";
        return "";
    }

    Process {
        id: ipLocate
        command: ["curl", "-s", "-m", "5", "http://ip-api.com/json/"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text);
                    if (parsed.status === "success") {
                        root.latitude = parsed.lat;
                        root.longitude = parsed.lon;
                        root.triggerForecastFetch();
                    }
                } catch (e) {
                    console.warn("[xidou] control-center weather: failed to parse ip geolocation response: " + e);
                }
            }
        }
    }

    Process {
        id: geocode
        command: ["curl", "-s", "-m", "5",
            "https://geocoding-api.open-meteo.com/v1/search?name=" + encodeURIComponent(root.cfg.city) + "&count=1"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text);
                    if (parsed.results && parsed.results.length > 0) {
                        root.latitude = parsed.results[0].latitude;
                        root.longitude = parsed.results[0].longitude;
                        root.triggerForecastFetch();
                    }
                } catch (e) {
                    console.warn("[xidou] control-center weather: failed to parse geocoding response: " + e);
                }
            }
        }
    }

    Process {
        id: forecast
        command: ["curl", "-s", "-m", "5",
            "https://api.open-meteo.com/v1/forecast?latitude=" + root.latitude
            + "&longitude=" + root.longitude
            + "&current=temperature_2m,weather_code&temperature_unit=" + (root.cfg.units === "fahrenheit" ? "fahrenheit" : "celsius")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text);
                    if (parsed.current) {
                        root.tempText = Math.round(parsed.current.temperature_2m) + "°" + (root.cfg.units === "fahrenheit" ? "F" : "C");
                        root.conditionText = root.wmoDescription(parsed.current.weather_code);
                        root.weatherIcon = root.wmoIcon(parsed.current.weather_code);
                    }
                } catch (e) {
                    console.warn("[xidou] control-center weather: failed to parse forecast response: " + e);
                }
            }
        }
    }

    Timer {
        id: forecastTimer
        interval: 900000 // 15 minutes, same cadence as the bar's Weather module
        repeat: true
        onTriggered: {
            forecast.running = false;
            forecast.running = true;
        }
    }

    // See bar/modules/Weather.qml's own triggerForecastFetch() for why this
    // exists rather than just calling forecastTimer.start() -- that's a
    // no-op once the timer is already running, which is true for every
    // resolution after the very first.
    function triggerForecastFetch() {
        forecast.running = false;
        forecast.running = true;
        if (!forecastTimer.running)
            forecastTimer.start();
    }

    // Re-run on WeatherRefresh's trigger() (settings panel's "Refresh Now",
    // or `xidou msg weather refresh`) as well as at startup -- see
    // bar/modules/Weather.qml's own resolveLocation() for why this stays
    // an explicit trigger rather than continuous re-resolution.
    function resolveLocation() {
        if (!cfg.enabled)
            return;
        if (cfg.auto_locate) {
            ipLocate.running = true;
        } else if (cfg.city && cfg.city.length > 0) {
            geocode.running = true;
        } else {
            root.latitude = cfg.latitude;
            root.longitude = cfg.longitude;
            root.triggerForecastFetch();
        }
    }

    // See bar/modules/Weather.qml's own hasResolvedOnce for why this exists
    // -- Component.onCompleted can fire before Config's async load
    // completes, silently resolving against hardcoded defaults instead of
    // the real config.toml with nothing to self-correct afterward.
    property bool hasResolvedOnce: false

    Connections {
        target: Config
        function onReloaded() {
            if (root.hasResolvedOnce || !Config.ready)
                return;
            root.hasResolvedOnce = true;
            root.resolveLocation();
        }
    }

    Connections {
        target: WeatherRefresh
        function onGenerationChanged() {
            root.resolveLocation();
        }
    }

    Component.onCompleted: {
        if (Config.ready) {
            root.hasResolvedOnce = true;
            root.resolveLocation();
        }
    }

    Row {
        anchors.fill: parent
        anchors.margins: Theme.fontSize

        Column {
            width: parent.width / 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.fontSize / 4

            Text {
                text: clock.date.toLocaleTimeString(Qt.locale(), "HH:mm")
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 1.6
            }

            Text {
                text: clock.date.toLocaleDateString(Qt.locale(), "ddd, MMM d")
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 0.85
            }
        }

        Column {
            width: parent.width / 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.fontSize / 4
            visible: root.cfg.enabled && root.tempText !== ""

            Text {
                text: root.weatherIcon
                color: Theme.textMuted
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.fontSize * 1.6
            }

            Text {
                text: root.tempText + (root.conditionText ? " · " + root.conditionText : "")
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 0.85
            }
        }
    }
}
