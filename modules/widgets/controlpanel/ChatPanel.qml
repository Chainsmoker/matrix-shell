pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.modules.globals
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config

PanelWindow {
    id: chatPanel

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "matrix:chatpanel"
    WlrLayershell.keyboardFocus: GlobalStates.chatPanelOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    readonly property bool isOpen: GlobalStates.chatPanelOpen
    visible: isOpen || panel.opacity > 0.001

    // Reservar dock/bar bottom
    readonly property int bottomReserved: {
        const isPinned = (Config.bar && Config.bar.pinnedOnStartup !== undefined ? Config.bar.pinnedOnStartup : true);
        const barHeight = (Config.showBackground !== false) ? 44 : 40;
        return (isPinned && Config.bar?.position === "bottom") ? barHeight : 0;
    }

    // Panel dimensions — bottom sheet floating
    readonly property int panelWidth: Math.min(720, screen.width - 80)
    readonly property int panelHeight: Math.min(680, screen.height - 120)
    readonly property int bottomGap: 20   // separación del borde inferior

    // Tabs
    property string activeTab: "chat"
    readonly property var tabs: [
        { id: "chat",    label: "Chat",     icon: Icons.robot },
        { id: "history", label: "History",  icon: Icons.note },
        { id: "models",  label: "Modelos",  icon: Icons.sparkle },
        { id: "config",  label: "Config",   icon: Icons.gear }
    ]

    mask: Region { item: chatPanel.visible ? fullMask : emptyMask }
    Item { id: fullMask; anchors.fill: parent }
    Item { id: emptyMask; width: 0; height: 0 }

    FocusGrab {
        windows: [chatPanel]
        active: chatPanel.isOpen
        onCleared: Qt.callLater(() => {
            if (chatPanel.isOpen) GlobalStates.chatPanelOpen = false;
        })
    }

    // Backdrop más oscuro para focus en el panel
    Rectangle {
        anchors.fill: parent
        color: Colors.scrim
        opacity: chatPanel.isOpen ? 0.45 : 0
        visible: opacity > 0.001

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutQuart }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: GlobalStates.chatPanelOpen = false
        }
    }

    // =================================================================
    // Panel — floating bottom sheet, centrado horizontal
    // Animación: scale desde Item.Bottom (pop up) + opacity fade
    // =================================================================
    StyledRect {
        id: panel
        variant: "bg"
        width: chatPanel.panelWidth
        height: chatPanel.panelHeight

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: chatPanel.bottomReserved + chatPanel.bottomGap

        scale: chatPanel.isOpen ? 1.0 : 0.0
        opacity: chatPanel.isOpen ? 1.0 : 0.0
        transformOrigin: Item.Bottom   // crece desde abajo (animación pop-up)

        radius: Styling.radius(24)

        layer.enabled: true
        layer.effect: Shadow {}
        clip: true

        Behavior on scale {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration * 1.3
                easing.type: chatPanel.isOpen ? Easing.OutBack : Easing.OutQuart
                easing.overshoot: chatPanel.isOpen ? 1.1 : 1.0
            }
        }
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutQuart }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ============================================================
            // HEADER — tab pills + close button
            // ============================================================
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 60

                // Grab handle visual (decorativo)
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    width: 36
                    height: 4
                    radius: 2
                    color: Colors.overSurfaceVariant
                    opacity: 0.3
                }

                // Close button (top right)
                Item {
                    width: 32
                    height: 32
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: 14
                    anchors.rightMargin: 16

                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        color: closeMouse.containsMouse
                               ? Qt.alpha(Colors.overBackground, 0.10)
                               : "transparent"
                        Behavior on color {
                            enabled: Config.animDuration > 0
                            ColorAnimation { duration: Config.animDuration / 2 }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 14
                        color: Colors.overBackground
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: GlobalStates.chatPanelOpen = false
                    }
                }
            }

            // ============================================================
            // TAB BAR — pill flotante centrada
            // ============================================================
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: tabsRow.implicitWidth + 8
                Layout.preferredHeight: 44
                Layout.bottomMargin: 12
                radius: 22
                color: Colors.surfaceContainerLow

                RowLayout {
                    id: tabsRow
                    anchors.centerIn: parent
                    spacing: 4

                    Repeater {
                        model: chatPanel.tabs
                        delegate: Item {
                            required property var modelData
                            Layout.preferredWidth: tabContent.implicitWidth + 24
                            Layout.preferredHeight: 36

                            readonly property bool isActive: chatPanel.activeTab === modelData.id

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2
                                radius: 18
                                color: parent.isActive
                                       ? Colors.primary
                                       : (tabMouse.containsMouse
                                          ? Qt.alpha(Colors.primary, 0.18)
                                          : "transparent")
                                Behavior on color {
                                    enabled: Config.animDuration > 0
                                    ColorAnimation { duration: Config.animDuration / 2 }
                                }
                            }

                            RowLayout {
                                id: tabContent
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: parent.parent.modelData.icon
                                    font.family: Icons.font
                                    font.pixelSize: 14
                                    color: parent.parent.isActive
                                           ? Styling.srItem("overprimary")
                                           : Colors.overBackground
                                }

                                Text {
                                    text: parent.parent.modelData.label
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-1)
                                    font.bold: parent.parent.isActive
                                    color: parent.parent.isActive
                                           ? Styling.srItem("overprimary")
                                           : Colors.overBackground
                                }
                            }

                            MouseArea {
                                id: tabMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: chatPanel.activeTab = parent.modelData.id
                            }
                        }
                    }
                }
            }

            // ============================================================
            // CONTENIDO DEL TAB
            // ============================================================
            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: {
                    switch (chatPanel.activeTab) {
                        case "chat":    return 0;
                        case "history": return 1;
                        case "models":  return 2;
                        case "config":  return 3;
                    }
                    return 0;
                }

                // -------- TAB CHAT --------
                Item {
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 32
                        anchors.rightMargin: 32
                        spacing: 0

                        // Welcome card grande (tipo end-4)
                        ColumnLayout {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 24
                            Layout.bottomMargin: 8
                            spacing: 16

                            // Avatar grande con halo
                            Item {
                                Layout.alignment: Qt.AlignHCenter
                                width: 96
                                height: 96

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 48
                                    color: Qt.alpha(Colors.primary, 0.15)
                                }
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 76
                                    height: 76
                                    radius: 38
                                    color: Colors.primaryContainer
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: Icons.robot
                                    font.family: Icons.font
                                    font.pixelSize: 40
                                    color: Colors.primary
                                }
                            }

                            ColumnLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 6

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: Config.brandName + " Assistant"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(3)
                                    font.bold: true
                                    color: Colors.overBackground
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Configurá tu API key para empezar"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overSurfaceVariant
                                }
                            }
                        }

                        // Chips de acciones rápidas
                        Flow {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 18
                            spacing: 8

                            Repeater {
                                model: [
                                    { icon: Icons.sparkle, text: "Saludá" },
                                    { icon: Icons.note,    text: "Resumí esto" },
                                    { icon: Icons.gear,    text: "Configurar" },
                                    { icon: Icons.user,    text: "Sobre mí" }
                                ]
                                delegate: Rectangle {
                                    required property var modelData
                                    width: chipRow.implicitWidth + 28
                                    height: 36
                                    radius: 18
                                    color: chipMouse.containsMouse
                                           ? Qt.alpha(Colors.primary, 0.20)
                                           : Colors.surfaceContainer
                                    Behavior on color {
                                        enabled: Config.animDuration > 0
                                        ColorAnimation { duration: Config.animDuration / 2 }
                                    }

                                    RowLayout {
                                        id: chipRow
                                        anchors.centerIn: parent
                                        spacing: 8

                                        Text {
                                            text: parent.parent.modelData.icon
                                            font.family: Icons.font
                                            font.pixelSize: 13
                                            color: Colors.primary
                                        }

                                        Text {
                                            text: parent.parent.modelData.text
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-1)
                                            color: Colors.overBackground
                                        }
                                    }

                                    MouseArea {
                                        id: chipMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                    }
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        // Model footer info
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.bottomMargin: 12
                            spacing: 8

                            Item { Layout.fillWidth: true }

                            Text {
                                text: Icons.sparkle
                                font.family: Icons.font
                                font.pixelSize: 11
                                color: Colors.overSurfaceVariant
                            }

                            Text {
                                text: "Claude 3.7 Sonnet · sin API key"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                color: Colors.overSurfaceVariant
                            }

                            Item { Layout.fillWidth: true }
                        }
                    }
                }

                // -------- TAB HISTORY --------
                Item {
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 32
                        spacing: 12

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "📋"
                            font.pixelSize: 40
                            opacity: 0.4
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Sin conversaciones aún"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(0)
                            color: Colors.overSurfaceVariant
                        }

                        Item { Layout.fillHeight: true }
                    }
                }

                // -------- TAB MODELS --------
                ScrollView {
                    clip: true

                    ColumnLayout {
                        width: parent.width
                        spacing: 8

                        Item { Layout.preferredHeight: 8 }

                        Repeater {
                            model: [
                                { name: "Claude 3.7 Sonnet",  provider: "Anthropic",  active: true },
                                { name: "Claude 3.5 Haiku",   provider: "Anthropic",  active: false },
                                { name: "GPT-4o",             provider: "OpenAI",     active: false },
                                { name: "Llama 3.3 70B",      provider: "Meta",       active: false },
                                { name: "Gemini 2.0 Flash",   provider: "Google",     active: false }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.leftMargin: 24
                                Layout.rightMargin: 24
                                Layout.preferredHeight: 56
                                radius: Styling.radius(14)
                                color: modelData.active
                                       ? Qt.alpha(Colors.primary, 0.15)
                                       : (modelMouse.containsMouse
                                          ? Colors.surfaceContainer
                                          : "transparent")
                                Behavior on color {
                                    enabled: Config.animDuration > 0
                                    ColorAnimation { duration: Config.animDuration / 2 }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    spacing: 12

                                    Rectangle {
                                        Layout.preferredWidth: 36
                                        Layout.preferredHeight: 36
                                        radius: 18
                                        color: parent.parent.modelData.active
                                               ? Colors.primary
                                               : Colors.surfaceContainer

                                        Text {
                                            anchors.centerIn: parent
                                            text: Icons.sparkle
                                            font.family: Icons.font
                                            font.pixelSize: 14
                                            color: parent.parent.parent.modelData.active
                                                   ? Styling.srItem("overprimary")
                                                   : Colors.overSurfaceVariant
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            text: parent.parent.parent.modelData.name
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(0)
                                            font.bold: parent.parent.parent.modelData.active
                                            color: Colors.overBackground
                                        }

                                        Text {
                                            text: parent.parent.parent.modelData.provider
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-1)
                                            color: Colors.overSurfaceVariant
                                        }
                                    }

                                    Text {
                                        visible: parent.parent.modelData.active
                                        text: "✓"
                                        font.pixelSize: 16
                                        color: Colors.primary
                                    }
                                }

                                MouseArea {
                                    id: modelMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }
                        }

                        Item { Layout.preferredHeight: 8 }
                    }
                }

                // -------- TAB CONFIG --------
                Item {
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 24
                        anchors.rightMargin: 24
                        anchors.topMargin: 16
                        spacing: 12

                        Text {
                            text: "API Keys"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(1)
                            font.bold: true
                            color: Colors.overBackground
                        }

                        Repeater {
                            model: ["Anthropic", "OpenAI", "Google", "OpenRouter"]
                            delegate: Rectangle {
                                required property string modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 56
                                radius: Styling.radius(14)
                                color: Colors.surfaceContainer

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    spacing: 10

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            text: parent.parent.modelData
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(0)
                                            font.bold: true
                                            color: Colors.overBackground
                                        }

                                        Text {
                                            text: "no configurada"
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-1)
                                            color: Colors.overSurfaceVariant
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 80
                                        Layout.preferredHeight: 32
                                        radius: 16
                                        color: Colors.primary

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Setear"
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-1)
                                            color: Styling.srItem("overprimary")
                                        }
                                    }
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }
            }

            // ============================================================
            // INPUT BAR (solo chat)
            // ============================================================
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: chatPanel.activeTab === "chat" ? 76 : 0
                visible: chatPanel.activeTab === "chat"
                color: Colors.surfaceContainerLow
                clip: true

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 16
                    anchors.topMargin: 12
                    anchors.bottomMargin: 16
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Styling.radius(24)
                        color: Colors.surfaceContainerHigh

                        TextInput {
                            id: chatInput
                            anchors.fill: parent
                            anchors.leftMargin: 20
                            anchors.rightMargin: 20
                            verticalAlignment: TextInput.AlignVCenter
                            color: Colors.overBackground
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(0)
                            clip: true
                            selectByMouse: true

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "Mandale un mensaje a " + Config.brandName + "..."
                                color: Colors.overSurfaceVariant
                                opacity: chatInput.text.length === 0 ? 0.55 : 0
                                font: chatInput.font
                            }
                        }
                    }

                    Item {
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48

                        Rectangle {
                            anchors.fill: parent
                            radius: 24
                            color: sendMouse.containsMouse
                                   ? Qt.lighter(Colors.primary, 1.1)
                                   : Colors.primary
                            Behavior on color {
                                enabled: Config.animDuration > 0
                                ColorAnimation { duration: Config.animDuration / 2 }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: Icons.arrowUp
                            font.family: Icons.font
                            font.pixelSize: 22
                            color: Styling.srItem("overprimary")
                        }

                        MouseArea {
                            id: sendMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                console.log("ChatPanel send:", chatInput.text);
                                chatInput.text = "";
                            }
                        }
                    }
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: chatPanel.isOpen
        onActivated: GlobalStates.chatPanelOpen = false
    }
}
