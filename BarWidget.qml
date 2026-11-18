import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root

  readonly property string pluginId: "oma.synth"
  moduleName: pluginId

  readonly property var synth: bar && bar.shell ? bar.shell.serviceFor(pluginId) : null
  readonly property bool playing: synth ? synth.playing : false
  readonly property string tooltip: !playing ? "SynthwaveRadio.eu"
    : (synth.nowPlaying !== "" ? synth.nowPlaying : "SynthwaveRadio.eu – hämtar låt…")

  visible: synth !== null
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    slotSize: Style.bar.iconSlot
    tooltipText: root.tooltip
    // Baren läser texten när pekaren kommer in; visa ny låt direkt om den byts
    // medan man hovrar.
    onTooltipTextChanged: if (tooltipHovered && root.bar) root.bar.showTooltip(button, tooltipText)
    onTooltipHoveredChanged: if (root.synth) root.synth.hovered = tooltipHovered
    iconComponent: Component {
      Image {
        source: Qt.resolvedUrl(root.playing ? "icon-red.png" : "icon-white.png")
        width: Style.bar.iconCanvas
        height: Style.bar.iconCanvas
        sourceSize.width: Style.bar.iconCanvas * 3
        sourceSize.height: Style.bar.iconCanvas * 3
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
      }
    }
    onPressed: function(b) {
      if (b === Qt.LeftButton && root.synth) root.synth.toggle()
    }
  }
}
