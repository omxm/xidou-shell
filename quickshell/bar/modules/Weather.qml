import QtQuick
import Quickshell.Io
import "../../config"
import "../../services"

// Open-Meteo current conditions (no API key needed). Location resolution
// priority, same as config.toml documents it:
//   1. auto_locate = true  -> IP geolocation (ip-api.com)
//   2. city set             -> Open-Meteo's own geocoding API
//   3. latitude/longitude   -> used as-is
// Location is resolved once at startup; only the forecast itself re-polls
// on a timer, so we're not hammering the geolocation/geocoding APIs.
Item {
    id: root

    readonly property var cfg: Config.data.weather

    property real latitude: cfg.latitude
    property real longitude: cfg.longitude
    property string tempText: ""
    property string conditionText: ""
    property string icon: ""

    implicitWidth: cfg.enabled && root.tempText ? (row.implicitWidth + Theme.fontSize) : 0
    implicitHeight: parent ? parent.height : Theme.fontSize * 2
    visible: cfg.enabled && root.tempText !== ""

    function wmoDescription(code) {
        if (code === 0)
            return "Clear";
        if (code <= 3)
            return "Cloudy";
        if (code === 45 || code === 48)
            return "Fog";
        if (code >= 51 && code <= 67)
            return "Rain";
        if (code >= 71 && code <= 77)
            return "Snow";
        if (code >= 80 && code <= 82)
            return "Showers";
        if (code >= 95)
            return "Storm";
        return "";
    }

    // Material Symbols Outlined codepoints for clear_day / cloudy / foggy /
    // rainy / ac_unit (snow) / thunderstorm, from Google's upstream
    // codepoints file.
    function wmoIcon(code) {
        if (code === 0)
            return "";
        if (code <= 3)
            return "";
        if (code === 45 || code === 48)
            return "";
        if (code >= 51 && code <= 67)
            return "";
        if (code >= 71 && code <= 77)
            return "";
        if (code >= 80 && code <= 82)
            return "";
        if (code >= 95)
            return "";
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
                    } else {
                        console.warn("[xidou] weather: ip geolocation failed: " + text);
                    }
                } catch (e) {
                    console.warn("[xidou] weather: failed to parse ip geolocation response: " + e);
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
                    } else {
                        console.warn("[xidou] weather: no geocoding match for city '" + root.cfg.city + "'");
                    }
                } catch (e) {
                    console.warn("[xidou] weather: failed to parse geocoding response: " + e);
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
                        root.icon = root.wmoIcon(parsed.current.weather_code);
                    }
                } catch (e) {
                    console.warn("[xidou] weather: failed to parse forecast response: " + e);
                }
            }
        }
    }

    // Re-fetch the forecast periodically once a location is known; does not
    // re-resolve location (the network is not going to move the laptop).
    Timer {
        id: forecastTimer
        interval: 900000 // 15 minutes
        repeat: true
        onTriggered: {
            forecast.running = false;
            forecast.running = true;
        }
    }

    // Runs the forecast fetch immediately and makes sure the periodic timer
    // above is (still) running -- NOT forecastTimer.start(): once the timer
    // is already running (true for every call after the very first), .start()
    // is a no-op (it just sets running to true, which it already is), so a
    // later re-resolution's forecastTimer.start() would silently do nothing
    // until the next natural 15-minute tick. Confirmed empirically while
    // wiring up the settings panel's "Refresh Now" -- this bug was
    // previously unreachable, since resolveLocation() used to only ever run
    // once per component lifetime.
    function triggerForecastFetch() {
        forecast.running = false;
        forecast.running = true;
        if (!forecastTimer.running)
            forecastTimer.start();
    }

    // Re-run on WeatherRefresh's trigger() (settings panel's "Refresh Now",
    // or `xidou msg weather refresh`) as well as at startup -- location is
    // still only re-resolved on an explicit trigger, never continuously,
    // for the same "don't hammer the geolocation/geocoding APIs" reason
    // the file-level comment already gives.
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

    // Component.onCompleted can fire before Config's own async file load
    // completes (confirmed empirically: Config.ready reads false at that
    // point on a normal cold start) -- reading `cfg` that early silently
    // resolves against the hardcoded defaults (auto_locate=true) instead of
    // the real config.toml, with nothing to ever self-correct once the real
    // values load, since nothing previously re-triggered resolution after
    // startup. hasResolvedOnce defers the initial resolution to Config's
    // first *ready* reload instead, exactly once -- later reloads (e.g. an
    // unrelated theme change) must not silently re-trigger a fresh
    // geolocation/geocoding call; only WeatherRefresh's explicit trigger
    // should do that after startup.
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
        id: row
        anchors.centerIn: parent
        spacing: Theme.fontSize / 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            visible: text.length > 0
            color: Theme.textMuted
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.fontSize
        }

        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            text: root.tempText
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }
}
