import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../.." as Root

Scope {
    id: controlCenter

    property bool panelVisible: false
    // The PanelWindow itself lives for the whole shell lifetime. It becomes
    // visible for the duration of the open/close animation only, so the
    // surface is not destroyed and re-created (at the wrong position) on
    // every toggle.
    property bool _windowVisible: false
    // Drives the inner panel position; true = fully shown above the shelf.
    property bool _panelOpen: false
    property string currentPage: "main"

    property string wifiStatus: ""
    property bool wifiEnabled: true
    property bool btEnabled: true
    property int btConnectedCount: 0
    readonly property bool airplaneModeEnabled: !wifiEnabled && !btEnabled
    property bool brightnessAvailable: false

    onPanelVisibleChanged: {
        if (panelVisible) {
            closeTimer.stop()
            _windowVisible = true
            // Start from the hidden position and slide up on the next frame.
            _panelOpen = false
            openDelayTimer.restart()
            wifiStatusProc.running = true
            btStatusProc.running = true
            btConnectedProc.running = true
            brightnessCheckProc.running = true
        } else {
            openDelayTimer.stop()
            // Slide down first; closeTimer hides the window afterwards.
            _panelOpen = false
            closeTimer.restart()
            resetPageTimer.running = true
        }
    }

    // Give the surface one frame to settle before starting the slide-up.
    Timer {
        id: openDelayTimer
        interval: 16
        repeat: false
        onTriggered: if (controlCenter.panelVisible) controlCenter._panelOpen = true
    }

    // Hide the window only after the slide-down animation finished.
    Timer {
        id: closeTimer
        interval: Root.Theme.animDuration + 40
        repeat: false
        onTriggered: if (!controlCenter.panelVisible) controlCenter._windowVisible = false
    }

    Timer {
        id: resetPageTimer
        interval: 300
        repeat: false
        onTriggered: controlCenter.currentPage = "main"
    }

    // ── Status processes ──────────────────────────────────────────

    // WiFi: nmcli -t -f TYPE,STATE,CONNECTION device
    Process {
        id: wifiStatusProc
        command: ["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "device"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                var found = false;
                for (var i = 0; i < lines.length; i++) {
                    // Some lines may have escaped colons; split on unescaped ":"
                    var parts = lines[i].split(":");
                    if (parts.length >= 1 && parts[0] === "wifi") {
                        found = true;
                        var state = parts.length >= 2 ? parts[1] : "";
                        var conn = parts.length >= 3 ? parts.slice(2).join(":") : "";
                        if (state === "connected" || state === "connecting (getting IP address)" || state.startsWith("connecting")) {
                            controlCenter.wifiEnabled = true;
                            controlCenter.wifiStatus = conn !== "" ? conn : "Connected";
                        } else if (state === "unavailable" || state === "unmanaged") {
                            controlCenter.wifiEnabled = false;
                            controlCenter.wifiStatus = "";
                        } else {
                            controlCenter.wifiEnabled = true;
                            controlCenter.wifiStatus = "";
                        }
                        break;
                    }
                }
                if (!found) {
                    controlCenter.wifiEnabled = false;
                    controlCenter.wifiStatus = "";
                }
            }
        }
    }

    // BT: bluetoothctl show
    Process {
        id: btStatusProc
        command: ["bluetoothctl", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                controlCenter.btEnabled = text.includes("Powered: yes");
            }
        }
    }

    // BT connected count: bluetoothctl devices Connected
    Process {
        id: btConnectedProc
        command: ["bluetoothctl", "devices", "Connected"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                var count = 0;
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i].trim().startsWith("Device"))
                        count++;
                }
                controlCenter.btConnectedCount = count;
            }
        }
    }

    // DND toggle removed: HyprTomic's notifications are handled by quickshell's
    // NotificationServer (no dunst), so there is no daemon to pause.

    // Brightness hardware detection
    Process {
        id: brightnessCheckProc
        command: ["brightnessctl", "--class=backlight", "-l"]
        stdout: StdioCollector {
            onStreamFinished: {
                controlCenter.brightnessAvailable = text.trim() !== ""
            }
        }
    }

    // ── Toggle actions ────────────────────────────────────────────

    Process {
        id: wifiToggleProc
        command: ["nmcli", "radio", "wifi", controlCenter.wifiEnabled ? "off" : "on"]
        onExited: wifiStatusProc.running = true
    }

    Process {
        id: btToggleProc
        command: ["bluetoothctl", "power", controlCenter.btEnabled ? "off" : "on"]
        onExited: btStatusProc.running = true
    }

    Process {
        id: airplaneWifiProc
        command: ["nmcli", "radio", "wifi", controlCenter.airplaneModeEnabled ? "on" : "off"]
        onExited: wifiStatusProc.running = true
    }

    Process {
        id: airplaneBtProc
        command: ["bluetoothctl", "power", controlCenter.airplaneModeEnabled ? "on" : "off"]
        onExited: btStatusProc.running = true
    }

    // ── Theme persistence ────────────────────────────────────────
    Process {
        id: themeSaveProc
        command: ["sh", "-c", "echo '" + Root.Theme.currentTheme + "' > ~/.config/quickshell/ii/current-theme"]
    }

    Process {
        id: themeApplyProc
        command: ["sh", "-c", "~/.config/quickshell/ii/scripts/apply-theme.sh " + Root.Theme.currentTheme]
    }

    // Re-apply the saved theme on every shell start so Hyprland / Qt / GTK /
    // ghostty stay in sync even when the theme did not change.
    Component.onCompleted: themeApplyProc.running = true

    Connections {
        target: Root.Theme
        function onCurrentThemeChanged() {
            themeSaveProc.running = true;
            themeApplyProc.running = true;
        }
    }

    // Poll status every 8s while panel is visible
    Timer {
        interval: 8000
        running: controlCenter.panelVisible
        repeat: true
        onTriggered: {
            wifiStatusProc.running = true
            btStatusProc.running = true
            btConnectedProc.running = true
            brightnessCheckProc.running = true
        }
    }

    // ── IPC handlers ──────────────────────────────────────────────

    IpcHandler {
        target: "controlcenter"

        function toggle(): void { controlCenter.panelVisible = !controlCenter.panelVisible }
        function show(): void { controlCenter.panelVisible = true }
        function hide(): void { controlCenter.panelVisible = false }
    }

    // ── Overlay window / panel ────────────────────────────────────

    // The window is loaded once and kept for the shell's lifetime; only its
    // visibility and the inner panel position change on toggle. Re-creating
    // the layer surface on every open caused a one-frame flash at the wrong
    // position (and the old state machine could get stuck).
    Loader {
        active: true

        sourceComponent: PanelWindow {
            id: panelWindow
            visible: controlCenter._windowVisible

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.namespace: "quickshell:controlcenter"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: controlCenter._panelOpen
                ? WlrKeyboardFocus.Exclusive
                : WlrKeyboardFocus.None

            Shortcut {
                sequence: "Escape"
                onActivated: {
                    if (controlCenter.currentPage !== "main")
                        controlCenter.currentPage = "main"
                    else
                        controlCenter.panelVisible = false
                }
            }

            // click-outside close area
            MouseArea {
                anchors.fill: parent
                onClicked: controlCenter.panelVisible = false
            }

            // Clip region: bottom edge sits at shelf top.
            // The panel animates inside this region so it appears to
            // emerge from the shelf rather than sliding through it.
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

                    // Slide between the clip's bottom edge (hidden) and just
                    // above the shelf (shown). A direct binding + Behavior
                    // keeps the position correct on the very first frame.
                    y: controlCenter._panelOpen
                        ? parent.height - height - Root.Theme.spacingSmall
                        : parent.height

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

                // block click-through to overlay close area
                MouseArea {
                    anchors.fill: parent
                }

                implicitHeight: pageContainer.height

                Item {
                    id: pageContainer
                    width: panel.width
                    height: mainPage.height

                    // MAIN PAGE
                    Item {
                        id: mainPage
                        width: pageContainer.width
                        height: mainContent.implicitHeight + Root.Theme.spacingLarge * 2
                        x: controlCenter.currentPage === "main" ? 0 : -pageContainer.width

                        Behavior on x {
                            NumberAnimation {
                                duration: Root.Theme.animDuration
                                easing.type: Easing.OutCubic
                            }
                        }

                        ColumnLayout {
                            id: mainContent
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                leftMargin: Root.Theme.spacingLarge
                                rightMargin: Root.Theme.spacingLarge
                                topMargin: Root.Theme.spacingLarge
                            }
                            spacing: Root.Theme.spacingMedium

                            GridLayout {
                                columns: 2
                                columnSpacing: Root.Theme.spacingSmall
                                rowSpacing: Root.Theme.spacingSmall
                                Layout.fillWidth: true

                                FeatureTile {
                                    Layout.fillWidth: true
                                    active: controlCenter.wifiEnabled
                                    icon: controlCenter.wifiEnabled ? "󰖩" : "󰖪"
                                    label: "Wi-Fi"
                                    subtitle: {
                                        if (!controlCenter.wifiEnabled)
                                            return "Disabled"
                                        if (controlCenter.wifiStatus !== "")
                                            return controlCenter.wifiStatus
                                        return "Not connected"
                                    }
                                    hasDetail: true
                                    onClicked: wifiToggleProc.running = true
                                    onDetailClicked: controlCenter.currentPage = "wifi"
                                }

                                FeatureTile {
                                    Layout.fillWidth: true
                                    active: controlCenter.btEnabled
                                    icon: controlCenter.btEnabled ? "󰂯" : "󰂲"
                                    label: "Bluetooth"
                                    subtitle: {
                                        if (!controlCenter.btEnabled)
                                            return "Disabled"
                                        if (controlCenter.btConnectedCount > 0)
                                            return controlCenter.btConnectedCount + " connected"
                                        return "No devices"
                                    }
                                    hasDetail: true
                                    onClicked: btToggleProc.running = true
                                    onDetailClicked: controlCenter.currentPage = "bluetooth"
                                }

                                FeatureTile {
                                    Layout.fillWidth: true
                                    active: controlCenter.airplaneModeEnabled
                                    icon: "󰀝"
                                    label: "Airplane Mode"
                                    subtitle: controlCenter.airplaneModeEnabled ? "Enabled" : "Disabled"
                                    hasDetail: false
                                    onClicked: {
                                        airplaneWifiProc.running = true
                                        airplaneBtProc.running = true
                                    }
                                }

                                FeatureTile {
                                    Layout.columnSpan: 2
                                    Layout.fillWidth: true
                                    active: true
                                    icon: "󰏘"
                                    label: "Theme"
                                    subtitle: Root.Theme.themeName
                                    hasDetail: true
                                    onDetailClicked: controlCenter.currentPage = "theme"
                                    onClicked: controlCenter.currentPage = "theme"
                                }
                            }

                            VolumeSection {
                                Layout.fillWidth: true
                            }

                            BrightnessSection {
                                visible: controlCenter.brightnessAvailable
                                Layout.fillWidth: true
                            }
                        }
                    }

                    // WIFI SUB-PAGE
                    WifiSection {
                        width: pageContainer.width
                        height: pageContainer.height
                        x: controlCenter.currentPage === "wifi" ? 0 : pageContainer.width

                        Behavior on x {
                            NumberAnimation {
                                duration: Root.Theme.animDuration
                                easing.type: Easing.OutCubic
                            }
                        }

                        onBack: {
                            controlCenter.currentPage = "main"
                            wifiStatusProc.running = true
                        }
                    }

                    // BLUETOOTH SUB-PAGE
                    BluetoothSection {
                        width: pageContainer.width
                        height: pageContainer.height
                        x: controlCenter.currentPage === "bluetooth" ? 0 : pageContainer.width

                        Behavior on x {
                            NumberAnimation {
                                duration: Root.Theme.animDuration
                                easing.type: Easing.OutCubic
                            }
                        }

                        onBack: {
                            controlCenter.currentPage = "main"
                            btStatusProc.running = true
                            btConnectedProc.running = true
                        }
                    }

                    // THEME SUB-PAGE
                    ThemeSection {
                        width: pageContainer.width
                        height: pageContainer.height
                        x: controlCenter.currentPage === "theme" ? 0 : pageContainer.width

                        Behavior on x {
                            NumberAnimation {
                                duration: Root.Theme.animDuration
                                easing.type: Easing.OutCubic
                            }
                        }

                        onBack: {
                            controlCenter.currentPage = "main"
                        }
                    }
                }
            }  // end Rectangle (panel)
            }  // end Item (panelClip)
        }
    }
}
