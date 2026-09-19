import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../.." as Root

// Notification Center — bottom-sliding panel (ChromeOS / MD3 style)
// Shows notification history from NotificationService in a scrollable card list.
Scope {
    id: notifCenter

    property bool panelVisible: false
    // The window is created once and kept for the shell lifetime; only its
    // visibility and the panel position change on toggle.
    property bool _windowVisible: false
    property bool _panelOpen: false

    onPanelVisibleChanged: {
        if (panelVisible) {
            closeTimer.stop();
            _windowVisible = true;
            // Start from the hidden position and slide in on the next frame.
            _panelOpen = false;
            openDelayTimer.restart();
            // Opening the center counts as reading the notifications.
            NotificationService.markAllRead();
        } else {
            openDelayTimer.stop();
            _panelOpen = false;
            closeTimer.restart();
        }
    }

    Timer {
        id: openDelayTimer
        interval: 16
        repeat: false
        onTriggered: if (notifCenter.panelVisible) notifCenter._panelOpen = true
    }

    Timer {
        id: closeTimer
        interval: Root.Theme.animDuration + 40
        repeat: false
        onTriggered: if (!notifCenter.panelVisible) notifCenter._windowVisible = false
    }

    // ── IPC Handler ──────────────────────────────────────────────
    IpcHandler {
        target: "notifications"

        function toggle(): void { notifCenter.panelVisible = !notifCenter.panelVisible; }
        function show(): void { notifCenter.panelVisible = true; }
        function hide(): void { notifCenter.panelVisible = false; }
    }

    // The window is created once and kept for the shell lifetime; only its
    // visibility and the panel position change on toggle.
    Loader {
        active: true

        sourceComponent: PanelWindow {
            id: panelWindow
            visible: notifCenter._windowVisible

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.namespace: "quickshell:notifications"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: notifCenter._panelOpen
                ? WlrKeyboardFocus.Exclusive
                : WlrKeyboardFocus.None

            Shortcut {
                sequence: "Escape"
                onActivated: notifCenter.panelVisible = false
            }

            // Click-outside close
            MouseArea {
                anchors.fill: parent
                onClicked: notifCenter.panelVisible = false
            }

            // Clip region: bottom edge at shelf top
            Item {
                id: panelClip
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Root.Theme.shelfHeight
                clip: true

                Rectangle {
                    id: panel

                    width: Root.Theme.panelWidth
                    anchors.right: parent.right
                    anchors.rightMargin: Root.Theme.spacingSmall

                    height: Math.min(panelContent.implicitHeight, panelClip.height - Root.Theme.spacingSmall * 2)

                    // Slide between the clip's bottom edge (hidden) and just
                    // above the shelf (shown); a direct binding keeps the
                    // position correct on the very first frame.
                    y: notifCenter._panelOpen
                        ? panelClip.height - height - Root.Theme.spacingSmall
                        : panelClip.height

                    Behavior on y {
                        NumberAnimation {
                            duration: Root.Theme.animDuration
                            easing.type: Easing.OutCubic
                        }
                    }

                    radius: Root.Theme.panelRadius
                    color: Qt.rgba(Root.Theme.panelBg.r, Root.Theme.panelBg.g, Root.Theme.panelBg.b, 0.78)
                    border.width: 1
                    border.color: Qt.rgba(Root.Theme.panelBorder.r,
                                           Root.Theme.panelBorder.g,
                                           Root.Theme.panelBorder.b,
                                           0.5)
                    clip: true

                    // Block click-through
                    MouseArea {
                        anchors.fill: parent
                    }

                    ColumnLayout {
                        id: panelContent
                        width: panel.width
                        spacing: 0

                        // ── Notification List ───────────────────────
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: NotificationService.count > 0
                                ? Math.min(notifListView.contentHeight + 20, 400)
                                : 160

                            // Empty state
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 12
                                visible: NotificationService.count === 0

                                Text {
                                    text: "󰂚"
                                    color: Root.Theme.textSecondary
                                    font.family: Root.Theme.fontFamily
                                    font.pixelSize: 48
                                    opacity: 0.3
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Text {
                                    text: "No notifications"
                                    color: Root.Theme.textSecondary
                                    font.family: Root.Theme.fontFamily
                                    font.pixelSize: Root.Theme.fontSizeNormal
                                    opacity: 0.5
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }

                            // Scrollable notification list
                            ListView {
                                id: notifListView
                                anchors.fill: parent
                                anchors.topMargin: 12
                                anchors.bottomMargin: 8
                                clip: true
                                visible: NotificationService.count > 0
                                spacing: 0
                                boundsMovement: Flickable.StopAtBounds

                                model: NotificationService.notifications

                                delegate: NotificationItem {
                                    width: notifListView.width
                                    notifId: modelData.id
                                    appName: modelData.appName
                                    summary: modelData.summary
                                    body: modelData.body
                                    urgency: modelData.urgency
                                    timestamp: modelData.timestamp
                                    timeAgo: NotificationService.relativeTime(modelData.timestamp)

                                    onDismissed: function(id) {
                                        NotificationService.removeNotification(id);
                                    }
                                }

                                ScrollBar.vertical: ScrollBar {
                                    active: true
                                    policy: ScrollBar.AsNeeded
                                }
                            }
                        }

                        // ── Footer — Clear All ──────────────────────
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            Layout.topMargin: 0
                            Layout.bottomMargin: 8
                            visible: NotificationService.count > 0

                            // Clear all — text button, right-aligned
                            Rectangle {
                                anchors.right: parent.right
                                anchors.rightMargin: Root.Theme.paddingLarge
                                anchors.verticalCenter: parent.verticalCenter
                                width: clearAllLabel.implicitWidth + 24
                                height: 36
                                radius: 18
                                color: clearAllMA.containsMouse
                                    ? Qt.rgba(Root.Theme.textSecondary.r, Root.Theme.textSecondary.g, Root.Theme.textSecondary.b, 0.12)
                                    : "transparent"

                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    id: clearAllLabel
                                    anchors.centerIn: parent
                                    text: "Clear all"
                                    color: Root.Theme.textSecondary
                                    font.family: Root.Theme.fontFamily
                                    font.pixelSize: Root.Theme.fontSizeNormal
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    id: clearAllMA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: NotificationService.clearAll()
                                }
                            }
                        }
                    }
                }  // end Rectangle (panel)
            }  // end Item (panelClip)
        }
    }
}
