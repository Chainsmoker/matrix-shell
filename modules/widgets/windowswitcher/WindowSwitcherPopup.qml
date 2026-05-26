pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.modules.globals
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config

PanelWindow {
    id: popup

    required property ShellScreen screen

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ambxst:windowswitcher"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property var screenVisibilities: Visibilities.getForScreen(screen.name)
    readonly property bool open: screenVisibilities ? screenVisibilities.windowswitcher : false

    property int currentIndex: 0
    property var cards: []

    visible: open
    exclusionMode: ExclusionMode.Ignore

    mask: Region { item: popup.open ? fullMask : emptyMask }
    Item { id: fullMask; anchors.fill: parent }
    Item { id: emptyMask; width: 0; height: 0 }

    function rebuildCards() {
        const ws = AxctlService.focusedWorkspace;
        if (!ws) { cards = []; return; }
        const all = AxctlService.clients.values || [];
        const list = all.filter(c => c.workspace && c.workspace.id === ws.id);
        list.sort((a, b) => (b.focusHistoryID || 0) - (a.focusHistoryID || 0));
        cards = list;
        const focusedIdx = list.findIndex(c => c.is_focused);
        currentIndex = (focusedIdx >= 0 && list.length > 1) ? (focusedIdx + 1) % list.length : 0;
    }

    function next() {
        if (cards.length === 0) return;
        currentIndex = (currentIndex + 1) % cards.length;
    }
    function prev() {
        if (cards.length === 0) return;
        currentIndex = (currentIndex - 1 + cards.length) % cards.length;
    }
    function confirm() {
        if (cards.length > 0 && currentIndex >= 0 && currentIndex < cards.length) {
            AxctlService.dispatch("focuswindow address:" + cards[currentIndex].address);
        }
        Visibilities.setActiveModule("");
    }
    function cancel() { Visibilities.setActiveModule(""); }

    onOpenChanged: if (open) rebuildCards()

    Connections {
        target: GlobalShortcuts
        function onWindowSwitcherCycle(direction) {
            if (!popup.open) return;
            (direction > 0) ? popup.next() : popup.prev();
        }
    }

    FocusGrab {
        windows: [popup]
        active: popup.open
        onCleared: Qt.callLater(() => { if (popup.open) popup.cancel(); })
    }

    // ═══════════════════════════════════════════════════════════
    // BACKDROP — Fullscreen workspace-specific video loop + dark overlay
    // ═══════════════════════════════════════════════════════════
    // ═══════════════════════════════════════════════════════════
    // BACKDROP — matugen (original gradient, clean dark glass look)
    // ═══════════════════════════════════════════════════════════
    Rectangle {
        id: backdrop
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(Colors.surfaceContainerLowest.r, Colors.surfaceContainerLowest.g, Colors.surfaceContainerLowest.b, 0.85) }
            GradientStop { position: 1.0; color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.85) }
        }
        opacity: popup.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: popup.cancel() }
    }

    // ═══════════════════════════════════════════════════════════
    // FLAT CAROUSEL SWITCHER — clean horizontal row of window thumbs
    // ═══════════════════════════════════════════════════════════
    Item {
        id: stage
        anchors.fill: parent

        readonly property real cardW: Math.min(440, Math.max(280, popup.width * 0.26))
        readonly property real cardH: cardW * 0.62
        readonly property real spacing: cardW + 32 // 32px clear gap, no overlapping or shadows behind!
        readonly property real centerX: popup.width / 2
        readonly property real centerY: popup.height / 2 - 20

        Repeater {
            model: popup.cards
            delegate: Item {
                id: card
                required property var modelData
                required property int index

                readonly property int offset: card.index - popup.currentIndex
                readonly property real absOff: Math.abs(offset)
                readonly property bool isActive: offset === 0

                readonly property string iconPath: AppSearch.guessIcon((modelData && modelData.class !== undefined ? modelData.class : "") || "")
                readonly property string titleText: (modelData && modelData.title) ? modelData.title : (modelData && modelData.class ? modelData.class : "Untitled")
                readonly property string classText: (modelData && modelData.class) ? modelData.class : ""

                width: stage.cardW
                height: stage.cardH

                // Simple flat horizontal row positioning
                x: stage.centerX + offset * stage.spacing - width / 2
                y: stage.centerY - height / 2

                z: isActive ? 100 : (10 - absOff)

                scale: isActive ? 1.06 : 0.90
                opacity: isActive ? 1.0 : Math.max(0.15, 0.60 - absOff * 0.15)

                Behavior on x       { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                Behavior on scale   { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

                ClippingRectangle {
                    id: body
                    anchors.fill: parent
                    radius: 18
                    color: card.isActive
                        ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.20)
                        : Qt.rgba(0, 0, 0, 0.60)
                    border.width: card.isActive ? 2 : 1
                    border.color: card.isActive ? Colors.primary : Qt.rgba(1, 1, 1, 0.12)
                    Behavior on color        { ColorAnimation { duration: 220 } }
                    Behavior on border.color { ColorAnimation { duration: 220 } }

                    // Only a clean drop shadow on the active card to make it float nicely
                    layer.enabled: card.isActive
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowBlur: 1.0
                        shadowColor: Qt.rgba(0, 0, 0, 0.60)
                        shadowOpacity: 0.75
                    }

                    Image {
                        id: iconFallback
                        anchors.centerIn: parent
                        width: Math.min(96, card.height * 0.50)
                        height: width
                        source: Quickshell.iconPath(card.iconPath, "image-missing")
                        sourceSize: Qt.size(width, height)
                        smooth: true
                        fillMode: Image.PreserveAspectFit
                        opacity: thumbImg.status === Image.Ready ? 0 : 0.85
                        Behavior on opacity { NumberAnimation { duration: 220 } }
                    }

                    Image {
                        id: thumbImg
                        anchors.fill: parent
                        anchors.margins: 1
                        cache: false
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                        function refresh() {
                            source = "";
                            if (card.modelData && card.modelData.address) {
                                source = WindowThumbnails.thumbPath(card.modelData.address);
                            }
                        }
                        Component.onCompleted: refresh()
                        Connections {
                            target: WindowThumbnails
                            function onCaptured() { thumbImg.refresh(); }
                        }
                    }

                    // Gradient overlay para legibilidad
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 1
                        height: 64
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.55; color: Qt.rgba(0, 0, 0, 0.55) }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.85) }
                        }
                        visible: thumbImg.status === Image.Ready
                    }

                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        anchors.bottomMargin: 12
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: card.titleText
                            color: "white"
                            font.family: Config.theme ? Config.theme.font : ""
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            horizontalAlignment: Text.AlignLeft
                        }
                        Text {
                            Layout.fillWidth: true
                            text: card.classText
                            color: Qt.rgba(1, 1, 1, 0.65)
                            font.family: Config.theme ? Config.theme.monoFont : ""
                            font.pixelSize: 9
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            horizontalAlignment: Text.AlignLeft
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.isActive ? popup.confirm() : (popup.currentIndex = card.index)
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    // INFO PILL
    // ═══════════════════════════════════════════════════════════
    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.max(56, popup.height * 0.07)
        width: Math.min(560, popup.width * 0.55)
        height: 72
        radius: 36
        color: Qt.rgba(0, 0, 0, 0.62)
        border.color: Qt.rgba(1, 1, 1, 0.10)
        border.width: 1
        visible: popup.open && popup.cards.length > 0
        z: 3000

        opacity: popup.open ? 1 : 0
        scale: popup.open ? 1 : 0.85
        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        Behavior on scale   { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 28
            anchors.rightMargin: 28
            spacing: 16

            Text {
                text: popup.cards.length > 0 ? (String(popup.currentIndex + 1).padStart(2, "0") + " / " + String(popup.cards.length).padStart(2, "0")) : "--"
                color: Colors.primary
                font.family: Config.theme ? Config.theme.monoFont : ""
                font.pixelSize: 18
                font.weight: Font.Bold
            }

            Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; Layout.topMargin: 14; Layout.bottomMargin: 14; color: Qt.rgba(1, 1, 1, 0.15) }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: popup.cards.length > 0 && popup.currentIndex < popup.cards.length ? popup.cards[popup.currentIndex].title : ""
                    color: "white"
                    font.family: Config.theme ? Config.theme.font : ""
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: popup.cards.length > 0 && popup.currentIndex < popup.cards.length ? popup.cards[popup.currentIndex].class : ""
                    color: Qt.rgba(1, 1, 1, 0.55)
                    font.family: Config.theme ? Config.theme.monoFont : ""
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            Text {
                text: "Tab  ⏎"
                color: Qt.rgba(1, 1, 1, 0.40)
                font.family: Config.theme ? Config.theme.monoFont : ""
                font.pixelSize: 12
            }
        }
    }

    Text {
        visible: popup.open && popup.cards.length === 0
        anchors.centerIn: parent
        text: "No windows on this workspace"
        color: Qt.rgba(1, 1, 1, 0.55)
        font.family: Config.theme ? Config.theme.font : ""
        font.pixelSize: 20
        z: 3000
    }

    // ═══════════════════════════════════════════════════════════
    // Keys
    // ═══════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        focus: popup.open
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) { popup.cancel(); e.accepted = true; }
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { popup.confirm(); e.accepted = true; }
            else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Right) { popup.next(); e.accepted = true; }
            else if (e.key === Qt.Key_Backtab || e.key === Qt.Key_Left) { popup.prev(); e.accepted = true; }
        }
    }
}
