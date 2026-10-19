import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.UPower
import "../theme"

// Содержимое экрана блокировки: размытый фон + часы; при активности — стеклянная панель.
FocusScope {
    id: root
    required property var controller
    property string screenName: ""

    property bool panelOn: false
    property string pw: ""

    // ---- данные ----
    property var now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

    readonly property var dows: ["воскресенье","понедельник","вторник","среда","четверг","пятница","суббота"]
    readonly property var mons: ["января","февраля","марта","апреля","мая","июня","июля","августа","сентября","октября","ноября","декабря"]
    readonly property string timeText: Qt.formatTime(now, "HH:mm")
    readonly property string dateText: dows[now.getDay()] + ", " + now.getDate() + " " + mons[now.getMonth()]

    property real cpu: 0; property real mem: 0; property string memGb: "0"
    property real temp: 0; property real disk: 0; property real rx: 0; property real tx: 0
    property string layout: "EN"

    function fmtRate(b) {
        if (b > 1048576) return (b / 1048576).toFixed(1) + " MB/s"
        if (b > 1024) return Math.round(b / 1024) + " KB/s"
        return Math.round(b) + " B/s"
    }

    // ---- фон ----
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#141633" }
            GradientStop { position: 1; color: "#08181c" }
        }
    }
    Image {
        id: shot
        anchors.fill: parent
        source: "file://" + Quickshell.env("XDG_RUNTIME_DIR") + "/serpantinum-lock-" + root.screenName + ".png"
        fillMode: Image.PreserveAspectCrop
        cache: false
        visible: false
        layer.enabled: false
    }
    MultiEffect {
        anchors.fill: parent
        source: shot
        visible: shot.status === Image.Ready
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: root.panelOn ? 1.0 : 0.65
        brightness: root.panelOn ? -0.32 : -0.22
        saturation: -0.1
        Behavior on blur { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic } }
        Behavior on brightness { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic } }
    }

    // ---- состояние простоя: большие часы ----
    Column {
        id: idleClock
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.panelOn ? parent.height * 0.12 : parent.height * 0.32
        spacing: 6
        opacity: root.panelOn ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.animMed } }
        Behavior on y { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic } }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.timeText
            color: Theme.text
            font { family: Theme.font; pixelSize: 150; weight: Font.Medium }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.dateText.toUpperCase()
            color: Theme.muted
            font { family: Theme.font; pixelSize: 22; letterSpacing: 4 }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: 40
            text: "нажмите любую клавишу"
            color: Qt.rgba(1, 1, 1, 0.35)
            font { family: Theme.font; pixelSize: 14; letterSpacing: 2 }
        }
    }

    // ---- панель ----
    Item {
        id: panel
        anchors.centerIn: parent
        width: Math.min(1100, root.width - 64)
        height: Math.min(460, root.height - 64)
        opacity: root.panelOn ? 1 : 0
        scale: root.panelOn ? 1 : 0.96
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic } }

        property real shake: 0
        transform: Translate { x: panel.shake }
        SequentialAnimation {
            id: shakeAnim
            NumberAnimation { target: panel; property: "shake"; to: -14; duration: 50 }
            NumberAnimation { target: panel; property: "shake"; to: 14;  duration: 90 }
            NumberAnimation { target: panel; property: "shake"; to: -8;  duration: 80 }
            NumberAnimation { target: panel; property: "shake"; to: 0;   duration: 70 }
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius + 4
            color: Theme.glass
            border.width: 1
            border.color: Theme.border
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0.16, 0.15, 0.30, 0.55) }
                GradientStop { position: 1; color: Qt.rgba(0.05, 0.09, 0.13, 0.60) }
            }
        }

        Row {
            anchors { fill: parent; margins: 16 }
            spacing: 16

            // Левая колонка: время/батарея + статистика
            Column {
                width: (parent.width - 32) * 0.29
                height: parent.height
                spacing: 12

                GlassCard {
                    width: parent.width; height: parent.height * 0.30
                    Column {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 16 }
                        spacing: 2
                        Text { text: root.timeText; color: Theme.text; font { family: Theme.font; pixelSize: 40; weight: Font.Medium } }
                        Text { text: root.dateText; color: Theme.muted; font { family: Theme.font; pixelSize: 13 } }
                    }
                }
                Row {
                    width: parent.width; height: parent.height * 0.34; spacing: 10
                    StatTile { width: (parent.width - 20) / 3; height: parent.height; label: "CPU"; valueText: root.cpu + "%"; fraction: root.cpu / 100; fill: Theme.accent }
                    StatTile { width: (parent.width - 20) / 3; height: parent.height; label: "RAM"; valueText: root.memGb + "G"; fraction: root.mem / 100; fill: Theme.accent2 }
                    StatTile { width: (parent.width - 20) / 3; height: parent.height; label: "Temp"; valueText: root.temp + "°"; fraction: root.temp / 100; fill: root.temp > 80 ? Theme.danger : Theme.warn }
                }
                Row {
                    width: parent.width; height: parent.height * 0.30 - 24; spacing: 10
                    StatTile { width: (parent.width - 10) * 0.45; height: parent.height; label: "Disk"; valueText: root.disk + "%"; fraction: root.disk / 100; fill: Theme.accent }
                    GlassCard {
                        width: (parent.width - 10) * 0.55; height: parent.height
                        Column {
                            anchors { centerIn: parent }
                            spacing: 6
                            Text { text: "󰁅 " + root.fmtRate(root.rx); color: Theme.accent2; font { family: Theme.font; pixelSize: 12 } }
                            Text { text: "󰁝 " + root.fmtRate(root.tx); color: Theme.accent;  font { family: Theme.font; pixelSize: 12 } }
                        }
                    }
                }
            }

            // Центр: аватар + пароль
            Column {
                width: (parent.width - 32) * 0.42
                height: parent.height
                spacing: 16

                Item { width: 1; height: parent.height * 0.04 }

                Rectangle {
                    id: avatarRing
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 150; height: 150; radius: 75
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.accent }
                        GradientStop { position: 1; color: Theme.accent2 }
                    }
                    Image {
                        id: avatar
                        anchors { fill: parent; margins: 3 }
                        source: "file://" + Quickshell.env("HOME") + "/.config/serpantinum/avatars/current.png"
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(300, 300)
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: avatarMask
                        }
                    }
                    Rectangle { id: avatarMask; anchors { fill: parent; margins: 3 } radius: width / 2; visible: false; layer.enabled: true }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: nameText.implicitWidth + 36; height: 32; radius: 16
                    color: Theme.glassSoft
                    Text {
                        id: nameText
                        anchors.centerIn: parent
                        text: Quickshell.env("USER") + "  ·  введите пароль"
                        color: Theme.text; font { family: Theme.font; pixelSize: 13 }
                    }
                }

                // Поле пароля
                Rectangle {
                    id: field
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 20; height: 54; radius: 27
                    color: Qt.rgba(0, 0, 0, 0.28)
                    border.width: 2
                    border.color: root.controller.failed ? Theme.danger : (input.activeFocus ? Theme.accent : Theme.border)
                    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                        text: "󰌾"; color: Theme.muted; font { family: Theme.font; pixelSize: 18 }
                    }
                    TextInput {
                        id: input
                        anchors { left: parent.left; right: submit.left; leftMargin: 54; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        echoMode: TextInput.Password
                        passwordCharacter: "●"
                        passwordMaskDelay: 0
                        color: Theme.text
                        font { family: Theme.font; pixelSize: 18; letterSpacing: 4 }
                        focus: true
                        enabled: !root.controller.busy
                        clip: true
                        selectByMouse: false
                        onTextChanged: { root.pw = text; root.wake() }
                        onAccepted: root.controller.submit(text)
                        Keys.onEscapePressed: { text = ""; root.sleepPanel() }
                    }
                    Text {
                        anchors { left: parent.left; leftMargin: 54; verticalCenter: parent.verticalCenter }
                        visible: input.text.length === 0
                        text: "Пароль"; color: Qt.rgba(1, 1, 1, 0.35)
                        font { family: Theme.font; pixelSize: 16 }
                    }
                    Rectangle {
                        id: submit
                        anchors { right: parent.right; rightMargin: 7; verticalCenter: parent.verticalCenter }
                        width: 40; height: 40; radius: 20
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Theme.accent }
                            GradientStop { position: 1; color: Theme.accent2 }
                        }
                        scale: sma.pressed ? 0.92 : (sma.containsMouse ? 1.08 : 1)
                        Behavior on scale { NumberAnimation { duration: Theme.animFast } }
                        Text {
                            anchors.centerIn: parent
                            text: root.controller.busy ? "󰔟" : "󰁔"
                            color: "#0b0d17"; font { family: Theme.font; pixelSize: 20 }
                        }
                        MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; onClicked: root.controller.submit(input.text) }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.controller.message
                    color: Theme.danger
                    opacity: root.controller.failed ? 1 : 0
                    font { family: Theme.font; pixelSize: 13 }
                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10
                    Rectangle {
                        width: layoutText.implicitWidth + 26; height: 28; radius: 14; color: Theme.glassSoft
                        Text { id: layoutText; anchors.centerIn: parent; text: "󰌌  " + root.layout; color: Theme.text; font { family: Theme.font; pixelSize: 12 } }
                    }
                    Rectangle {
                        visible: UPower.displayDevice && UPower.displayDevice.isLaptopBattery
                        width: batText.implicitWidth + 26; height: 28; radius: 14; color: Theme.glassSoft
                        Text {
                            id: batText; anchors.centerIn: parent
                            readonly property real p: UPower.displayDevice ? UPower.displayDevice.percentage * 100 : 0
                            text: "󰁹  " + Math.round(p) + "%"
                            color: p < 20 ? Theme.danger : Theme.accent2
                            font { family: Theme.font; pixelSize: 12 }
                        }
                    }
                }
            }

            // Правая колонка: медиа
            Column {
                width: (parent.width - 32) * 0.29
                height: parent.height
                spacing: 12
                GlassCard {
                    width: parent.width; height: parent.height - mediaCard.height - 12
                    Text {
                        anchors.centerIn: parent
                        text: "󰂚  Уведомления\nпоявятся здесь позже"
                        horizontalAlignment: Text.AlignHCenter
                        color: Qt.rgba(1, 1, 1, 0.30)
                        font { family: Theme.font; pixelSize: 12 }
                    }
                }
                MediaCard { id: mediaCard; width: parent.width; height: visible ? 92 : 0 }
            }
        }
    }

    // ---- активность / простой ----
    function wake() { panelOn = true; idleTimer.restart(); input.forceActiveFocus() }
    function sleepPanel() { panelOn = false; input.text = "" }
    Timer { id: idleTimer; interval: 25000; onTriggered: if (!root.controller.busy) root.sleepPanel() }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        z: -1
        onPositionChanged: root.wake()
        onClicked: root.wake()
    }
    Component.onCompleted: { input.forceActiveFocus(); if (Quickshell.env("SERP_LOCK_SHOW") === "1") wake() }

    Connections {
        target: root.controller
        function onFailedChanged() {
            if (root.controller.failed) { shakeAnim.restart(); input.text = ""; input.forceActiveFocus() }
        }
    }

    // ---- статистика (работает только при открытой панели) ----
    Process {
        running: root.panelOn
        command: [Quickshell.shellPath("lock/stats.sh")]
        stdout: SplitParser {
            onRead: line => {
                const p = line.trim().split(" ")
                if (p.length < 7) return
                root.cpu = +p[0]; root.mem = +p[1]; root.memGb = p[2]
                root.temp = +p[3]; root.disk = +p[4]; root.rx = +p[5]; root.tx = +p[6]
            }
        }
    }

    // ---- раскладка ----
    function setLayoutFrom(name) { layout = /russian|ru/i.test(name) ? "RU" : "EN" }
    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kbs = JSON.parse(text).keyboards
                    const main = kbs.find(k => k.main) || kbs[0]
                    if (main) root.setLayoutFrom(main.active_keymap)
                } catch (e) {}
            }
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") {
                const d = event.data.split(",")
                root.setLayoutFrom(d[d.length - 1])
            }
        }
    }
}
