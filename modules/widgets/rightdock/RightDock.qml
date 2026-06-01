pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.modules.globals
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.corners
import qs.config
import "../../bar/clock"
import "../dashboard/widgets"

PanelWindow {
    id: dock

    anchors {
        top: true
        bottom: true
        right: true
    }

    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "matrix:rightdock"
    exclusionMode: ExclusionMode.Ignore

    readonly property bool isOpen: GlobalStates.rightDockOpen
    // CRÍTICO: ocultar PanelWindow cuando cerrado para no bloquear clicks del sistema.
    visible: isOpen || dockContainer.opacity > 0.001

    readonly property int dockWidth: 420
    readonly property int hPadding: 12
    readonly property int vPadding: 0          // header come hasta el borde
    readonly property int headerHeight: 150
    readonly property int sectionSpacing: 10
    // Tamaño del hombro cóncavo (bottom-left del dock y top-left de la franja del bar)
    readonly property int shoulderSize: Config.roundness > 0 ? Config.roundness + 28 : 44

    readonly property bool barAtTop: {
        const pos = Config.bar?.position ?? "top";
        return pos === "top";
    }

    // Tab activa: 0=Calendar, 1=Weather, 2=Pomodoro, 3=ColorPicker
    property int currentTab: 0
    readonly property int tabBarHeight: 64  // altura reservada arriba para las pills floating

    // Accent dinámico por tab — define el color del border + active pill
    readonly property color tabAccent: {
        switch (currentTab) {
            case 0: return Colors.primary;        // calendar: matugen
            case 1: return "#5dadeb";             // weather: sky blue
            case 2: return "#E07556";             // pomodoro: tomato
            case 3: return Colors.tertiary;       // color picker: matugen tertiary
        }
        return Colors.primary;
    }

    readonly property int barReserved: {
        const enabled = (Config.bar && Config.bar.pinnedOnStartup !== undefined ? Config.bar.pinnedOnStartup : true);
        if (!enabled) return 0;
        const base = (Config.showBackground !== false) ? 44 : 40;
        return Config.bar?.position === "top" ? base : 0;
    }

    implicitWidth: dockWidth + dock.shoulderSize + 8

    // Patrón ChatPanel: cerrado → emptyMask (no intercepta), abierto → fullMask con hombros.
    mask: Region {
        regions: [
            Region { item: dock.visible ? fullMask : emptyMask },
            Region { item: (dock.visible && (!dock.barAtTop || Config.showBackground)) ? topLeftShoulder : null },
            Region { item: (dock.visible && !dock.barAtTop && Config.showBackground) ? bottomLeftShoulder : null }
        ]
    }
    Item {
        id: fullMask
        x: dock.width - dock.dockWidth
        y: dock.barReserved
        width: dock.dockWidth
        height: dock.height - dock.barReserved
    }
    Item { id: emptyMask; width: 0; height: 0 }

    // Width total = dockBg (380) + shoulderSize. Tab rail vertical eliminada.
    readonly property int dockContainerWidth: dock.dockWidth + dock.shoulderSize

    Item {
        id: dockContainer
        width: dock.dockContainerWidth
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: dock.barReserved
        anchors.bottom: parent.bottom
        opacity: dock.isOpen ? 1 : 0
        visible: opacity > 0.001

        transform: Translate {
            id: slideTransform
            x: dock.isOpen ? 0 : dock.dockContainerWidth
            Behavior on x {
                NumberAnimation {
                    duration: Config.animDuration > 0 ? Config.animDuration : 220
                    easing.type: dock.isOpen ? Easing.OutCubic : Easing.InCubic
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDuration > 0 ? Config.animDuration : 220
                easing.type: Easing.OutCubic
            }
        }

        // Dock body — bg matugen sólido, sin border ni overlay.
        StyledRect {
            id: dockBg
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: dock.dockWidth
            variant: "bg"
            enableShadow: true
            radius: 0
            topLeftRadius: 0
            bottomLeftRadius: 0
            topRightRadius: 0
            bottomRightRadius: 0
            clip: true
        }

        // Header fijo (wallpaper + distro logo) arriba del dock — vive
        // FUERA del ScrollView para que las pills floten sobre él.
        Item {
            id: dockHeader
            anchors.top: dockBg.top
            anchors.left: dockBg.left
            anchors.right: dockBg.right
            height: dock.headerHeight  // 150px
            clip: true
            z: 5

            DistroHeader {
                anchors.fill: parent
            }

            // Vignette inferior sutil para destacar borde del header con el contenido
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 24
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.45) }
                }
            }
        }

        // Hombro cóncavo top-left del dock body (solo si bar está arriba).
        Item {
            id: topLeftShoulder
            width: dock.shoulderSize
            height: dock.shoulderSize
            anchors.top: dockBg.top
            anchors.right: dockBg.left
            visible: !dock.barAtTop || Config.showBackground

            RoundCorner {
                anchors.fill: parent
                corner: RoundCorner.CornerEnum.TopRight
                size: dock.shoulderSize
                color: dockBg.color
                Behavior on color { ColorAnimation { duration: 700 } }
            }
        }

        // Hombro cóncavo bottom-left del dock body (solo si bar está abajo).
        Item {
            id: bottomLeftShoulder
            width: dock.shoulderSize
            height: dock.shoulderSize
            anchors.bottom: dockBg.bottom
            anchors.right: dockBg.left
            visible: !dock.barAtTop && Config.showBackground

            RoundCorner {
                anchors.fill: parent
                corner: RoundCorner.CornerEnum.BottomRight
                size: dock.shoulderSize
                color: dockBg.color
                Behavior on color { ColorAnimation { duration: 700 } }
            }
        }

        // Floating tab pills (top center del dock body) — flotan ENCIMA del
        // contenido. Z elevado para quedar sobre la animación de cada tab.
        Row {
            id: tabPills
            z: 100
            anchors.top: dockBg.top
            anchors.horizontalCenter: dockBg.horizontalCenter
            anchors.topMargin: 14
            spacing: 8

            Repeater {
                model: [
                    { ico: Icons.note,    name: "Calendar" },
                    { ico: Icons.sun,     name: "Weather" },
                    { ico: Icons.timer,   name: "Pomodoro" },
                    { ico: Icons.palette, name: "Color picker" }
                ]

                Rectangle {
                    id: pill
                    required property var modelData
                    required property int index
                    readonly property bool isActive: dock.currentTab === index

                    width: 44
                    height: 44
                    radius: 14
                    color: isActive
                        ? dock.tabAccent
                        : (pillMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0, 0, 0, 0.42))
                    border.color: isActive ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.15)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 220 } }
                    Behavior on border.color { ColorAnimation { duration: 220 } }

                    // Glow sutil del pill activo
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 12
                        height: parent.height + 12
                        radius: parent.radius + 6
                        color: "transparent"
                        border.color: dock.tabAccent
                        border.width: 1
                        opacity: pill.isActive ? 0.4 : 0
                        Behavior on opacity { NumberAnimation { duration: 260 } }
                        z: -1
                    }

                    Text {
                        anchors.centerIn: parent
                        text: pill.modelData.ico
                        font.family: Icons.font
                        font.pixelSize: 20
                        color: "white"
                    }

                    MouseArea {
                        id: pillMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dock.currentTab = pill.index
                    }

                    StyledToolTip {
                        show: pillMouse.containsMouse
                        tooltipText: pill.modelData.name
                    }
                }
            }
        }

        ScrollView {
            id: scroller
            anchors.right: parent.right
            anchors.top: dockHeader.bottom  // empieza debajo del DistroHeader fijo
            anchors.bottom: parent.bottom
            width: dock.dockWidth
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: scroller.width
                height: Math.max(implicitHeight, scroller.height)
                spacing: dock.sectionSpacing

                // ── CONTENT (sección activa, full-width) ────────
                StackLayout {
                    id: contentStack
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: dock.hPadding
                    Layout.rightMargin: dock.hPadding
                    Layout.alignment: Qt.AlignTop
                    currentIndex: dock.currentTab

                // ═══════ TAB 0: TIME // CALENDAR (brutalist matugen) ═
                Item {
                    id: calendarTab
                    Layout.fillWidth: true
                    implicitHeight: calendarContent.implicitHeight + 24
                    Layout.preferredHeight: implicitHeight

                    // Reloj central — un solo tick/seg, solo cuando el tab está visible
                    property date now: new Date()
                    Timer {
                        interval: 1000
                        running: dock.isOpen && dock.currentTab === 0
                        repeat: true
                        triggeredOnStart: true
                        onTriggered: calendarTab.now = new Date()
                    }

                    // ── Parallax mouse-follow: px/py normalizados [-1..1] desde el centro.
                    // HoverHandler NO consume eventos → los MouseArea de abajo (nav del mes,
                    // celdas del día) siguen recibiendo su hover normal. El Behavior amortigua
                    // el seguimiento y devuelve las capas al centro al salir.
                    property real px: parallaxHover.hovered ? (parallaxHover.point.position.x / width - 0.5) * 2 : 0
                    property real py: parallaxHover.hovered ? (parallaxHover.point.position.y / height - 0.5) * 2 : 0
                    Behavior on px { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                    Behavior on py { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                    HoverHandler { id: parallaxHover }

                    // ── BACKGROUND: superficie matugen oscura + grid técnico + glows primary/tertiary.
                    // Reemplaza el viejo cielo time-of-day para alinear el tab con los demás.
                    Rectangle {
                        id: calendarBg
                        anchors.fill: parent
                        radius: Styling.radius(8)
                        clip: true
                        color: Qt.darker(Colors.surface, 1.25)

                        // Glow blob primary (capa profunda, parallax fuerte)
                        Rectangle {
                            width: parent.width * 1.1
                            height: width
                            radius: width / 2
                            x: parent.width * 0.55 - width / 2
                            y: -width * 0.35
                            color: Colors.primary
                            opacity: 0.16
                            transform: Translate { x: calendarTab.px * 26; y: calendarTab.py * 20 }
                        }
                        // Glow blob tertiary (parallax aún más fuerte, esquina opuesta)
                        Rectangle {
                            width: parent.width * 0.7
                            height: width
                            radius: width / 2
                            x: parent.width * 0.1 - width / 2
                            y: parent.height * 0.72
                            color: Colors.tertiary
                            opacity: 0.10
                            transform: Translate { x: calendarTab.px * 34; y: calendarTab.py * 26 }
                        }

                        // Grid técnico (capa media, parallax medio)
                        Canvas {
                            id: gridCanvas
                            anchors.fill: parent
                            antialiasing: false
                            transform: Translate { x: calendarTab.px * 12; y: calendarTab.py * 10 }
                            readonly property color lineColor: Colors.outline
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                ctx.strokeStyle = lineColor;
                                ctx.globalAlpha = 0.12;
                                ctx.lineWidth = 1;
                                var step = 26;
                                for (var gx = -step; gx <= width + step; gx += step) {
                                    ctx.beginPath(); ctx.moveTo(gx, 0); ctx.lineTo(gx, height); ctx.stroke();
                                }
                                for (var gy = -step; gy <= height + step; gy += step) {
                                    ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(width, gy); ctx.stroke();
                                }
                            }
                            Connections {
                                target: Colors
                                function onOutlineChanged() { gridCanvas.requestPaint(); }
                            }
                        }

                        // Vignette inferior sutil para asentar el contenido
                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.0) }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.28) }
                            }
                        }
                    }

                    ColumnLayout {
                        id: calendarContent
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        // ════ HERO: reloj digital con parallax en capas ════
                        StyledRect {
                            variant: "internalbg"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 168
                            radius: 0

                            // Accent bar izquierda (brutalist)
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 4
                                color: Colors.primary
                            }

                            // Header chip
                            Text {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.topMargin: 10
                                anchors.leftMargin: 16
                                text: "Time · Calendar"
                                color: Colors.outline
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.Medium
                            }

                            // Ghost digits (capa profunda, parallax fuerte y contrario)
                            Text {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -4
                                text: Qt.formatTime(calendarTab.now, "HH")
                                font.family: Config.theme.monoFont
                                font.pixelSize: 150
                                font.weight: Font.DemiBold
                                color: Colors.primary
                                opacity: 0.08
                                transform: Translate { x: calendarTab.px * -18; y: calendarTab.py * -12 }
                            }

                            // Dígitos reales (capa frontal, parallax leve)
                            Row {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: 4
                                spacing: 2
                                transform: Translate { x: calendarTab.px * 8; y: calendarTab.py * 6 }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Qt.formatTime(calendarTab.now, "HH")
                                    font.family: Config.theme.monoFont
                                    font.pixelSize: 58
                                    font.weight: Font.DemiBold
                                    color: Colors.overBackground
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: ":"
                                    font.family: Config.theme.monoFont
                                    font.pixelSize: 58
                                    font.weight: Font.DemiBold
                                    color: Colors.primary
                                    opacity: calendarTab.now.getSeconds() % 2 === 0 ? 1.0 : 0.3
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Qt.formatTime(calendarTab.now, "mm")
                                    font.family: Config.theme.monoFont
                                    font.pixelSize: 58
                                    font.weight: Font.DemiBold
                                    color: Colors.overBackground
                                }
                                // Segundos en bloque primary (superscript brutalist)
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: -16
                                    width: ssText.implicitWidth + 10
                                    height: ssText.implicitHeight + 6
                                    color: Colors.primary
                                    Text {
                                        id: ssText
                                        anchors.centerIn: parent
                                        text: Qt.formatTime(calendarTab.now, "ss")
                                        font.family: Config.theme.monoFont
                                        font.pixelSize: 16
                                        font.weight: Font.Bold
                                        color: Colors.background
                                    }
                                }
                            }

                            // Fecha + context strip abajo
                            Column {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 12
                                anchors.leftMargin: 16
                                spacing: 3

                                Text {
                                    text: {
                                        var s = calendarTab.now.toLocaleDateString(Qt.locale(), "dddd, d MMMM yyyy");
                                        return s.charAt(0).toUpperCase() + s.slice(1);
                                    }
                                    color: Colors.overBackground
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(1)
                                    font.weight: Font.Medium
                                }

                                Row {
                                    spacing: 8

                                    function isoWeek(d) {
                                        var x = new Date(d.getTime());
                                        x.setHours(0, 0, 0, 0);
                                        x.setDate(x.getDate() + 3 - (x.getDay() + 6) % 7);
                                        var week1 = new Date(x.getFullYear(), 0, 4);
                                        return 1 + Math.round(((x - week1) / 86400000 - 3 + (week1.getDay() + 6) % 7) / 7);
                                    }
                                    function dayOfYear(d) {
                                        var start = new Date(d.getFullYear(), 0, 0);
                                        return Math.floor((d - start) / 86400000);
                                    }
                                    function daysInYear(y) {
                                        return ((y % 4 === 0 && y % 100 !== 0) || y % 400 === 0) ? 366 : 365;
                                    }

                                    Text {
                                        text: "Week " + parent.isoWeek(calendarTab.now)
                                        color: Colors.outline
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-1)
                                        font.weight: Font.Medium
                                    }
                                    Text { text: "·"; color: Colors.outline; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1) }
                                    Text {
                                        text: "Day " + parent.dayOfYear(calendarTab.now) + "/" + parent.daysInYear(calendarTab.now.getFullYear())
                                        color: Colors.outline
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-1)
                                        font.weight: Font.Medium
                                    }
                                    Text { text: "·"; color: Colors.outline; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1) }
                                    Text {
                                        text: (100 * parent.dayOfYear(calendarTab.now) / parent.daysInYear(calendarTab.now.getFullYear())).toFixed(0) + "% año"
                                        color: Colors.primary
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-1)
                                        font.weight: Font.Medium
                                    }
                                }
                            }
                        }

                        // ════ ELAPSED: barras de progreso brutalist ════
                        StyledRect {
                            id: elapsedCard
                            variant: "internalbg"
                            Layout.fillWidth: true
                            Layout.preferredHeight: elapsedCol.implicitHeight + 28
                            radius: 0

                            function dayProgress(d) {
                                return (d.getHours() * 3600 + d.getMinutes() * 60 + d.getSeconds()) / 86400;
                            }
                            function weekProgress(d) {
                                var dow = (d.getDay() + 6) % 7;
                                var elapsed = dow * 86400000 + (d - new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime());
                                return elapsed / (7 * 86400000);
                            }
                            function monthProgress(d) {
                                var first = new Date(d.getFullYear(), d.getMonth(), 1);
                                var next = new Date(d.getFullYear(), d.getMonth() + 1, 1);
                                return (d - first) / (next - first);
                            }
                            function yearProgress(d) {
                                var first = new Date(d.getFullYear(), 0, 1);
                                var next = new Date(d.getFullYear() + 1, 0, 1);
                                return (d - first) / (next - first);
                            }

                            Column {
                                id: elapsedCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 14
                                anchors.leftMargin: 18
                                spacing: 9

                                Row {
                                    spacing: 8
                                    Rectangle { width: 4; height: elapsedHdr.implicitHeight; color: Colors.primary; anchors.verticalCenter: parent.verticalCenter }
                                    Text {
                                        id: elapsedHdr
                                        text: "Elapsed"
                                        color: Colors.overBackground
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-1)
                                        font.weight: Font.DemiBold
                                    }
                                }

                                Repeater {
                                    model: [
                                        { label: "Day",   getter: elapsedCard.dayProgress },
                                        { label: "Week",  getter: elapsedCard.weekProgress },
                                        { label: "Month", getter: elapsedCard.monthProgress },
                                        { label: "Year",  getter: elapsedCard.yearProgress }
                                    ]

                                    Item {
                                        required property var modelData
                                        width: elapsedCol.width
                                        height: 18
                                        readonly property real pct: modelData.getter(calendarTab.now)

                                        Row {
                                            anchors.fill: parent
                                            spacing: 10

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 50
                                                text: modelData.label
                                                color: Colors.outline
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-1)
                                                font.weight: Font.Medium
                                            }
                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width - 50 - 10 - 56 - 10
                                                height: 8
                                                radius: 0
                                                color: Qt.darker(Colors.surface, 1.5)
                                                border.color: Colors.outline
                                                border.width: 1
                                                Rectangle {
                                                    x: 1; y: 1
                                                    width: Math.max(0, (parent.width - 2) * pct)
                                                    height: parent.height - 2
                                                    radius: 0
                                                    color: Colors.primary
                                                    Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                                                }
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 56
                                                horizontalAlignment: Text.AlignRight
                                                text: (pct * 100).toFixed(1) + "%"
                                                color: Colors.overBackground
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-1)
                                                font.weight: Font.Medium
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ════ CALENDAR del mes (brutalist) ════
                        StyledRect {
                            id: calendarPane
                            variant: "internalbg"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 96 + 6 * monthGrid.cellW
                            radius: 0

                            property date currentDate: calendarTab.now
                            property date viewDate: new Date()

                            function isSameDay(a, b) {
                                return a.getFullYear() === b.getFullYear()
                                    && a.getMonth() === b.getMonth()
                                    && a.getDate() === b.getDate();
                            }

                            Column {
                                id: calendarColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.leftMargin: 14
                                anchors.rightMargin: 12
                                anchors.topMargin: 12
                                spacing: 8

                                // Header mes + nav
                                Item {
                                    width: parent.width
                                    height: 28

                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 8
                                        Rectangle { width: 4; height: monthLbl.implicitHeight; color: Colors.primary; anchors.verticalCenter: parent.verticalCenter }
                                        Text {
                                            id: monthLbl
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: {
                                                var s = calendarPane.viewDate.toLocaleDateString(Qt.locale(), "MMMM yyyy");
                                                return s.charAt(0).toUpperCase() + s.slice(1);
                                            }
                                            color: Colors.overBackground
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(0)
                                            font.weight: Font.DemiBold
                                        }
                                    }

                                    Row {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4

                                        Repeater {
                                            model: [
                                                { ico: "‹", delta: -1 },
                                                { ico: "●", delta:  0 },
                                                { ico: "›", delta:  1 }
                                            ]
                                            Item {
                                                id: navBtn
                                                required property var modelData
                                                width: 24
                                                height: 24
                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: 0
                                                    color: navMa.containsMouse ? Colors.primary : "transparent"
                                                    border.color: Colors.outline
                                                    border.width: 1
                                                    Behavior on color { ColorAnimation { duration: 100 } }
                                                }
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: navBtn.modelData.ico
                                                    font.family: Config.theme.font
                                                    font.pixelSize: navBtn.modelData.delta === 0 ? 10 : 16
                                                    font.weight: Font.Bold
                                                    color: navMa.containsMouse ? Colors.background : Colors.overBackground
                                                }
                                                MouseArea {
                                                    id: navMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (navBtn.modelData.delta === 0) {
                                                            calendarPane.viewDate = new Date();
                                                        } else {
                                                            var d = new Date(calendarPane.viewDate);
                                                            d.setMonth(d.getMonth() + navBtn.modelData.delta);
                                                            calendarPane.viewDate = d;
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Headers de día
                                Row {
                                    id: weekHeaderRow
                                    spacing: 2
                                    property real cellW: (calendarColumn.width - 6 * spacing) / 7

                                    Repeater {
                                        model: ["L", "M", "M", "J", "V", "S", "D"]
                                        Item {
                                            required property var modelData
                                            width: weekHeaderRow.cellW
                                            height: 18
                                            Text {
                                                anchors.centerIn: parent
                                                text: parent.modelData
                                                color: Colors.outline
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-1)
                                                font.weight: Font.Medium
                                            }
                                        }
                                    }
                                }

                                // Grid del mes (42 celdas)
                                Grid {
                                    id: monthGrid
                                    columns: 7
                                    spacing: 2
                                    property real cellW: (calendarColumn.width - 6 * spacing) / 7
                                    property real cellH: Math.max(cellW, (calendarPane.height - 96) / 6)

                                    property var monthCells: {
                                        var view = calendarPane.viewDate;
                                        var first = new Date(view.getFullYear(), view.getMonth(), 1);
                                        var startWeekday = (first.getDay() + 6) % 7;
                                        var start = new Date(first);
                                        start.setDate(first.getDate() - startWeekday);
                                        var cells = [];
                                        for (var i = 0; i < 42; i++) {
                                            var d = new Date(start);
                                            d.setDate(start.getDate() + i);
                                            cells.push({
                                                date: d,
                                                day: d.getDate(),
                                                inMonth: d.getMonth() === view.getMonth(),
                                                isToday: calendarPane.isSameDay(d, calendarPane.currentDate)
                                            });
                                        }
                                        return cells;
                                    }

                                    Repeater {
                                        model: monthGrid.monthCells
                                        Item {
                                            required property var modelData
                                            width: monthGrid.cellW
                                            height: monthGrid.cellH

                                            Rectangle {
                                                anchors.fill: parent
                                                anchors.margins: 1
                                                radius: 0
                                                color: parent.modelData.isToday
                                                       ? Colors.primary
                                                       : (cellHover.containsMouse ? Qt.darker(Colors.surface, 1.5) : "transparent")
                                                border.color: parent.modelData.isToday
                                                              ? Colors.primary
                                                              : (cellHover.containsMouse ? Colors.outline : "transparent")
                                                border.width: 1
                                                Behavior on color { ColorAnimation { duration: 100 } }
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: parent.modelData.day
                                                color: parent.modelData.isToday
                                                       ? Colors.background
                                                       : (parent.modelData.inMonth ? Colors.overBackground : Colors.outline)
                                                opacity: parent.modelData.inMonth ? 1 : 0.4
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-1)
                                                font.weight: parent.modelData.isToday ? Font.DemiBold : Font.Normal
                                            }

                                            MouseArea {
                                                id: cellHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                            }
                                        }
                                    }
                                }
                            }
                        }

                    } // ColumnLayout calendarContent
                } // Item calendarTab (TAB 0)

                // ═══════ TAB 1: WEATHER (brutalist matugen HUD) ═
                Item {
                    id: weatherTab
                    Layout.fillWidth: true
                    implicitHeight: weatherContent.implicitHeight + 24
                    Layout.preferredHeight: implicitHeight

                    // Categoría del weather code (animación + color reactivo)
                    readonly property string weatherCategory: {
                        var c = WeatherService.weatherCode;
                        if (c === 0) return WeatherService.isDay ? "sunny" : "night";
                        if (c <= 3) return "cloudy";
                        if (c === 45 || c === 48) return "foggy";
                        if ((c >= 51 && c <= 57) || (c >= 61 && c <= 67) || (c >= 80 && c <= 82)) return "rainy";
                        if ((c >= 71 && c <= 77) || (c >= 85 && c <= 86)) return "snowy";
                        if (c >= 95 && c <= 99) return "stormy";
                        return "cloudy";
                    }

                    // weatherCode → glyph Phosphor (hero + forecast)
                    function codeIcon(code, day) {
                        if (code === 0 || code === 1) return day ? Icons.sun : Icons.moon;
                        if (code === 2) return day ? Icons.wCloudSun : Icons.wCloudMoon;
                        if (code === 3) return Icons.wCloud;
                        if (code === 45 || code === 48) return Icons.wCloudFog;
                        if ((code >= 51 && code <= 57) || (code >= 61 && code <= 67) || (code >= 80 && code <= 82)) return Icons.wCloudRain;
                        if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86)) return Icons.wCloudSnow;
                        if (code >= 95) return Icons.wCloudLightning;
                        return Icons.wCloud;
                    }

                    // Color del glow, reactivo al clima
                    property color weatherAccent: {
                        switch (weatherCategory) {
                            case "sunny":  return Colors.tertiary;
                            case "night":  return Colors.primary;
                            case "rainy":  return Colors.secondary;
                            case "stormy": return Colors.secondary;
                            case "snowy":  return Colors.primary;
                            case "foggy":  return Colors.outline;
                            case "cloudy": return Colors.secondary;
                        }
                        return Colors.primary;
                    }
                    Behavior on weatherAccent { ColorAnimation { duration: 1200 } }

                    // ── Parallax mouse-follow (hermano del tab Calendar)
                    property real px: parallaxHoverW.hovered ? (parallaxHoverW.point.position.x / width - 0.5) * 2 : 0
                    property real py: parallaxHoverW.hovered ? (parallaxHoverW.point.position.y / height - 0.5) * 2 : 0
                    Behavior on px { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                    Behavior on py { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                    HoverHandler { id: parallaxHoverW }

                    // ── BACKGROUND: superficie matugen + grid + glow reactivo + animación clima
                    Rectangle {
                        id: weatherBg
                        anchors.fill: parent
                        radius: Styling.radius(8)
                        clip: true
                        color: Qt.darker(Colors.surface, 1.25)

                        // Glow reactivo (parallax fuerte)
                        Rectangle {
                            width: parent.width * 1.1
                            height: width
                            radius: width / 2
                            x: parent.width * 0.6 - width / 2
                            y: -width * 0.35
                            color: weatherTab.weatherAccent
                            opacity: 0.16
                            transform: Translate { x: weatherTab.px * 26; y: weatherTab.py * 20 }
                        }

                        // Grid técnico (parallax medio)
                        Canvas {
                            id: wGridCanvas
                            anchors.fill: parent
                            antialiasing: false
                            transform: Translate { x: weatherTab.px * 12; y: weatherTab.py * 10 }
                            readonly property color lineColor: Colors.outline
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                ctx.strokeStyle = lineColor;
                                ctx.globalAlpha = 0.12;
                                ctx.lineWidth = 1;
                                var step = 26;
                                for (var gx = -step; gx <= width + step; gx += step) { ctx.beginPath(); ctx.moveTo(gx, 0); ctx.lineTo(gx, height); ctx.stroke(); }
                                for (var gy = -step; gy <= height + step; gy += step) { ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(width, gy); ctx.stroke(); }
                            }
                            Connections { target: Colors; function onOutlineChanged() { wGridCanvas.requestPaint(); } }
                        }

                        // Animación del clima (tinte matugen, sutil, parallax leve)
                        Loader {
                            anchors.fill: parent
                            opacity: 0.5
                            transform: Translate { x: weatherTab.px * 8; y: weatherTab.py * 6 }
                            sourceComponent: {
                                switch (weatherTab.weatherCategory) {
                                    case "sunny":  return sunnyAnim;
                                    case "night":  return nightAnim;
                                    case "rainy":  return rainAnim;
                                    case "stormy": return stormyAnim;
                                    case "snowy":  return snowyAnim;
                                    case "foggy":  return foggyAnim;
                                    case "cloudy": return cloudyAnim;
                                }
                                return cloudyAnim;
                            }
                        }

                        // Vignette inferior
                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.0) }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.30) }
                            }
                        }
                    }

                    // ── CONTENT
                    ColumnLayout {
                        id: weatherContent
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        // HERO: icono + temperatura gigante + descripción
                        StyledRect {
                            variant: "internalbg"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 140
                            radius: 0

                            Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 4; color: Colors.primary }

                            Text {
                                anchors.top: parent.top; anchors.left: parent.left
                                anchors.topMargin: 10; anchors.leftMargin: 16
                                text: "Weather"
                                color: Colors.outline
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.Medium
                            }

                            // Ghost glyph (parallax fuerte y contrario)
                            Text {
                                anchors.centerIn: parent
                                text: weatherTab.codeIcon(WeatherService.weatherCode, WeatherService.isDay)
                                font.family: Icons.font
                                font.pixelSize: 150
                                color: Colors.primary
                                opacity: 0.07
                                transform: Translate { x: weatherTab.px * -18; y: weatherTab.py * -12 }
                            }

                            // Foreground: icono + temp + desc
                            Row {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: 6
                                spacing: 16
                                transform: Translate { x: weatherTab.px * 8; y: weatherTab.py * 6 }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: weatherTab.codeIcon(WeatherService.weatherCode, WeatherService.isDay)
                                    font.family: Icons.font
                                    font.pixelSize: 60
                                    color: Colors.primary
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    Row {
                                        spacing: 0
                                        Text {
                                            text: Math.round(WeatherService.currentTemp)
                                            color: Colors.overBackground
                                            font.family: Config.theme.monoFont
                                            font.pixelSize: 54
                                            font.weight: Font.DemiBold
                                        }
                                        Text {
                                            anchors.top: parent.top
                                            anchors.topMargin: 6
                                            text: "°"
                                            color: Colors.primary
                                            font.family: Config.theme.monoFont
                                            font.pixelSize: 30
                                            font.weight: Font.DemiBold
                                        }
                                    }
                                    Text {
                                        text: {
                                            var s = WeatherService.weatherDescription || "—";
                                            return s.charAt(0).toUpperCase() + s.slice(1);
                                        }
                                        color: Colors.overBackground
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(0)
                                        font.weight: Font.Medium
                                    }
                                    Text {
                                        text: "Feels " + Math.round(WeatherService.apparentTemp) + "°   ↑" + Math.round(WeatherService.maxTemp) + "°  ↓" + Math.round(WeatherService.minTemp) + "°"
                                        color: Colors.outline
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-1)
                                    }
                                }
                            }
                        }

                        // STATS: 4 bloques con glyph Phosphor
                        Row {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 76
                            spacing: 8

                            Repeater {
                                model: [
                                    { ico: Icons.wHumidity, lab: "Humidity", val: Math.round(WeatherService.humidity) + "%" },
                                    { ico: Icons.sun,       lab: "UV",       val: WeatherService.uvIndex.toFixed(1) },
                                    { ico: Icons.wUmbrella, lab: "Rain",     val: Math.round(WeatherService.precipitationProbability) + "%" },
                                    { ico: Icons.wWind,     lab: "Wind",     val: WeatherService.windSpeed.toFixed(0) }
                                ]
                                StyledRect {
                                    required property var modelData
                                    variant: "internalbg"
                                    width: (weatherContent.width - 24) / 4
                                    height: 76
                                    radius: 0

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 3
                                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.ico; font.family: Icons.font; font.pixelSize: 20; color: Colors.primary }
                                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.val; color: Colors.overBackground; font.family: Config.theme.monoFont; font.pixelSize: Styling.fontSize(1); font.weight: Font.DemiBold }
                                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.lab; color: Colors.outline; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-2) }
                                    }
                                }
                            }
                        }

                        // WIND: dial brutalist
                        StyledRect {
                            variant: "internalbg"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 96
                            radius: 0

                            Row {
                                anchors.centerIn: parent
                                spacing: 24

                                Item {
                                    width: 64; height: 64
                                    anchors.verticalCenter: parent.verticalCenter

                                    Canvas {
                                        id: windDial
                                        anchors.fill: parent
                                        antialiasing: true
                                        readonly property color ringColor: Colors.outline
                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.clearRect(0, 0, width, height);
                                            var cx = width / 2, cy = height / 2, r = Math.min(cx, cy) - 2;
                                            ctx.strokeStyle = ringColor;
                                            ctx.lineWidth = 1.5;
                                            ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2 * Math.PI); ctx.stroke();
                                            // ticks afilados cada 45°
                                            for (var i = 0; i < 8; i++) {
                                                var a = i * Math.PI / 4 - Math.PI / 2;
                                                var inner = i % 2 === 0 ? r - 7 : r - 4;
                                                ctx.beginPath();
                                                ctx.moveTo(cx + inner * Math.cos(a), cy + inner * Math.sin(a));
                                                ctx.lineTo(cx + r * Math.cos(a), cy + r * Math.sin(a));
                                                ctx.stroke();
                                            }
                                            ctx.fillStyle = ringColor;
                                            ctx.font = "600 9px " + Config.theme.font;
                                            ctx.textAlign = "center"; ctx.textBaseline = "middle";
                                            ctx.fillText("N", cx, cy - r + 9);
                                        }
                                        Connections { target: Colors; function onOutlineChanged() { windDial.requestPaint(); } }
                                    }
                                    Rectangle {
                                        width: 3; height: 26; radius: 0
                                        color: Colors.primary
                                        x: parent.width / 2 - width / 2
                                        y: parent.height / 2 - height
                                        transformOrigin: Item.Bottom
                                        rotation: WeatherService.windDirection + 180
                                        Behavior on rotation { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                                    }
                                    Rectangle { anchors.centerIn: parent; width: 6; height: 6; radius: 0; color: Colors.primary }
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Row {
                                        spacing: 4
                                        Text {
                                            text: WeatherService.windSpeed.toFixed(0)
                                            color: Colors.overBackground
                                            font.family: Config.theme.monoFont
                                            font.pixelSize: Styling.fontSize(5)
                                            font.weight: Font.DemiBold
                                        }
                                        Text {
                                            anchors.bottom: parent.bottom
                                            anchors.bottomMargin: 4
                                            text: "km/h"
                                            color: Colors.outline
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-1)
                                        }
                                    }
                                    Text {
                                        text: {
                                            var dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
                                            return "From " + dirs[Math.round(WeatherService.windDirection / 45) % 8];
                                        }
                                        color: Colors.outline
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-1)
                                    }
                                }
                            }
                        }

                        // FORECAST 5 días
                        StyledRect {
                            variant: "internalbg"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 124
                            radius: 0
                            visible: WeatherService.forecast.length > 0

                            Column {
                                anchors.fill: parent
                                anchors.margins: 12
                                anchors.leftMargin: 16
                                spacing: 10

                                Row {
                                    spacing: 8
                                    Rectangle { width: 4; height: fcHdr.implicitHeight; color: Colors.primary; anchors.verticalCenter: parent.verticalCenter }
                                    Text {
                                        id: fcHdr
                                        text: "Forecast"
                                        color: Colors.overBackground
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-1)
                                        font.weight: Font.DemiBold
                                    }
                                }

                                Row {
                                    width: parent.width
                                    spacing: 4
                                    Repeater {
                                        model: WeatherService.forecast.slice(0, 5)
                                        Column {
                                            required property var modelData
                                            width: (parent.width - 4 * 4) / 5
                                            spacing: 4
                                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.dayName; color: Colors.outline; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1); font.weight: Font.Medium }
                                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: weatherTab.codeIcon(modelData.weatherCode, true); font.family: Icons.font; font.pixelSize: 22; color: Colors.primary }
                                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(modelData.maxTemp) + "°"; color: Colors.overBackground; font.family: Config.theme.monoFont; font.pixelSize: Styling.fontSize(0); font.weight: Font.DemiBold }
                                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(modelData.minTemp) + "°"; color: Colors.outline; font.family: Config.theme.monoFont; font.pixelSize: Styling.fontSize(-1) }
                                        }
                                    }
                                }
                            }
                        }

                        // HOURLY 24h (curva)
                        StyledRect {
                            variant: "internalbg"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 116
                            radius: 0
                            visible: WeatherService.hourly.length > 0

                            Column {
                                anchors.fill: parent
                                anchors.margins: 12
                                anchors.leftMargin: 16
                                spacing: 6

                                Row {
                                    spacing: 8
                                    Rectangle { width: 4; height: hrHdr.implicitHeight; color: Colors.primary; anchors.verticalCenter: parent.verticalCenter }
                                    Text {
                                        id: hrHdr
                                        text: "Next 24h"
                                        color: Colors.overBackground
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-1)
                                        font.weight: Font.DemiBold
                                    }
                                }

                                Canvas {
                                    id: hourlyCanvas
                                    width: parent.width
                                    height: parent.height - 26
                                    antialiasing: true
                                    property var d: WeatherService.hourly
                                    readonly property color curveColor: Colors.primary
                                    readonly property color labelColor: Colors.outline
                                    onDChanged: requestPaint()
                                    Connections { target: Colors; function onPrimaryChanged() { hourlyCanvas.requestPaint(); } }
                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.clearRect(0, 0, width, height);
                                        if (!d || d.length === 0) return;
                                        var w = width, h = height, pad = 8, n = d.length;
                                        var minT = d[0].temp, maxT = d[0].temp;
                                        for (var i = 0; i < n; i++) { if (d[i].temp < minT) minT = d[i].temp; if (d[i].temp > maxT) maxT = d[i].temp; }
                                        var range = maxT - minT || 1;
                                        function px(j) { return pad + (j / (n - 1)) * (w - 2 * pad); }
                                        function py(t) { return h - pad - ((t - minT) / range) * (h - 2 * pad - 12); }
                                        // fill bajo la curva (primary translúcido)
                                        ctx.fillStyle = Qt.rgba(curveColor.r, curveColor.g, curveColor.b, 0.14);
                                        ctx.beginPath();
                                        ctx.moveTo(px(0), h - pad);
                                        for (var j = 0; j < n; j++) ctx.lineTo(px(j), py(d[j].temp));
                                        ctx.lineTo(px(n - 1), h - pad);
                                        ctx.closePath(); ctx.fill();
                                        // curva
                                        ctx.strokeStyle = curveColor; ctx.lineWidth = 2;
                                        ctx.beginPath();
                                        for (var k = 0; k < n; k++) { if (k === 0) ctx.moveTo(px(k), py(d[k].temp)); else ctx.lineTo(px(k), py(d[k].temp)); }
                                        ctx.stroke();
                                        // labels horarios
                                        ctx.fillStyle = labelColor;
                                        ctx.font = "10px " + Config.theme.font;
                                        ctx.textAlign = "center";
                                        var marks = [0, 6, 12, 18, n - 1];
                                        for (var m = 0; m < marks.length; m++) {
                                            var mi = marks[m];
                                            if (mi >= n) continue;
                                            ctx.fillText(d[mi].time.split("T")[1].substring(0, 5), px(mi), h - 1);
                                        }
                                    }
                                }
                            }
                        }

                        // SUN / MOON
                        StyledRect {
                            variant: "internalbg"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 64
                            radius: 0

                            Row {
                                anchors.centerIn: parent
                                spacing: 28

                                Repeater {
                                    model: [
                                        { ico: Icons.wSunHorizon, lab: "Sunrise", val: WeatherService.sunrise || "—" },
                                        { ico: Icons.wSunHorizon, lab: "Sunset",  val: WeatherService.sunset  || "—" },
                                        { ico: Icons.moon,        lab: "Moon",    val: "" }
                                    ]
                                    Row {
                                        required property var modelData
                                        spacing: 8
                                        Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.ico; font.family: Icons.font; font.pixelSize: 22; color: Colors.primary }
                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 0
                                            Text { text: modelData.lab; color: Colors.outline; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-2) }
                                            Text {
                                                text: modelData.val !== "" ? modelData.val : "—"
                                                color: Colors.overBackground
                                                font.family: Config.theme.monoFont
                                                font.pixelSize: Styling.fontSize(0)
                                                font.weight: Font.DemiBold
                                                visible: modelData.val !== ""
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── ANIMATION COMPONENTS (tinte matugen)
                    Component {
                        id: sunnyAnim
                        Item {
                            Item {
                                width: 120; height: 120
                                x: parent.width - width - 28
                                y: 28
                                Rectangle { anchors.centerIn: parent; width: 140; height: 140; radius: 70; color: Qt.rgba(Colors.tertiary.r, Colors.tertiary.g, Colors.tertiary.b, 0.12) }
                                Rectangle { anchors.centerIn: parent; width: 110; height: 110; radius: 55; color: Qt.rgba(Colors.tertiary.r, Colors.tertiary.g, Colors.tertiary.b, 0.22) }
                                Rectangle { anchors.centerIn: parent; width: 80; height: 80; radius: 40; color: Colors.tertiary }
                                Rectangle { anchors.centerIn: parent; width: 60; height: 60; radius: 30; color: Qt.lighter(Colors.tertiary, 1.3) }
                                Item {
                                    anchors.centerIn: parent
                                    width: 180; height: 180
                                    NumberAnimation on rotation { from: 0; to: 360; duration: 30000; loops: Animation.Infinite }
                                    Repeater {
                                        model: 8
                                        Rectangle {
                                            required property int index
                                            width: 2; height: 28; radius: 1
                                            color: Qt.rgba(Colors.tertiary.r, Colors.tertiary.g, Colors.tertiary.b, 0.4)
                                            x: 180 / 2 - 1; y: 0
                                            transformOrigin: Item.Bottom
                                            rotation: index * 45
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Component {
                        id: nightAnim
                        Item {
                            Repeater {
                                model: 60
                                Rectangle {
                                    required property int index
                                    x: Math.random() * parent.width
                                    y: Math.random() * (parent.height * 0.7)
                                    width: 1 + Math.random() * 1.5
                                    height: width
                                    radius: width / 2
                                    color: Colors.overBackground
                                    SequentialAnimation on opacity {
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 0.2; to: 1.0; duration: 1500 + Math.random() * 2000 }
                                        NumberAnimation { from: 1.0; to: 0.2; duration: 1500 + Math.random() * 2000 }
                                    }
                                }
                            }
                            Rectangle {
                                width: 80; height: 80; radius: 40
                                x: parent.width - 110; y: 30
                                color: Qt.lighter(Colors.tertiary, 1.2)
                                Rectangle { width: 65; height: 65; radius: 32; x: 20; y: -5; color: Qt.darker(Colors.surface, 1.25) }
                            }
                        }
                    }

                    Component {
                        id: rainAnim
                        Item {
                            Repeater {
                                model: 80
                                Rectangle {
                                    required property int index
                                    x: Math.random() * parent.width
                                    width: 1
                                    height: 8 + Math.random() * 8
                                    color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.5)
                                    SequentialAnimation on y {
                                        loops: Animation.Infinite
                                        NumberAnimation { from: -20; to: parent.height + 20; duration: 800 + Math.random() * 800; easing.type: Easing.InQuad }
                                    }
                                }
                            }
                        }
                    }

                    Component {
                        id: stormyAnim
                        Item {
                            Repeater {
                                model: 100
                                Rectangle {
                                    required property int index
                                    x: Math.random() * parent.width
                                    width: 1.5
                                    height: 12 + Math.random() * 10
                                    color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.6)
                                    SequentialAnimation on y {
                                        loops: Animation.Infinite
                                        NumberAnimation { from: -30; to: parent.height + 20; duration: 600 + Math.random() * 500; easing.type: Easing.InQuad }
                                    }
                                }
                            }
                            Rectangle {
                                anchors.fill: parent
                                color: Colors.overBackground
                                opacity: 0
                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    PauseAnimation { duration: 4000 + Math.random() * 4000 }
                                    NumberAnimation { to: 0.45; duration: 60 }
                                    NumberAnimation { to: 0; duration: 200 }
                                    PauseAnimation { duration: 80 }
                                    NumberAnimation { to: 0.3; duration: 50 }
                                    NumberAnimation { to: 0; duration: 250 }
                                }
                            }
                        }
                    }

                    Component {
                        id: snowyAnim
                        Item {
                            Repeater {
                                model: 60
                                Text {
                                    required property int index
                                    readonly property real startX: Math.random() * parent.width
                                    readonly property real swayAmp: 12 + Math.random() * 12
                                    text: "❄"
                                    color: Colors.overBackground
                                    opacity: 0.6 + Math.random() * 0.4
                                    font.pixelSize: 8 + Math.random() * 10
                                    x: startX
                                    NumberAnimation on y { loops: Animation.Infinite; from: -10; to: parent.height + 10; duration: 5000 + Math.random() * 3000 }
                                    SequentialAnimation on x {
                                        loops: Animation.Infinite
                                        NumberAnimation { from: startX - swayAmp; to: startX + swayAmp; duration: 2500; easing.type: Easing.InOutSine }
                                        NumberAnimation { from: startX + swayAmp; to: startX - swayAmp; duration: 2500; easing.type: Easing.InOutSine }
                                    }
                                }
                            }
                        }
                    }

                    Component {
                        id: foggyAnim
                        Item {
                            Repeater {
                                model: 6
                                Rectangle {
                                    required property int index
                                    width: parent.width * 1.3
                                    height: 40 + Math.random() * 30
                                    radius: 20
                                    color: Qt.rgba(Colors.overBackground.r, Colors.overBackground.g, Colors.overBackground.b, 0.08)
                                    y: index * (parent.height / 6) + Math.random() * 30
                                    NumberAnimation on x { loops: Animation.Infinite; from: -parent.width * 0.3; to: parent.width * 0.1; duration: 18000 + Math.random() * 10000 }
                                }
                            }
                        }
                    }

                    Component {
                        id: cloudyAnim
                        Item {
                            Repeater {
                                model: 5
                                Item {
                                    required property int index
                                    readonly property real cw: 80 + Math.random() * 60
                                    readonly property real ch: 30 + Math.random() * 20
                                    width: cw; height: ch
                                    y: index * (parent.height / 6) + 10 + Math.random() * 20
                                    NumberAnimation on x { loops: Animation.Infinite; from: -150; to: parent.width + 150; duration: 22000 + Math.random() * 18000 }
                                    Rectangle { anchors.fill: parent; radius: parent.height / 2; color: Qt.rgba(Colors.overBackground.r, Colors.overBackground.g, Colors.overBackground.b, 0.14) }
                                    Rectangle { width: parent.width * 0.5; height: parent.height * 0.9; radius: height / 2; x: parent.width * 0.15; y: -parent.height * 0.35; color: Qt.rgba(Colors.overBackground.r, Colors.overBackground.g, Colors.overBackground.b, 0.12) }
                                }
                            }
                        }
                    }

                } // Item weatherTab (TAB 1)

                // ═══════ TAB 2: POMODORO (creative) ═════════════
                ColumnLayout {
                    spacing: dock.sectionSpacing

                    // Estado del día (in-memory)
                    property int sessionsToday: 0
                    property int minutesToday: 0
                    property int streakDays: 0  // requiere persistencia para ser real

                    Connections {
                        target: pomo
                        function onIsWorkSessionChanged() {
                            if (!pomo.isWorkSession && pomo.alarmActive) {
                                pomoTabRoot.sessionsToday++;
                                pomoTabRoot.minutesToday += Math.round(pomo.totalTime / 60);
                            }
                        }
                    }

                    Item { id: pomoTabRoot }  // placeholder para los Connections

                    // ──── HERO PANE: gradient bg + partículas + tomate + ring
                    Item {
                        id: heroPane
                        Layout.fillWidth: true
                        Layout.preferredHeight: 340

                        // Gradient dinámico: tonos cálidos en work, fríos en break
                        Rectangle {
                            anchors.fill: parent
                            radius: Styling.radius(6)
                            clip: true

                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop {
                                    position: 0.0
                                    color: pomo.isWorkSession
                                        ? Qt.darker(Colors.primary, 1.4)
                                        : Qt.lighter(Colors.secondary, 1.1)
                                    Behavior on color { ColorAnimation { duration: 1200 } }
                                }
                                GradientStop {
                                    position: 1.0
                                    color: pomo.isWorkSession
                                        ? Qt.darker(Colors.background, 1.2)
                                        : Qt.darker(Colors.tertiary, 1.3)
                                    Behavior on color { ColorAnimation { duration: 1200 } }
                                }
                            }

                            // Partículas flotantes — gotas de lluvia simuladas
                            Item {
                                anchors.fill: parent
                                clip: true

                                Repeater {
                                    model: 32

                                    Rectangle {
                                        required property int index
                                        readonly property real fallDuration: 2200 + Math.random() * 1800
                                        readonly property real startX: Math.random() * heroPane.width
                                        x: startX
                                        width: 1
                                        height: 8 + Math.random() * 6
                                        radius: 0.5
                                        color: Qt.rgba(1, 1, 1, 0.25 + Math.random() * 0.2)
                                        opacity: pomo.isRunning ? 1 : 0.4
                                        Behavior on opacity { NumberAnimation { duration: 600 } }

                                        SequentialAnimation on y {
                                            loops: Animation.Infinite
                                            running: heroPane.visible
                                            NumberAnimation {
                                                from: -20
                                                to: heroPane.height + 20
                                                duration: fallDuration
                                                easing.type: Easing.InQuad
                                            }
                                        }
                                    }
                                }
                            }

                            // Anillo de progreso + tomate centrado
                            Item {
                                id: tomatoStage
                                anchors.centerIn: parent
                                width: 220
                                height: 220

                                // Ring de progreso (Canvas)
                                Canvas {
                                    id: progressRing
                                    anchors.fill: parent
                                    antialiasing: true

                                    property real progress: pomo.visualProgress
                                    onProgressChanged: requestPaint()
                                    Connections {
                                        target: Colors
                                        function onPrimaryChanged() { progressRing.requestPaint(); }
                                    }

                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.clearRect(0, 0, width, height);
                                        var cx = width / 2, cy = height / 2;
                                        var r = Math.min(cx, cy) - 8;

                                        // Track de fondo
                                        ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.15);
                                        ctx.lineWidth = 6;
                                        ctx.beginPath();
                                        ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                                        ctx.stroke();

                                        // Progress arc
                                        ctx.strokeStyle = pomo.isWorkSession ? Colors.primary : Colors.tertiary;
                                        ctx.lineWidth = 6;
                                        ctx.lineCap = "round";
                                        ctx.beginPath();
                                        ctx.arc(cx, cy, r, -Math.PI / 2,
                                                -Math.PI / 2 + (progress * 2 * Math.PI));
                                        ctx.stroke();
                                    }
                                }

                                // Tomate emoji con pulse + wobble al click
                                Text {
                                    id: tomato
                                    anchors.centerIn: parent
                                    text: pomo.isWorkSession ? "🍅" : "☕"
                                    font.pixelSize: 90

                                    // Pulse continuo cuando isRunning
                                    SequentialAnimation on scale {
                                        running: pomo.isRunning && dock.currentTab === 2
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 1.0; to: 1.06; duration: 1500; easing.type: Easing.InOutSine }
                                        NumberAnimation { from: 1.06; to: 1.0; duration: 1500; easing.type: Easing.InOutSine }
                                    }

                                    // Wobble al hover/click
                                    transform: Rotation {
                                        id: wobble
                                        origin.x: tomato.width / 2
                                        origin.y: tomato.height / 2
                                        angle: 0
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: wobbleAnim.restart()
                                    }
                                    SequentialAnimation {
                                        id: wobbleAnim
                                        NumberAnimation { target: wobble; property: "angle"; to: -8; duration: 80 }
                                        NumberAnimation { target: wobble; property: "angle"; to: 8;  duration: 120 }
                                        NumberAnimation { target: wobble; property: "angle"; to: -4; duration: 100 }
                                        NumberAnimation { target: wobble; property: "angle"; to: 0;  duration: 100 }
                                    }
                                }

                                // Timer text encima del tomate (top center)
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.top
                                    anchors.topMargin: 20
                                    text: {
                                        var s = Math.max(0, pomo.timeLeft);
                                        var m = Math.floor(s / 60);
                                        var ss = s % 60;
                                        return (m < 10 ? "0" : "") + m + ":" + (ss < 10 ? "0" : "") + ss;
                                    }
                                    color: "white"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(3)
                                    font.weight: Font.Bold
                                }

                                // Label work/break debajo del tomate
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 18
                                    text: pomo.isWorkSession ? "FOCUS" : "BREAK"
                                    color: "white"
                                    opacity: 0.7
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-1)
                                    font.weight: Font.Bold
                                    font.letterSpacing: 3
                                }
                            }

                            // Pomodoro widget existente (controles play/pause/skip) en bottom
                            Item {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 8
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width - 20
                                height: pomo.implicitHeight

                                Pomodoro {
                                    id: pomo
                                    anchors.centerIn: parent
                                    width: parent.width
                                }
                            }
                        }
                    }

                    // ──── STATS ANIMADOS ───────────────────────────
                    StyledRect {
                        Layout.fillWidth: true
                        variant: "pane"
                        radius: Styling.radius(6)
                        enableShadow: false
                        Layout.preferredHeight: 86

                        Row {
                            anchors.centerIn: parent
                            spacing: 32

                            // Sessions
                            Column {
                                spacing: 2
                                Row {
                                    spacing: 6
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    Text {
                                        text: "🍅"; font.pixelSize: 18
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: pomoTabRoot.parent.sessionsToday
                                        color: Colors.overBackground
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(4)
                                        font.weight: Font.Bold
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "sessions today"
                                    color: Colors.outline
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-1)
                                }
                            }

                            // Minutes
                            Column {
                                spacing: 2
                                Row {
                                    spacing: 6
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    Text {
                                        text: "⏱"; font.pixelSize: 18
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: pomoTabRoot.parent.minutesToday
                                        color: Colors.overBackground
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(4)
                                        font.weight: Font.Bold
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "minutes"
                                    color: Colors.outline
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-1)
                                }
                            }

                            // Streak (con flame animada)
                            Column {
                                spacing: 2
                                Row {
                                    spacing: 6
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    Text {
                                        text: "🔥"; font.pixelSize: 18
                                        anchors.verticalCenter: parent.verticalCenter
                                        SequentialAnimation on scale {
                                            loops: Animation.Infinite
                                            running: dock.isOpen && dock.currentTab === 2
                                            NumberAnimation { from: 1.0; to: 1.15; duration: 800; easing.type: Easing.InOutSine }
                                            NumberAnimation { from: 1.15; to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                                        }
                                    }
                                    Text {
                                        text: pomoTabRoot.parent.streakDays
                                        color: Colors.overBackground
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(4)
                                        font.weight: Font.Bold
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "day streak"
                                    color: Colors.outline
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-1)
                                }
                            }
                        }
                    }

                    // ──── QUOTE ROTATIVA ───────────────────────────
                    StyledRect {
                        id: quotePane
                        Layout.fillWidth: true
                        variant: "pane"
                        radius: Styling.radius(6)
                        enableShadow: false
                        Layout.preferredHeight: 64

                        readonly property var quotes: [
                            "Focus is the new IQ.",
                            "Small steps every day.",
                            "Done is better than perfect.",
                            "Progress, not perfection.",
                            "Slow is smooth, smooth is fast.",
                            "Quality is the result of attention.",
                            "Start where you are. Use what you have.",
                            "Discipline is freedom.",
                            "The work is the reward.",
                            "Deep work beats shallow hustle."
                        ]
                        property int quoteIdx: 0

                        Timer {
                            interval: 25000
                            running: dock.isOpen && dock.currentTab === 2
                            repeat: true
                            onTriggered: quoteRotateAnim.start()
                        }

                        SequentialAnimation {
                            id: quoteRotateAnim
                            NumberAnimation { target: quoteText; property: "opacity"; to: 0; duration: 280 }
                            ScriptAction { script: quotePane.quoteIdx = (quotePane.quoteIdx + 1) % quotePane.quotes.length }
                            NumberAnimation { target: quoteText; property: "opacity"; to: 1; duration: 280 }
                        }

                        Text {
                            id: quoteText
                            anchors.centerIn: parent
                            width: parent.width - 32
                            text: '"' + quotePane.quotes[quotePane.quoteIdx] + '"'
                            color: Colors.outline
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(0)
                            font.italic: true
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }
                    }

                    Item { Layout.fillHeight: true } // spacer fin de tab Pomodoro
                } // ColumnLayout TAB 2 Pomodoro

                // ═══════ TAB 3: COLOR PICKER (immersive) ════════
                Item {
                    id: colorTab
                    Layout.fillWidth: true
                    implicitHeight: colorContent.implicitHeight + 24
                    Layout.preferredHeight: implicitHeight

                    readonly property color currentColor: hsvPicker.resultColor

                    // BACKGROUND: oscurecido del color elegido + glow blob central
                    Rectangle {
                        anchors.fill: parent
                        radius: Styling.radius(8)
                        clip: true
                        color: Qt.darker(colorTab.currentColor, 2.6)
                        Behavior on color { ColorAnimation { duration: 250 } }

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width
                            height: parent.width * 0.7
                            radius: width / 2
                            color: colorTab.currentColor
                            opacity: 0.18
                            Behavior on color { ColorAnimation { duration: 250 } }
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * 0.65
                            height: parent.width * 0.45
                            radius: width / 2
                            color: colorTab.currentColor
                            opacity: 0.30
                            Behavior on color { ColorAnimation { duration: 250 } }
                        }

                        Repeater {
                            model: 18
                            Rectangle {
                                required property int index
                                readonly property real startX: Math.random() * parent.width
                                width: 2 + Math.random() * 2
                                height: width
                                radius: width / 2
                                color: Qt.rgba(1, 1, 1, 0.5)
                                opacity: 0.6
                                x: startX
                                SequentialAnimation on y {
                                    loops: Animation.Infinite
                                    NumberAnimation {
                                        from: parent.height + 10; to: -10
                                        duration: 6000 + Math.random() * 4000
                                        easing.type: Easing.Linear
                                    }
                                }
                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 0; to: 0.6; duration: 1500 }
                                    PauseAnimation { duration: 3000 }
                                    NumberAnimation { from: 0.6; to: 0; duration: 1500 }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        id: colorContent
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        // HERO: swatch + hex grande + rgb (click copia)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 110
                            color: Qt.rgba(0, 0, 0, 0.35)
                            radius: 14
                            border.color: Qt.rgba(1, 1, 1, 0.12); border.width: 1
                            Row {
                                anchors.centerIn: parent
                                spacing: 18
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 64; height: 64; radius: 12
                                    color: colorTab.currentColor
                                    border.color: Qt.rgba(1, 1, 1, 0.3); border.width: 1
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text {
                                        text: hsvPicker.hexValue.toUpperCase()
                                        color: "white"
                                        font.family: Config.theme.monoFont
                                        font.pixelSize: 32; font.weight: Font.Light
                                    }
                                    Text {
                                        text: {
                                            var c = colorTab.currentColor;
                                            return "rgb(" + Math.round(c.r * 255) + ", " +
                                                   Math.round(c.g * 255) + ", " +
                                                   Math.round(c.b * 255) + ")";
                                        }
                                        color: Qt.rgba(1, 1, 1, 0.6)
                                        font.family: Config.theme.monoFont
                                        font.pixelSize: Styling.fontSize(-1)
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Quickshell.execDetached(["wl-copy", hsvPicker.hexValue]);
                                    Quickshell.execDetached(["notify-send", "-t", "1500", "Color copied", hsvPicker.hexValue]);
                                }
                            }
                        }

                        // PICKER existente como child
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: pickerHolder.implicitHeight + 20
                            color: Qt.rgba(0, 0, 0, 0.32)
                            radius: 12
                            border.color: Qt.rgba(1, 1, 1, 0.10); border.width: 1
                            Item {
                                id: pickerHolder
                                anchors.left: parent.left; anchors.right: parent.right
                                anchors.top: parent.top; anchors.margins: 10
                                implicitHeight: hsvPicker.implicitHeight
                                ColorPicker {
                                    id: hsvPicker
                                    anchors.left: parent.left; anchors.right: parent.right
                                }
                            }
                        }

                        // FORMATS: HEX / RGB / HSL bidireccionales
                        Rectangle {
                            id: formatsCard
                            Layout.fillWidth: true
                            Layout.preferredHeight: formatsCol.implicitHeight + 20
                            color: Qt.rgba(0, 0, 0, 0.32)
                            radius: 12
                            border.color: Qt.rgba(1, 1, 1, 0.10); border.width: 1

                            function rgbToHex(r, g, b) {
                                var pad = function (n) { var s = Math.round(n).toString(16); return s.length < 2 ? "0" + s : s; };
                                return "#" + pad(r) + pad(g) + pad(b);
                            }
                            function parseRgb(s) {
                                var m = s.match(/(\d+)[,\s]+(\d+)[,\s]+(\d+)/);
                                if (!m) return null;
                                return [parseInt(m[1]), parseInt(m[2]), parseInt(m[3])];
                            }
                            function parseHsl(s) {
                                var m = s.match(/(\d+(?:\.\d+)?)[,\s]+(\d+(?:\.\d+)?)%?[,\s]+(\d+(?:\.\d+)?)%?/);
                                if (!m) return null;
                                return [parseFloat(m[1]), parseFloat(m[2]) / 100, parseFloat(m[3]) / 100];
                            }
                            function hslToRgb(h, s, l) {
                                h = h / 360;
                                var r, g, b;
                                if (s === 0) { r = g = b = l; }
                                else {
                                    var hue2rgb = function (p, q, t) {
                                        if (t < 0) t += 1; if (t > 1) t -= 1;
                                        if (t < 1/6) return p + (q - p) * 6 * t;
                                        if (t < 1/2) return q;
                                        if (t < 2/3) return p + (q - p) * (2/3 - t) * 6;
                                        return p;
                                    };
                                    var q = l < 0.5 ? l * (1 + s) : l + s - l * s;
                                    var p = 2 * l - q;
                                    r = hue2rgb(p, q, h + 1/3);
                                    g = hue2rgb(p, q, h);
                                    b = hue2rgb(p, q, h - 1/3);
                                }
                                return [Math.round(r * 255), Math.round(g * 255), Math.round(b * 255)];
                            }
                            function rgbToHsl(r, g, b) {
                                r /= 255; g /= 255; b /= 255;
                                var max = Math.max(r, g, b), min = Math.min(r, g, b);
                                var h = 0, s = 0, l = (max + min) / 2;
                                if (max !== min) {
                                    var d = max - min;
                                    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
                                    if (max === r) h = ((g - b) / d + (g < b ? 6 : 0));
                                    else if (max === g) h = (b - r) / d + 2;
                                    else h = (r - g) / d + 4;
                                    h *= 60;
                                }
                                return [Math.round(h), Math.round(s * 100), Math.round(l * 100)];
                            }

                            ColumnLayout {
                                id: formatsCol
                                anchors.left: parent.left; anchors.right: parent.right
                                anchors.top: parent.top; anchors.margins: 10
                                spacing: 6
                                Text {
                                    text: "Formats"
                                    color: Qt.rgba(1, 1, 1, 0.6)
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-1); font.weight: Font.Medium
                                }
                                Repeater {
                                    model: ["HEX", "RGB", "HSL"]
                                    Row {
                                        Layout.fillWidth: true
                                        required property string modelData
                                        required property int index
                                        spacing: 8
                                        Text {
                                            text: modelData; color: Qt.rgba(1,1,1,0.55)
                                            font.family: Config.theme.monoFont
                                            font.pixelSize: Styling.fontSize(-1)
                                            anchors.verticalCenter: parent.verticalCenter; width: 38
                                        }
                                        Rectangle {
                                            width: formatsCard.width - 20 - 38 - 8
                                            height: 32; radius: 6
                                            color: Qt.rgba(1, 1, 1, 0.08)
                                            border.color: Qt.rgba(1, 1, 1, 0.15); border.width: 1
                                            TextInput {
                                                anchors.fill: parent; anchors.leftMargin: 10
                                                verticalAlignment: TextInput.AlignVCenter
                                                color: "white"
                                                font.family: Config.theme.monoFont
                                                font.pixelSize: Styling.fontSize(0)
                                                selectByMouse: true
                                                text: {
                                                    var c = colorTab.currentColor;
                                                    if (modelData === "HEX") return hsvPicker.hexValue.toUpperCase();
                                                    if (modelData === "RGB")
                                                        return Math.round(c.r * 255) + ", " + Math.round(c.g * 255) + ", " + Math.round(c.b * 255);
                                                    var hsl = formatsCard.rgbToHsl(c.r * 255, c.g * 255, c.b * 255);
                                                    return hsl[0] + ", " + hsl[1] + "%, " + hsl[2] + "%";
                                                }
                                                onEditingFinished: {
                                                    if (modelData === "HEX") {
                                                        hsvPicker.setFromHex(text);
                                                    } else if (modelData === "RGB") {
                                                        var rgb = formatsCard.parseRgb(text);
                                                        if (rgb) hsvPicker.setFromHex(formatsCard.rgbToHex(rgb[0], rgb[1], rgb[2]));
                                                    } else {
                                                        var hsl = formatsCard.parseHsl(text);
                                                        if (hsl) {
                                                            var rgb2 = formatsCard.hslToRgb(hsl[0], hsl[1], hsl[2]);
                                                            hsvPicker.setFromHex(formatsCard.rgbToHex(rgb2[0], rgb2[1], rgb2[2]));
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // HARMONIES: 5 swatches derivados
                        Rectangle {
                            id: harmoniesCard
                            Layout.fillWidth: true
                            Layout.preferredHeight: 96
                            color: Qt.rgba(0, 0, 0, 0.32)
                            radius: 12
                            border.color: Qt.rgba(1, 1, 1, 0.10); border.width: 1
                            Column {
                                anchors.fill: parent; anchors.margins: 10; spacing: 8
                                Text {
                                    text: "Harmonies"
                                    color: Qt.rgba(1, 1, 1, 0.6)
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-1); font.weight: Font.Medium
                                }
                                Row {
                                    width: parent.width; spacing: 8
                                    Repeater {
                                        model: [
                                            { name: "comp",     hueOffset: 0.5 },
                                            { name: "analog 1", hueOffset: 0.0833 },
                                            { name: "analog 2", hueOffset: -0.0833 },
                                            { name: "triad 1",  hueOffset: 0.333 },
                                            { name: "triad 2",  hueOffset: 0.667 }
                                        ]
                                        Column {
                                            required property var modelData
                                            spacing: 3
                                            width: (harmoniesCard.width - 20 - 4 * 8) / 5
                                            Rectangle {
                                                width: parent.width; height: 38; radius: 8
                                                color: Qt.hsva((hsvPicker.hue + modelData.hueOffset + 1) % 1,
                                                               hsvPicker.sat, hsvPicker.val, 1)
                                                border.color: Qt.rgba(1, 1, 1, 0.18); border.width: 1
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: hsvPicker.setFromColor(parent.color)
                                                }
                                            }
                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: modelData.name
                                                color: Qt.rgba(1, 1, 1, 0.5)
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-2)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ACTIONS: eyedropper + apply
                        Row {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            spacing: 8

                            Rectangle {
                                width: 50; height: 50; radius: 12
                                color: eyedropMouse.containsMouse ? Qt.rgba(1,1,1,0.18) : Qt.rgba(0,0,0,0.32)
                                border.color: Qt.rgba(1, 1, 1, 0.12); border.width: 1
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Text { anchors.centerIn: parent; text: "💧"; font.pixelSize: 22 }
                                MouseArea {
                                    id: eyedropMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: eyedropProc.running = true
                                }
                                StyledToolTip {
                                    show: eyedropMouse.containsMouse
                                    tooltipText: "Pick color from screen (hyprpicker)"
                                }
                            }

                            Rectangle {
                                width: parent.width - 50 - 8; height: 50; radius: 12
                                color: applyMouse.containsMouse ? colorTab.currentColor : Qt.darker(colorTab.currentColor, 1.3)
                                border.color: Qt.rgba(1, 1, 1, 0.2); border.width: 1
                                Behavior on color { ColorAnimation { duration: 160 } }
                                Row {
                                    anchors.centerIn: parent; spacing: 10
                                    Text { text: "🎨"; font.pixelSize: 20; anchors.verticalCenter: parent.verticalCenter }
                                    Text {
                                        text: "Use as wallpaper accent"
                                        color: "white"
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(0); font.weight: Font.Bold
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                MouseArea {
                                    id: applyMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Quickshell.execDetached(["matugen", "color", "hex", hsvPicker.hexValue]);
                                        Quickshell.execDetached(["notify-send", "-t", "2000", "Accent applied", hsvPicker.hexValue]);
                                    }
                                }
                            }
                        }

                        // MATUGEN PALETTE
                        Rectangle {
                            id: paletteCard
                            Layout.fillWidth: true
                            Layout.preferredHeight: 84
                            color: Qt.rgba(0, 0, 0, 0.32)
                            radius: 12
                            border.color: Qt.rgba(1, 1, 1, 0.10); border.width: 1
                            Column {
                                anchors.fill: parent; anchors.margins: 10; spacing: 6
                                Text {
                                    text: "Matugen palette"
                                    color: Qt.rgba(1, 1, 1, 0.6)
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-1); font.weight: Font.Medium
                                }
                                Row {
                                    spacing: 6
                                    Repeater {
                                        model: [
                                            { name: "primary",   c: Colors.primary },
                                            { name: "secondary", c: Colors.secondary },
                                            { name: "tertiary",  c: Colors.tertiary },
                                            { name: "error",     c: Colors.error },
                                            { name: "surface",   c: Colors.background },
                                            { name: "outline",   c: Colors.outline }
                                        ]
                                        Rectangle {
                                            required property var modelData
                                            width: (paletteCard.width - 20 - 5 * 6) / 6
                                            height: 36; radius: 8
                                            color: modelData.c
                                            border.color: Qt.rgba(1, 1, 1, 0.18); border.width: 1
                                            MouseArea {
                                                id: pmouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: hsvPicker.setFromColor(modelData.c)
                                            }
                                            StyledToolTip {
                                                show: pmouse.containsMouse
                                                tooltipText: modelData.name + ": " + modelData.c
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // RECENT
                        Rectangle {
                            id: recentCard
                            Layout.fillWidth: true
                            Layout.preferredHeight: visible ? (recentCol.implicitHeight + 20) : 0
                            color: Qt.rgba(0, 0, 0, 0.32)
                            radius: 12
                            border.color: Qt.rgba(1, 1, 1, 0.10); border.width: 1
                            visible: colorHistory.colors.length > 0
                            QtObject {
                                id: colorHistory
                                property var colors: []
                                function add(hex) {
                                    if (!hex || hex === "") return;
                                    var filtered = colors.filter(function (c) { return c !== hex; });
                                    filtered.unshift(hex);
                                    if (filtered.length > 12) filtered = filtered.slice(0, 12);
                                    colors = filtered;
                                }
                            }
                            Timer {
                                id: histDebounce
                                interval: 1000; repeat: false
                                onTriggered: colorHistory.add(hsvPicker.hexValue)
                            }
                            Connections {
                                target: hsvPicker
                                function onHexValueChanged() { histDebounce.restart(); }
                            }
                            Column {
                                id: recentCol
                                anchors.left: parent.left; anchors.right: parent.right
                                anchors.top: parent.top; anchors.margins: 10
                                spacing: 6
                                Text {
                                    text: "Recent"
                                    color: Qt.rgba(1, 1, 1, 0.6)
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-1); font.weight: Font.Medium
                                }
                                Flow {
                                    width: parent.width; spacing: 6
                                    Repeater {
                                        model: colorHistory.colors
                                        Rectangle {
                                            required property string modelData
                                            width: 30; height: 30; radius: 7
                                            color: modelData
                                            border.color: Qt.rgba(1, 1, 1, 0.2); border.width: 1
                                            MouseArea {
                                                id: rmouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: hsvPicker.setFromHex(parent.modelData)
                                            }
                                            StyledToolTip {
                                                show: rmouse.containsMouse
                                                tooltipText: parent.modelData
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Eyedropper: hyprpicker (preciso, magnifica el pixel). Fallback a
                    // grim+slurp si hyprpicker no está instalado.
                    Process {
                        id: eyedropProc
                        command: ["sh", "-c",
                            "if command -v hyprpicker >/dev/null 2>&1; then hyprpicker -f hex; else grim -g \"$(slurp -p)\" -t ppm - | tail -c 3 | hexdump -e '\"#%02X%02X%02X\"'; fi"]
                        stdout: StdioCollector {
                            onStreamFinished: {
                                var hex = this.text.trim();
                                if (hex.length > 0 && hex.charAt(0) !== "#")
                                    hex = "#" + hex;
                                if (hex.match(/^#[0-9A-F]{6}$/i)) {
                                    hsvPicker.setFromHex(hex);
                                }
                            }
                        }
                    }
                } // Item colorTab (TAB 3)
                } // StackLayout contentStack

                Item {
                    Layout.preferredHeight: 12
                    Layout.fillWidth: true
                }
            }
        }
    }

    Connections {
        target: GlobalStates
        function onRightDockOpenChanged() {
            if (GlobalStates.rightDockOpen && !WeatherService.dataAvailable) {
                WeatherService.updateWeather();
            }
        }
    }

    // Refetch weather al cambiar a la tab Weather si faltan los campos
    // nuevos (humidity/uv/wind direction/hourly) — la API expandida fue
    // agregada después, así que el cache previo no los tiene.
    onCurrentTabChanged: {
        if (currentTab === 1 && WeatherService.dataAvailable) {
            // Si humidity es 0 Y uvIndex es 0 Y hourly vacío, asumimos cache viejo
            if (WeatherService.humidity === 0 && WeatherService.uvIndex === 0 &&
                WeatherService.hourly.length === 0) {
                WeatherService.updateWeather();
            }
        }
    }
}
