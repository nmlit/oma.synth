import QtQuick
import Quickshell.Io

// Delat tillstånd för alla skärmar. Sanningen är systemd-enheten oma-synth,
// så ikonen synkas även efter omarchy-restart-shell medan strömmen spelar.
Item {
  id: root

  property var shell: null

  readonly property string pluginId: "oma.synth"
  readonly property string script: Qt.resolvedUrl("synth.sh").toString().replace("file://", "")

  property bool playing: false
  // "Artist - Låt" (ICY-titel från mpv, annars stationens AzuraCast-API).
  property string nowPlaying: ""
  // Sätts av BarWidget när muspekaren är över ikonen.
  property bool hovered: false
  readonly property bool busy: ctlProc.running

  function run(action) {
    if (ctlProc.running) return
    ctlProc.command = ["bash", root.script, action]
    ctlProc.running = true
  }

  function toggle() { if (ctlProc.running) return; var next = !root.playing; run(next ? "start" : "stop"); root.playing = next }
  function play() { if (ctlProc.running) return; run("start"); root.playing = true }
  function stop() { if (ctlProc.running) return; run("stop"); root.playing = false }
  function refreshNowPlaying() { if (root.playing && !npProc.running) npProc.running = true }
  onPlayingChanged: if (playing) npKick.restart()
  onHoveredChanged: if (hovered) refreshNowPlaying()

  function refresh() { if (!statusProc.running && !ctlProc.running) statusProc.running = true }

  Process {
    id: ctlProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.playing = text.trim() === "playing"
    }
    onExited: function(code) { if (code !== 0) Qt.callLater(root.refresh) }
  }

  Process {
    id: statusProc
    command: ["bash", root.script, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.playing = text.trim() === "playing"
    }
  }

  Process {
    id: npProc
    command: ["bash", root.script, "nowplaying"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: { var t = text.trim(); if (t !== "") root.nowPlaying = t }
    }
  }

  // Strömmen behöver någon sekund innan första ICY-titeln finns.
  Timer { id: npKick; interval: 2500; onTriggered: root.refreshNowPlaying() }

  // Låg belastning: bara medan strömmen spelar.
  Timer {
    interval: 15000
    running: root.playing
    repeat: true
    onTriggered: root.refreshNowPlaying()
  }

  // Fångar även att strömmen dött av sig själv (t.ex. nätverksfel).
  Timer {
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // omarchy-shell -q oma.synth toggle | play | stop
  IpcHandler {
    target: root.pluginId
    function toggle(): void { root.toggle() }
    function play(): void { root.play() }
    function stop(): void { root.stop() }
  }
}
