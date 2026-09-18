import QtQuick
import Quickshell
import "../config"
import "modules" as Modules

// The bar panel: a single PanelWindow reserving strut space, top or bottom
// per config.toml [bar].position. Left/center/right module lists are read
// from config and resolved against `moduleComponents` below — an unknown
// module name is skipped with a warning rather than rendered broken, so a
// typo in modules_left/center/right degrades gracefully instead of crashing
// the bar.
PanelWindow {
    id: bar

    property int monitorNum: 0

    readonly property var barConfig: Config.data.bar
    readonly property bool onTop: barConfig.position !== "bottom"

    implicitHeight: barConfig.height
    exclusiveZone: barConfig.height
    color: Theme.background

    anchors.left: true
    anchors.right: true
    anchors.top: onTop
    anchors.bottom: !onTop

    readonly property var moduleComponents: ({
        logo: logoComponent,
        workspaces: workspacesComponent,
        clock: clockComponent,
        media: mediaComponent,
        weather: weatherComponent,
        tray: trayComponent,
        mem: memComponent,
        cpu: cpuComponent,
        bluetooth: bluetoothComponent,
        volume: volumeComponent,
        power: powerComponent
    })

    function resolveModules(names) {
        var out = [];
        for (var i = 0; i < names.length; i++) {
            var name = names[i];
            if (moduleComponents[name]) {
                out.push({ name: name, component: moduleComponents[name] });
            } else {
                console.warn("[xidou] bar: module '" + name + "' is not implemented yet, skipping");
            }
        }
        return out;
    }

    Component {
        id: logoComponent
        Modules.Logo {}
    }

    Component {
        id: workspacesComponent
        Modules.Workspaces { monitorNum: bar.monitorNum }
    }

    Component {
        id: clockComponent
        Modules.Clock {}
    }

    Component {
        id: mediaComponent
        Modules.Media {}
    }

    Component {
        id: weatherComponent
        Modules.Weather {}
    }

    Component {
        id: trayComponent
        Modules.Tray {}
    }

    Component {
        id: memComponent
        Modules.Mem {}
    }

    Component {
        id: cpuComponent
        Modules.Cpu {}
    }

    Component {
        id: bluetoothComponent
        Modules.Bluetooth {}
    }

    Component {
        id: volumeComponent
        Modules.Volume {}
    }

    Component {
        id: powerComponent
        Modules.Power {}
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: Theme.fontSize / 2
        anchors.rightMargin: Theme.fontSize / 2

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.fontSize / 2
            height: parent.height

            Repeater {
                model: bar.resolveModules(bar.barConfig.modules_left)
                Loader {
                    required property var modelData
                    height: parent.height
                    sourceComponent: modelData.component
                }
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: Theme.fontSize / 2
            height: parent.height

            Repeater {
                model: bar.resolveModules(bar.barConfig.modules_center)
                Loader {
                    required property var modelData
                    height: parent.height
                    sourceComponent: modelData.component
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.fontSize / 2
            height: parent.height

            Repeater {
                model: bar.resolveModules(bar.barConfig.modules_right)
                Loader {
                    required property var modelData
                    height: parent.height
                    sourceComponent: modelData.component
                }
            }
        }
    }
}
