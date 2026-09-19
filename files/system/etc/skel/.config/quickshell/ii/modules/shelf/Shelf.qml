pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../.." as Root

Scope {
    id: shelf

    // Quick settings (control center) IPC — used by the bottom-right hot strip.
    Process {
        id: ccShowProc
        command: ["qs", "-c", "ii", "ipc", "call", "controlcenter", "show"]
    }

    Process {
        id: ccToggleProc
        command: ["qs", "-c", "ii", "ipc", "call", "controlcenter", "toggle"]
    }

    // ── System tray menu ───────────────────────────────────────────
    // SystemTrayItem.display() wants window-relative coordinates; the
    // MouseArea's own coordinates are item-local, so map them to the window
    // (scene) first. Platform menus also need `//@ pragma UseQApplication`
    // in the root shell.qml.
    function showTrayMenu(item, mouse, source) {
        if (!item || !item.hasMenu) return;
        const p = source.mapToItem(null, mouse.x, mouse.y);
        item.display(panelWindow, p.x, p.y);
    }

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
            // Round only the top corners. Squaring the bottom with an overlay
            // rectangle used to stack two semi-transparent layers, which made
            // the bottom 14px (~1/3 of the bar) visibly darker.
            topLeftRadius: Root.Theme.radiusLarge
            topRightRadius: Root.Theme.radiusLarge

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

            // Left cluster: launcher + desktop pager, left-aligned.
            RowLayout {
                anchors.left: parent.left
                anchors.leftMargin: Root.Theme.padding
                anchors.verticalCenter: parent.verticalCenter
                spacing: Root.Theme.paddingSmall

                // App launcher (quickshell launcher) — leftmost item.
                SearchButton {
                    Layout.alignment: Qt.AlignVCenter
                }

                // Desktop pager 1..10 with the app icon of each occupied
                // workspace (replaces the old pinned-app shortcuts).
                WorkspaceSwitcher {
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            // Clock centred on the bar (independent of the cluster widths).
            ClockWidget {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
            }

            // Right cluster: resident apps + status icons.
            RowLayout {
                anchors.right: parent.right
                anchors.rightMargin: Root.Theme.padding
                anchors.verticalCenter: parent.verticalCenter
                spacing: Root.Theme.paddingSmall

                // Resident apps (system tray) sit before the status cluster.
                Row {
                    spacing: Root.Theme.paddingSmall
                    Layout.alignment: Qt.AlignVCenter

                    Repeater {
                        model: SystemTray.items

                        delegate: Item {
                            id: trayItem
                            required property SystemTrayItem modelData
                            width: 20; height: 20

                            Image {
                                anchors.fill: parent
                                source: trayItem.modelData.icon
                                sourceSize.width: 20
                                sourceSize.height: 20
                            }

                            MouseArea {
                                id: trayMouse
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.LeftButton && !trayItem.modelData.onlyMenu) {
                                        trayItem.modelData.activate();
                                    } else {
                                        shelf.showTrayMenu(trayItem.modelData, mouse, trayMouse);
                                    }
                                }
                            }
                        }
                    }
                }

                // Network / Bluetooth / Battery / Volume.
                StatusArea {
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }
}
