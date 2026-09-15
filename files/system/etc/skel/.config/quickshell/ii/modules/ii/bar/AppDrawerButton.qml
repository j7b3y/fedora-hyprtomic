import QtQuick
import qs
import qs.modules.common
import qs.modules.common.widgets

RippleButton {
    id: root

    property real buttonPadding: 5
    implicitWidth: icon.width + buttonPadding * 2
    implicitHeight: icon.height + buttonPadding * 2
    buttonRadius: Appearance.rounding.full
    colBackgroundHover: Appearance.colors.colLayer1Hover
    colRipple: Appearance.colors.colLayer1Active
    colBackgroundToggled: Appearance.colors.colSecondaryContainer
    colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
    colRippleToggled: Appearance.colors.colSecondaryContainerActive
    toggled: GlobalStates.appDrawerOpen

    onPressed: {
        GlobalStates.appDrawerOpen = !GlobalStates.appDrawerOpen;
    }

    MaterialSymbol {
        id: icon
        anchors.centerIn: parent
        text: "apps"
        iconSize: Appearance.font.pixelSize.larger
        color: root.toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer0
    }
}
