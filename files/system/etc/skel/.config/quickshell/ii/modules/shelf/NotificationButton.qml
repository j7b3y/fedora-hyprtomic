import QtQuick
import Quickshell
import Quickshell.Io
import "../notifications" as Notifications
import "../.." as Root

// Bell button with an unread badge; toggles the notification center
// (history of notifications that were not dismissed by hand).
Item {
    id: root

    implicitWidth: 34
    implicitHeight: 34

    readonly property int unread: Notifications.NotificationService.unreadCount

    Rectangle {
        anchors.fill: parent
        radius: 17
        color: mouseArea.containsMouse ? Root.Theme.hoverOverlay : "transparent"

        Behavior on color { ColorAnimation { duration: Root.Theme.animDurationFast } }

        Text {
            anchors.centerIn: parent
            // md-bell / md-bell-outline
            text: root.unread > 0 ? "󰂚" : "󰂜"
            font.family: Root.Theme.fontFamily
            font.pixelSize: 18
            color: root.unread > 0 ? Root.Theme.primary : Root.Theme.textSecondary

            Behavior on color { ColorAnimation { duration: Root.Theme.animDurationFast } }
        }

        // Unread count badge
        Rectangle {
            visible: root.unread > 0
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 1
            anchors.topMargin: 1
            width: Math.max(14, badgeLabel.implicitWidth + 6)
            height: 14
            radius: 7
            color: Root.Theme.error

            Text {
                id: badgeLabel
                anchors.centerIn: parent
                text: root.unread > 9 ? "9+" : root.unread
                font.family: Root.Theme.fontFamily
                font.pixelSize: 9
                font.weight: Font.DemiBold
                color: Root.Theme.bg
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: notifProc.startDetached()
    }

    Process {
        id: notifProc
        command: ["qs", "-c", "ii", "ipc", "call", "notifications", "toggle"]
    }
}
