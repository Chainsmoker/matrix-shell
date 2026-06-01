pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.config

Rectangle {
    id: root
    color: "transparent"
    implicitWidth: 600
    implicitHeight: 400

    readonly property var wm: GlobalStates.wallpaperManager
    readonly property string currentScreenName: AxctlService.focusedMonitor ? AxctlService.focusedMonitor.name : ""

    readonly property var schemes: [
        { "id": "scheme-tonal-spot", "name": "Tonal Spot" },
        { "id": "scheme-content", "name": "Content" },
        { "id": "scheme-expressive", "name": "Expressive" },
        { "id": "scheme-fidelity", "name": "Fidelity" },
        { "id": "scheme-fruit-salad", "name": "Fruit Salad" },
        { "id": "scheme-monochrome", "name": "Monochrome" },
        { "id": "scheme-neutral", "name": "Neutral" },
        { "id": "scheme-rainbow", "name": "Rainbow" }
    ]

    readonly property bool isPerScreen: {
        if (!wm || currentScreenName === "")
            return false;
        let ps = wm.perScreenWallpapers || {};
        return ps[currentScreenName] !== undefined;
    }

    function baseName(p) {
        return p ? p.substring(p.lastIndexOf("/") + 1) : "";
    }
    function prettyName(p) {
        let b = baseName(p);
        let dot = b.lastIndexOf(".");
        return dot > 0 ? b.substring(0, dot) : b;
    }
    function thumb(path) {
        if (!wm || !path)
            return "";
        return "file://" + wm.getThumbnailPath(path) + "?v=" + wm.thumbnailsVersion;
    }

    function openPicker() {
        GlobalStates.wallpaperPickerVisible = true;
        Visibilities.setActiveModule("");
    }
    function togglePerScreen() {
        if (!wm || currentScreenName === "")
            return;
        if (isPerScreen)
            wm.clearPerScreenWallpaper(currentScreenName);
        else if (wm.currentWallpaper)
            wm.setWallpaper(wm.currentWallpaper, currentScreenName);
    }
    function randomWallpaper() {
        if (!wm)
            return;
        let n = wm.wallpaperPaths.length;
        if (n > 0)
            wm.setWallpaperByIndex(Math.floor(Math.random() * n));
    }
    function pickWallpaperDir() {
        dirPicker.command = ["/home/calvin/.local/bin/matrix-pick", "dir", (wm ? wm.wallpaperDir : ""), "Wallpaper folder"];
        dirPicker.running = true;
    }

    // Folder chooser via the unified matrix-pick wrapper: floats by itself and
    // respects the yad/yazi preference; prints the chosen path on stdout.
    Process {
        id: dirPicker
        running: false
        stdout: StdioCollector {
            id: dirPickerOut
        }
        onExited: code => {
            var p = (dirPickerOut.text || "").trim();
            if (p && root.wm)
                root.wm.setWallpaperDir(p);
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // ── Left column: preview + launch + quick actions ────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            spacing: 12

            Text {
                text: "WALLPAPERS"
                font.family: Config.theme.monoFont
                font.pixelSize: Styling.fontSize(2)
                font.weight: Font.Bold
                color: Colors.primary
            }

            // Current wallpaper banner
            ClippingRectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                radius: Styling.radius(4)
                color: Colors.surfaceContainer

                Image {
                    anchors.fill: parent
                    source: root.thumb(root.wm ? root.wm.currentWallpaper : "")
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    mipmap: true
                    cache: false
                    sourceSize.width: 600
                }

                // Bottom gradient for legible text
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 56
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.7) }
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 12
                    text: root.wm && root.wm.currentWallpaper ? root.prettyName(root.wm.currentWallpaper) : "No wallpaper"
                    font.family: Config.theme.monoFont
                    font.pixelSize: Styling.monoFontSize(0)
                    font.bold: true
                    color: "white"
                    elide: Text.ElideRight
                }

                // CURRENT chip
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: 10
                    width: curTxt.implicitWidth + 16
                    height: 22
                    radius: Styling.radius(2)
                    color: Colors.primary
                    Text {
                        id: curTxt
                        anchors.centerIn: parent
                        text: "CURRENT"
                        font.family: Config.theme.monoFont
                        font.pixelSize: Styling.monoFontSize(-2)
                        font.bold: true
                        color: Styling.srItem("primary")
                    }
                }

                // Dark / light mode toggle (circular, over the wallpaper)
                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 10
                    width: 34
                    height: 34
                    radius: 17
                    color: modeMa.containsMouse ? Qt.rgba(0, 0, 0, 0.6) : Qt.rgba(0, 0, 0, 0.45)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.35)

                    Text {
                        anchors.centerIn: parent
                        text: Config.theme.lightMode ? Icons.sun : Icons.moon
                        font.family: Icons.font
                        font.pixelSize: 16
                        color: "white"
                    }

                    MouseArea {
                        id: modeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Config.theme.lightMode = !Config.theme.lightMode
                    }

                    StyledToolTip {
                        show: modeMa.containsMouse
                        tooltipText: Config.theme.lightMode ? "Switch to dark mode" : "Switch to light mode"
                    }
                }
            }

            // Launch the coverflow picker
            Rectangle {
                id: cta
                Layout.fillWidth: true
                Layout.preferredHeight: 54
                radius: Styling.radius(4)
                color: ctaMa.containsMouse ? Qt.lighter(Colors.primary, 1.08) : Colors.primary
                scale: ctaMa.pressed ? 0.98 : 1.0

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on scale { NumberAnimation { duration: 120 } }

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Colors.primary
                    shadowOpacity: 0.4
                    shadowBlur: 0.6
                }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 10
                    Text {
                        text: Icons.wallpapers
                        font.family: Icons.font
                        font.pixelSize: 20
                        color: Styling.srItem("primary")
                    }
                    Text {
                        text: "Browse wallpapers"
                        font.family: Config.theme.monoFont
                        font.pixelSize: Styling.fontSize(1)
                        font.bold: true
                        color: Styling.srItem("primary")
                    }
                }

                MouseArea {
                    id: ctaMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openPicker()
                }
            }

            // Quick actions
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                IconAction {
                    icon: Icons.arrowLeft
                    tip: "Previous"
                    onTriggered: if (root.wm) root.wm.previousWallpaper()
                }
                IconAction {
                    icon: Icons.shuffle
                    tip: "Random"
                    onTriggered: root.randomWallpaper()
                }
                IconAction {
                    icon: Icons.arrowRight
                    tip: "Next"
                    onTriggered: if (root.wm) root.wm.nextWallpaper()
                }
                IconAction {
                    icon: Icons.folder
                    tip: "Change wallpaper folder"
                    onTriggered: root.pickWallpaperDir()
                }
            }

            Item { Layout.fillHeight: true }

            Text {
                text: (root.wm ? root.wm.wallpaperPaths.length : 0) + " wallpapers"
                font.family: Config.theme.monoFont
                font.pixelSize: Styling.monoFontSize(-1)
                color: Colors.overBackground
                opacity: 0.5
            }
        }

        Separator {
            Layout.fillHeight: true
            implicitWidth: 2
            vert: true
        }

        // ── Right column: appearance + scheme (scrollable) ───────────────────
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            clip: true
            contentWidth: width
            contentHeight: rightCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: rightCol
                width: parent.width
                spacing: 10

            Text {
                text: "APPEARANCE"
                font.family: Config.theme.monoFont
                font.pixelSize: Styling.monoFontSize(0)
                font.bold: true
                color: Colors.overBackground
                opacity: 0.6
            }

            Toggle {
                icon: Icons.image
                label: "Per-screen"
                sub: root.currentScreenName !== "" ? root.currentScreenName : "no monitor"
                checked: root.isPerScreen
                onToggled: root.togglePerScreen()
            }
            Toggle {
                icon: Icons.moon
                label: "OLED mode"
                sub: "pure-black background"
                checked: Config.theme.oledMode
                onToggled: Config.theme.oledMode = !Config.theme.oledMode
            }
            Toggle {
                icon: Icons.drop
                label: "Tint"
                sub: "recolor with palette"
                checked: root.wm ? root.wm.tintEnabled : false
                onToggled: if (root.wm) root.wm.tintEnabled = !root.wm.tintEnabled
            }
            Toggle {
                icon: Icons.palette
                label: "Tinted background"
                sub: "matugen tone instead of black"
                checked: Config.theme.tintedBackground
                onToggled: Config.theme.tintedBackground = !Config.theme.tintedBackground
            }

            Text {
                Layout.topMargin: 6
                text: "MATUGEN SCHEME"
                font.family: Config.theme.monoFont
                font.pixelSize: Styling.monoFontSize(0)
                font.bold: true
                color: Colors.overBackground
                opacity: 0.6
            }

            Flow {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: root.schemes

                    delegate: Rectangle {
                        id: chip
                        required property var modelData
                        readonly property bool active: root.wm && root.wm.currentMatugenScheme === modelData.id

                        implicitWidth: chipTxt.implicitWidth + 22
                        implicitHeight: 30
                        radius: Styling.radius(3)
                        color: active ? Colors.primary : (chipMa.containsMouse ? Colors.surfaceContainerHigh : Colors.surfaceContainer)
                        border.width: 1
                        border.color: active ? Colors.primary : Colors.outline

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            id: chipTxt
                            anchors.centerIn: parent
                            text: chip.modelData.name
                            font.family: Config.theme.monoFont
                            font.pixelSize: Styling.monoFontSize(-1)
                            font.bold: true
                            color: chip.active ? Styling.srItem("primary") : Colors.overBackground
                        }

                        MouseArea {
                            id: chipMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (root.wm) root.wm.setMatugenScheme(chip.modelData.id)
                        }
                    }
                }
            }

            }
        }
    }

    // ── Reusable: square icon button ─────────────────────────────────────────
    component IconAction: Rectangle {
        id: ia
        property string icon
        property string tip: ""
        signal triggered

        Layout.fillWidth: true
        Layout.preferredHeight: 42
        radius: Styling.radius(3)
        color: iaMa.containsMouse ? Colors.surfaceContainerHigh : Colors.surfaceContainer
        border.width: 1
        border.color: Colors.outline

        Text {
            anchors.centerIn: parent
            text: ia.icon
            font.family: Icons.font
            font.pixelSize: 18
            color: iaMa.containsMouse ? Colors.primary : Colors.overBackground
        }

        MouseArea {
            id: iaMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ia.triggered()
        }

        StyledToolTip {
            show: iaMa.containsMouse && ia.tip !== ""
            tooltipText: ia.tip
        }
    }

    // ── Reusable: labelled sliding toggle ────────────────────────────────────
    component Toggle: Rectangle {
        id: tg
        property string icon: ""
        property string label: ""
        property string sub: ""
        property bool checked: false
        signal toggled

        Layout.fillWidth: true
        implicitHeight: 48
        radius: Styling.radius(3)
        color: tgMa.containsMouse ? Colors.surfaceContainerHigh : Colors.surfaceContainer

        Behavior on color { ColorAnimation { duration: 150 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            Text {
                text: tg.icon
                font.family: Icons.font
                font.pixelSize: 18
                color: tg.checked ? Colors.primary : Colors.overBackground
                visible: tg.icon !== ""
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: tg.label
                    font.family: Config.theme.monoFont
                    font.pixelSize: Styling.monoFontSize(0)
                    font.bold: true
                    color: Colors.overBackground
                }
                Text {
                    text: tg.sub
                    font.family: Config.theme.monoFont
                    font.pixelSize: Styling.monoFontSize(-2)
                    color: Colors.overBackground
                    opacity: 0.5
                    visible: tg.sub !== ""
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            // Sliding switch
            Rectangle {
                Layout.preferredWidth: 42
                Layout.preferredHeight: 24
                radius: 12
                color: tg.checked ? Colors.primary : Colors.surfaceContainerHighest
                border.width: 1
                border.color: tg.checked ? Colors.primary : Colors.outline

                Behavior on color { ColorAnimation { duration: 180 } }

                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    anchors.verticalCenter: parent.verticalCenter
                    x: tg.checked ? parent.width - width - 3 : 3
                    color: tg.checked ? Styling.srItem("primary") : Colors.overBackground

                    Behavior on x {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                }
            }
        }

        MouseArea {
            id: tgMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tg.toggled()
        }
    }
}
