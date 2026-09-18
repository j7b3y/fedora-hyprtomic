import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../.." as Root

Scope {
    id: shelf

    // ── Icon resolution for pinned apps ───────────────────────────
    // GTK IconTheme is used (same as nwg-dock) so the icon pack on the
    // shelf matches the dock. The 6 pinned icons are passed explicitly
    // — no .desktop scan needed.
    property var iconCache: ({})

    readonly property string iconScript:
        Quickshell.env("HOME") + "/.config/quickshell/ii/scripts/resolve-icons.py"

    Process {
        id: iconResolveProc
        command: ["python3", shelf.iconScript, "org.mozilla.firefox",
            "system-file-manager", "com.mitchellh.ghostty",
            "com.bitwarden.desktop", "org.gnome.Loupe", "org.fcitx.fcitx5-config-qt"]
        stdout: StdioCollector {
            onStreamFinished: {
                var cache = {};
                var lines = text.trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("\t");
                    if (parts.length === 2 && parts[1] !== "") {
                        cache[parts[0]] = parts[1];
                    }
                }
                shelf.iconCache = cache;
            }
        }
    }

    Process {
        id: appLauncher
    }

    // Quick settings (control center) IPC — used by the bottom-right hot strip.
    Process {
        id: ccShowProc
        command: ["qs", "-c", "ii", "ipc", "call", "controlcenter", "show"]
    }

    Process {
        id: ccToggleProc
        command: ["qs", "-c", "ii", "ipc", "call", "controlcenter", "toggle"]
    }

    Component.onCompleted: iconResolveProc.running = true

    function resolveIcon(name) {
        if (!name) return "";
        if (name.startsWith("/")) return "file://" + name;
        var qtPath = Quickshell.iconPath(name, "");
        if (qtPath && qtPath !== "") return qtPath;
        var p = iconCache[name];
        return p ? "file://" + p : "";
    }

    function launchApp(cmd) {
        appLauncher.command = cmd;
        appLauncher.startDetached();
    }

    // ── Pinned apps ────────────────────────────────────────────────
    // Host apps / flatpaks are launched through distrobox-host-exec (the shell
    // runs inside the GUI container); fcitx5-configtool is a container app.
    readonly property var pinnedApps: [
        { icon: "org.mozilla.firefox",        cmd: ["distrobox-host-exec", "flatpak", "run", "org.mozilla.firefox"] },
        { icon: "system-file-manager",        cmd: ["distrobox-host-exec", "nemo"] },
        { icon: "com.mitchellh.ghostty",      cmd: ["distrobox-host-exec", "ghostty"] },
        { icon: "com.bitwarden.desktop",      cmd: ["distrobox-host-exec", "flatpak", "run", "com.bitwarden.desktop"] },
        { icon: "org.gnome.Loupe",            cmd: ["distrobox-host-exec", "flatpak", "run", "org.gnome.Loupe"] },
        { icon: "org.fcitx.fcitx5-config-qt", cmd: ["fcitx5-configtool"] },
    ]

    PanelWindow {
        id: panelWindow

        anchors {
            left: true
            right: true
            bottom: true
        }

        implicitHeight: Root.Theme.shelfHeight
        exclusiveZone: Root.Theme.shelfHeight
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell:shelf"

        Rectangle {
            id: shelfBackground
            anchors.fill: parent
            color: Root.Theme.shelfBg
            radius: Root.Theme.radiusLarge

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Root.Theme.radiusLarge
                color: parent.color
            }

            // ── Bottom-right hot strip (quick settings) ────────────
            // Thin strip along the shelf's bottom-right edge: hovering opens
            // the control center, clicking toggles it. It lives in the shelf's
            // reserved area, so it never steals input from windows.
            MouseArea {
                id: quickSettingsCorner
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: Math.min(parent.width / 3, 220)
                height: 6
                acceptedButtons: Qt.LeftButton
                hoverEnabled: true
                onEntered: ccCornerTimer.start()
                onExited: ccCornerTimer.stop()
                onClicked: ccToggleProc.running = true

                Timer {
                    id: ccCornerTimer
                    // Long enough to be deliberate: the pointer has to rest on
                    // the very bottom edge of the shelf.
                    interval: 500
                    repeat: false
                    onTriggered: ccShowProc.running = true
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Root.Theme.padding
                anchors.rightMargin: Root.Theme.padding
                spacing: Root.Theme.paddingSmall

                WorkspaceIndicator {
                    Layout.alignment: Qt.AlignVCenter
                }

                Item {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignVCenter
                    SearchButton { }
                }

                Item { Layout.fillWidth: true }

                // ── Pinned app icon buttons (centered) ────────────
                Row {
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter

                    Repeater {
                        model: shelf.pinnedApps

                        delegate: Item {
                            required property var modelData
                            required property int index

                            width: 36
                            height: 36

                            Rectangle {
                                anchors.fill: parent
                                radius: 10
                                color: btnArea.pressed
                                    ? Qt.rgba(1, 1, 1, 0.15)
                                    : btnArea.containsMouse
                                        ? Qt.rgba(1, 1, 1, 0.08)
                                        : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            Image {
                                anchors.centerIn: parent
                                width: 24
                                height: 24
                                source: shelf.resolveIcon(modelData.icon)
                                sourceSize: Qt.size(48, 48)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }

                            MouseArea {
                                id: btnArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: shelf.launchApp(modelData.cmd)
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                StatusArea {
                    Layout.alignment: Qt.AlignVCenter
                }

                Row {
                    spacing: Root.Theme.paddingSmall
                    Layout.alignment: Qt.AlignVCenter

                    Repeater {
                        model: SystemTray.items

                        delegate: Item {
                            required property SystemTrayItem modelData
                            width: 20; height: 20

                            Image {
                                anchors.fill: parent
                                source: modelData.icon
                                sourceSize.width: 20
                                sourceSize.height: 20
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.LeftButton)
                                        modelData.activate()
                                    else
                                        modelData.display(panelWindow, mouse.x, mouse.y)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
