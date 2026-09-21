pragma Singleton

import QtQuick
import Quickshell

// A shared "something wants weather re-resolved" signal -- each of the
// three weather displays (bar/modules/Weather.qml, control-center's
// WeatherSection.qml/ClockWeatherCard.qml) is self-contained by this
// codebase's own deliberate convention (each has its own duplicated
// location-resolution + forecast-fetch logic; not consolidated here), so
// this singleton doesn't own any weather state itself -- it's purely a
// trigger every one of those three listens to, via a generation counter
// rather than a signal so a listener that isn't alive at the moment of a
// call doesn't just silently miss it (matches Connections' own "property
// changed" semantics rather than needing a live signal connection at
// exactly the right moment).
//
// Reached via `xidou msg weather refresh` (shell.qml's "weather"
// IpcHandler) and the settings panel's own "Refresh Now" button.
Singleton {
    id: root

    property int generation: 0

    function trigger() {
        root.generation++;
    }
}
