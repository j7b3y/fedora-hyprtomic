import QtQuick
import "../.." as Root

// Single-line filter chip row (ChromeOS-style pills). The chips never wrap:
// drag or scroll horizontally when they do not fit. Used for the container
// filter row and the app-category row above the app grid.
Item {
    id: root

    property var model: []
    property string selected: ""
    property var labelFor: function(value) { return value }

    signal activated(string value)

    implicitHeight: 28

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: chips.implicitWidth
        contentHeight: height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 3000
        interactive: contentWidth > width

        // Keep the scroll position valid when the model changes (e.g. the
        // category row is recomputed for another container).
        onContentWidthChanged: {
            if (contentWidth <= width)
                contentX = 0;
            else
                contentX = Math.min(contentX, contentWidth - width);
        }

        // Bring the selected chip into view (selection can change without a
        // click, e.g. when the model is recomputed).
        function scrollToSelected() {
            for (var i = 0; i < chips.children.length; i++) {
                var chip = chips.children[i];
                if (chip.modelData === undefined || chip.modelData !== root.selected)
                    continue;
                var maxX = Math.max(0, contentWidth - width);
                if (chip.x < contentX)
                    contentX = chip.x;
                else if (chip.x + chip.width > contentX + width)
                    contentX = Math.min(maxX, chip.x + chip.width - width);
                return;
            }
        }

        Connections {
            target: root
            function onSelectedChanged() { flick.scrollToSelected() }
        }

        Row {
            id: chips
            spacing: 6

            Repeater {
                model: root.model

                Rectangle {
                    id: chip
                    required property string modelData
                    width: chipLabel.implicitWidth + 22
                    height: 28
                    radius: 14
                    color: root.selected === chip.modelData
                        ? Qt.rgba(Root.Theme.primary.r, Root.Theme.primary.g, Root.Theme.primary.b, 0.85)
                        : Qt.rgba(Root.Theme.surfaceContainer.r, Root.Theme.surfaceContainer.g, Root.Theme.surfaceContainer.b, 0.5)
                    border.width: 1
                    border.color: root.selected === chip.modelData
                        ? "transparent"
                        : Qt.rgba(Root.Theme.panelBorder.r, Root.Theme.panelBorder.g, Root.Theme.panelBorder.b, 0.25)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        id: chipLabel
                        anchors.centerIn: parent
                        text: root.labelFor(chip.modelData)
                        font.pixelSize: 11
                        font.family: Root.Theme.fontFamily
                        color: root.selected === chip.modelData
                            ? Root.Theme.textPrimary
                            : Root.Theme.textSecondary
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activated(chip.modelData)
                    }
                }
            }
        }

        // Mouse wheel / touchpad: vertical wheel scrolls the row sideways.
        WheelHandler {
            onWheel: (event) => {
                var delta = event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y;
                var maxX = Math.max(0, flick.contentWidth - flick.width);
                flick.contentX = Math.max(0, Math.min(maxX, flick.contentX - delta));
                event.accepted = true;
            }
        }
    }
}
