pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.modules.globals
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config

Item {
    id: root

    required property ShellScreen screen
    property bool reveal: false
    property bool unifiedEffectActive: false

    readonly property string notchPosition: Config.notchPosition !== undefined ? Config.notchPosition : "top"
    readonly property bool isIsland: Config.notchTheme === "island"
    readonly property int baseHeight: isIsland ? 36 : (Config.showBackground ? 44 : 40)
    
    readonly property bool activeWindowFullscreen: {
        const toplevel = ToplevelManager.activeToplevel;
        if (!toplevel || !toplevel.activated)
            return false;
        return toplevel.fullscreen === true;
    }

    readonly property int frameOffset: (Config.bar && Config.bar.frameEnabled && !activeWindowFullscreen) ? ((Config.bar.frameThickness !== undefined) ? Config.bar.frameThickness : 6) : 0

    // Full screen container to align and translate easily
    Item {
        id: leftNotchContainer
        
        width: 48
        height: baseHeight

        x: isIsland ? (frameOffset + 12) : 0
        y: {
            if (notchPosition === "top") {
                return isIsland ? (frameOffset + 4) : frameOffset;
            } else {
                return isIsland ? (parent.height - frameOffset - height - 4) : (parent.height - frameOffset - height);
            }
        }

        opacity: root.reveal ? 1 : 0
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 2
                easing.type: Easing.OutCubic
            }
        }

        transform: Translate {
            y: {
                if (root.reveal) return 0;
                if (root.notchPosition === "top")
                    return -(leftNotchContainer.height + 16);
                else
                    return (leftNotchContainer.height + 16);
            }
            Behavior on y {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Shadow for island theme
        layer.enabled: isIsland
        layer.effect: Shadow {}

        StyledRect {
            id: bgRect
            anchors.fill: parent
            variant: "bg"
            enableBorder: !root.unifiedEffectActive
            animateRadius: false
            
            radius: isIsland ? 18 : 0
            topLeftRadius: isIsland ? 18 : (notchPosition === "bottom" ? (Config.roundness > 0 ? Config.roundness + 4 : 0) : 0)
            topRightRadius: isIsland ? 18 : (notchPosition === "bottom" ? (Config.roundness > 0 ? Config.roundness + 4 : 0) : 0)
            bottomLeftRadius: isIsland ? 18 : (notchPosition === "top" ? (Config.roundness > 0 ? Config.roundness + 4 : 0) : 0)
            bottomRightRadius: isIsland ? 18 : (notchPosition === "top" ? (Config.roundness > 0 ? Config.roundness + 4 : 0) : 0)
        }

        // Button Area
        MouseArea {
            id: clickArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                GlobalStates.newsPanelOpen = !GlobalStates.newsPanelOpen;
            }

            // Icon inside
            Text {
                text: Icons.globe
                font.family: Icons.font
                font.pixelSize: 16
                anchors.centerIn: parent
                color: GlobalStates.newsPanelOpen ? Colors.primary : (clickArea.containsMouse ? Colors.primary : Colors.text)
                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }
        }
    }
}
