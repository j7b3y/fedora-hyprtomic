pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../.." as Root

// WorkspaceSwitcher — bar-center desktop pager (1..10).
// Each cell shows its number and the icon of the app that owns the window on
// that workspace (the activated window wins, otherwise the first one found).
Item {
    id: root

    readonly property int workspaceCount: 10
    readonly property int focusedWorkspaceId: Hyprland.focusedMonitor?.activeWorkspace?.id ?? -1

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    function toplevelFor(wsId) {
        const list = Hyprland.toplevels.values;
        let fallback = null;
        for (let i = 0; i < list.length; ++i) {
            const t = list[i];
            if (!t.workspace || t.workspace.id !== wsId)
                continue;
            if (t.activated)
                return t;
            if (!fallback)
                fallback = t;
        }
        return fallback;
    }

    Row {
        id: row
        spacing: 4

        Repeater {
            model: root.workspaceCount

            delegate: Item {
                id: cell
                required property int index

                readonly property int wsId: index + 1
                readonly property var toplevel: root.toplevelFor(wsId)
                readonly property bool occupied: toplevel !== null
                readonly property bool active: root.focusedWorkspaceId === wsId
                readonly property string appId: toplevel && toplevel.wayland ? toplevel.wayland.appId : ""
                readonly property string iconSource: appId !== "" ? Quickshell.iconPath(appId, "") : ""

                width: 30
                height: 32

                Rectangle {
                    anchors.fill: parent
                    radius: Root.Theme.radiusSmall
                    color: cell.active ? Root.Theme.accent
                         : cell.occupied ? Root.Theme.surfaceContainerHigh
                         : "transparent"
                    Behavior on color { ColorAnimation { duration: Root.Theme.animDurationFast } }
                }

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: cell.iconSource !== "" ? -3 : 0
                    text: cell.wsId
                    color: cell.active ? Root.Theme.bg : Root.Theme.textSecondary
                    font.family: Root.Theme.fontFamily
                    font.pixelSize: Root.Theme.fontSizeNormal
                    font.weight: cell.active ? Font.DemiBold : Font.Normal

                    Behavior on color { ColorAnimation { duration: Root.Theme.animDurationFast } }
                }

                Image {
                    visible: cell.iconSource !== ""
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: 3
                    anchors.bottomMargin: 3
                    width: 13
                    height: 13
                    source: cell.iconSource
                    sourceSize: Qt.size(26, 26)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch("workspace " + cell.wsId)
                    onWheel: (event) => {
                        if (event.angleDelta.y > 0)
                            Hyprland.dispatch("workspace e-1");
                        else if (event.angleDelta.y < 0)
                            Hyprland.dispatch("workspace e+1");
                    }
                }
            }
        }
    }
}
