pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtMultimedia
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
    WlrLayershell.namespace: "matrix:workspaceswitcher"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property var screenVisibilities: Visibilities.getForScreen(screen.name)
    readonly property bool open: screenVisibilities ? screenVisibilities.workspaceswitcher : false

    property var workspaces: []
    property int currentIndex: 0

    // Crossfade entre dos players
    property int frontPlayer: 0   // 0 = A es el visible, 1 = B
    property string currentVideoSrc: ""

    visible: open
    exclusionMode: ExclusionMode.Ignore

    mask: Region { item: popup.open ? fullMask : emptyMask }
    Item { id: fullMask; anchors.fill: parent }
    Item { id: emptyMask; width: 0; height: 0 }

    function resolveVideo(wsId) {
        return Qt.resolvedUrl("../../../assets/workspaces/w" + wsId + ".mp4");
    }

    function loadVideoForCurrent() {
        if (workspaces.length === 0) return;
        const ws = workspaces[currentIndex];
        if (!ws || ws.id === undefined) return;
        const src = popup.resolveVideo(ws.id);
        if (src === popup.currentVideoSrc) return;

        const back = popup.frontPlayer === 0 ? playerB : playerA;
        back.source = "";        // reset
        back.source = src;
        back.play();
        popup.frontPlayer = 1 - popup.frontPlayer;
        popup.currentVideoSrc = src;
    }

    function rebuildWorkspaces() {
        const existing = AxctlService.workspaces.values || [];
        let maxId = 5;
        for (let i = 0; i < existing.length; i++) {
            const id = existing[i].id;
            if (id > maxId) {
                maxId = id;
            }
        }
        const focusedWs = AxctlService.focusedWorkspace;
        if (focusedWs && focusedWs.id > maxId) {
            maxId = focusedWs.id;
        }

        const wsList = [];
        for (let i = 1; i <= maxId; i++) {
            const found = existing.find(w => w.id === i);
            if (found) {
                wsList.push(found);
            } else {
                const isActive = (focusedWs && focusedWs.id === i);
                wsList.push({
                    id: i,
                    name: String(i),
                    active: isActive,
                    monitor: focusedWs ? focusedWs.monitor : 0,
                    windows: 0
                });
            }
        }
        workspaces = wsList;
        const focusedIdx = wsList.findIndex(w => w.active);
        currentIndex = focusedIdx >= 0 ? focusedIdx : 0;
        // Forzar carga inicial (crossfade desde "vacío")
        currentVideoSrc = "";
        loadVideoForCurrent();
    }

    function next() {
        if (workspaces.length === 0) return;
        currentIndex = (currentIndex + 1) % workspaces.length;
    }
    function prev() {
        if (workspaces.length === 0) return;
        currentIndex = (currentIndex - 1 + workspaces.length) % workspaces.length;
    }
    function confirm() {
        if (workspaces.length > 0 && currentIndex >= 0 && currentIndex < workspaces.length) {
            AxctlService.dispatch("workspace " + workspaces[currentIndex].id);
        }
        Visibilities.setActiveModule("");
    }
    function cancel() { Visibilities.setActiveModule(""); }

    onOpenChanged: {
        if (open) rebuildWorkspaces();
        else {
            playerA.stop();
            playerB.stop();
        }
    }
    onCurrentIndexChanged: if (open) loadVideoForCurrent()

    Connections {
        target: GlobalShortcuts
        function onWorkspaceSwitcherCycle(direction) {
            if (!popup.open) return;
            (direction > 0) ? popup.next() : popup.prev();
        }
    }

    FocusGrab {
        windows: [popup]
        active: popup.open
        onCleared: Qt.callLater(() => { if (popup.open) popup.cancel(); })
    }

    // ════ Fallback fondo matugen (cuando no hay video) ════
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(Colors.surfaceContainerLowest.r, Colors.surfaceContainerLowest.g, Colors.surfaceContainerLowest.b, 1.0) }
            GradientStop { position: 1.0; color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 1.0) }
        }
        opacity: popup.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    // ════ Video fullscreen — dos players con crossfade ════
    Item {
        id: videoLayer
        anchors.fill: parent
        opacity: popup.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        VideoOutput {
            id: voutA
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectCrop
            opacity: popup.frontPlayer === 0 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 360; easing.type: Easing.InOutCubic } }
        }
        VideoOutput {
            id: voutB
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectCrop
            opacity: popup.frontPlayer === 1 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 360; easing.type: Easing.InOutCubic } }
        }

        MediaPlayer {
            id: playerA
            videoOutput: voutA
            loops: MediaPlayer.Infinite
            audioOutput: AudioOutput { muted: true }
            onErrorOccurred: (err, msg) => {
                if (popup.frontPlayer === 0) videoLayer.fallbackVisible = true;
            }
            onMediaStatusChanged: {
                if (mediaStatus === MediaPlayer.LoadedMedia && popup.frontPlayer === 0)
                    videoLayer.fallbackVisible = false;
            }
        }
        MediaPlayer {
            id: playerB
            videoOutput: voutB
            loops: MediaPlayer.Infinite
            audioOutput: AudioOutput { muted: true }
            onErrorOccurred: (err, msg) => {
                if (popup.frontPlayer === 1) videoLayer.fallbackVisible = true;
            }
            onMediaStatusChanged: {
                if (mediaStatus === MediaPlayer.LoadedMedia && popup.frontPlayer === 1)
                    videoLayer.fallbackVisible = false;
            }
        }

        // Si el video falla, el layer baja opacidad → el fondo matugen aparece
        property bool fallbackVisible: false
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: videoLayer.fallbackVisible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 320 } }
        }
    }

    // ════ Scrim — gradiente más oscuro del lado derecho para el rail ════
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0;  color: Qt.rgba(0, 0, 0, 0.10) }
            GradientStop { position: 0.55; color: Qt.rgba(0, 0, 0, 0.20) }
            GradientStop { position: 1.0;  color: Qt.rgba(Colors.surfaceContainerLowest.r, Colors.surfaceContainerLowest.g, Colors.surfaceContainerLowest.b, 0.78) }
        }
        opacity: popup.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 220 } }

        MouseArea { anchors.fill: parent; onClicked: popup.cancel() }
    }

    // ════ Rail vertical derecho ════
    Item {
        id: rail
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.rightMargin: Math.max(24, popup.width * 0.025)
        width: Math.min(420, Math.max(280, popup.width * 0.26))

        readonly property real cardSpacing: 18
        readonly property int  visibleCount: Math.max(1, popup.workspaces.length)
        readonly property real cardH: Math.min(180,
            (popup.height * 0.78 - (visibleCount - 1) * cardSpacing) / visibleCount)
        readonly property real cardW: rail.width
        readonly property real stackHeight: visibleCount * cardH + (visibleCount - 1) * cardSpacing
        readonly property real stackY: (popup.height - stackHeight) / 2

        Repeater {
            model: popup.workspaces
            delegate: Item {
                id: wsCard
                required property var modelData
                required property int index

                readonly property int offset: wsCard.index - popup.currentIndex
                readonly property real absOff: Math.abs(offset)
                readonly property bool isActive: offset === 0
                readonly property int wsId: modelData.id !== undefined ? modelData.id : -1

                width: rail.cardW
                height: rail.cardH

                x: isActive ? -28 : 0   // la activa se sale ligeramente hacia el centro
                y: rail.stackY + wsCard.index * (rail.cardH + rail.cardSpacing)

                z: isActive ? 100 : (10 - absOff)

                scale: isActive ? 1.0 : Math.max(0.78, 0.92 - absOff * 0.04)
                opacity: isActive ? 1.0 : Math.max(0.45, 0.78 - absOff * 0.10)

                Behavior on x       { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                Behavior on scale   { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

                ClippingRectangle {
                    anchors.fill: parent
                    radius: 18
                    color: wsCard.isActive
                        ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.22)
                        : Qt.rgba(0, 0, 0, 0.55)
                    border.width: wsCard.isActive ? 2 : 1
                    border.color: wsCard.isActive ? Colors.primary : Qt.rgba(1, 1, 1, 0.10)
                    Behavior on color        { ColorAnimation { duration: 220 } }
                    Behavior on border.color { ColorAnimation { duration: 220 } }

                    // Número XXL de fondo
                    Text {
                        anchors.centerIn: parent
                        text: wsCard.wsId >= 0 ? wsCard.wsId : "?"
                        color: Qt.rgba(1, 1, 1, 0.07)
                        font.family: Config.theme ? Config.theme.font : ""
                        font.pixelSize: Math.round(wsCard.height * 0.95)
                        font.weight: Font.Black
                    }

                    // Mini-mapa de ventanas
                    Item {
                        id: thumbsArea
                        anchors.fill: parent
                        anchors.margins: 16
                        anchors.topMargin: 30

                        property var clientsInWs: {
                            const id = wsCard.wsId;
                            return (AxctlService.clients.values || []).filter(c => c.workspace && c.workspace.id === id);
                        }
                        property real bbMinX: clientsInWs.length === 0 ? 0
                            : clientsInWs.reduce((m, c) => Math.min(m, (c.at && c.at[0]) || 0), Infinity)
                        property real bbMinY: clientsInWs.length === 0 ? 0
                            : clientsInWs.reduce((m, c) => Math.min(m, (c.at && c.at[1]) || 0), Infinity)
                        property real bbMaxX: clientsInWs.length === 0 ? 1
                            : clientsInWs.reduce((m, c) => Math.max(m, ((c.at && c.at[0]) || 0) + ((c.size && c.size[0]) || 0)), -Infinity)
                        property real bbMaxY: clientsInWs.length === 0 ? 1
                            : clientsInWs.reduce((m, c) => Math.max(m, ((c.at && c.at[1]) || 0) + ((c.size && c.size[1]) || 0)), -Infinity)
                        property real bbW: Math.max(1, bbMaxX - bbMinX)
                        property real bbH: Math.max(1, bbMaxY - bbMinY)
                        property real mapScale: Math.min(width / bbW, height / bbH)
                        property real offX: (width - bbW * mapScale) / 2
                        property real offY: (height - bbH * mapScale) / 2

                        Repeater {
                            model: thumbsArea.clientsInWs
                            delegate: ClippingRectangle {
                                id: winThumb
                                required property var modelData
                                radius: 4
                                color: Qt.rgba(1, 1, 1, 0.08)
                                border.color: Qt.rgba(1, 1, 1, 0.20)
                                border.width: 1

                                readonly property real wx: (modelData.at && modelData.at[0]) || 0
                                readonly property real wy: (modelData.at && modelData.at[1]) || 0
                                readonly property real ww: (modelData.size && modelData.size[0]) || 100
                                readonly property real wh: (modelData.size && modelData.size[1]) || 100

                                x: thumbsArea.offX + (wx - thumbsArea.bbMinX) * thumbsArea.mapScale
                                y: thumbsArea.offY + (wy - thumbsArea.bbMinY) * thumbsArea.mapScale
                                width: ww * thumbsArea.mapScale
                                height: wh * thumbsArea.mapScale

                                // Screenshot real de la ventana
                                Image {
                                    id: thumbImg
                                    anchors.fill: parent
                                    cache: false
                                    asynchronous: true
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                    opacity: status === Image.Ready ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 200 } }

                                    function refresh() {
                                        source = "";
                                        if (winThumb.modelData && winThumb.modelData.address)
                                            source = WindowThumbnails.thumbPath(winThumb.modelData.address);
                                    }
                                    Component.onCompleted: refresh()
                                    Connections {
                                        target: WindowThumbnails
                                        function onCaptured() { thumbImg.refresh(); }
                                    }
                                }

                                // Fallback icon de la app si el thumb no cargó
                                Image {
                                    anchors.centerIn: parent
                                    width: Math.min(parent.width, parent.height) * 0.5
                                    height: width
                                    source: Quickshell.iconPath(AppSearch.guessIcon((winThumb.modelData && winThumb.modelData.class) || ""), "image-missing")
                                    sourceSize: Qt.size(width, height)
                                    smooth: true
                                    fillMode: Image.PreserveAspectFit
                                    opacity: thumbImg.status === Image.Ready ? 0 : 0.75
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                }
                            }
                        }

                        Text {
                            visible: thumbsArea.clientsInWs.length === 0
                            anchors.centerIn: parent
                            text: "empty"
                            color: Qt.rgba(1, 1, 1, 0.30)
                            font.family: Config.theme ? Config.theme.monoFont : ""
                            font.pixelSize: 11
                        }
                    }

                    // Header
                    RowLayout {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 12
                        spacing: 8

                        Text {
                            text: "WS"
                            color: Qt.rgba(1, 1, 1, 0.40)
                            font.family: Config.theme ? Config.theme.monoFont : ""
                            font.pixelSize: 10
                            font.weight: Font.Bold
                        }
                        Text {
                            text: wsCard.wsId >= 0 ? String(wsCard.wsId).padStart(2, "0") : "--"
                            color: wsCard.isActive ? Colors.primary : "white"
                            font.family: Config.theme ? Config.theme.monoFont : ""
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            Behavior on color { ColorAnimation { duration: 220 } }
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            visible: wsCard.modelData.active
                            Layout.preferredWidth: 7
                            Layout.preferredHeight: 7
                            radius: 3.5
                            color: Colors.tertiary
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                running: wsCard.modelData.active
                                NumberAnimation { from: 0.4; to: 1; duration: 800; easing.type: Easing.InOutSine }
                                NumberAnimation { from: 1; to: 0.4; duration: 800; easing.type: Easing.InOutSine }
                            }
                        }
                        Text {
                            text: thumbsArea.clientsInWs.length
                            color: Qt.rgba(1, 1, 1, 0.55)
                            font.family: Config.theme ? Config.theme.monoFont : ""
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: wsCard.isActive ? popup.confirm() : (popup.currentIndex = wsCard.index)
                }
            }
        }
    }

    // ════ Indicador en esquina inferior izquierda ════
    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: Math.max(32, popup.width * 0.03)
        anchors.bottomMargin: Math.max(32, popup.height * 0.05)
        width: indicatorContent.width + 40
        height: 60
        radius: 30
        color: Qt.rgba(0, 0, 0, 0.55)
        border.color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 1
        visible: popup.open && popup.workspaces.length > 0

        RowLayout {
            id: indicatorContent
            anchors.centerIn: parent
            spacing: 14

            Text {
                text: popup.workspaces.length > 0
                    ? (String(popup.currentIndex + 1).padStart(2, "0") + " / " + String(popup.workspaces.length).padStart(2, "0"))
                    : "--"
                color: Colors.primary
                font.family: Config.theme ? Config.theme.monoFont : ""
                font.pixelSize: 16
                font.weight: Font.Bold
            }
            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 24; color: Qt.rgba(1, 1, 1, 0.18) }
            Text {
                text: {
                    if (popup.workspaces.length === 0) return "";
                    const w = popup.workspaces[popup.currentIndex];
                    return (w.name && w.name !== "" && w.name !== String(w.id)) ? w.name : ("Workspace " + w.id);
                }
                color: "white"
                font.family: Config.theme ? Config.theme.font : ""
                font.pixelSize: 15
                font.weight: Font.Medium
            }
            Text {
                text: "Tab  ⏎"
                color: Qt.rgba(1, 1, 1, 0.45)
                font.family: Config.theme ? Config.theme.monoFont : ""
                font.pixelSize: 11
            }
        }
    }

    // Keys
    Item {
        anchors.fill: parent
        focus: popup.open
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) { popup.cancel(); e.accepted = true; }
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { popup.confirm(); e.accepted = true; }
            else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab) { popup.next(); e.accepted = true; }
            else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) { popup.prev(); e.accepted = true; }
        }
    }
}
