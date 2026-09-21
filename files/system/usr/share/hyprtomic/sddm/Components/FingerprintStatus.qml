// Fingerprint status line for the HyprTomic SDDM theme.
// Copyright (C) 2026 HyprTomic contributors
// Distributed under the GPLv3+ License https://www.gnu.org/licenses/gpl-3.0.html
//
// SDDM forwards the PAM information and error messages of the current login
// attempt to the greeter (sddm.informationMessage).  With the HyprTomic PAM
// stack (/etc/pam.d/sddm) these are the pam_fprintd messages ("Place your
// finger on the fingerprint reader", "Verification timed out", "Failed to
// match fingerprint"), shown here while the reader is waiting.  The PAM
// return code adds a generic "Authentication failure" right before
// loginFailed(); that one is dropped in favour of the previous message.

import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: fingerprintStatus

    // point size of the theme font (set by LoginForm)
    property real fontSize: 12
    // message currently shown ("" hides the line)
    property string message: ""
    property string previousMessage: ""
    property double messageTime: 0

    implicitHeight: fontSize * 2

    function showMessage(text) {
        if (!text || text === message)
            return;
        previousMessage = message;
        message = text;
        messageTime = Date.now();
        clearTimer.stop();
    }

    function loginFailed() {
        // "Authentication failure" (from the PAM return code) follows the real
        // reason immediately: drop it and keep the informative message.
        if (Date.now() - messageTime < 250)
            message = previousMessage;
        clearTimer.restart();
    }

    Label {
        id: statusLabel

        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        font.pointSize: fingerprintStatus.fontSize * 0.8
        font.italic: true
        color: config.WarningColor
        text: fingerprintStatus.message
        opacity: fingerprintStatus.message ? 1 : 0

        Behavior on opacity {
            PropertyAnimation { duration: 150 }
        }
    }

    Timer {
        id: clearTimer
        interval: 8000
        onTriggered: {
            fingerprintStatus.message = "";
            fingerprintStatus.previousMessage = "";
        }
    }

    Connections {
        target: sddm

        function onInformationMessage(text) {
            fingerprintStatus.showMessage(text);
        }

        function onLoginFailed() {
            fingerprintStatus.loginFailed();
        }

        function onLoginSucceeded() {
            clearTimer.stop();
            fingerprintStatus.message = "";
            fingerprintStatus.previousMessage = "";
        }
    }
}
