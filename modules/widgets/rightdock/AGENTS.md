# rightdock/ — Right Edge Dock

## OVERVIEW

Panel full-height anclado al borde derecho que reemplaza el viejo `clockPopup`. Se abre con click en el reloj del bar y contiene Calendar + Weather + Pomodoro + ColorPicker, todo envuelto en un único fondo `StyledRect "bg"` con esquinas redondeadas solo del lado izquierdo (el lado derecho queda pegado al borde de la pantalla).

## STRUCTURE

```
rightdock/
├── RightDock.qml      ← PanelWindow anchors top/bottom/right
├── DistroHeader.qml   ← Hero header con wallpaper/GIF + logo + nombre distro
└── ColorPicker.qml    ← HSV picker estilo Google
```

## WHERE TO LOOK

| Tarea | Ubicación | Notas |
|---|---|---|
| Cambiar ancho del dock | `RightDock.qml:dockWidth` | Default 380px |
| Cambiar altura del header | `RightDock.qml:headerHeight` | Default 150px |
| Cambiar spacing entre secciones | `RightDock.qml:sectionSpacing` | Default 10px |
| Cambiar GIF/imagen del header | `DistroHeader.qml:headerImage` (prop) | Default: wallpaper actual |
| Detección del logo distro | `DistroHeader.qml:logoCheck` | Busca `/usr/share/pixmaps/<id>(-logo).{svg,png}` |
| Calendario completo del mes | `RightDock.qml` grid 7×6 con `monthCells` | Nav con flechas + botón today (centro) |
| Animación slide-in | `RightDock.qml:slideTransform` | `Translate` con OutCubic/InCubic |
| Tamaño del cuadrado HSV | `ColorPicker.qml:svSquare` | `Layout.preferredHeight: width * 0.6` |
| Swatches predefinidos | `ColorPicker.qml` Repeater de Flow | Material You roles |

## TRIGGER

```
Clock click  →  GlobalStates.rightDockOpen = !rightDockOpen
Pomodoro alarm → GlobalStates.rightDockOpen = true (vía onRequestPopupOpen)
Botón X header → GlobalStates.rightDockOpen = false
```

## INTEGRACIÓN VISUAL CON EL BAR

El dock empieza a `y = barReserved` para no taparse con el bar superior. El radius del fondo es 0 en las esquinas derechas (tocan el borde de pantalla) y `Styling.radius(8)` en las izquierdas. Resultado: parece una extensión natural del bar.

## ANTI-PATTERNS

- ❌ **No usar BarPopup acá** — BarPopup ancla a un widget del bar; el RightDock es un PanelWindow independiente full-height.
- ❌ **No dejar mask sin item** — Setear `Region.item` a `null` deja la ventana capturando TODOS los clicks del lado derecho. Usá `panelMask` con `width: 0` cuando cerrado.
- ❌ **No animar mask** — La región de hit-test no acepta animación. Animá opacity/translate del contenido visible, no el mask.

## COLOR PICKER

Implementación HSV manual (sin QtQuick.Controls.ColorDialog):
- **SV square** — Dos gradients superpuestos: horizontal `white → pureHue`, vertical `transparent → black`. Click + drag actualiza `sat` y `val`.
- **Hue slider** — Gradient horizontal con stops cada 60°. Click + drag actualiza `hue`.
- **Hex input** — Bidireccional. Acepta `#RRGGBB` o `#RGB`.
- **Inicialización** — Toma `Colors.primary` al `Component.onCompleted`.

Para integrarlo afuera del dock: importa el .qml y úsalo como `ColorPicker { width: ... }`.
