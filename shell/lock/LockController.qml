import QtQuick
import Quickshell
import Quickshell.Services.Pam

// Проверка пароля через PAM (конфиг /etc/pam.d/hyprlock, он включает стандартный login).
Scope {
    id: root
    signal unlocked()

    property bool busy: false
    property bool failed: false
    property string message: ""
    property string pending: ""

    function submit(pw) {
        if (busy || pw === "") return
        pending = pw
        failed = false
        message = ""
        busy = true
        pam.start()
    }

    PamContext {
        id: pam
        config: "hyprlock"

        onPamMessage: {
            if (responseRequired) respond(root.pending)
        }
        onCompleted: result => {
            root.busy = false
            root.pending = ""
            if (result === PamResult.Success) {
                root.unlocked()
            } else {
                root.failed = true
                root.message = "Неверный пароль"
            }
        }
        onError: {
            root.busy = false
            root.pending = ""
            root.failed = true
            root.message = "Ошибка проверки пароля"
        }
    }
}
