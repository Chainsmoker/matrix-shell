pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.config

PanelWindow {
    id: root

    required property var targetScreen
    screen: targetScreen

    visible: GlobalStates.wallpaperPickerVisible

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"

    readonly property var wm: GlobalStates.wallpaperManager

    property string search: ""
    // Path the cursor is currently hovering (drives the live preview + freezes the spin)
    property string hoveredPath: ""

    function baseName(p) {
        return p ? p.substring(p.lastIndexOf("/") + 1) : "";
    }
    function prettyName(p) {
        let b = baseName(p);
        let dot = b.lastIndexOf(".");
        return dot > 0 ? b.substring(0, dot) : b;
    }

    readonly property var allPaths: wm ? wm.wallpaperPaths : []
    readonly property var filtered: {
        if (!search)
            return allPaths;
        let q = search.toLowerCase();
        return allPaths.filter(p => root.baseName(p).toLowerCase().indexOf(q) !== -1);
    }

    // High-quality source: original for images, cached frame for videos
    function hqSource(path) {
        if (!wm || !path)
            return "";
        return "file://" + wm.getLockscreenFramePath(path);
    }
    function thumbSource(path) {
        if (!wm || !path)
            return "";
        return "file://" + wm.getThumbnailPath(path) + "?v=" + wm.thumbnailsVersion;
    }

    function apply(path) {
        if (wm && path)
            wm.setWallpaper(path);
    }

    function close() {
        GlobalStates.wallpaperPickerVisible = false;
    }

    function focusTo(idx) {
        if (idx < 0)
            idx = 0;
        orbit.pos = idx;
    }
    function focusToCurrent() {
        if (!wm)
            return;
        focusTo(root.filtered.indexOf(wm.currentWallpaper));
    }

    // Intro animation flag
    property bool shown: false
    onVisibleChanged: {
        if (visible) {
            shown = false;
            hoveredPath = "";
            Qt.callLater(() => {
                root.shown = true;
                root.focusToCurrent();
                searchInput.focusInput();
            });
        } else {
            root.search = "";
            root.hoveredPath = "";
            searchInput.clear();
        }
    }

    onSearchChanged: root.focusTo(0)

    // The wallpaper previewed full-screen: the hovered tile, else the focused (front)
    // tile as you navigate, falling back to the active wallpaper
    readonly property string previewPath: {
        if (hoveredPath !== "")
            return hoveredPath;
        let f = filtered[orbit.frontIndex];
        return f ? f : (wm ? wm.currentWallpaper : "");
    }

    // ── Background: blurred live preview + scrim ─────────────────────────────
    Image {
        id: bgSrc
        anchors.fill: parent
        source: root.thumbSource(root.previewPath)
        fillMode: Image.PreserveAspectCrop
        visible: false
        asynchronous: true
    }
    MultiEffect {
        anchors.fill: parent
        source: bgSrc
        blurEnabled: true
        blurMax: 64
        blur: 1.0
        opacity: root.shown ? 1 : 0
        visible: bgSrc.status === Image.Ready
        Behavior on opacity {
            NumberAnimation { duration: 400; easing.type: Easing.OutQuart }
        }
    }
    Rectangle {
        anchors.fill: parent
        color: Colors.background
        opacity: root.shown ? 0.62 : 0
        Behavior on opacity {
            NumberAnimation { duration: 400; easing.type: Easing.OutQuart }
        }
    }

    // Click on empty space closes
    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    // ── Content (fades/scales in) ────────────────────────────────────────────
    Item {
        id: content
        anchors.fill: parent
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.96
        Behavior on opacity {
            NumberAnimation { duration: 350; easing.type: Easing.OutQuart }
        }
        Behavior on scale {
            NumberAnimation { duration: 450; easing.type: Easing.OutBack; easing.overshoot: 0.6 }
        }

        // Empty state
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 10
            visible: root.filtered.length === 0

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Icons.wallpapers
                font.family: Icons.font
                font.pixelSize: 56
                color: Colors.overBackground
                opacity: 0.35
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.search ? "No wallpapers match \"" + root.search + "\"" : "No wallpapers found"
                font.family: Config.theme.monoFont
                font.pixelSize: Styling.monoFontSize(1)
                color: Colors.overBackground
                opacity: 0.5
            }
        }

        // ── Orbital ring (Saturn's rings) ────────────────────────────────────
        Item {
            id: orbit
            anchors.fill: parent
            anchors.topMargin: 60
            anchors.bottomMargin: 196
            visible: root.filtered.length > 0

            readonly property int count: root.filtered.length

            // Windowed ring: only ~(2*windowHalf+1) tiles are shown around the
            // front, at a fixed angular spacing — so it never looks crowded no
            // matter how many wallpapers there are. The window cycles as you move.
            readonly property real spacingDeg: 22
            readonly property int windowHalf: 6

            // Navigation position in *tile units*; the front tile is round(pos)
            property real pos: 0
            Behavior on pos {
                NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
            }

            readonly property int frontIndex: ((Math.round(pos) % count) + count) % count

            // Ellipse geometry — wide & shallow = tilted ring viewed from above
            readonly property real cx: width / 2
            readonly property real cy: height * 0.5
            readonly property real rx: width * 0.34
            readonly property real ry: height * 0.20

            // Base tile size (front tile, scale = 1.0)
            readonly property real baseW: Math.min(width * 0.27, 440)
            readonly property real baseH: baseW * 0.6

            // Shortest signed offset of an index from the current position (wrapped)
            function offsetOf(index) {
                var off = index - pos;
                if (count > 0) {
                    while (off > count / 2)
                        off -= count;
                    while (off < -count / 2)
                        off += count;
                }
                return off;
            }

            function step(dir) {
                pos += dir;
            }

            Repeater {
                model: root.filtered

                delegate: Item {
                    id: tileItem
                    required property int index
                    required property var modelData

                    // Signed offset from the front; only a window of tiles is shown
                    readonly property real off: orbit.offsetOf(index)
                    readonly property bool nearFront: Math.abs(off) <= orbit.windowHalf + 0.5
                    // 0° = front (closest, largest); fixed spacing around the ellipse
                    readonly property real aRad: (off * orbit.spacingDeg + 90) * Math.PI / 180
                    readonly property real depth: Math.sin(aRad)       // -1 back .. 1 front
                    readonly property real t: (depth + 1) / 2          // 0 back .. 1 front
                    readonly property bool isFront: index === orbit.frontIndex

                    visible: nearFront
                    width: orbit.baseW
                    height: orbit.baseH
                    transformOrigin: Item.Center

                    x: orbit.cx + orbit.rx * Math.cos(aRad) - width / 2
                    y: orbit.cy + orbit.ry * Math.sin(aRad) - height / 2
                    scale: 0.42 + 0.58 * t
                    z: Math.round(t * 1000)
                    opacity: nearFront ? (0.35 + 0.65 * t) : 0

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: Styling.radius(4)
                        color: Colors.surface
                        border.width: tileItem.isFront ? 3 : 0
                        border.color: Colors.primary

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: "#000000"
                            shadowOpacity: tileItem.isFront ? 0.7 : 0.4
                            shadowBlur: 1.0
                            shadowVerticalOffset: 6
                        }

                        Image {
                            id: img
                            anchors.fill: parent
                            // Load the high-quality source only for tiles near the front
                            source: tileItem.nearFront ? root.hqSource(tileItem.modelData) : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            mipmap: true
                            cache: false
                            sourceSize.width: Math.round(orbit.baseW * 2)
                            onStatusChanged: {
                                if (status === Image.Error && tileItem.nearFront)
                                    source = root.thumbSource(tileItem.modelData);
                            }
                        }

                        // Active-wallpaper marker
                        Rectangle {
                            visible: root.wm && tileItem.modelData === root.wm.currentWallpaper
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 10
                            width: 14
                            height: 14
                            radius: 7
                            color: Colors.primary
                            border.width: 2
                            border.color: Styling.srItem("primary")
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: tileItem.nearFront
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.hoveredPath = tileItem.modelData
                        onExited: if (root.hoveredPath === tileItem.modelData)
                            root.hoveredPath = ""
                        onClicked: {
                            root.apply(tileItem.modelData);
                            root.close();
                        }
                    }
                }
            }
        }

        // ── Bottom bar: focused name + hint + search ─────────────────────────
        ColumnLayout {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: root.shown ? 34 : -80
            spacing: 12
            visible: root.filtered.length > 0

            Behavior on anchors.bottomMargin {
                NumberAnimation { duration: 500; easing.type: Easing.OutExpo }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.prettyName((root.hoveredPath !== "" ? root.hoveredPath : root.filtered[orbit.frontIndex]) ?? "")
                font.family: Config.theme.monoFont
                font.pixelSize: Styling.fontSize(3)
                font.bold: true
                color: Colors.overBackground
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "← →  rotate    ↵  apply    hover + click    esc  close"
                font.family: Config.theme.monoFont
                font.pixelSize: Styling.monoFontSize(-1)
                color: Colors.overBackground
                opacity: 0.45
            }

            // Polished search bar
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 480
                implicitHeight: 52
                radius: height / 2
                color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.75)
                border.width: 1
                border.color: searchInput.activeFocus ? Colors.primary : Colors.outline

                Behavior on border.color {
                    ColorAnimation { duration: 200 }
                }

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#000000"
                    shadowOpacity: 0.5
                    shadowBlur: 1.0
                    shadowVerticalOffset: 4
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 8
                    spacing: 10

                    Text {
                        text: Icons.glassPlus
                        font.family: Icons.font
                        font.pixelSize: 18
                        color: Colors.overBackground
                        opacity: 0.6
                    }

                    SearchInput {
                        id: searchInput
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        variant: "transparent"
                        iconText: ""
                        placeholderText: "Search wallpapers…"
                        clearOnEscape: false
                        disableCursorNavigation: true
                        handleTabNavigation: true

                        onSearchTextChanged: text => root.search = text
                        // → / Tab advance to the right; ← / Shift+Tab to the left
                        onRightPressed: orbit.step(-1)
                        onLeftPressed: orbit.step(1)
                        onTabPressed: orbit.step(-1)
                        onShiftTabPressed: orbit.step(1)
                        onAccepted: {
                            root.apply(root.filtered[orbit.frontIndex]);
                            root.close();
                        }
                        onEscapePressed: root.close()
                    }

                    Rectangle {
                        Layout.preferredHeight: 36
                        Layout.preferredWidth: countTxt.implicitWidth + 22
                        radius: height / 2
                        color: Colors.primary

                        Text {
                            id: countTxt
                            anchors.centerIn: parent
                            text: root.filtered.length + (root.search ? "/" + root.allPaths.length : "")
                            font.family: Config.theme.monoFont
                            font.pixelSize: Styling.monoFontSize(-1)
                            font.bold: true
                            color: Styling.srItem("primary")
                        }
                    }
                }
            }
        }
    }
}
