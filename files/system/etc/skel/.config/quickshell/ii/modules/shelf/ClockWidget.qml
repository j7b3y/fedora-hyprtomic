import QtQuick
import "../.." as Root

// ClockWidget — shelf clock in a soft pill, pinned to the right corner.
// Shows `yyyy-MM-dd HH:mm`; the date and time are separate labels so the time
// keeps a stronger weight. Refreshes every 20 s (covers date rollover).
Item {
    id: root

    property string dateText: Qt.formatDateTime(new Date(), "yyyy-MM-dd")
    property string timeText: Qt.formatDateTime(new Date(), "HH:mm")

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    Timer {
        interval: 20000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const now = new Date();
            root.dateText = Qt.formatDateTime(now, "yyyy-MM-dd");
            root.timeText = Qt.formatDateTime(now, "HH:mm");
        }
    }

    Rectangle {
        id: pill
        anchors.centerIn: parent
        implicitWidth: labelRow.implicitWidth + 22
        implicitHeight: 32
        radius: height / 2
        color: Root.Theme.surfaceContainerHigh
        border.width: 1
        border.color: Qt.rgba(Root.Theme.panelBorder.r,
                              Root.Theme.panelBorder.g,
                              Root.Theme.panelBorder.b, 0.6)

        Row {
            id: labelRow
            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.dateText
                color: Root.Theme.textSecondary
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSizeSmall
            }

            Rectangle {
                width: 1
                height: 12
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(Root.Theme.textSecondary.r,
                               Root.Theme.textSecondary.g,
                               Root.Theme.textSecondary.b, 0.35)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.timeText
                color: Root.Theme.textPrimary
                font.family: Root.Theme.fontFamily
                font.pixelSize: Root.Theme.fontSizeNormal
                font.weight: Font.DemiBold
            }
        }
    }
}
