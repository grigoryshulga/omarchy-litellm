import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "gshulga.litellm"
  ipcTarget: "gshulga.litellm"
  manageIpc: false

  readonly property var service: bar && bar.shell && typeof bar.shell.serviceFor === "function"
    ? bar.shell.serviceFor(root.moduleName) : null
  readonly property var cache: service ? service.cache : Model.emptyCache()
  readonly property var key: cache.key || ({})
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color track: Style.selectedFillFor(foreground, Color.accent)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool ready: cache.state === "ready" || cache.state === "error"
  readonly property bool weeklyUsageAvailable: cache.analyticsState === "ready"
  readonly property bool weeklyCacheCurrent: String(cache.weekStart || "") === Model.weekStartDate(nowMs)
  readonly property var actionCaptions: [
    "Spending corpo money",
    "tokenmaxxing for free",
    "Burning the company tab",
    "Printing shareholder value",
    "Making tokens go brrr",
    "Maxxing the context window",
    "Putting the cloud to work",
    "Turning cash into tokens",
    "Summoning more compute",
    "Expensing the inference"
  ]
  property int captionIndex: 0
  readonly property string heroCaption: actionCaptions[captionIndex % actionCaptions.length]
  readonly property real dailyLimit: {
    var configured = Number(setting("dailyLimitUsd", 50))
    return isFinite(configured) && configured > 0 ? configured : 50
  }
  readonly property real weeklyLimit: {
    return root.dailyLimit * 7
  }
  readonly property real dailySpend: weeklyUsageAvailable ? Math.max(0, Model.number(cache.today ? cache.today.spend : 0)) : 0
  readonly property real dailySpentRatio: weeklyUsageAvailable ? Math.min(1, dailySpend / dailyLimit) : -1
  readonly property real dailyRemaining: Math.max(0, dailyLimit - dailySpend)
  readonly property real dailyRemainingRatio: weeklyUsageAvailable ? Math.max(0, 1 - dailySpend / dailyLimit) : -1
  readonly property bool dailyAlarming: dailyRemainingRatio >= 0 && dailyRemainingRatio < 0.1
  readonly property real weeklySpend: weeklyCacheCurrent ? Math.max(0, Model.number(cache.week ? cache.week.spend : 0)) : 0
  readonly property real weeklySpentRatio: weeklyUsageAvailable ? Math.min(1, weeklySpend / weeklyLimit) : -1
  readonly property real weeklyRemaining: Math.max(0, weeklyLimit - weeklySpend)
  readonly property real weeklyRemainingRatio: weeklyUsageAvailable ? Math.max(0, 1 - weeklySpend / weeklyLimit) : -1
  readonly property bool weeklyAlarming: weeklyRemainingRatio >= 0 && weeklyRemainingRatio < 0.1
  property double nowMs: Date.now()

  function refresh() { if (service) service.refresh() }
  onOpenedChanged: if (opened) nowMs = Date.now()
  function clamp(value, low, high) { return Math.max(low, Math.min(high, value)) }
  function alpha(color, opacity) { return Qt.rgba(color.r, color.g, color.b, opacity) }
  function nextCaption() {
    var next = Math.floor(Math.random() * actionCaptions.length)
    if (actionCaptions.length > 1 && next === captionIndex) next = (next + 1) % actionCaptions.length
    captionIndex = next
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refresh(); return "ok" }
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }

  Timer {
    id: captionTimer
    interval: 2800
    running: root.opened && root.ready
    repeat: true
    onTriggered: captionSwap.restart()
  }

  SequentialAnimation {
    id: captionSwap
    PropertyAnimation {
      target: hero; property: "metaOpacity"
      to: 0.0; duration: 180; easing.type: Easing.OutQuad
    }
    ScriptAction { script: root.nextCaption() }
    PropertyAnimation {
      target: hero; property: "metaOpacity"
      to: 1.0; duration: 260; easing.type: Easing.InQuad
    }
  }

  Connections {
    target: root
    function onReadyChanged() {
      if (!root.ready) {
        captionSwap.stop()
        hero.metaOpacity = 1.0
      }
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    labelVisible: false
    hasVisualContent: true
    fixedWidth: icon.implicitWidth + percentage.implicitWidth + Style.space(13)
    dimmed: !root.ready
    tooltipText: !root.ready ? "LiteLLM - setup required" : !root.weeklyUsageAvailable
      ? "LiteLLM - usage unavailable" : "LiteLLM - " + Math.round(root.weeklyRemainingRatio * 100) + "% of weekly limit remaining"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) root.refresh()
      else root.toggle()
    }

    Row {
      anchors.centerIn: parent
      spacing: Style.space(7)
      Item {
        id: icon
        implicitWidth: Style.space(18)
        implicitHeight: Style.space(18)
        width: implicitWidth
        height: implicitHeight

        Image {
          anchors.fill: parent
          source: "litellm-light.svg"
          fillMode: Image.PreserveAspectFit
        }
      }
      Text {
        id: percentage
        text: root.ready && root.weeklyUsageAvailable ? Math.round(root.weeklyRemainingRatio * 100) + "%" : "-"
        color: root.weeklyAlarming ? root.urgent : button.foreground
        font.family: root.fontFamily
        font.pixelSize: button.fontSize
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(640))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (dy !== 0) flick.contentY = root.clamp(flick.contentY + dy * Style.space(56), 0, Math.max(0, flick.contentHeight - flick.height))
      }
      onActivateRequested: root.refresh()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(value) { if (value === "r" || value === "R") root.refresh() }

      Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: content
          width: flick.width
          spacing: Style.space(12)

          PanelHero {
            id: hero
            width: parent.width
            title: "LiteLLM"
            meta: root.ready ? root.heroCaption : "Personal usage"
            foreground: root.foreground
            fontFamily: root.fontFamily
            trailingControl: Component {
              Text {
                text: root.weeklyUsageAvailable ? Math.round(root.weeklyRemainingRatio * 100) + "%" : "-"
                color: root.weeklyAlarming ? root.urgent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
                font.bold: true
              }
            }
            iconComponent: Component {
              Item {
                width: Style.font.display
                height: Style.font.display

                Image {
                  anchors.fill: parent
                  source: "litellm-light.svg"
                  fillMode: Image.PreserveAspectFit
                }
              }
            }
          }

          BorderSurface {
            visible: root.cache.state === "error"
            width: parent.width
            implicitHeight: errorText.implicitHeight + Style.space(20)
            color: root.alpha(root.urgent, 0.1)
            borderSpec: Border.flat(root.alpha(root.urgent, 0.35), 1)
            radius: Style.cornerRadius
            Text {
              id: errorText
              anchors.fill: parent
              anchors.margins: Style.space(10)
              text: String(root.cache.error || "Could not refresh LiteLLM")
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          PanelSeparator { visible: root.ready; foreground: root.foreground }

          Column {
            visible: root.ready && root.weeklyUsageAvailable
            width: parent.width
            spacing: Style.space(10)
            PanelSectionHeader { width: parent.width; text: "LIMITS"; foreground: root.foreground; fontFamily: root.fontFamily }

            Item {
              width: parent.width
              implicitHeight: Math.max(budgetLabel.implicitHeight, budgetValue.implicitHeight)
              Text { id: budgetLabel; text: "Daily"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
              Text {
                id: budgetValue
                text: Model.formatMoney(root.dailyRemaining)
                color: root.dailyAlarming ? root.urgent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            Meter { width: parent.width; value: root.dailySpentRatio; alarming: root.dailyAlarming }

            Item {
              width: parent.width
              implicitHeight: Math.max(weeklyBudgetLabel.implicitHeight, weeklyBudgetValue.implicitHeight)
              Text { id: weeklyBudgetLabel; text: "Weekly"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
              Text {
                id: weeklyBudgetValue
                text: Model.formatMoney(root.weeklyRemaining)
                color: root.weeklyAlarming ? root.urgent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            Meter { width: parent.width; value: root.weeklySpentRatio; alarming: root.weeklyAlarming }

            Item {
              width: parent.width
              implicitHeight: Math.max(resetText.implicitHeight, spentText.implicitHeight)
              Text {
                id: resetText
                anchors.left: parent.left
                anchors.right: spentText.left
                anchors.rightMargin: Style.space(12)
                anchors.verticalCenter: parent.verticalCenter
                text: Model.weekResetLabel(root.nowMs)
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
              Text {
                id: spentText
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: Model.formatMoney(root.weeklySpend) + " of " + Model.formatMoney(root.weeklyLimit) + " spent"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Row {
              visible: Number(root.key.rpmLimit || 0) > 0 || Number(root.key.tpmLimit || 0) > 0
              width: parent.width
              spacing: Style.space(18)
              Text { visible: Number(root.key.rpmLimit || 0) > 0; text: "RPM: " + String(root.key.rpmLimit); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              Text { visible: Number(root.key.tpmLimit || 0) > 0; text: "TPM: " + Model.formatTokens(root.key.tpmLimit); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
            }
          }

          PanelSeparator { visible: root.cache.analyticsState === "ready"; foreground: root.foreground }

          Column {
            visible: root.cache.analyticsState === "ready"
            width: parent.width
            spacing: Style.space(9)
            PanelSectionHeader { width: parent.width; text: "TODAY"; foreground: root.foreground; fontFamily: root.fontFamily }
            Row {
              width: parent.width
              spacing: Style.space(10)
              Stat { width: (parent.width - parent.spacing) / 2; label: "Spend"; value: Model.formatMoney(root.cache.today.spend) }
              Stat { width: (parent.width - parent.spacing) / 2; label: "Tokens"; value: Model.formatTokens(root.cache.today.totalTokens) }
            }
            Row {
              width: parent.width
              spacing: Style.space(10)
              Stat { width: (parent.width - parent.spacing) / 2; label: "Requests"; value: String(root.cache.today.requests || 0) }
              Stat { width: (parent.width - parent.spacing) / 2; label: "Successful"; value: String(root.cache.today.successfulRequests || 0) }
            }
          }

          PanelSeparator { visible: root.cache.analyticsState === "ready" && root.cache.days.length > 0; foreground: root.foreground }

          Column {
            id: daySection
            visible: root.cache.analyticsState === "ready" && root.cache.days.length > 0
            width: parent.width
            spacing: Style.space(8)
            readonly property real peak: Model.dayPeak(root.cache.days)
            PanelSectionHeader { width: parent.width; text: "SPEND BY DAY"; foreground: root.foreground; fontFamily: root.fontFamily }
            Repeater {
              model: root.cache.days
              DayRow { required property var modelData; width: daySection.width; day: modelData; ratio: Number(modelData.spend || 0) / daySection.peak }
            }
          }

          PanelSeparator { visible: root.cache.analyticsState === "ready" && root.cache.models.length > 0; foreground: root.foreground }

          Column {
            id: modelSection
            visible: root.cache.analyticsState === "ready" && root.cache.models.length > 0
            width: parent.width
            spacing: Style.space(8)
            PanelSectionHeader { width: parent.width; text: "SPEND BY MODEL"; foreground: root.foreground; fontFamily: root.fontFamily }
            Repeater {
              model: root.cache.models
              ModelRow {
                required property var modelData
                width: modelSection.width
                row: modelData
                share: Number(modelData.spend || 0) / Math.max(0.000001, Number(root.cache.models[0].spend || 0))
              }
            }
          }

          Text {
            visible: root.cache.analyticsState !== "ready"
            width: parent.width
            text: String(root.cache.analyticsError || "Detailed usage statistics are unavailable for this virtual key")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          Text {
            width: parent.width
            text: root.service && root.service.syncing ? "Refreshing..." : Model.staleLabel(root.cache, root.nowMs)
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }
    }
  }

  component Meter: Item {
    property real value: -1
    property bool alarming: false
    implicitHeight: Math.max(Style.space(4), Math.round(Style.spacing.controlHeight * 0.14))
    Rectangle { id: meterTrack; anchors.fill: parent; radius: height / 2; color: root.track }
    Rectangle {
      anchors.left: meterTrack.left
      anchors.verticalCenter: meterTrack.verticalCenter
      height: meterTrack.height
      radius: meterTrack.radius
      width: meterTrack.width * root.clamp(value, 0, 1)
      color: alarming ? root.urgent : root.foreground
      Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }
  }

  component Stat: BorderSurface {
    id: stat
    required property string label
    required property string value
    implicitHeight: statColumn.implicitHeight + Style.space(16)
    color: root.alpha(root.foreground, 0.05)
    borderSpec: Border.flat(root.alpha(root.foreground, 0.1), 1)
    radius: Style.cornerRadius
    Column {
      id: statColumn
      anchors.fill: parent
      anchors.margins: Style.space(8)
      spacing: Style.space(3)
      Text { text: stat.label; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
      Text { text: stat.value; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
    }
  }

  component DayRow: Item {
    id: dayRow
    property var day: null
    property real ratio: 0
    implicitHeight: Math.max(dayLabel.implicitHeight, dayValue.implicitHeight) + Style.space(6)
    Text { id: dayLabel; text: Model.dayLabel(dayRow.day ? dayRow.day.date : "", root.nowMs); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; width: Style.space(52) }
    Rectangle {
      id: dayTrack
      anchors.left: dayLabel.right
      anchors.right: dayValue.left
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      height: Math.max(Style.space(4), Math.round(Style.spacing.controlHeight * 0.14))
      radius: height / 2
      color: root.track
      Rectangle { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; height: parent.height; radius: parent.radius; width: parent.width * root.clamp(dayRow.ratio, 0, 1); color: root.alpha(root.foreground, 0.65); Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } } }
    }
    Text { id: dayValue; text: Model.formatMoney(dayRow.day ? dayRow.day.spend : 0); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true; horizontalAlignment: Text.AlignRight; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: Style.space(58) }
  }

  component ModelRow: Item {
    id: modelRow
    property var row: null
    property real share: 0
    implicitHeight: modelName.implicitHeight + Style.space(16)
    Rectangle { anchors.fill: parent; radius: Style.cornerRadius; color: root.alpha(root.foreground, 0.05) }
    Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: parent.width * root.clamp(modelRow.share, 0, 1); radius: Style.cornerRadius; color: root.alpha(root.foreground, 0.14); Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } } }
    Text { id: modelName; text: modelRow.row ? String(modelRow.row.name || "Unknown") : ""; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight; anchors.left: parent.left; anchors.leftMargin: Style.space(8); anchors.right: modelValue.left; anchors.rightMargin: Style.space(8); anchors.verticalCenter: parent.verticalCenter }
    Text { id: modelValue; text: modelRow.row ? Model.formatMoney(modelRow.row.spend) : ""; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true; anchors.right: parent.right; anchors.rightMargin: Style.space(8); anchors.verticalCenter: parent.verticalCenter }
    MouseArea { id: modelHover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
    PanelToolTip { visible: modelHover.containsMouse; text: modelRow.row ? Model.formatTokens(modelRow.row.totalTokens) + " tokens, " + String(modelRow.row.requests || 0) + " requests" : ""; fontFamily: root.fontFamily }
  }
}
