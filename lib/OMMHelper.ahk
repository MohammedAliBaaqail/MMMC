#Requires AutoHotkey v2.0

/**
 * Logitech Onboard Memory Manager (OMM) Key Injector Assistant
 * Physical keyboards lack F13-F24 keys. This tool allows users to select
 * a key, gives a 3-second countdown to switch to OMM's keystroke recorder,
 * and automatically fires the virtual F-key.
 */
class OMMHelper {
    static countdownTimer := ""
    static secondsLeft := 0
    static targetKey := ""
    static statusControl := ""
    static isInjecting := false

    static tickFn := () => OMMHelper.Tick()

    static StartCountdown(keyName, statusCtrl := "") {
        if (this.isInjecting)
            return

        this.targetKey := keyName
        this.statusControl := statusCtrl
        this.secondsLeft := 3
        this.isInjecting := true

        this.UpdateStatus("Focus OMM record field! Injecting " . keyName . " in " . this.secondsLeft . "s...")
        try WebViewGuiManager.PostMessage(Map("type", "ommInjectTick", "secondsLeft", 3, "key", keyName))
        SoundBeep(700, 100)
        SetTimer(this.tickFn, 1000)
    }

    static Tick() {
        OMMHelper.secondsLeft--
        if (OMMHelper.secondsLeft > 0) {
            OMMHelper.UpdateStatus("Switching to OMM! Injecting " . OMMHelper.targetKey . " in " . OMMHelper.secondsLeft . "s...")
            try WebViewGuiManager.PostMessage(Map("type", "ommInjectTick", "secondsLeft", OMMHelper.secondsLeft, "key", OMMHelper.targetKey))
            SoundBeep(700 + (3 - OMMHelper.secondsLeft) * 150, 100)
        } else {
            SetTimer(OMMHelper.tickFn, 0)
            OMMHelper.PerformInjection()
        }
    }

    static PerformInjection() {
        Key := OMMHelper.targetKey
        OMMHelper.UpdateStatus(">>> SENT {" . Key . "} TO ACTIVE WINDOW! <<<")
        
        ; Send the actual virtual key
        Send("{" . Key . "}")
        
        ; Sound beep feedback
        SoundBeep(1200, 250)
        
        try WebViewGuiManager.PostMessage(Map("type", "ommInjectDone", "key", Key))

        ; Reset after 2 seconds
        SetTimer(() => OMMHelper.Reset(), -2500)
    }

    static Reset() {
        OMMHelper.isInjecting := false
        OMMHelper.UpdateStatus("Ready. Click any key below to inject.")
        try WebViewGuiManager.PostMessage(Map("type", "ommInjectReset"))
    }

    static UpdateStatus(msg) {
        if (this.statusControl != "") {
            try this.statusControl.Value := msg
        }
    }
}
