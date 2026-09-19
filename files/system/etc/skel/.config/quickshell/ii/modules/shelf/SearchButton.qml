import QtQuick
import Quickshell.Io
import "../.." as Root

// Launcher button — opens the quickshell launcher (the categorised app grid
// in modules/launcher). The IPC toggle also closes it, so the button works as
// a toggle while the launcher is open.
Item {
    width: 40
    height: 40

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: Root.Theme.surfaceHigh

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Root.Theme.hoverOverlay
            opacity: mouseArea.containsMouse ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Root.Theme.animDurationFast
                }
            }
        }

        Text {
            anchors.centerIn: parent
            // Nerd Font MDI "apps" (󰀻). Use the literal glyph: a "\uf003b"
            // escape would be parsed as U+F003 + "b" by the JS engine.
            text: "󰀻"
            font.family: Root.Theme.fontFamily
            font.pixelSize: 20
            color: Root.Theme.textPrimary
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: launcherProc.startDetached()
    }

    Process {
        id: launcherProc
        command: ["qs", "-c", "ii", "ipc", "call", "launcher", "toggle"]
    }
}
