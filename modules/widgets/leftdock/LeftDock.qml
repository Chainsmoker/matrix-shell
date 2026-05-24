pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.modules.globals
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.corners
import qs.config

PanelWindow {
    id: dock

    anchors {
        top: true
        bottom: true
        left: true
    }

    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "ambxst:leftdock"
    exclusionMode: ExclusionMode.Ignore

    readonly property bool isOpen: GlobalStates.newsPanelOpen
    // Ocultar PanelWindow cuando cerrado para no bloquear clicks del sistema.
    visible: isOpen || dockContainer.opacity > 0.001

    readonly property int dockWidth: 420
    readonly property int hPadding: 16
    readonly property int sectionSpacing: 12
    readonly property int headerHeight: 110
    readonly property int shoulderSize: 18

    // Tab activa: 0=Tech News, 1=CVEs
    property int currentTab: 0

    // Accent dinámico por tab — define el color del border + active pill
    readonly property color tabAccent: {
        switch (currentTab) {
            case 0: return Colors.primary;        // tech news: matugen primary
            case 1: return "#E07556";             // CVEs: Alert orange/tomato
        }
        return Colors.primary;
    }

    readonly property bool barAtTop: {
        const pos = Config.bar?.position ?? "top";
        return pos === "top";
    }

    readonly property int barReserved: {
        const enabled = (Config.bar && Config.bar.pinnedOnStartup !== undefined ? Config.bar.pinnedOnStartup : true);
        if (!enabled) return 0;
        const base = (Config.showBackground !== false) ? 44 : 40;
        return Config.bar?.position === "top" ? base : 0;
    }

    implicitWidth: dockWidth + 32

    // Patrón ChatPanel: cerrado → emptyMask (no intercepta), abierto → fullMask.
    mask: Region { item: dock.visible ? fullMask : emptyMask }
    Item {
        id: fullMask
        x: 0
        y: dock.barReserved
        width: dock.dockWidth
        height: dock.height - dock.barReserved
    }
    Item { id: emptyMask; width: 0; height: 0 }

    readonly property int dockContainerWidth: dock.dockWidth

    // Mock Data para Noticias Tech con imágenes y fallbacks
    readonly property var techNews: [
        {
            title: "Gemini 2.0 Ultra de Google revoluciona la codificación de agentes autónomos",
            source: "Hacker News · Hace 2h",
            tag: "AI",
            tagColor: "#5dadeb",
            image: "https://images.unsplash.com/photo-1677442136019-21780efad99a?w=150&auto=format&fit=crop&q=60",
            excerpt: "La nueva arquitectura de agentes autónomos logra resolver tareas complejas de desarrollo de software con razonamiento secuencial de nivel experto."
        },
        {
            title: "Kernel Linux 6.15 introduce optimizaciones de scheduler para CPUs AMD Zen 5",
            source: "Phoronix · Hace 4h",
            tag: "Kernel",
            tagColor: "#E07556",
            image: "https://images.unsplash.com/photo-1544383835-bda2bc66a55d?w=150&auto=format&fit=crop&q=60",
            excerpt: "Las mejoras reducen la latencia de hilos y aumentan el rendimiento de compilación hasta en un 12% en procesadores de última generación."
        },
        {
            title: "Hyprland lanza v0.48 con soporte experimental de sincronización por hardware",
            source: "GitHub Changelog · Hace 1d",
            tag: "Wayland",
            tagColor: "#9fd0ec",
            image: "", // Activará el diseño de fallback abstracto
            excerpt: "La nueva entrega reduce significativamente el consumo de GPU al sincronizar directamente los búferes de renderizado de la pantalla."
        },
        {
            title: "Rust consolida su adopción en componentes de seguridad crítica del sistema operativo",
            source: "Tech Crunch · Hace 1d",
            tag: "Security",
            tagColor: "#7a4a8a",
            image: "https://images.unsplash.com/photo-1607799279861-4dd421887fb3?w=150&auto=format&fit=crop&q=60",
            excerpt: "Varias distros principales de Linux anuncian planes para migrar submódulos críticos a librerías escritas nativamente en Rust."
        }
    ]

    // Mock Data para CVEs
    readonly property var cveFeed: [
        {
            cve: "CVE-2026-12345",
            severity: "CRITICAL",
            score: "9.8",
            color: "#E07556",
            description: "Vulnerabilidad de ejecución remota de código (RCE) en el subsistema XFRM del kernel Linux. Permite a atacantes no autenticados saltarse las protecciones de IPsec."
        },
        {
            cve: "CVE-2026-98765",
            severity: "HIGH",
            score: "8.2",
            color: "#ff8a4a",
            description: "Desbordamiento de búfer en el daemon de OpenSSH al procesar paquetes de autenticación personalizados a través de módulos PAM específicos."
        },
        {
            cve: "CVE-2026-45678",
            severity: "MEDIUM",
            score: "6.5",
            color: "#ffe57a",
            description: "Denegación de servicio (DoS) en el compositor Hyprland. Paquetes maliciosos de IPC pueden inducir un ciclo infinito en el despachador de eventos."
        },
        {
            cve: "CVE-2026-11111",
            severity: "LOW",
            score: "3.1",
            color: "#7f8fa6",
            description: "Divulgación de información de permisos insuficientes en el socket de comunicación UNIX local de axctl. Usuarios locales pueden leer metadatos básicos."
        }
    ]

    Item {
        id: dockContainer
        width: dock.dockContainerWidth
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.topMargin: dock.barReserved
        anchors.bottom: parent.bottom
        opacity: dock.isOpen ? 1 : 0
        visible: opacity > 0.001

        transform: Translate {
            id: slideTransform
            x: dock.isOpen ? 0 : -dock.dockContainerWidth
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

        // Dock body — bg matugen sólido, sin border.
        StyledRect {
            id: dockBg
            anchors.left: parent.left
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

        // Header fijo
        Item {
            id: dockHeader
            anchors.top: dockBg.top
            anchors.left: dockBg.left
            anchors.right: dockBg.right
            height: dock.headerHeight
            clip: true
            z: 5

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: dock.hPadding
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Feed de Noticias"
                        color: Colors.overBackground
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(2)
                        font.weight: Font.Bold
                    }

                    Item { Layout.fillWidth: true }

                    // Botón cerrar (X)
                    Item {
                        width: 32
                        height: 32
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: 16
                            color: closeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: Icons.cancel
                            font.family: Icons.font
                            font.pixelSize: 16
                            color: Colors.outline
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: GlobalStates.newsPanelOpen = false
                        }
                    }
                }

                Text {
                    text: "Mantente al día con lo último en tecnología y seguridad"
                    color: Colors.outline
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    Layout.fillWidth: true
                }
            }
        }

        // Hombro cóncavo bottom-right del dock body (solo si bar está abajo).
        Item {
            id: bottomRightShoulder
            width: dock.shoulderSize
            height: dock.shoulderSize
            anchors.bottom: dockBg.bottom
            anchors.left: dockBg.right
            visible: !dock.barAtTop

            RoundCorner {
                anchors.fill: parent
                corner: RoundCorner.CornerEnum.TopLeft
                size: dock.shoulderSize
                color: dockBg.color
                Behavior on color { ColorAnimation { duration: 700 } }
            }
        }

        // Floating tab pills (debajo del header)
        Row {
            id: tabPills
            z: 100
            anchors.top: dockHeader.bottom
            anchors.horizontalCenter: dockBg.horizontalCenter
            anchors.topMargin: 4
            spacing: 12

            Repeater {
                model: [
                    { ico: Icons.globe, name: "Tech News" },
                    { ico: Icons.shield, name: "Últimos CVEs" }
                ]

                Rectangle {
                    id: pill
                    required property var modelData
                    required property int index
                    readonly property bool isActive: dock.currentTab === index

                    width: 170
                    height: 40
                    radius: 12
                    color: isActive
                        ? dock.tabAccent
                        : (pillMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0, 0, 0, 0.42))
                    border.color: isActive ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.15)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 220 } }
                    Behavior on border.color { ColorAnimation { duration: 220 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: pill.modelData.ico
                            font.family: Icons.font
                            font.pixelSize: 16
                            color: "white"
                        }

                        Text {
                            text: pill.modelData.name
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(0)
                            font.weight: Font.Medium
                            color: "white"
                        }
                    }

                    MouseArea {
                        id: pillMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dock.currentTab = pill.index
                    }
                }
            }
        }

        ScrollView {
            id: scroller
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: tabPills.bottom
            anchors.topMargin: 16
            anchors.bottom: parent.bottom
            width: dock.dockWidth
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: scroller.width - 24
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: dock.sectionSpacing

                StackLayout {
                    id: contentStack
                    Layout.fillWidth: true
                    currentIndex: dock.currentTab

                    // TAB 0: Noticias Tech (con Layout asimétrico e imágenes)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Repeater {
                            model: dock.techNews

                            delegate: StyledRect {
                                id: cardRect
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: contentRow.implicitHeight + 24
                                variant: "internalbg"
                                radius: 14
                                enableShadow: false

                                RowLayout {
                                    id: contentRow
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 12

                                    // Lado Izquierdo: Textos
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        RowLayout {
                                            Layout.fillWidth: true

                                            Rectangle {
                                                width: tagText.implicitWidth + 12
                                                height: 22
                                                radius: 6
                                                color: cardRect.modelData.tagColor

                                                Text {
                                                    id: tagText
                                                    anchors.centerIn: parent
                                                    text: cardRect.modelData.tag
                                                    color: "white"
                                                    font.family: Config.theme.font
                                                    font.pixelSize: Styling.fontSize(-2)
                                                    font.weight: Font.Bold
                                                }
                                            }

                                            Item { Layout.fillWidth: true }

                                            Text {
                                                text: cardRect.modelData.source
                                                color: Colors.outline
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-2)
                                            }
                                        }

                                        Text {
                                            text: cardRect.modelData.title
                                            color: Colors.overBackground
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(0)
                                            font.weight: Font.Bold
                                            Layout.fillWidth: true
                                            wrapMode: Text.WordWrap
                                        }

                                        Text {
                                            text: cardRect.modelData.excerpt
                                            color: Colors.outline
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-1)
                                            Layout.fillWidth: true
                                            wrapMode: Text.WordWrap
                                            opacity: 0.85
                                        }
                                    }

                                    // Lado Derecho: Thumbnail / Fallback
                                    Item {
                                        id: imageContainer
                                        Layout.preferredWidth: 80
                                        Layout.preferredHeight: 80
                                        Layout.alignment: Qt.AlignTop

                                        // Fallback degradado abstracto
                                        Rectangle {
                                            id: fallbackBg
                                            anchors.fill: parent
                                            radius: 10
                                            visible: !thumbImage.visible
                                            gradient: Gradient {
                                                GradientStop { position: 0.0; color: cardRect.modelData.tagColor }
                                                GradientStop { position: 1.0; color: Qt.darker(cardRect.modelData.tagColor, 1.6) }
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: cardRect.modelData.tag.charAt(0)
                                                color: "white"
                                                font.family: Config.theme.font
                                                font.pixelSize: 32
                                                font.weight: Font.Bold
                                            }
                                        }

                                        // Imagen real
                                        Image {
                                            id: thumbImage
                                            anchors.fill: parent
                                            source: cardRect.modelData.image || ""
                                            visible: cardRect.modelData.image !== "" && status === Image.Ready
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            cache: true

                                            layer.enabled: true
                                            layer.effect: MultiEffect {
                                                maskEnabled: true
                                                maskSource: maskShape
                                            }
                                        }

                                        // Máscara redondeada para la imagen
                                        Item {
                                            id: maskShape
                                            anchors.fill: parent
                                            visible: false
                                            Rectangle {
                                                anchors.fill: parent
                                                radius: 10
                                                color: "black"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // TAB 1: CVE Feed
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Repeater {
                            model: dock.cveFeed

                            delegate: StyledRect {
                                id: cveCard
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: cveRow.implicitHeight + 24
                                variant: "internalbg"
                                radius: 14
                                enableShadow: false

                                RowLayout {
                                    id: cveRow
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 12

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        RowLayout {
                                            Layout.fillWidth: true

                                            Text {
                                                text: cveCard.modelData.cve
                                                color: Colors.overBackground
                                                font.family: Config.theme.monoFont
                                                font.pixelSize: Styling.fontSize(0)
                                                font.weight: Font.Bold
                                            }

                                            Item { Layout.fillWidth: true }

                                            // Badge de severidad
                                            Rectangle {
                                                width: sevText.implicitWidth + 12
                                                height: 20
                                                radius: 6
                                                color: cveCard.modelData.color

                                                Text {
                                                    id: sevText
                                                    anchors.centerIn: parent
                                                    text: cveCard.modelData.severity + " (" + cveCard.modelData.score + ")"
                                                    color: "white"
                                                    font.family: Config.theme.font
                                                    font.pixelSize: Styling.fontSize(-2)
                                                    font.weight: Font.Bold
                                                }
                                            }
                                        }

                                        Text {
                                            text: cveCard.modelData.description
                                            color: Colors.outline
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-1)
                                            Layout.fillWidth: true
                                            wrapMode: Text.WordWrap
                                            opacity: 0.85
                                        }
                                    }

                                    // Lado Derecho: Icono de Escudo Simétrico
                                    Item {
                                        Layout.preferredWidth: 80
                                        Layout.preferredHeight: 80
                                        Layout.alignment: Qt.AlignTop

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 10
                                            gradient: Gradient {
                                                GradientStop { position: 0.0; color: cveCard.modelData.color }
                                                GradientStop { position: 1.0; color: Qt.darker(cveCard.modelData.color, 1.6) }
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: Icons.shield
                                                color: "white"
                                                font.family: Icons.font
                                                font.pixelSize: 32
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
