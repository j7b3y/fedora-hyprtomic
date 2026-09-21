pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

QtObject {
    id: root

    // Exposed notification list (JS array of parsed notification objects)
    property var notifications: []
    property int count: notifications.length

    // Notifications stay in the list after their toast times out. Opening the
    // notification center marks everything read, so the badge clears.
    readonly property int unreadCount: {
        let n = 0;
        for (let i = 0; i < notifications.length; ++i) {
            if (notifications[i].unread)
                n++;
        }
        return n;
    }

    // History is persisted so unread notifications survive a shell restart.
    readonly property string historyFile:
        Quickshell.env("HOME") + "/.cache/quickshell/notifications.json"
    readonly property int maxHistory: 50

    // Internal map of id → Notification object (for tracked=false on remove)
    property var _notifMap: ({})

    // Negative ids for loaded history entries so they never collide with the
    // live server's positive ids.
    property int _historyId: 0

    // Signal emitted for each new notification — toast layer listens here
    signal newNotification(int notifId, string appName, string summary,
                           string body, string urgency, int timeout)

    // ── NotificationServer — claims org.freedesktop.Notifications on DBus ──
    property var server: NotificationServer {
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: false

        onNotification: function(notif) {
            // Keep in tracked list for history
            notif.tracked = true
            root._notifMap[notif.id] = notif

            // Prepend to history array
            var newList = root.notifications.slice()
            newList.unshift({
                id: notif.id,
                appName: notif.appName,
                summary: notif.summary,
                body: notif.body,
                urgency: root._urgencyStr(notif.urgency),
                timestamp: Date.now(),
                iconPath: notif.appIcon,
                unread: true
            })
            root.notifications = root._trim(newList)

            // Fire toast signal
            var ms = notif.expireTimeout > 0 ? Math.round(notif.expireTimeout) : 5000
            root.newNotification(notif.id, notif.appName, notif.summary,
                                 notif.body, root._urgencyStr(notif.urgency), ms)
        }
    }

    // ── Persistence ───────────────────────────────────────────────────────
    // QtObject has no default property, so these are property-assigned.
    property Process loadProc: Process {
        command: ["cat", root.historyFile]
        stdout: StdioCollector {
            onStreamFinished: root._load(text)
        }
    }

    property Process saveProc: Process {}

    property Timer saveTimer: Timer {
        interval: 500
        repeat: false
        onTriggered: root._save()
    }

    onNotificationsChanged: saveTimer.restart()
    Component.onCompleted: loadProc.running = true

    function _trim(list) {
        return list.length > root.maxHistory ? list.slice(0, root.maxHistory) : list
    }

    function _load(text) {
        if (!text || text.trim() === "")
            return;
        let parsed;
        try { parsed = JSON.parse(text); } catch (e) { return; }
        if (!Array.isArray(parsed) || parsed.length === 0)
            return;
        const loaded = [];
        for (let i = 0; i < parsed.length; ++i) {
            const n = parsed[i];
            if (!n || typeof n !== "object")
                continue;
            loaded.push({
                id: --root._historyId, // fresh negative id
                appName: n.appName || "",
                summary: n.summary || "",
                body: n.body || "",
                urgency: n.urgency || "NORMAL",
                timestamp: n.timestamp || 0,
                iconPath: n.iconPath || "",
                unread: n.unread !== false
            });
        }
        if (loaded.length === 0)
            return;
        // Keep anything that arrived before the file finished loading.
        root.notifications = root._trim(loaded.concat(root.notifications));
    }

    function _save() {
        if (root.notifications.length === 0) {
            saveProc.command = ["sh", "-c", "rm -f \"$1\"", "sh", root.historyFile];
            saveProc.running = true;
            return;
        }
        saveProc.command = ["sh", "-c",
            "mkdir -p \"$(dirname \"$1\")\" && printf %s \"$2\" > \"$1\"",
            "sh", root.historyFile, JSON.stringify(root.notifications)];
        saveProc.running = true;
    }

    // ── Helpers ───────────────────────────────────────────────────────────
    function _urgencyStr(urgency) {
        if (urgency === NotificationUrgency.Critical) return "CRITICAL"
        if (urgency === NotificationUrgency.Low)      return "LOW"
        return "NORMAL"
    }

    // Compute relative timestamp string (uses Unix epoch ms from Date.now())
    function relativeTime(timestampMs) {
        if (!timestampMs || timestampMs <= 0) return ""
        var diffSec = Math.floor((Date.now() - timestampMs) / 1000)
        if (diffSec < 0)    return "just now"
        if (diffSec < 60)   return "just now"
        if (diffSec < 3600) {
            var m = Math.floor(diffSec / 60)
            return m + (m === 1 ? " min ago" : " mins ago")
        }
        if (diffSec < 86400) {
            var h = Math.floor(diffSec / 3600)
            return h + (h === 1 ? " hour ago" : " hours ago")
        }
        var d = Math.floor(diffSec / 86400)
        return d + (d === 1 ? " day ago" : " days ago")
    }

    function markAllRead() {
        let changed = false;
        const list = root.notifications.map(function(n) {
            if (!n.unread)
                return n;
            changed = true;
            const copy = Object.assign({}, n);
            copy.unread = false;
            return copy;
        });
        if (changed)
            root.notifications = list;
    }

    function clearAll() {
        for (var id in root._notifMap) {
            if (root._notifMap.hasOwnProperty(id))
                root._notifMap[id].tracked = false
        }
        root._notifMap = {}
        root.notifications = []
    }

    function removeNotification(notifId) {
        if (root._notifMap[notifId]) {
            root._notifMap[notifId].tracked = false
            delete root._notifMap[notifId]
        }
        root.notifications = root.notifications.filter(function(n) {
            return n.id !== notifId
        })
    }
}
