import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // --- Dati grezzi -------------------------------------------------------
    property string target: "inactive"     // stato di ai.target da systemctl
    property string pending: ""            // "start" | "stop" dopo un click, finché systemd non conferma
    property double pendingSince: 0
    property var gpus: []                  // [{name, vram, vramTotal, gtt, gttTotal}] in MB
    property int llamaRss: 0               // MB di RAM normale usati da llama-server
    property bool swapOk: false            // llama-swap risponde (9292)
    property bool webuiOk: false           // Open WebUI risponde (8080)
    property string model: ""              // modello caricato da llama-swap
    property string modelState: ""         // starting | ready | ...
    property int modelTtl: 0               // secondi di inattività prima dello scaricamento
    property int ctxUsed: 0
    property int ctxMax: 0
    property int ctxTrain: 0               // contesto massimo supportato dal modello
    property string ctxTrainModel: ""
    property bool generating: false

    readonly property string swapUrl: "http://127.0.0.1:9292"
    readonly property string webuiUrl: "http://127.0.0.1:8080"
    readonly property int gttWarnMB: 512

    // --- Stato derivato ----------------------------------------------------
    readonly property var mainGpu: gpus.length ? gpus.reduce((a, b) => b.vramTotal > a.vramTotal ? b : a) : null
    readonly property bool targetUp: target === "active" || target === "activating" || target === "reloading"
    readonly property string phase: {
        if (pending === "stop" || target === "deactivating") return "stopping"
        if (!targetUp && pending !== "start") return "off"
        if (target !== "active" || !swapOk || !webuiOk) return "starting"
        if (model && modelState !== "ready") return "loading"
        if (model) return "model"
        return "ready"
    }
    readonly property bool aiOn: phase !== "off"
    readonly property real ctxRatio: ctxMax > 0 ? ctxUsed / ctxMax : 0

    readonly property color onColor: "#2ecc71"
    readonly property color warnColor: "#f1c40f"
    readonly property color loadColor: "#3498db"
    readonly property color dangerColor: "#e74c3c"
    readonly property color spillColor: "#e67e22"
    readonly property color offColor: Kirigami.Theme.disabledTextColor
    readonly property color phaseColor: {
        switch (phase) {
        case "off": return offColor
        case "starting":
        case "stopping": return warnColor
        case "loading": return loadColor
        default: return onColor
        }
    }
    readonly property string phaseText: {
        switch (phase) {
        case "off": return "AI disattivo"
        case "starting": return "AI in avvio…"
        case "stopping": return "AI in spegnimento…"
        case "loading": return "Carico " + model + "…"
        case "model": return "AI · " + model
        default: return "AI pronto"
        }
    }

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // --- Formattazione -----------------------------------------------------
    function mb(n) { return Number(n).toLocaleString(Qt.locale(), 'f', 0) + " MB" }
    function ktok(n) { return n >= 10240 ? Math.round(n / 1024) + "k" : (n / 1024).toFixed(1) + "k" }
    function ctxColor() {
        if (ctxRatio >= 0.9) return dangerColor
        if (ctxRatio >= 0.75) return warnColor
        return Kirigami.Theme.textColor
    }

    // --- Sonda locale (systemd, sysfs, /proc) ogni 2 s -------------------------
    readonly property string pollCmd:
        "sh '" + decodeURIComponent(Qt.resolvedUrl("../code/poll.sh").toString().replace("file://", "")) + "'"

    Plasma5Support.DataSource {
        id: poller
        engine: "executable"
        connectedSources: [root.pollCmd]
        interval: 2000
        onNewData: (source, data) => root.parsePoll(String(data["stdout"]))
    }

    function parsePoll(out) {
        const list = []
        let rss = 0
        for (const line of out.trim().split("\n")) {
            const i = line.indexOf("=")
            if (i < 0) continue
            const k = line.slice(0, i), v = line.slice(i + 1)
            if (k === "ai") target = v
            else if (k === "llama_rss") rss = Number(v)
            else if (k === "gpu") {
                const p = v.split(";")
                list.push({ name: p[0], vram: +p[1], vramTotal: +p[2], gtt: +p[3], gttTotal: +p[4] })
            }
        }
        gpus = list
        llamaRss = rss

        // Il click è confermato quando systemd raggiunge lo stato richiesto (o dopo 2 min)
        if ((pending === "start" && target === "active") ||
            (pending === "stop" && !targetUp && target !== "deactivating") ||
            (pending && Date.now() - pendingSince > 120000))
            pending = ""

        if (target === "active") pollHttp()
        else resetHttp()
    }

    // --- Sonde HTTP (solo con AI attiva, nessun processo esterno) ---------------
    property var inflight: ({})

    function getJson(key, url, done) {
        const old = inflight[key]
        if (old) {
            if (Date.now() - old.t < 10000) return   // richiesta precedente ancora in corso
            old.x.abort()
        }
        const x = new XMLHttpRequest()
        inflight[key] = { x: x, t: Date.now() }
        x.onreadystatechange = () => {
            if (x.readyState !== XMLHttpRequest.DONE) return
            delete inflight[key]
            let json = null
            if (x.status === 200) {
                try { json = JSON.parse(x.responseText) } catch (e) { }
            }
            done(json)
        }
        x.open("GET", url)
        x.send()
    }

    function pollHttp() {
        getJson("health", webuiUrl + "/health", j => webuiOk = j !== null)
        getJson("running", swapUrl + "/running", j => {
            swapOk = j !== null
            const r = j && j.running && j.running.length ? j.running[0] : null
            model = r ? r.model : ""
            modelState = r ? r.state : ""
            modelTtl = r && r.ttl ? r.ttl : 0
            if (r && r.state === "ready") pollModel(r.model)
            else { ctxUsed = 0; ctxMax = 0; generating = false }
        })
    }

    function pollModel(m) {
        const base = swapUrl + "/upstream/" + encodeURIComponent(m)
        getJson("slots", base + "/slots", j => {
            const s = j && j.length ? j[0] : null
            if (!s) return
            const decoded = s.next_token && s.next_token.length ? s.next_token[0].n_decoded : 0
            ctxUsed = (s.n_prompt_tokens || 0) + (s.is_processing ? decoded : 0)
            ctxMax = s.n_ctx || 0
            generating = !!s.is_processing
        })
        if (ctxTrainModel !== m) {
            getJson("models", base + "/v1/models", j => {
                const d = j && j.data && j.data.length ? j.data[0] : null
                ctxTrain = d && d.meta ? d.meta.n_ctx_train : 0
                ctxTrainModel = m
            })
        }
    }

    function resetHttp() {
        swapOk = false; webuiOk = false
        model = ""; modelState = ""; modelTtl = 0
        ctxUsed = 0; ctxMax = 0; generating = false
    }

    // --- Azioni ------------------------------------------------------------------
    Plasma5Support.DataSource {
        id: runner
        engine: "executable"
        onNewData: (source, data) => disconnectSource(source)
    }

    function toggle() {
        pending = aiOn ? "stop" : "start"
        pendingSince = Date.now()
        runner.connectSource("systemctl --user " + pending + " ai.target")
    }

    // --- Tooltip -------------------------------------------------------------------
    toolTipMainText: phaseText
    toolTipSubText: {
        const L = []
        for (const g of gpus) {
            L.push(g.name)
            L.push("   VRAM " + mb(g.vram) + " / " + mb(g.vramTotal))
            L.push("   RAM usata dalla GPU (GTT) " + mb(g.gtt) + (g.gtt > gttWarnMB ? "  ⚠ VRAM insufficiente?" : ""))
        }
        if (llamaRss > 0) L.push("RAM del modello (llama-server): " + mb(llamaRss))
        if (aiOn) {
            L.push("")
            L.push("llama-swap: " + (swapOk ? "ok" : "in avvio") + " · Open WebUI: " + (webuiOk ? "ok" : "in avvio"))
            if (phase === "model") {
                L.push("Contesto: " + ctxUsed.toLocaleString(Qt.locale(), 'f', 0) + " / " +
                       ctxMax.toLocaleString(Qt.locale(), 'f', 0) + " token (" + Math.round(ctxRatio * 100) + "%)" +
                       (generating ? " · sta generando" : ""))
                if (ctxTrain > ctxMax) L.push("   il modello supporta fino a " + ktok(ctxTrain) + " (opzione -c)")
            } else if (phase === "ready") {
                L.push("Nessun modello in memoria: si carica alla prima domanda")
            }
            if (modelTtl > 0) L.push("Scaricato dopo " + Math.round(modelTtl / 60) + " min di inattività")
        }
        L.push("")
        L.push("Clic: " + (aiOn ? "spegni" : "accendi") + " · Clic centrale: apri Open WebUI")
        return L.join("\n")
    }

    // --- Aspetto -------------------------------------------------------------------
    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 11
        Layout.preferredWidth: Math.max(Kirigami.Units.gridUnit * 11, content.implicitWidth + Kirigami.Units.gridUnit * 1.5)
        Layout.minimumHeight: Kirigami.Units.gridUnit * 2.8
        Layout.preferredHeight: Kirigami.Units.gridUnit * 3

        Rectangle {
            id: pill
            anchors.fill: parent
            anchors.margins: 2
            radius: Math.min(height / 2, Kirigami.Units.gridUnit * 1.2)
            color: root.aiOn ? Qt.rgba(root.phaseColor.r, root.phaseColor.g, root.phaseColor.b, 0.18)
                             : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)
            border.width: 1.5
            border.color: root.aiOn ? root.phaseColor : Qt.rgba(root.offColor.r, root.offColor.g, root.offColor.b, 0.6)
            Behavior on color { ColorAnimation { duration: 250 } }
            Behavior on border.color { ColorAnimation { duration: 250 } }
            scale: mouse.pressed ? 0.97 : 1
            Behavior on scale { NumberAnimation { duration: 90 } }

            RowLayout {
                id: content
                anchors.centerIn: parent
                spacing: Kirigami.Units.smallSpacing * 2

                Rectangle {
                    id: dot
                    width: Kirigami.Units.gridUnit * 0.7
                    height: width
                    radius: width / 2
                    color: root.phaseColor
                    // Pulsa durante le transizioni e mentre il modello genera
                    SequentialAnimation on opacity {
                        running: ["starting", "stopping", "loading"].includes(root.phase) || root.generating
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                        onRunningChanged: if (!running) dot.opacity = 1
                    }
                }
                ColumnLayout {
                    spacing: 0
                    Kirigami.Heading {
                        level: 4
                        text: root.phaseText
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.maximumWidth: Kirigami.Units.gridUnit * 14
                        color: root.aiOn ? root.phaseColor : Kirigami.Theme.textColor
                    }
                    Row {
                        spacing: 0
                        readonly property real fs: Kirigami.Theme.smallFont.pointSize
                        Text {
                            text: "VRAM: " + (root.mainGpu ? root.mb(root.mainGpu.vram) : "—")
                            font.pointSize: parent.fs
                            color: Kirigami.Theme.textColor
                            opacity: 0.8
                        }
                        Text {
                            visible: root.phase === "model" && root.ctxMax > 0
                            text: " · Ctx " + root.ktok(root.ctxUsed) + "/" + root.ktok(root.ctxMax)
                            font.pointSize: parent.fs
                            font.bold: root.ctxRatio >= 0.75
                            color: root.ctxColor()
                            opacity: root.ctxRatio >= 0.75 ? 1 : 0.8
                        }
                        Text {
                            visible: root.mainGpu !== null && root.mainGpu.gtt > root.gttWarnMB
                            text: " · RAM-GPU " + (root.mainGpu ? root.mb(root.mainGpu.gtt) : "")
                            font.pointSize: parent.fs
                            color: root.spillColor
                        }
                    }
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: ev => {
                    if (ev.button === Qt.MiddleButton) Qt.openUrlExternally(root.webuiUrl)
                    else root.toggle()
                }
            }
        }
    }
}
