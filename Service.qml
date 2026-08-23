import "Model.js" as Model
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var settings: ({
    })
    readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace("file://", "")
    readonly property string cli: pluginDir + "bin/omarchy-litellm-sync"
    readonly property string statePath: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/litellm/data.json"
    property var cache: Model.emptyCache()
    property string lastError: ""
    readonly property bool syncing: syncProcess.running
    readonly property int refreshIntervalSeconds: {
        var configured = Number(settings && settings.refreshIntervalSec);
        if (!isFinite(configured))
            configured = 300;

        return Math.max(60, Math.min(3600, Math.round(configured)));
    }

    function refresh() {
        if (syncProcess.running)
            return ;

        syncProcess.running = true;
    }

    visible: false

    FileView {
        id: cacheFile

        path: root.statePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.cache = Model.parseCache(text())
        onLoadFailed: root.cache = Model.emptyCache()
    }

    Process {
        id: syncProcess

        command: [root.cli, "sync"]

        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.lastError = String(text || "").trim()
        }

    }

    Timer {
        interval: root.refreshIntervalSeconds * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

}
