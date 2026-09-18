import QtQuick
import Quickshell.Io
import "../../config"

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
                        forecastTimer.start();
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
                        forecastTimer.start();
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
        triggeredOnStart: true
        onTriggered: {
            forecast.running = false;
            forecast.running = true;
        }
    }

    Component.onCompleted: {
        if (!cfg.enabled)
            return;
        if (cfg.auto_locate) {
            ipLocate.running = true;
        } else if (cfg.city && cfg.city.length > 0) {
            geocode.running = true;
        } else {
            forecastTimer.start();
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.fontSize / 4

        Text {
            text: root.icon
            visible: text.length > 0
            color: Theme.textMuted
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.fontSize
        }

        Text {
            id: label
            text: root.tempText
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }
}
