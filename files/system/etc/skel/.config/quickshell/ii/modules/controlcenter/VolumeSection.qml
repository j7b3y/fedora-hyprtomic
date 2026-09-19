pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
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
                onClicked: root.deviceListOpen = !root.deviceListOpen
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
