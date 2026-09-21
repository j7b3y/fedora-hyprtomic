import QtQuick
import "../.." as Root

// App icon cell: icon + label.
// The active icon theme (Tela-circle-dark in the GUI container) already draws
// its own circular background, so the launcher does not add one — the icon is
// rendered at full size. Only the no-icon fallback draws a neutral circle.
Item {
    id: appIcon
    width: 120
    height: 116

    required property string appName
    required property string iconSource

    property bool isSelected: false

    signal clicked()

    // ── Hover / selected background (white translucent rounded rect) ─
    Rectangle {
        id: hoverRect
        anchors.fill: parent
        anchors.margins: 8
        radius: 16
        color: mouseArea.pressed
            ? Qt.rgba(1, 1, 1, 0.15)
            : (mouseArea.containsMouse || appIcon.isSelected)
                ? Qt.rgba(1, 1, 1, 0.08)
                : "transparent"

        Behavior on color { ColorAnimation { duration: 100 } }
    }

    // ── App icon ─────────────────────────────────────────────────
    // sourceSize is only forced for SVGs: they rasterize at that size (sharp
    // at any display scale). Raster icons (flatpak/web-app artwork) load at
    // their natural size and are downscaled, so they are never upscaled.
    Image {
        id: iconImage
        width: 56
        height: 56
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 10
        source: appIcon.iconSource !== "" ? appIcon.iconSource : ""
        sourceSize: appIcon.iconSource.toLowerCase().endsWith(".svg") ? Qt.size(256, 256) : Qt.size(0, 0)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        asynchronous: true
        visible: source !== "" && status === Image.Ready

        scale: mouseArea.pressed ? 0.93 : 1.0
        Behavior on scale {
            NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
        }

        onStatusChanged: {
            if (status === Image.Error) source = "";
        }
    }

    // ── Fallback: first letter on a neutral circle ───────────────
    Rectangle {
        id: fallbackCircle
        width: 56
        height: 56
        radius: 28
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 10
        color: Qt.rgba(1, 1, 1, 0.12)
        visible: iconImage.status !== Image.Ready

        Text {
            anchors.centerIn: parent
            text: appIcon.appName.length > 0 ? appIcon.appName.charAt(0).toUpperCase() : "?"
            font.pixelSize: 20
            font.family: Root.Theme.fontFamily
            font.weight: Font.Medium
            color: Root.Theme.textSecondary
        }
    }

    // ── App name label ───────────────────────────────────────────
    Text {
        anchors.top: iconImage.bottom
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 6
        text: appIcon.appName
        font.pixelSize: 12
        font.family: Root.Theme.fontFamily
        color: Root.Theme.textPrimary
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        maximumLineCount: 1
    }

    // ── Click area ───────────────────────────────────────────────
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: appIcon.clicked()
    }
}
