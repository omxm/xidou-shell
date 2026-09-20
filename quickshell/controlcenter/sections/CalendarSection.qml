import QtQuick
import "../../config"
import ".." as ControlCenter

// A plain month-grid date picker -- no CalDAV/ICS backend exists anywhere
// in the repo or CLAUDE.md's roadmap to sync against, so this is scoped to
// what's real and useful without one: today highlighted, month navigation.
Item {
    id: root

    property date viewDate: new Date()
    readonly property date today: new Date()

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    function daysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate();
    }

    // Monday-first grid (day-of-week index remapped so Sunday=6 instead of 0).
    readonly property var gridDays: {
        var year = viewDate.getFullYear();
        var month = viewDate.getMonth();
        var firstDow = (new Date(year, month, 1).getDay() + 6) % 7;
        var count = daysInMonth(year, month);
        var prevCount = daysInMonth(year, month - 1 < 0 ? 11 : month - 1);
        var days = [];
        for (var i = 0; i < firstDow; i++)
            days.push({ day: prevCount - firstDow + i + 1, inMonth: false, date: null });
        for (var d = 1; d <= count; d++)
            days.push({ day: d, inMonth: true, date: new Date(year, month, d) });
        var nextDay = 1;
        while (days.length % 7 !== 0)
            days.push({ day: nextDay++, inMonth: false, date: null });
        return days;
    }

    ControlCenter.Card {
        anchors.fill: parent

        Column {
            anchors.fill: parent
            anchors.margins: Theme.fontSize
            spacing: Theme.fontSize / 2

            Item {
                width: parent.width
                height: Theme.fontSize * 1.8

                Text {
                    anchors.left: parent.left
                    text: "" // chevron_left
                    color: Theme.text
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fontSize * 1.2
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -Theme.fontSize / 2
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.viewDate = new Date(root.viewDate.getFullYear(), root.viewDate.getMonth() - 1, 1)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: root.viewDate.toLocaleDateString(Qt.locale(), "MMMM yyyy")
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize * 1.05
                    font.bold: true
                }

                Text {
                    anchors.right: parent.right
                    text: "" // chevron_right
                    color: Theme.text
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fontSize * 1.2
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -Theme.fontSize / 2
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.viewDate = new Date(root.viewDate.getFullYear(), root.viewDate.getMonth() + 1, 1)
                    }
                }
            }

            Grid {
                width: parent.width
                columns: 7
                rowSpacing: Theme.fontSize / 4

                Repeater {
                    model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                    delegate: Text {
                        required property string modelData
                        width: parent.parent.width / 7
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize * 0.8
                    }
                }

                Repeater {
                    model: root.gridDays
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool isToday: modelData.inMonth && root.sameDay(modelData.date, root.today)

                        width: parent.parent.width / 7
                        height: Theme.fontSize * 2.2
                        radius: Theme.radius / 2
                        color: isToday ? Theme.accent : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: modelData.day
                            color: isToday ? Theme.background : (modelData.inMonth ? Theme.text : Theme.textMuted)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize * 0.9
                        }
                    }
                }
            }

            Text {
                text: "No calendar sources configured yet"
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 0.85
            }
        }
    }
}
