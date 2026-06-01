pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.services

Singleton {
    id: root

    readonly property string thumbDir: "/tmp/matrix-switcher-thumbs"
    property int tick: 0
    signal captured()

    function sanitize(addr) {
        return String(addr).replace(/[^a-zA-Z0-9]/g, "_");
    }
    function thumbPath(addr) {
        return root.thumbDir + "/" + root.sanitize(addr) + ".png";
    }

    Process {
        id: grimProc
        running: false
        onExited: {
            root.tick++;
            root.captured();
            if (root._pendingCallback) {
                const cb = root._pendingCallback;
                root._pendingCallback = null;
                cb();
            }
        }
    }
    property var _pendingCallback: null

    function _isSwitcherOpen() {
        try {
            const screens = Visibilities.screens || {};
            for (let k in screens) {
                if (screens[k] && screens[k].windowswitcher) return true;
            }
        } catch (e) {}
        return false;
    }

    // Captura todas las ventanas dadas (array con .address, .at[0..1], .size[0..1])
    // Llama onDone() cuando termina (o de inmediato si nada que captar).
    function captureClients(clients, onDone) {
        if (!clients || clients.length === 0) {
            if (onDone) onDone();
            return;
        }
        if (grimProc.running) {
            // Otra captura en vuelo; encolar callback simple
            if (onDone) onDone();
            return;
        }
        let parts = clients.map(c => {
            const x = (c.at && c.at[0] !== undefined) ? c.at[0] : 0;
            const y = (c.at && c.at[1] !== undefined) ? c.at[1] : 0;
            const w = (c.size && c.size[0] !== undefined) ? c.size[0] : 100;
            const h = (c.size && c.size[1] !== undefined) ? c.size[1] : 100;
            const path = root.thumbPath(c.address);
            return `grim -g "${x},${y} ${w}x${h}" "${path}" 2>/dev/null &`;
        });
        const script = `mkdir -p "${root.thumbDir}" && ${parts.join(" ")} wait`;
        root._pendingCallback = onDone || null;
        grimProc.command = ["bash", "-c", script];
        grimProc.running = true;
    }

    function captureCurrentWorkspace(onDone) {
        if (root._isSwitcherOpen()) {
            // No captures mientras el overlay está visible (saldría el overlay en el thumb)
            if (onDone) onDone();
            return;
        }
        const ws = AxctlService.focusedWorkspace;
        if (!ws) { if (onDone) onDone(); return; }
        const list = (AxctlService.clients.values || []).filter(c => c.workspace && c.workspace.id === ws.id);
        captureClients(list, onDone);
    }

    // ── Auto-refresh: debounce ante cambios de cliente/workspace ──────────
    Timer {
        id: debounce
        interval: 400
        repeat: false
        onTriggered: root.captureCurrentWorkspace(null)
    }

    Connections {
        target: AxctlService
        function onFocusedClientChanged()    { debounce.restart(); }
        function onFocusedWorkspaceChanged() { debounce.restart(); }
    }

    // Captura inicial al arrancar (espera 1.5s a que el daemon esté listo)
    Timer {
        interval: 1500
        repeat: false
        running: true
        onTriggered: root.captureCurrentWorkspace(null)
    }
}
