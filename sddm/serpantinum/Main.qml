import QtQuick
import QtQuick.Effects
import QtQuick.Window

// Экран входа Serpantinum (SDDM). Повторяет раскладку экрана блокировки Serpantinum:
// стадия 1 — размытые обои, большие часы, дата, «нажмите любую клавишу»;
// стадия 2 — стеклянная панель из трёх колонок: время/погода | аватар, имя, пароль | сессия и питание.
// Первая клавиша только открывает панель и в пароль не попадает.
// Только реальные данные: время, погода (Open-Meteo по координатам из theme.conf), пользователи, сессии, раскладка.
Item {
    id: root
    width: Screen.width
    height: Screen.height

    readonly property real s: Math.max(0.6, height / 1080)
    function cfg(key, def) { return (config[key] !== undefined && config[key] !== "") ? config[key] : def }
    readonly property color cBase: cfg("base", "#0d0f08")
    readonly property color cText: cfg("text", "#e4e3d7")
    readonly property color cSub: cfg("subtext", "#c7c8b8")
    readonly property color cAccent: cfg("accent", "#bdce80")
    readonly property color cAccent2: cfg("accent2", "#a1d0c5")
    readonly property color cDanger: cfg("danger", "#f38ba8")
    readonly property string fam: cfg("fontFamily", "JetBrainsMono Nerd Font")
    readonly property string lat: cfg("lat", "")
    readonly property string lon: cfg("lon", "")

    property bool panelOn: false
    property bool busy: false
    property string message: ""
    property int userIndex: (typeof userModel !== "undefined" && userModel.lastIndex >= 0) ? userModel.lastIndex : 0
    property int sessionIndex: (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0) ? sessionModel.lastIndex : 0
    property var now: new Date()

    readonly property var dows: ["воскресенье","понедельник","вторник","среда","четверг","пятница","суббота"]
    readonly property var mons: ["января","февраля","марта","апреля","мая","июня","июля","августа","сентября","октября","ноября","декабря"]
    readonly property string timeText: Qt.formatTime(now, "HH:mm")
    readonly property string dateText: dows[now.getDay()] + ", " + now.getDate() + " " + mons[now.getMonth()]

    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

    function wake() { panelOn = true; idle.restart(); pwd.forceActiveFocus() }
    function sleepPanel() { panelOn = false; pwd.text = ""; message = ""; root.forceActiveFocus() }
    Timer { id: idle; interval: 45000; onTriggered: if (!root.busy) root.sleepPanel() }

    // Роли UserModel в SDDM: Name=257, RealName=258, HomeDir=259, Icon=260
    function userField(i, role) {
        if (typeof userModel === "undefined" || userModel.count === 0) return ""
        var k = Math.max(0, Math.min(i, userModel.count - 1))
        return userModel.data(userModel.index(k, 0), role) || ""
    }
    readonly property string userName: userField(userIndex, 257)
    readonly property string userReal: userField(userIndex, 258)
    readonly property string userIcon: userField(userIndex, 260)

    function sessionName() {
        if (typeof sessionModel === "undefined" || sessionModel.count === 0) return "—"
        var k = Math.max(0, Math.min(sessionIndex, sessionModel.count - 1))
        return sessionModel.data(sessionModel.index(k, 0), 260) || "—"   // SessionModel: NameRole=260
    }

    function tryLogin() {
        if (busy || pwd.text === "" || userName === "") return
        busy = true; message = ""
        sddm.login(userName, pwd.text, sessionIndex)
    }
    Connections {
        target: sddm
        function onLoginFailed() { root.busy = false; root.message = "Неверный пароль"; pwd.text = ""; shake.restart(); pwd.forceActiveFocus() }
        function onLoginSucceeded() { root.busy = false }
    }

    // ---------- погода (реальные данные Open-Meteo; при ошибке карточка скрывается) ----------
    property bool weatherOk: false
    property real wTemp: 0
    property real wFeels: 0
    property int wCode: 0
    property int wIsDay: 1
    property var wHours: []
    function wmoText(c) {
        if (c === 0) return "Ясно"
        if (c === 1) return "Малооблачно"
        if (c === 2) return "Переменная облачность"
        if (c === 3) return "Пасмурно"
        if (c === 45 || c === 48) return "Туман"
        if (c >= 51 && c <= 57) return "Морось"
        if ((c >= 61 && c <= 67) || (c >= 80 && c <= 82)) return "Дождь"
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return "Снег"
        if (c >= 95) return "Гроза"
        return "—"
    }
    function wmoIcon(c, day) {
        if (c === 0 || c === 1) return day ? "☀" : "☾"
        if (c === 2) return "⛅"
        if (c === 3) return "☁"
        if (c === 45 || c === 48) return "≋"
        if ((c >= 51 && c <= 67) || (c >= 80 && c <= 82)) return "☂"
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return "❄"
        if (c >= 95) return "⚡"
        return "·"
    }
    function loadWeather() {
        if (lat === "" || lon === "") return
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status !== 200) { return }
            try {
                var d = JSON.parse(xhr.responseText)
                root.wTemp = d.current.temperature_2m
                root.wFeels = d.current.apparent_temperature
                root.wCode = d.current.weather_code
                root.wIsDay = d.current.is_day
                var out = [], nowH = new Date().getHours()
                for (var i = 0; i < d.hourly.time.length && out.length < 4; i++) {
                    var h = parseInt(d.hourly.time[i].substring(11, 13))
                    var day = d.hourly.time[i].substring(0, 10)
                    var cur = d.current.time.substring(0, 10)
                    if ((day === cur && h > nowH && (h - nowH) % 3 === 0) || (day > cur && out.length < 4 && ((24 - nowH + h) % 3 === 0)))
                        out.push({ h: d.hourly.time[i].substring(11, 16), t: Math.round(d.hourly.temperature_2m[i]), c: d.hourly.weather_code[i] })
                }
                root.wHours = out
                root.weatherOk = true
            } catch (e) { root.weatherOk = false }
        }
        xhr.open("GET", "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon +
                 "&current=temperature_2m,apparent_temperature,weather_code,is_day&hourly=temperature_2m,weather_code&forecast_days=2&timezone=auto")
        xhr.send()
    }
    Timer { interval: 900000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.loadWeather() }

    // ---------- фон ----------
    Rectangle { anchors.fill: parent; color: root.cBase }
    Image { anchors.fill: parent; source: "bg.jpg"; fillMode: Image.PreserveAspectCrop }
    Image {
        anchors.fill: parent; source: "bg-blur.jpg"; fillMode: Image.PreserveAspectCrop
        opacity: root.panelOn ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(root.cBase.r, root.cBase.g, root.cBase.b, root.panelOn ? 0.22 : 0.08) }
            GradientStop { position: 1; color: Qt.rgba(root.cBase.r, root.cBase.g, root.cBase.b, root.panelOn ? 0.55 : 0.46) }
        }
    }

    // ---------- стадия 1: часы ----------
    Column {
        id: clock
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.33
        spacing: 8 * root.s
        opacity: root.panelOn ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 350 } }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.timeText; color: root.cText; font { family: root.fam; pixelSize: 168 * root.s; weight: Font.Medium } }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.dateText.toUpperCase(); color: root.cSub; font { family: root.fam; pixelSize: 24 * root.s; letterSpacing: 5 * root.s } }
        Text { anchors.horizontalCenter: parent.horizontalCenter; topPadding: 46 * root.s; text: "нажмите любую клавишу"; color: Qt.rgba(root.cText.r, root.cText.g, root.cText.b, 0.45); font { family: root.fam; pixelSize: 15 * root.s; letterSpacing: 2 * root.s } }
    }

    // ---------- стадия 2: панель ----------
    Item {
        id: panel
        anchors.centerIn: parent
        width: Math.min(1120 * root.s, root.width - 64)
        height: 470 * root.s
        opacity: root.panelOn ? 1 : 0
        scale: root.panelOn ? 1 : 0.96
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
        property real shakeX: 0
        transform: Translate { x: panel.shakeX }
        SequentialAnimation {
            id: shake
            NumberAnimation { target: panel; property: "shakeX"; to: -16; duration: 50 }
            NumberAnimation { target: panel; property: "shakeX"; to: 16; duration: 90 }
            NumberAnimation { target: panel; property: "shakeX"; to: -9; duration: 80 }
            NumberAnimation { target: panel; property: "shakeX"; to: 0; duration: 70 }
        }

        Rectangle {
            anchors.fill: parent; radius: 34 * root.s
            color: Qt.rgba(root.cBase.r, root.cBase.g, root.cBase.b, 0.60)
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.14)
        }

        Row {
            anchors { fill: parent; margins: 16 * root.s }
            spacing: 16 * root.s
            readonly property real inner: width - 32 * root.s

            // ===== левая колонка: время и погода =====
            Column {
                width: parent.inner * 0.29; height: parent.height
                spacing: 12 * root.s

                Rectangle {
                    width: parent.width; height: parent.height * 0.30; radius: 14 * root.s
                    color: Qt.rgba(1, 1, 1, 0.06); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)
                    Column {
                        anchors { left: parent.left; leftMargin: 18 * root.s; verticalCenter: parent.verticalCenter }
                        spacing: 2 * root.s
                        Text { text: root.timeText; color: root.cText; font { family: root.fam; pixelSize: 44 * root.s; weight: Font.Medium } }
                        Text { text: root.dateText; color: root.cSub; font { family: root.fam; pixelSize: 13 * root.s } }
                    }
                }
                Rectangle {
                    width: parent.width; height: parent.height - parent.height * 0.30 - 12 * root.s; radius: 14 * root.s
                    color: Qt.rgba(1, 1, 1, 0.06); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)
                    visible: root.weatherOk
                    Column {
                        anchors { fill: parent; margins: 18 * root.s }
                        spacing: 6 * root.s
                        Row {
                            spacing: 12 * root.s
                            Text { text: root.wmoIcon(root.wCode, root.wIsDay === 1); color: root.cAccent; font { family: root.fam; pixelSize: 40 * root.s } }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: Math.round(root.wTemp) + "°"; color: root.cText; font { family: root.fam; pixelSize: 40 * root.s; weight: Font.Medium } }
                        }
                        Text { text: root.wmoText(root.wCode); color: root.cText; font { family: root.fam; pixelSize: 14 * root.s } }
                        Text { text: "Ощущается как " + Math.round(root.wFeels) + "°"; color: root.cSub; font { family: root.fam; pixelSize: 12 * root.s } }
                        Item { width: 1; height: 6 * root.s }
                        Row {
                            spacing: 14 * root.s
                            Repeater {
                                model: root.wHours
                                delegate: Column {
                                    required property var modelData
                                    spacing: 3 * root.s
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.t + "°"; color: root.cText; font { family: root.fam; pixelSize: 13 * root.s } }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.wmoIcon(modelData.c, true); color: root.cAccent2; font { family: root.fam; pixelSize: 16 * root.s } }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.h; color: root.cSub; font { family: root.fam; pixelSize: 10 * root.s } }
                                }
                            }
                        }
                    }
                }
            }

            // ===== центр: аватар, имя, пароль =====
            Column {
                width: parent.inner * 0.42; height: parent.height
                spacing: 16 * root.s

                Item { width: 1; height: 6 * root.s }
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 140 * root.s; height: width
                    Rectangle {
                        anchors.fill: parent; radius: width / 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: root.cAccent }
                            GradientStop { position: 1; color: root.cAccent2 }
                        }
                    }
                    Rectangle { id: avMask; anchors { fill: parent; margins: 4 * root.s } radius: width / 2; visible: false; layer.enabled: true }
                    Image {
                        id: avImg
                        anchors { fill: parent; margins: 4 * root.s }
                        source: root.userIcon
                        fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize: Qt.size(300, 300)
                        visible: status === Image.Ready
                        layer.enabled: true
                        layer.effect: MultiEffect { maskEnabled: true; maskSource: avMask }
                    }
                    Rectangle {
                        anchors { fill: parent; margins: 4 * root.s } radius: width / 2
                        color: Qt.rgba(1, 1, 1, 0.10); visible: avImg.status !== Image.Ready
                        Text { anchors.centerIn: parent; text: (root.userReal || root.userName || "?").charAt(0).toUpperCase(); color: root.cText; font { family: root.fam; pixelSize: 56 * root.s } }
                    }
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: pillTxt.implicitWidth + 40 * root.s; height: 34 * root.s; radius: height / 2
                    color: Qt.rgba(1, 1, 1, 0.08)
                    Text {
                        id: pillTxt; anchors.centerIn: parent
                        text: (root.userReal !== "" ? root.userReal : root.userName) + "  ·  введите пароль"
                        color: root.cText; font { family: root.fam; pixelSize: 13 * root.s }
                    }
                }
                Rectangle {
                    id: field
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 20 * root.s; height: 56 * root.s; radius: height / 2
                    color: Qt.rgba(0, 0, 0, 0.32)
                    border.width: 2
                    border.color: root.message !== "" ? root.cDanger : (pwd.activeFocus ? root.cAccent : Qt.rgba(1, 1, 1, 0.16))
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                    TextInput {
                        id: pwd
                        anchors { left: parent.left; right: go.left; leftMargin: 24 * root.s; rightMargin: 10 * root.s; verticalCenter: parent.verticalCenter }
                        echoMode: TextInput.Password; passwordCharacter: "●"
                        color: root.cText; font { family: root.fam; pixelSize: 19 * root.s; letterSpacing: 4 * root.s }
                        clip: true; enabled: !root.busy
                        onTextChanged: { idle.restart(); if (text.length > 0) root.message = "" }
                        onAccepted: root.tryLogin()
                        Keys.onEscapePressed: root.sleepPanel()
                        Text {
                            visible: parent.text.length === 0; anchors.verticalCenter: parent.verticalCenter
                            text: "Пароль"; color: Qt.rgba(root.cText.r, root.cText.g, root.cText.b, 0.40)
                            font { family: root.fam; pixelSize: 16 * root.s }
                        }
                    }
                    Rectangle {
                        id: go
                        anchors { right: parent.right; rightMargin: 7 * root.s; verticalCenter: parent.verticalCenter }
                        width: 42 * root.s; height: width; radius: width / 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: root.cAccent }
                            GradientStop { position: 1; color: root.cAccent2 }
                        }
                        scale: gma.pressed ? 0.92 : (gma.containsMouse ? 1.08 : 1)
                        Behavior on scale { NumberAnimation { duration: 120 } }
                        Text { anchors.centerIn: parent; text: root.busy ? "…" : "→"; color: root.cBase; font { family: root.fam; pixelSize: 21 * root.s; bold: true } }
                        MouseArea { id: gma; anchors.fill: parent; hoverEnabled: true; onClicked: root.tryLogin() }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 16 * root.s
                    text: root.message !== "" ? root.message : ((typeof keyboard !== "undefined" && keyboard.capsLock) ? "включён Caps Lock" : "")
                    color: root.message !== "" ? root.cDanger : root.cAccent
                    font { family: root.fam; pixelSize: 13 * root.s }
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10 * root.s
                    visible: typeof keyboard !== "undefined" && keyboard.layouts && keyboard.layouts.length > 0
                    Rectangle {
                        height: 30 * root.s; width: kbTxt.implicitWidth + 30 * root.s; radius: height / 2
                        color: kma.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
                        Text {
                            id: kbTxt; anchors.centerIn: parent; color: root.cText; font { family: root.fam; pixelSize: 12 * root.s }
                            text: (typeof keyboard !== "undefined" && keyboard.layouts && keyboard.layouts.length > 0) ? (keyboard.layouts[keyboard.currentLayout].shortName || "").toUpperCase() : ""
                        }
                        MouseArea {
                            id: kma; anchors.fill: parent; hoverEnabled: true
                            onClicked: if (keyboard.layouts.length > 1) { keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length; idle.restart() }
                        }
                    }
                }
            }

            // ===== правая колонка: сессия и питание =====
            Column {
                width: parent.inner * 0.29; height: parent.height
                spacing: 10 * root.s

                Rectangle {
                    width: parent.width; height: 64 * root.s; radius: 14 * root.s
                    color: sma.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)
                    Column {
                        anchors { left: parent.left; leftMargin: 18 * root.s; verticalCenter: parent.verticalCenter }
                        spacing: 3 * root.s
                        Text { text: "СЕССИЯ"; color: root.cSub; font { family: root.fam; pixelSize: 10 * root.s; letterSpacing: 2 * root.s } }
                        Text { text: root.sessionName(); color: root.cText; font { family: root.fam; pixelSize: 14 * root.s }
                               width: parent.parent.width - 36 * root.s; elide: Text.ElideRight }
                    }
                    MouseArea {
                        id: sma; anchors.fill: parent; hoverEnabled: true
                        onClicked: if (typeof sessionModel !== "undefined" && sessionModel.count > 1) { root.sessionIndex = (root.sessionIndex + 1) % sessionModel.count; idle.restart() }
                    }
                }
                Repeater {
                    model: [
                        { label: "Сон", sub: "приостановить", act: "suspend", svg: "<path d='M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z'/>" },
                        { label: "Перезагрузка", sub: "перезапустить", act: "reboot", svg: "<polyline points='23 4 23 10 17 10'/><path d='M20.49 15a9 9 0 1 1-2.12-9.36L23 10'/>" },
                        { label: "Выключение", sub: "завершить работу", act: "poweroff", svg: "<path d='M18.36 6.64a9 9 0 1 1-12.73 0'/><line x1='12' y1='2' x2='12' y2='12'/>" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width; height: 74 * root.s; radius: 14 * root.s
                        color: pma.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
                        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Rectangle {
                            id: ico; anchors { left: parent.left; leftMargin: 14 * root.s; verticalCenter: parent.verticalCenter }
                            width: 44 * root.s; height: width; radius: width / 2; color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.20)
                            Image {
                                anchors.centerIn: parent; width: 20 * root.s; height: width; sourceSize: Qt.size(64, 64)
                                source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='white' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'>" + modelData.svg + "</svg>"
                            }
                        }
                        Column {
                            anchors { left: ico.right; leftMargin: 12 * root.s; verticalCenter: parent.verticalCenter }
                            spacing: 2 * root.s
                            Text { text: modelData.label; color: root.cText; font { family: root.fam; pixelSize: 14 * root.s; weight: Font.Medium } }
                            Text { text: modelData.sub; color: root.cSub; font { family: root.fam; pixelSize: 10 * root.s } }
                        }
                        MouseArea {
                            id: pma; anchors.fill: parent; hoverEnabled: true
                            onClicked: { if (modelData.act === "suspend") sddm.suspend(); else if (modelData.act === "reboot") sddm.reboot(); else sddm.powerOff() }
                        }
                    }
                }
            }
        }
    }

    // ---------- переключение пользователей (если их больше одного) ----------
    Row {
        id: usersRow
        visible: root.panelOn && typeof userModel !== "undefined" && userModel.count > 1
        anchors { horizontalCenter: parent.horizontalCenter; top: panel.bottom; topMargin: 24 * root.s }
        spacing: 16 * root.s
        Repeater {
            model: typeof userModel !== "undefined" ? userModel : null
            delegate: Item {
                required property int index
                required property string name
                required property string icon
                width: 60 * root.s; height: width
                Rectangle {
                    anchors.fill: parent; radius: width / 2; color: Qt.rgba(1, 1, 1, 0.10)
                    border.width: root.userIndex === index ? 3 : 1
                    border.color: root.userIndex === index ? root.cAccent : Qt.rgba(1, 1, 1, 0.2)
                }
                Rectangle { id: m2; anchors { fill: parent; margins: 4 } radius: width / 2; visible: false; layer.enabled: true }
                Image {
                    anchors { fill: parent; margins: 4 } source: icon; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(128, 128)
                    visible: status === Image.Ready
                    layer.enabled: true; layer.effect: MultiEffect { maskEnabled: true; maskSource: m2 }
                }
                Text { anchors.centerIn: parent; visible: icon === ""; text: name.charAt(0).toUpperCase(); color: root.cText; font { family: root.fam; pixelSize: 22 * root.s } }
                MouseArea { anchors.fill: parent; onClicked: { root.userIndex = index; pwd.text = ""; root.message = ""; pwd.forceActiveFocus(); idle.restart() } }
            }
        }
    }

    // ---------- ввод ----------
    focus: true
    Keys.onPressed: (e) => {
        if (!root.panelOn) { root.wake(); e.accepted = true }   // первая клавиша только открывает панель
    }
    MouseArea {
        anchors.fill: parent; z: -1; hoverEnabled: true
        onClicked: root.wake()
        onPositionChanged: if (root.panelOn) idle.restart()
    }
    Component.onCompleted: root.forceActiveFocus()
}
