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
  onLaptopChanged: unitFollower.running = laptop

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

  // The unit can fail, restart, or stop outside the toggle. Its journal logs
  // every change, so follow it rather than poll: lines wait in the pipe while
  // the shell is busy, so none is missed. pdeathsig stops the follower if the
  // shell dies without cleaning up its children.
  Process {
    id: unitFollower
    command: ["setpriv", "--pdeathsig", "TERM", "journalctl", "--user", "--follow", "--lines=0", "--output=cat", "--unit=omarchy-lid-awake"]
    stdout: SplitParser {
      onRead: root.refresh()
    }
    onExited: if (root.laptop) followerRestart.start()
  }

  // Changes logged while the follower was down are not replayed, so check the
  // unit again once it is back.
  Timer {
    id: followerRestart
    interval: 5000
    onTriggered: {
      unitFollower.running = true
      root.refresh()
    }
  }

  onPressed: function() {
    if (root.bar) root.bar.run("omarchy-toggle-lid-awake")
  }
}
