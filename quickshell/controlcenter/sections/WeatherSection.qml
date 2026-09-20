import QtQuick
import Quickshell.Io
import "../../config"
import ".." as ControlCenter

// Fuller forecast than Home's compact clock+weather card: current
// conditions plus a 5-day strip. Same Open-Meteo API and location
// resolution (auto_locate -> city -> lat/long) as bar/modules/Weather.qml
// and the Home card, kept self-contained rather than shared per this
// codebase's existing per-module convention -- just asks Open-Meteo for
// `daily` fields too in the same request instead of a second endpoint.
Item {
    id: root

    readonly property var cfg: Config.data.weather

    property real latitude: cfg.latitude
    property real longitude: cfg.longitude
    property string tempText: ""
    property string conditionText: ""
    property string weatherIcon: ""
    property var dailyForecast: [] // [{day, icon, hi, lo}]

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
                        forecastTimer.start();
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
                        forecastTimer.start();
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
            + "&current=temperature_2m,weather_code"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min"
            + "&timezone=auto"
            + "&temperature_unit=" + (root.cfg.units === "fahrenheit" ? "fahrenheit" : "celsius")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text);
                    if (parsed.current) {
                        root.tempText = Math.round(parsed.current.temperature_2m) + "°" + (root.cfg.units === "fahrenheit" ? "F" : "C");
                        root.conditionText = root.wmoDescription(parsed.current.weather_code);
                        root.weatherIcon = root.wmoIcon(parsed.current.weather_code);
                    }
                    if (parsed.daily && parsed.daily.time) {
                        var days = [];
                        for (var i = 0; i < parsed.daily.time.length; i++) {
                            var d = new Date(parsed.daily.time[i]);
                            days.push({
                                day: d.toLocaleDateString(Qt.locale(), "ddd"),
                                icon: root.wmoIcon(parsed.daily.weather_code[i]),
                                hi: Math.round(parsed.daily.temperature_2m_max[i]),
                                lo: Math.round(parsed.daily.temperature_2m_min[i])
                            });
                        }
                        root.dailyForecast = days;
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
        triggeredOnStart: true
        onTriggered: {
            forecast.running = false;
            forecast.running = true;
        }
    }

    Component.onCompleted: {
        if (!cfg.enabled)
            return;
        if (cfg.auto_locate)
            ipLocate.running = true;
        else if (cfg.city && cfg.city.length > 0)
            geocode.running = true;
        else
            forecastTimer.start();
    }

    ControlCenter.Card {
        anchors.fill: parent
        visible: root.cfg.enabled

        Column {
            anchors.fill: parent
            anchors.margins: Theme.fontSize
            spacing: Theme.fontSize

            Row {
                width: parent.width
                spacing: Theme.fontSize
                visible: root.tempText !== ""

                Text {
                    text: root.weatherIcon
                    color: Theme.text
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fontSize * 3
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: root.tempText
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize * 2
                        font.bold: true
                    }

                    Text {
                        text: root.conditionText
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                }
            }

            Text {
                visible: root.tempText === ""
                text: "Fetching weather…"
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            Row {
                width: parent.width
                spacing: Theme.fontSize / 2
                visible: root.dailyForecast.length > 0

                Repeater {
                    model: root.dailyForecast
                    delegate: Rectangle {
                        required property var modelData

                        width: (parent.width - (root.dailyForecast.length - 1) * (Theme.fontSize / 2)) / Math.max(1, root.dailyForecast.length)
                        height: Theme.fontSize * 6
                        radius: Theme.radius / 2
                        color: Theme.surfaceAlt
                        border.width: 1
                        border.color: Theme.border

                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.fontSize / 4

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.day
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize * 0.85
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.icon
                                color: Theme.text
                                font.family: Theme.iconFontFamily
                                font.pixelSize: Theme.fontSize * 1.3
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.hi + "° / " + modelData.lo + "°"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize * 0.85
                            }
                        }
                    }
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: !root.cfg.enabled
        text: "Weather is disabled in config.toml"
        color: Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }
}
