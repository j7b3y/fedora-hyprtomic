pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../.." as Root

Item {
    id: root

    implicitHeight: contentColumn.implicitHeight
    implicitWidth: parent ? parent.width : 300

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    property var audio: Pipewire.defaultAudioSink
    readonly property real currentVolume: audio && audio.audio ? audio.audio.volume : 0
    readonly property bool currentMuted: audio && audio.audio ? audio.audio.muted : false
    readonly property string sinkName: audio && audio.description ? audio.description : "Audio Output"
    readonly property int volumePercent: Math.round(currentVolume * 100)

    // ── Output device selector ─────────────────────────────────────
    property bool deviceListOpen: false

    // Every output node (hardware and virtual sinks), streams excluded.
    readonly property var sinkNodes: {
        const list = Pipewire.nodes.values;
        const sinks = [];
        for (let i = 0; i < list.length; ++i) {
            const node = list[i];
            if (node.isSink && !node.isStream)
                sinks.push(node);
        }
        return sinks;
    }

    function isCurrentSink(node) {
        const preferred = Pipewire.preferredDefaultAudioSink;
        if (preferred)
            return node === preferred;
        return node === Pipewire.defaultAudioSink;
    }

    function selectSink(node) {
        if (!node)
            return;
        Pipewire.preferredDefaultAudioSink = node;
        root.deviceListOpen = false;
    }

    // ── Port / Profile (card settings via pactl) ───────────────────
    // quickshell's Pipewire API does not expose sink ports or card
    // profiles, so those come from pactl (the host's PipeWire-Pulse is
    // reachable through the shared user socket).
    property bool portListOpen: false
    property bool profileListOpen: false
    property var sinkPorts: []
    property string activePort: ""
    property var cardProfiles: []
    property string activeProfile: ""
    property string sinkKey: ""
    property string sinkCardName: ""

    readonly property string activePortLabel: {
        for (let i = 0; i < root.sinkPorts.length; ++i) {
            if (root.sinkPorts[i].name === root.activePort)
                return root.sinkPorts[i].label;
        }
        return root.activePort;
    }

    readonly property string activeProfileLabel: {
        for (let i = 0; i < root.cardProfiles.length; ++i) {
            if (root.cardProfiles[i].name === root.activeProfile)
                return root.cardProfiles[i].label;
        }
        return root.activeProfile;
    }

    // "alsa_output.pci-0000_0d_00.4.iec958-stereo" -> "pci-0000_0d_00.4.iec958-stereo"
    // (the card name shares the same key as a prefix, "alsa_card.pci-0000_0d_00.4").
    function deviceKey(name) {
        const i = name.indexOf(".");
        return i >= 0 ? name.slice(i + 1) : name;
    }

    function toggleDeviceList() {
        const open = !root.deviceListOpen;
        root.deviceListOpen = open;
        if (open) {
            root.portListOpen = false;
            root.profileListOpen = false;
        }
    }

    function togglePortList() {
        const open = !root.portListOpen;
        root.portListOpen = open;
        if (open) {
            root.deviceListOpen = false;
            root.profileListOpen = false;
        }
    }

    function toggleProfileList() {
        const open = !root.profileListOpen;
        root.profileListOpen = open;
        if (open) {
            root.deviceListOpen = false;
            root.portListOpen = false;
        }
    }

    function refreshCardSettings() {
        if (!root.audio)
            return;
        pactlSinksProc.running = true;
        pactlCardsProc.running = true;
    }

    function applySinks(text) {
        let sinks;
        try { sinks = JSON.parse(text); } catch (e) { return; }
        const name = root.audio && root.audio.name ? root.audio.name : "";
        const ports = [];
        let active = "";
        let key = "";
        for (let i = 0; i < sinks.length; ++i) {
            if (sinks[i].name !== name)
                continue;
            const list = sinks[i].ports || [];
            for (let j = 0; j < list.length; ++j) {
                ports.push({
                    name: list[j].name,
                    label: list[j].description && list[j].description !== "(null)"
                        ? list[j].description
                        : list[j].name
                });
            }
            active = sinks[i].active_port || "";
            key = root.deviceKey(name);
            break;
        }
        root.sinkPorts = ports;
        root.activePort = active;
        root.sinkKey = key;
    }

    function applyCards(text) {
        let cards;
        try { cards = JSON.parse(text); } catch (e) { return; }
        if (root.sinkKey === "") {
            root.cardProfiles = [];
            root.activeProfile = "";
            return;
        }
        const profiles = [];
        let active = "";
        let cardName = "";
        for (let i = 0; i < cards.length; ++i) {
            const key = root.deviceKey(cards[i].name);
            if (!root.sinkKey.startsWith(key))
                continue;
            active = cards[i].active_profile || "";
            cardName = cards[i].name;
            const list = cards[i].profiles || {};
            for (const name in list) {
                const desc = list[name] ? list[name].description : "";
                profiles.push({
                    name: name,
                    label: desc && desc !== "(null)"
                        ? desc
                        : name.replace(/^output:/, "").replace(/\+input:/, " + "),
                    available: list[name] ? list[name].available !== false : true
                });
            }
            break;
        }
        root.cardProfiles = profiles;
        root.activeProfile = active;
        root.sinkCardName = cardName;
    }

    function selectPort(portName) {
        if (!portName || !root.audio)
            return;
        pactlSetPortProc.command = ["pactl", "set-sink-port", root.audio.name, portName];
        pactlSetPortProc.running = true;
        root.portListOpen = false;
    }

    function selectProfile(profileName) {
        if (!profileName || root.sinkCardName === "")
            return;
        pactlSetProfileProc.command = ["pactl", "set-card-profile", root.sinkCardName, profileName];
        pactlSetProfileProc.running = true;
        root.profileListOpen = false;
    }

    Process {
        id: pactlSinksProc
        command: ["pactl", "-f", "json", "list", "sinks"]
        stdout: StdioCollector { onStreamFinished: root.applySinks(text) }
    }

    Process {
        id: pactlCardsProc
        command: ["pactl", "-f", "json", "list", "cards"]
        stdout: StdioCollector { onStreamFinished: root.applyCards(text) }
    }

    Process {
        id: pactlSetPortProc
        onExited: (code, status) => { if (code === 0) cardRefreshTimer.restart(); }
    }

    Process {
        id: pactlSetProfileProc
        onExited: (code, status) => { if (code === 0) cardRefreshTimer.restart(); }
    }

    Timer {
        id: cardRefreshTimer
        interval: 400
        repeat: false
        onTriggered: root.refreshCardSettings()
    }

    Component.onCompleted: root.refreshCardSettings()

    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() { root.refreshCardSettings(); }
    }

    // Shared row used by the port and profile lists.
    component SettingsRow: Rectangle {
        id: row
        required property string label
        required property bool current
        signal activated()

        Layout.fillWidth: true
        implicitHeight: 34
        radius: Root.Theme.radiusSmall
        color: row.current
            ? Qt.rgba(Root.Theme.primary.r, Root.Theme.primary.g, Root.Theme.primary.b, 0.18)
            : (rowArea.containsMouse ? Root.Theme.surfaceContainerHigh : Root.Theme.surfaceContainer)
        border.width: 1
        border.color: row.current
            ? Qt.rgba(Root.Theme.primary.r, Root.Theme.primary.g, Root.Theme.primary.b, 0.5)
            : "transparent"

        Behavior on color { ColorAnimation { duration: Root.Theme.animDurationFast } }

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12
            anchors.rightMargin: 30
            anchors.verticalCenter: parent.verticalCenter
            text: row.label
            font.family: Root.Theme.fontFamily
            font.pixelSize: Root.Theme.fontSizeSmall
            color: row.current ? Root.Theme.textPrimary : Root.Theme.textSecondary
            elide: Text.ElideRight
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            visible: row.current
            text: "✓"
            font.family: Root.Theme.fontFamily
            font.pixelSize: Root.Theme.fontSizeNormal
            color: Root.Theme.primary
        }

        MouseArea {
            id: rowArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.activated()
        }
    }

    // ── Volume control ─────────────────────────────────────────────
    function setVolume(value) {
        var clamped = Math.min(Math.max(value, 0.0), 1.0);
        if (audio && audio.audio)
            audio.audio.volume = clamped;
    }

    function toggleMute() {
        if (audio && audio.audio)
            audio.audio.muted = !audio.audio.muted;
    }

    function volumeIcon(level, muted) {
        if (muted || level === 0) return "󰖁";
        if (level < 0.34) return "󰕿";
        if (level < 0.67) return "󰖀";
        return "󰕾";
    }

    // ── UI Layout ──
    ColumnLayout {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Root.Theme.spacingSmall

        // Sink selector button — opens the output device list.
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 30
            radius: Root.Theme.radiusSmall
            color: sinkButtonArea.containsMouse ? Root.Theme.surfaceContainerHigh : "transparent"

            Behavior on color { ColorAnimation { duration: Root.Theme.animDurationFast } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                spacing: 8

                Text {
                    text: root.volumeIcon(root.currentVolume, root.currentMuted)
                    font.family: Root.Theme.fontFamily
                    font.pixelSize: Root.Theme.fontSizeLarge
                    color: Root.Theme.textSecondary
                }

                Text {
                    text: root.sinkName
                    font.family: Root.Theme.fontFamily
                    font.pixelSize: Root.Theme.fontSizeSmall
                    color: Root.Theme.textSecondary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: root.deviceListOpen ? "▴" : "▾"
                    font.family: Root.Theme.fontFamily
                    font.pixelSize: Root.Theme.fontSizeSmall
                    color: Root.Theme.textDisabled
                }
            }

            MouseArea {
                id: sinkButtonArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleDeviceList()
            }
        }

        // Output device list.
        ColumnLayout {
            visible: root.deviceListOpen
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: root.sinkNodes

                delegate: Rectangle {
                    id: deviceRow
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: Root.Theme.radiusSmall
                    color: root.isCurrentSink(deviceRow.modelData)
                        ? Qt.rgba(Root.Theme.primary.r, Root.Theme.primary.g, Root.Theme.primary.b, 0.18)
                        : (deviceRowArea.containsMouse ? Root.Theme.surfaceContainerHigh : Root.Theme.surfaceContainer)
                    border.width: 1
                    border.color: root.isCurrentSink(deviceRow.modelData)
                        ? Qt.rgba(Root.Theme.primary.r, Root.Theme.primary.g, Root.Theme.primary.b, 0.5)
                        : "transparent"

                    Behavior on color { ColorAnimation { duration: Root.Theme.animDurationFast } }

                    MouseArea {
                        id: deviceRowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectSink(deviceRow.modelData)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Text {
                            text: deviceRow.modelData.description && deviceRow.modelData.description !== ""
                                ? deviceRow.modelData.description
                                : deviceRow.modelData.name
                            font.family: Root.Theme.fontFamily
                            font.pixelSize: Root.Theme.fontSizeSmall
                            color: root.isCurrentSink(deviceRow.modelData)
                                ? Root.Theme.textPrimary
                                : Root.Theme.textSecondary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            visible: root.isCurrentSink(deviceRow.modelData)
                            text: "✓"
                            font.family: Root.Theme.fontFamily
                            font.pixelSize: Root.Theme.fontSizeNormal
                            color: Root.Theme.primary
                        }
                    }
                }
            }
        }

        // Port selector (sink ports: analog-output, hdmi-output-0, ...).
        Rectangle {
            visible: root.sinkPorts.length > 1
            Layout.fillWidth: true
            implicitHeight: 30
            radius: Root.Theme.radiusSmall
            color: portButtonArea.containsMouse ? Root.Theme.surfaceContainerHigh : "transparent"

            Behavior on color { ColorAnimation { duration: Root.Theme.animDurationFast } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                spacing: 8

                Text {
                    text: "Port"
                    font.family: Root.Theme.fontFamily
                    font.pixelSize: Root.Theme.fontSizeSmall
                    color: Root.Theme.textDisabled
                }

                Text {
                    text: root.activePortLabel
                    font.family: Root.Theme.fontFamily
                    font.pixelSize: Root.Theme.fontSizeSmall
                    color: Root.Theme.textSecondary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: root.portListOpen ? "▴" : "▾"
                    font.family: Root.Theme.fontFamily
                    font.pixelSize: Root.Theme.fontSizeSmall
                    color: Root.Theme.textDisabled
                }
            }

            MouseArea {
                id: portButtonArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.togglePortList()
            }
        }

        Flickable {
            visible: root.portListOpen
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(portColumn.implicitHeight, 180)
            contentHeight: portColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: portColumn
                width: parent.width
                spacing: 4

                Repeater {
                    model: root.sinkPorts

                    delegate: SettingsRow {
                        required property var modelData
                        label: modelData.label
                        current: modelData.name === root.activePort
                        onActivated: root.selectPort(modelData.name)
                    }
                }
            }
        }

        // Profile selector (card profiles: output:analog-stereo, ...).
        Rectangle {
            visible: root.cardProfiles.length > 0
            Layout.fillWidth: true
            implicitHeight: 30
            radius: Root.Theme.radiusSmall
            color: profileButtonArea.containsMouse ? Root.Theme.surfaceContainerHigh : "transparent"

            Behavior on color { ColorAnimation { duration: Root.Theme.animDurationFast } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                spacing: 8

                Text {
                    text: "Profile"
                    font.family: Root.Theme.fontFamily
                    font.pixelSize: Root.Theme.fontSizeSmall
                    color: Root.Theme.textDisabled
                }

                Text {
                    text: root.activeProfileLabel
                    font.family: Root.Theme.fontFamily
                    font.pixelSize: Root.Theme.fontSizeSmall
                    color: Root.Theme.textSecondary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: root.profileListOpen ? "▴" : "▾"
                    font.family: Root.Theme.fontFamily
                    font.pixelSize: Root.Theme.fontSizeSmall
                    color: Root.Theme.textDisabled
                }
            }

            MouseArea {
                id: profileButtonArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleProfileList()
            }
        }

        Flickable {
            visible: root.profileListOpen
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(profileColumn.implicitHeight, 180)
            contentHeight: profileColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: profileColumn
                width: parent.width
                spacing: 4

                Repeater {
                    model: root.cardProfiles

                    delegate: SettingsRow {
                        required property var modelData
                        label: modelData.available ? modelData.label : modelData.label + " (unavailable)"
                        current: modelData.name === root.activeProfile
                        onActivated: root.selectProfile(modelData.name)
                    }
                }
            }
        }

        // Volume slider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Root.Theme.sliderHeight
            radius: Root.Theme.sliderHeight / 2
            color: Root.Theme.sliderTrack
            clip: true

            // Active fill — dims when muted
            Rectangle {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                width: Math.max(parent.height, parent.width * root.currentVolume)
                radius: parent.radius
                color: root.currentMuted
                    ? Qt.rgba(Root.Theme.sliderActiveTrack.r, Root.Theme.sliderActiveTrack.g, Root.Theme.sliderActiveTrack.b, 0.35)
                    : Root.Theme.sliderActiveTrack
                Behavior on width { NumberAnimation { duration: 80 } }
                Behavior on color { ColorAnimation { duration: Root.Theme.animDurationFast } }
            }

            // Volume icon (left, click = mute toggle)
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: root.volumeIcon(root.currentVolume, root.currentMuted)
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSizeLarge
                color: Root.Theme.bg
                z: 1
            }

            // Percentage or "Muted" (right)
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: root.currentMuted ? "Muted" : root.volumePercent + "%"
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSizeNormal
                color: root.currentVolume > 0.85 ? Root.Theme.bg : Root.Theme.textSecondary
                z: 1
            }

            MouseArea {
                anchors.fill: parent
                preventStealing: true
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => { if (mouse.x < 48) root.toggleMute() }
                onPressed: (mouse) => { if (mouse.x >= 48) updateVolume(mouse.x) }
                onPositionChanged: (mouse) => { if (pressed && mouse.x >= 48) updateVolume(mouse.x) }
                function updateVolume(mx) {
                    var val = Math.min(Math.max(mx / width, 0.0), 1.0);
                    root.setVolume(val);
                }
            }
        }
    }
}
