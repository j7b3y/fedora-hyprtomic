pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../.." as Root

// WorkspaceSwitcher — bar-center desktop pager (1..10).
// Each cell shows its number and the icon of the app that owns the window on
// that workspace (the activated window wins, otherwise the first one found).
Item {
    id: root

    readonly property int workspaceCount: 10
    readonly property int focusedWorkspaceId: Hyprland.focusedMonitor?.activeWorkspace?.id ?? -1

    // Window classes present on any workspace. Changes when windows open,
    // close or move, which triggers a debounced icon resolution.
    readonly property string classSignature: {
        const ids = {};
        const list = Hyprland.toplevels.values;
        for (let i = 0; i < list.length; ++i) {
            const t = list[i];
            const id = t && t.wayland ? t.wayland.appId : "";
            if (id)
                ids[id] = true;
        }
        return Object.keys(ids).sort().join("|");
    }

    property var iconCache: ({})
    readonly property string iconScript:
        Quickshell.env("HOME") + "/.config/quickshell/ii/scripts/resolve-icons.py"

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    onClassSignatureChanged: if (classSignature !== "") iconQueryTimer.restart()
    Component.onCompleted: if (classSignature !== "") iconQueryTimer.start()

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

    // Resolved through StartupWMClass first (window classes and icon names do
    // not always match, e.g. google-chrome -> com.google.Chrome).
    function iconFor(appId) {
        if (!appId)
            return "";
        return root.iconCache[appId] || Quickshell.iconPath(appId, "");
    }

    Timer {
        id: iconQueryTimer
        interval: 250
        repeat: false
        onTriggered: {
            const ids = root.classSignature.split("|").filter(id => id !== "");
            if (ids.length === 0)
                return;
            iconResolveProc.command = ["python3", root.iconScript, "--wmclass"].concat(ids);
            iconResolveProc.running = true;
        }
    }

    Process {
        id: iconResolveProc
        stdout: StdioCollector {
            onStreamFinished: {
                const cache = Object.assign({}, root.iconCache);
                const lines = text.trim().split("\n");
                for (let i = 0; i < lines.length; ++i) {
                    const parts = lines[i].split("\t");
                    if (parts.length === 2 && parts[1] !== "")
                        cache[parts[0]] = "file://" + parts[1];
                }
                root.iconCache = cache;
            }
        }
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
                readonly property string iconSource: root.iconFor(appId)

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
