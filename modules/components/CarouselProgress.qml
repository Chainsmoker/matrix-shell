import QtQuick
import qs.config
import qs.modules.theme

WavyLine {
    id: root

    // Los sliders/seekbars usan onda estática por-valor, NO el visualizador de cava
    // (si no, cada slider lanza su propio proceso cava y se "enlaza" al notch).
    useCava: false

    // API Compatibility for CarouselProgress users
    property real dotSize: 4
    property real spacing: 6
    property real targetSpacing: 6
    property bool active: true

    // Map Carousel properties to WavyLine properties
    lineWidth: dotSize
    
    // Default WavyLine properties are already set in WavyLine.qml
    // Users can override frequency, amplitude etc.
}
