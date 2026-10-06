import QtQuick
import Quickshell.Io
import qs.Ui

BarIndicator {
  id: root

  property bool lidAwake: false
  property bool laptop: false
  property bool refreshPending: false
  readonly property var batteryService: bar?.shell?.firstPartyServiceFor("omarchy.battery")
  readonly property bool batteryFloorReached: batteryService ? batteryService.lidAwakeFloorReached : false

  active: lidAwake
  activeText: "󰌢"
  inactiveText: "󰌢"
  activeTooltipText: "Allow Lid-Close Suspend"
  inactiveTooltipText: batteryFloorReached ? "Battery floor reached" : "Stay On With Lid Closed"

  // Only a laptop has a lid to keep awake.
  visible: laptop && belongsInBlock

  function refresh() {
    if (!root.bar) return
    // A check already running may have sampled the unit before a toggle, so
    // run one more after it rather than dropping this request.
    if (statusProc.running) {
      root.refreshPending = true
      return
    }
    statusProc.running = true
  }

  onBarChanged: refresh()
  Component.onCompleted: {
    laptopProc.running = true
    refresh()
  }

  Connections {
    target: root.indicatorHost
    ignoreUnknownSignals: true
    function onRefreshRequested() { root.refresh() }
  }

  Process {
    id: laptopProc
    command: ["omarchy-hw-laptop"]
    onExited: function(exitCode) {
      root.laptop = exitCode === 0
    }
  }

  Process {
    id: statusProc
    command: ["systemctl", "--user", "--quiet", "is-active", "omarchy-lid-awake"]
    onExited: function(exitCode) {
      root.lidAwake = exitCode === 0
      if (root.refreshPending) {
        root.refreshPending = false
        root.refresh()
      }
    }
  }

  onPressed: function() {
    if (root.bar) root.bar.run("omarchy-toggle-lid-awake")
  }
}
