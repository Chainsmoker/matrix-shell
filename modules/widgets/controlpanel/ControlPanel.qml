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
    id: controlPanel

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ambxst:controlpanel"
    WlrLayershell.keyboardFocus: controlPanelOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property var screenVisibilities: Visibilities.getForScreen(screen.name)
    readonly property bool controlPanelOpen: screenVisibilities ? screenVisibilities.controlpanel : false

    visible: controlPanelOpen
    exclusionMode: ExclusionMode.Ignore

    // Ancho del panel (slide-in)
    property int panelWidth: 380

    mask: Region {
        item: controlPanelOpen ? fullMask : emptyMask
    }

    Item {
        id: fullMask
        anchors.fill: parent
    }

    Item {
        id: emptyMask
        width: 0
        height: 0
    }

    FocusGrab {
        id: focusGrab
        windows: [controlPanel]
        active: controlPanelOpen

        onCleared: {
            Qt.callLater(() => {
                if (controlPanelOpen) {
                    Visibilities.setActiveModule("");
                }
            });
        }
    }

    // Backdrop semi-transparente
    Rectangle {
        anchors.fill: parent
        color: Colors.scrim
        opacity: controlPanelOpen ? 0.4 : 0

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutQuart
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Visibilities.setActiveModule("")
        }
    }

    // Panel deslizable desde la izquierda
    StyledRect {
        id: panel
        variant: "bg"
        width: controlPanel.panelWidth
        anchors {
            top: parent.top
            bottom: parent.bottom
            topMargin: 12
            bottomMargin: 12
        }

        // Slide: cuando está cerrado, x = -width (fuera de pantalla a la izquierda)
        //       cuando está abierto, x = 12 (12px de margen)
        x: controlPanelOpen ? 12 : -width

        topRightRadius: Styling.radius(20)
        bottomRightRadius: Styling.radius(20)
        topLeftRadius: Styling.radius(20)
        bottomLeftRadius: Styling.radius(20)

        layer.enabled: true
        layer.effect: Shadow {}

        Behavior on x {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }

        // Atrapar clicks dentro del panel (no cerrarlo)
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: {}  // swallow
        }

        // Contenido placeholder — acá iteramos
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            Text {
                text: "Control Panel"
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(3)
                font.bold: true
                color: Colors.overBackground
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "Placeholder — acá van los controles"
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                color: Colors.overSurfaceVariant
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 8
            }

            // Spacer + footer botón cerrar
            Item { Layout.fillHeight: true }

            Text {
                text: "Click fuera del panel o ESC para cerrar"
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.overSurfaceVariant
                opacity: 0.6
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    // ESC para cerrar
    Shortcut {
        sequence: "Escape"
        enabled: controlPanelOpen
        onActivated: Visibilities.setActiveModule("")
    }
}
