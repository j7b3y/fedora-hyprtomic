import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../.." as Root

Scope {
    id: launcher

    property bool panelVisible: false
    property bool _showing: false
    property bool _panelOpen: false
    property string searchText: ""

    // ── Category filter ──────────────────────────────────────────
    property string selectedCategory: "All Applications"

    // Plasma-desktop category order (matches Kickoff sidebar)
    readonly property var plasmaCategoryOrder: [
        "Development",
        "Education",
        "Games",
        "Graphics",
        "Internet",
        "Multimedia",
        "Office",
        "Science & Math",
        "Settings",
        "System",
        "Utilities"
    ]

    // XDG category → display category mapping (plasma-desktop Kickoff)
    readonly property var categoryMap: ({
        "Development": ["Development", "Building", "Debugger", "GUIDesigner", "IDE", "Profiling", "RevisionControl"],
        "Education": ["Education", "Languages", "Teaching", "KidsGame"],
        "Games": ["Game"],
        "Graphics": ["Graphics", "2DGraphics", "3DGraphics", "Photography", "RasterGraphics", "Scanning", "VectorGraphics", "Viewer"],
        "Internet": ["Network", "WebBrowser", "Email", "Chat", "InstantMessaging", "IRCClient", "RemoteAccess", "Telephony", "VideoConference"],
        "Multimedia": ["AudioVideo", "Audio", "Midi", "Mixer", "Music", "Player", "Recorder", "Sequencer", "TV", "Video"],
        "Office": ["Office", "Calendar", "ContactManagement", "Dictionary", "Finance", "FlowChart", "Presentation", "ProjectManagement", "Spreadsheet", "WordProcessor"],
        "Science & Math": ["Science", "ArtificialIntelligence", "Astronomy", "Biology", "Chemistry", "ComputerScience", "DataVisualization", "Electricity", "Geology", "Math", "NumericalAnalysis", "Physics"],
        "Settings": ["Settings", "DesktopSettings", "HardwareSettings", "PackageManager", "Security"],
        "System": ["System", "Core", "Emulator", "FileManager", "Monitor", "TerminalEmulator"],
        "Utilities": ["Utility", "Accessibility", "Archiving", "Calculator", "Clock", "Compression", "Documentation", "TextEditor", "TextTools"]
    })

    // Assign each app to exactly one display category.
    // Flatpak and Wine get dedicated categories; others follow plasma-desktop.
    function appCategory(entry) {
        if (isFlatpak(entry)) return "Flatpak";
        if (isWine(entry)) return "Wine";

        var entryCats = entry.categories || [];
        for (var cat in categoryMap) {
            var targets = categoryMap[cat];
            for (var i = 0; i < targets.length; i++) {
                if (entryCats.indexOf(targets[i]) >= 0)
                    return cat;
            }
        }
        return "Lost & Found";
    }

    function appMatchesCategory(entry, cat) {
        if (cat === "All Applications") return true;
        return appCategory(entry) === cat;
    }

    // Dynamic category list — empty categories are hidden.
    readonly property var visibleCategories: {
        var result = ["All Applications"];
        var allCats = ["Flatpak", "Wine"].concat(plasmaCategoryOrder).concat(["Lost & Found"]);
        for (var i = 0; i < allCats.length; i++) {
            var cat = allCats[i];
            for (var j = 0; j < allApps.length; j++) {
                if (appMatchesCategory(allApps[j], cat)) {
                    result.push(cat);
                    break;
                }
            }
        }
        return result;
    }

    onVisibleCategoriesChanged: {
        if (visibleCategories.indexOf(selectedCategory) < 0)
            selectedCategory = "All Applications";
    }

    onSelectedCategoryChanged: {
        kbIndex = 0;
        kbSection = (selectedCategory === "All Applications" && recentApps.length > 0) ? 0 : 1;
    }

    // ── Keyboard navigation state ────────────────────────────────
    property int kbSection: 0   // 0 = recent row, 1 = app grid
    property int kbIndex: 0
    property int gridColumns: 5
    property bool gridFocused: false  // true = arrow keys navigate grid; false = search input

    // ── Icon path cache (icon name -> file path) ─────────────────
    // Resolved via GTK IconTheme (same library nwg-dock uses), so the
    // icon pack matches the dock. Follows index.theme Inherits chains
    // (e.g. Papirus-Dark → breeze-dark → hicolor) and skips symbolic
    // icons that render as black SVGs.
    property var iconCache: ({})

    readonly property string iconScript:
        Quickshell.env("HOME") + "/.config/quickshell/scripts/resolve-icons.py"

    // Unique icon names from the current app set. Used to feed the
    // resolver only the icons we actually need (skips a .desktop scan
    // and avoids resolving icons for hidden categories).
    readonly property var appIconNames: {
        var seen = {};
        for (var i = 0; i < allApps.length; i++) {
            var n = allApps[i].icon;
            if (n) seen[n] = true;
        }
        return Object.keys(seen);
    }

    Process {
        id: iconResolveProc
        // Default command: scan all .desktop files (used until allApps
        // is populated by the async DesktopEntries service).
        command: ["python3", launcher.iconScript]
        stdout: StdioCollector {
            onStreamFinished: {
                var cache = {};
                var lines = text.trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("\t");
                    if (parts.length === 2 && parts[1] !== "") {
                        cache[parts[0]] = parts[1];
                    }
                }
                launcher.iconCache = cache;
            }
        }
    }

    onAppIconNamesChanged: {
        // Once DesktopEntries has populated allApps, switch to a targeted
        // resolution that resolves only the icons we actually display.
        if (appIconNames.length > 0) {
            iconResolveProc.command = ["python3", launcher.iconScript].concat(appIconNames);
            iconResolveProc.running = true;
        }
    }

    Component.onCompleted: {
        iconResolveProc.running = true;
        recentReadProc.running = true;
        flatpakIdProc.running = true;
    }

    function resolveIcon(iconName) {
        if (!iconName) return "";
        if (iconName.startsWith("/")) return "file://" + iconName;
        // Prefer the script cache (only returns existing, non-symbolic files)
        var path = iconCache[iconName];
        if (path) return "file://" + path;
        // Fall back to Quickshell's icon path lookup
        var qtPath = Quickshell.iconPath(iconName, "");
        if (qtPath && qtPath !== "") return qtPath;
        return "";
    }

    // ── Recent apps ──────────────────────────────────────────────
    property var recentAppNames: []
    property int maxRecent: 5

    Process {
        id: recentReadProc
        command: ["sh", "-c", "cat ~/.cache/quickshell/recent-apps.txt 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                var names = [];
                if (text.trim() !== "") {
                    var lines = text.trim().split("\n");
                    for (var i = 0; i < lines.length && i < launcher.maxRecent; i++) {
                        var n = lines[i].trim();
                        if (n !== "") names.push(n);
                    }
                }
                launcher.recentAppNames = names;
            }
        }
    }

    function recordRecentApp(appName) {
        var names = recentAppNames.slice();
        // Remove duplicate
        var idx = names.indexOf(appName);
        if (idx >= 0) names.splice(idx, 1);
        // Prepend
        names.unshift(appName);
        // Trim
        if (names.length > maxRecent) names = names.slice(0, maxRecent);
        recentAppNames = names;
        // Write to file
        recentWriteProc.command = ["sh", "-c",
            "mkdir -p ~/.cache/quickshell && printf '%s\\n' " +
            names.map(function(n) { return "'" + n.replace(/'/g, "'\\''") + "'"; }).join(" ") +
            " > ~/.cache/quickshell/recent-apps.txt"];
        recentWriteProc.running = true;
    }

    Process { id: recentWriteProc }

    // Map recent names back to plain data objects {name, icon, entry}
    // (plain JS objects avoid QObject property access issues from inside Loader)
    property var recentApps: {
        var result = [];
        var names = recentAppNames;
        for (var i = 0; i < names.length; i++) {
            for (var j = 0; j < allApps.length; j++) {
                if (allApps[j].name === names[i]) {
                    var e = allApps[j];
                    result.push({ name: e.name, icon: e.icon, entry: e });
                    break;
                }
            }
        }
        return result;
    }

    // ── Flatpak detection via actual installed flatpak list ──────
    property var flatpakIds: ({})

    Process {
        id: flatpakIdProc
        command: ["sh", "-c", "ls /var/lib/flatpak/exports/share/applications/*.desktop \"$HOME\"/.local/share/flatpak/exports/share/applications/*.desktop 2>/dev/null | xargs -I{} basename {} .desktop"]
        stdout: StdioCollector {
            onStreamFinished: {
                var ids = {};
                var lines = text.trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var id = lines[i].trim();
                    if (id) ids[id] = true;
                }
                launcher.flatpakIds = ids;
            }
        }
    }

    function isFlatpak(entry) {
        return flatpakIds[entry.id] === true;
    }

    function isWine(entry) {
        var cats = entry.categories || [];
        if (cats.indexOf("X-Wine") >= 0) return true;
        var exec = entry.execString || "";
        if (/\bwine\d*\b/.test(exec)) return true;
        return false;
    }

    // Detect name collisions between native/flatpak/wine variants
    readonly property var nameCollisions: {
        var counts = {};
        for (var i = 0; i < allApps.length; i++) {
            var name = allApps[i].name;
            counts[name] = (counts[name] || 0) + 1;
        }
        var collisions = {};
        for (var name in counts) {
            if (counts[name] > 1) collisions[name] = true;
        }
        return collisions;
    }

    function displayName(entry) {
        if (nameCollisions[entry.name]) {
            if (isFlatpak(entry)) return entry.name + " (flatpak)";
            if (isWine(entry)) return entry.name + " (wine)";
            return entry.name + " (native)";
        }
        return entry.name;
    }

    // ── Filtered app list ────────────────────────────────────────
    property var allApps: {
        var apps = [];
        var seen = {};
        var entries = DesktopEntries.applications.values;
        for (var i = 0; i < entries.length; i++) {
            var entry = entries[i];
            // Deduplicate by id (not name) so native/flatpak variants both appear
            var key = entry.id || entry.name;
            if (entry && !entry.noDisplay && entry.name !== "" && !seen[key]) {
                seen[key] = true;
                apps.push(entry);
            }
        }
        apps.sort(function(a, b) {
            return a.name.localeCompare(b.name);
        });
        return apps;
    }

    property var filteredApps: {
        var query = searchText.toLowerCase();
        return allApps.filter(function(entry) {
            if (!appMatchesCategory(entry, selectedCategory))
                return false;
            if (query === "")
                return true;
            if (entry.name.toLowerCase().indexOf(query) >= 0)
                return true;
            if (entry.genericName && entry.genericName.toLowerCase().indexOf(query) >= 0)
                return true;
            if (entry.comment && entry.comment.toLowerCase().indexOf(query) >= 0) return true;
            if (entry.keywords) {
                for (var k = 0; k < entry.keywords.length; k++) {
                    if (entry.keywords[k].toLowerCase().indexOf(query) >= 0) return true;
                }
            }
            return false;
        });
    }

    // Each launch gets its own Process so that starting a new app never
    // sends SIGTERM to a previously-launched one. With `uwsm app -t scope`
    // (the default), the sh -c → uwsm → systemd-run --scope chain execs
    // into the app, so a reused Process would stay "running" as long as
    // the app lives; setting running = false on the next launch would
    // kill that app. A per-launch Process avoids this entirely.
    Component {
        id: launchProcFactory
        Process {}
    }

    // Launch via `uwsm app` so the app spawns as a transient systemd unit
    // in app-graphical.slice, detached from the compositor cgroup.
    function launchApp(entry) {
        recordRecentApp(entry.name);
        var id = entry.id || "";
        var exec = entry.execString || "";
        if (!id && !exec) {
            panelVisible = false;
            return;
        }
        // -s a: pin to app-graphical.slice so the new scope sits next to
        // autostart apps (which we move into the same slice via the
        // app-@autostart.service.d/slice.conf drop-in), avoiding slice
        // boundary churn on launch.
        var cmd = id
            ? "uwsm app -s a -- '" + id.replace(/'/g, "'\\''") + ".desktop'"
            : "uwsm app -s a -- sh -c '" + exec.replace(/'/g, "'\\''") + "'";
        var proc = launchProcFactory.createObject(launcher, {
            "command": ["sh", "-c", cmd]
        });
        proc.running = true;
        panelVisible = false;
    }

    // ── Keyboard navigation ───────────────────────────────────────
    function handleNavKey(dir) {
        var recentVisible = recentApps.length > 0 && searchText === "";
        var recentCount = recentApps.length;
        var gridCount = filteredApps.length;
        var cols = gridColumns;

        if (recentVisible && kbSection === 0) {
            // Recent row (horizontal)
            if (dir === "left") {
                if (kbIndex > 0) kbIndex--;
            } else if (dir === "right") {
                if (kbIndex < recentCount - 1) kbIndex++;
            } else if (dir === "down") {
                if (gridCount > 0) { kbSection = 1; kbIndex = 0; }
            }
            // up in recent row: do nothing
        } else {
            // App grid (2D)
            if (dir === "left") {
                if (kbIndex > 0) kbIndex--;
            } else if (dir === "right") {
                if (kbIndex < gridCount - 1) kbIndex++;
            } else if (dir === "up") {
                var upIdx = kbIndex - cols;
                if (upIdx >= 0) {
                    kbIndex = upIdx;
                } else if (recentVisible) {
                    kbSection = 0; kbIndex = 0;
                }
            } else if (dir === "down") {
                var downIdx = kbIndex + cols;
                if (downIdx < gridCount) kbIndex = downIdx;
            }
        }
    }

    function getKeyboardSelectedApp() {
        if (kbSection === 0 && kbIndex < recentApps.length)
            return recentApps[kbIndex].entry;
        if (kbSection === 1 && kbIndex < filteredApps.length)
            return filteredApps[kbIndex];
        return null;
    }

    onPanelVisibleChanged: {
        if (panelVisible) {
            _showing = true;
            searchText = "";
            gridFocused = false;
            // Default selection: first recent app (or first grid app if no recent)
            kbSection = recentApps.length > 0 ? 0 : 1;
            kbIndex = 0;
        } else {
            _panelOpen = false;
        }
    }

    // ── IPC handlers ─────────────────────────────────────────────
    IpcHandler {
        target: "launcher"

        function toggle(): void { launcher.panelVisible = !launcher.panelVisible }
        function show(): void { launcher.panelVisible = true }
        function hide(): void { launcher.panelVisible = false }
    }

    // ── Overlay window ───────────────────────────────────────────
    Loader {
        active: launcher._showing

        sourceComponent: PanelWindow {
            id: panelWindow
            visible: true

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.namespace: "quickshell:launcher"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            Component.onCompleted: openDelayTimer.start()

            Timer {
                id: openDelayTimer
                interval: 16
                repeat: false
                onTriggered: if (launcher.panelVisible) launcher._panelOpen = true
            }

            Shortcut {
                sequence: "Escape"
                onActivated: launcher.panelVisible = false
            }

            // Click-outside to close
            MouseArea {
                anchors.fill: parent
                onClicked: launcher.panelVisible = false
            }

            // ── Clip region (above shelf/waybar) ─────────────────
            Item {
                id: panelClip
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Root.Theme.shelfHeight
                clip: true

                // ── Launcher panel — bottom-left, ChromeOS style ─
                Rectangle {
                    id: panel

                    property real cellW: 130
                    property real panelW: launcher.gridColumns * cellW + 48
                    property real panelH: Math.min(panelClip.height * 0.78, 780)

                    width: panelW
                    height: panelH

                    // Bottom-left positioning
                    anchors.left: parent.left
                    anchors.leftMargin: 12

                    states: [
                        State {
                            name: "visible"
                            when: launcher._panelOpen
                            PropertyChanges {
                                target: panel
                                y: panelClip.height - panel.height - 8
                                opacity: 1
                            }
                        },
                        State {
                            name: "hidden"
                            when: !launcher._panelOpen
                            PropertyChanges {
                                target: panel
                                y: panelClip.height + 20
                                opacity: 0
                            }
                        }
                    ]

                    transitions: [
                        Transition {
                            from: "hidden"
                            to: "visible"
                            ParallelAnimation {
                                NumberAnimation {
                                    property: "y"
                                    duration: 200
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    property: "opacity"
                                    duration: 200
                                    easing.type: Easing.OutCubic
                                }
                            }
                        },
                        Transition {
                            from: "visible"
                            to: "hidden"
                            SequentialAnimation {
                                ParallelAnimation {
                                    NumberAnimation {
                                        property: "y"
                                        duration: 200
                                        easing.type: Easing.InCubic
                                    }
                                    NumberAnimation {
                                        property: "opacity"
                                        duration: 200
                                        easing.type: Easing.InCubic
                                    }
                                }
                                ScriptAction {
                                    script: launcher._showing = false
                                }
                            }
                        }
                    ]

                    radius: 28
                    color: Qt.rgba(Root.Theme.panelBg.r, Root.Theme.panelBg.g, Root.Theme.panelBg.b, 0.78)
                    border.width: 1
                    border.color: Qt.rgba(Root.Theme.panelBorder.r,
                                           Root.Theme.panelBorder.g,
                                           Root.Theme.panelBorder.b, 0.3)

                    // Block click-through
                    MouseArea {
                        anchors.fill: parent
                    }

                    // ── Content layout ───────────────────────────
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.topMargin: 20
                        anchors.bottomMargin: 20
                        anchors.leftMargin: 24
                        anchors.rightMargin: 24
                        spacing: 16

                        // ── Search bar (ChromeOS pill) ───────────
                        Rectangle {
                            id: searchBar
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            radius: 24
                            color: Root.Theme.surfaceContainer
                            opacity: launcher.gridFocused ? 0.5 : 1.0
                            Behavior on opacity { NumberAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 12

                                Text {
                                    text: "\uf002"
                                    font.pixelSize: 15
                                    font.family: Root.Theme.fontFamily
                                    color: Root.Theme.textSecondary
                                }

                                TextInput {
                                    id: searchInput
                                    Layout.fillWidth: true
                                    font.pixelSize: 13
                                    font.family: Root.Theme.fontFamily
                                    color: Root.Theme.textPrimary
                                    clip: true
                                    selectByMouse: true
                                    selectionColor: Root.Theme.primary

                                    onTextChanged: {
                                        launcher.searchText = text;
                                        launcher.gridFocused = false;
                                        // Reset kb selection on search change
                                        if (text !== "") {
                                            launcher.kbSection = 1;
                                            launcher.kbIndex = 0;
                                        } else {
                                            launcher.kbSection = launcher.recentApps.length > 0 ? 0 : 1;
                                            launcher.kbIndex = 0;
                                        }
                                    }

                                    // Auto-focus when component loads
                                    Component.onCompleted: focusTimer.start()

                                    Timer {
                                        id: focusTimer
                                        interval: 50
                                        repeat: false
                                        onTriggered: searchInput.forceActiveFocus()
                                    }

                                    Text {
                                        anchors.fill: parent
                                        text: "Search your apps..."
                                        font: searchInput.font
                                        color: Root.Theme.textSecondary
                                        visible: !searchInput.text
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    // ── Unified key handler ──────────────
                                    Keys.onPressed: (event) => {
                                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                            var app = launcher.getKeyboardSelectedApp();
                                            if (app) launcher.launchApp(app);
                                            event.accepted = true;
                                        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                                            launcher.gridFocused = !launcher.gridFocused;
                                            event.accepted = true;
                                        } else if (launcher.gridFocused) {
                                            if (event.key === Qt.Key_Up) {
                                                launcher.handleNavKey("up");
                                                event.accepted = true;
                                            } else if (event.key === Qt.Key_Down) {
                                                launcher.handleNavKey("down");
                                                event.accepted = true;
                                            } else if (event.key === Qt.Key_Left) {
                                                launcher.handleNavKey("left");
                                                event.accepted = true;
                                            } else if (event.key === Qt.Key_Right) {
                                                launcher.handleNavKey("right");
                                                event.accepted = true;
                                            } else if (event.text !== "" && event.key !== Qt.Key_Escape) {
                                                // Printable character: switch back to search input
                                                launcher.gridFocused = false;
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ── Category tabs ───────────────────────
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: categoryFlow.height

                            Flow {
                                id: categoryFlow
                                width: parent.width
                                height: childrenRect.height
                                spacing: 6

                                Repeater {
                                    model: launcher.visibleCategories

                                    Rectangle {
                                        required property string modelData
                                        required property int index
                                        width: tabLabel.implicitWidth + 22
                                        height: 28
                                        radius: 14
                                        color: launcher.selectedCategory === modelData
                                            ? Qt.rgba(Root.Theme.primary.r, Root.Theme.primary.g, Root.Theme.primary.b, 0.85)
                                            : Qt.rgba(Root.Theme.surfaceContainer.r, Root.Theme.surfaceContainer.g, Root.Theme.surfaceContainer.b, 0.5)
                                        border.width: 1
                                        border.color: launcher.selectedCategory === modelData
                                            ? "transparent"
                                            : Qt.rgba(Root.Theme.panelBorder.r, Root.Theme.panelBorder.g, Root.Theme.panelBorder.b, 0.25)
                                        Behavior on color { ColorAnimation { duration: 120 } }

                                        Text {
                                            id: tabLabel
                                            anchors.centerIn: parent
                                            text: modelData
                                            font.pixelSize: 11
                                            font.family: Root.Theme.fontFamily
                                            color: launcher.selectedCategory === modelData
                                                ? Root.Theme.textPrimary
                                                : Root.Theme.textSecondary
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: launcher.selectedCategory = modelData
                                        }
                                    }
                                }
                            }
                        }

                        // ── Scrollable content (recent apps + app grid) ─
                        Item {
                            id: scrollContainer
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            // Scroll to keep keyboard-selected item visible
                            function scrollToSelected() {
                                var recentH = recentSection.visible
                                    ? recentSection.height + scrollContent.spacing
                                    : 0;
                                var targetY, itemH;
                                if (launcher.kbSection === 0) {
                                    targetY = 0;
                                    itemH = 116;
                                } else {
                                    var row = Math.floor(launcher.kbIndex / launcher.gridColumns);
                                    targetY = recentH + row * 126;
                                    itemH = 126;
                                }
                                var viewH = appFlickable.height;
                                if (targetY < appFlickable.contentY)
                                    appFlickable.contentY = targetY;
                                else if (targetY + itemH > appFlickable.contentY + viewH)
                                    appFlickable.contentY = Math.max(0, targetY + itemH - viewH);
                            }

                            Connections {
                                target: launcher
                                function onKbIndexChanged() { scrollContainer.scrollToSelected() }
                                function onKbSectionChanged() { scrollContainer.scrollToSelected() }
                            }

                            Flickable {
                                id: appFlickable
                                anchors.fill: parent
                                contentWidth: width
                                contentHeight: scrollContent.height
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                flickDeceleration: 3000

                                Column {
                                    id: scrollContent
                                    width: appFlickable.width
                                    spacing: 8

                                    // ── Recent apps section (only when not searching) ─
                                    Column {
                                        id: recentSection
                                        width: parent.width
                                        spacing: 8
                                        visible: launcher.recentApps.length > 0 && launcher.searchText === "" && launcher.selectedCategory === "All Applications"

                                        Text {
                                            text: "Recent"
                                            font.pixelSize: 12
                                            font.family: Root.Theme.fontFamily
                                            color: Root.Theme.textSecondary
                                        }

                                        Row {
                                            spacing: 4

                                             Repeater {
                                                model: launcher.recentApps

                                                AppIcon {
                                                    required property var modelData
                                                    required property int index
                                                    appName: launcher.displayName(modelData.entry)
                                                    iconSource: launcher.resolveIcon(modelData.icon)
                                                    isSelected: launcher.gridFocused && launcher.kbSection === 0 && launcher.kbIndex === index
                                                    onClicked: launcher.launchApp(modelData.entry)
                                                }
                                            }
                                        }

                                        // Separator
                                        Rectangle {
                                            width: parent.width
                                            height: 1
                                            color: Qt.rgba(Root.Theme.textSecondary.r, Root.Theme.textSecondary.g, Root.Theme.textSecondary.b, 0.3)
                                        }
                                    }

                                    // ── App grid ─────────────────────────
                                    Flow {
                                        id: appGrid
                                        width: parent.width

                                        property real cellWidth: width / launcher.gridColumns

                                        Repeater {
                                            model: launcher.filteredApps

                                            Item {
                                                required property var modelData
                                                required property int index
                                                width: appGrid.cellWidth
                                                height: 126

                                                AppIcon {
                                                    anchors.centerIn: parent
                                                    appName: launcher.displayName(modelData)
                                                    iconSource: launcher.resolveIcon(modelData.icon)
                                                    isSelected: launcher.gridFocused && launcher.kbSection === 1 && launcher.kbIndex === index
                                                    onClicked: launcher.launchApp(modelData)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "No apps found"
                                font.pixelSize: Root.Theme.fontSizeNormal
                                font.family: Root.Theme.fontFamily
                                color: Root.Theme.textSecondary
                                visible: launcher.filteredApps.length === 0
                            }
                        }
                    }
                }
            }
        }
    }
}
