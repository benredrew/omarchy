import QtQuick
import Quickshell.Io
import qs.Ui

BarIndicator {
  id: root

  property bool lidAwake: false
  property bool laptop: false

  active: lidAwake
  activeText: "󰌢"
  inactiveText: "󰌢"
  activeTooltipText: "Allow Lid-Close Suspend"
  inactiveTooltipText: "Stay On With Lid Closed"

  // Only a laptop has a lid to keep awake.
  visible: laptop && belongsInBlock

  function refresh() {
    if (!root.bar || statusProc.running) return
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
    }
  }

  onPressed: function() {
    if (root.bar) root.bar.run("omarchy-toggle-lid-awake")
  }
}
