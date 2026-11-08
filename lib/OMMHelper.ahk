#Requires AutoHotkey v2.0
#Warn All, Off

/**
 * Onboard Memory Key Injector Assistant
 * Physical keyboards lack F13-F24 keys. This tool allows users to select
 * a virtual key, gives a 3-second countdown to switch to the mouse's onboard memory tool,
 * and automatically fires the virtual F-key with reliable hold duration.
 */
class OMMHelper {
    static countdownTimer := ""
    static secondsLeft := 0
    static targetKey := ""
    static statusControl := ""
    static isInjecting := false

    static tickFn := ""

    /**
     * Normalize key string into a recognized virtual F-Key (F13-F24)
     * Maps mouse actions (Middle, Back, Forward) into designated virtual F-keys.
     */
    static NormalizeKey(k) {
        k := Trim(k)
        upper := StrUpper(k)
        if RegExMatch(upper, "^F(1[3-9]|2[0-4])$") ; F13-F24
            return upper

        static keyMap := Map(
            "MIDDLE", "F13",
            "MBUTTON", "F13",
            "BACK", "F22",
            "XBUTTON1", "F22",
            "FORWARD", "F16",
            "XBUTTON2", "F16",
            "TILTLEFT", "F17",
            "WHEELLEFT", "F17",
            "TILTRIGHT", "F18",
            "WHEELRIGHT", "F18",
            "DPISHIFT", "F15",
            "G7", "F21",
            "G8", "F20",
            "PROFILECYCLE", "F19",
            "LEFTCLICK", "F13",
            "RIGHTCLICK", "F14"
        )
        if keyMap.Has(upper)
            return keyMap[upper]
        return upper != "" ? upper : "F13"
    }

    static FindOMMWindow() {
        SetTitleMatchMode(2)
        hw := WinExist("Onboard Memory Manager")
        if (hw)
            return hw
        hw := WinExist("ahk_exe OnboardMemoryManager.exe")
        if (hw)
            return hw
        hw := WinExist("ahk_exe OnboardMemoryManager_2.7.4428.exe")
        if (hw)
            return hw
        hw := WinExist("ahk_exe OnboardMemoryManager_2.1.7479.exe")
        if (hw)
            return hw
        hw := WinExist("ahk_exe OMM.exe")
        if (hw)
            return hw
        return 0
    }

    static EnsureOMMActive() {
        hw := this.FindOMMWindow()
        if (hw) {
            try {
                if (WinGetMinMax(hw) = -1)
                    WinRestore(hw)
                WinActivate(hw)
            }
            return true
        }

        ; Try launching from known user path if not already running
        candidatePaths := [
            "C:\Users\" . A_UserName . "\Downloads\OnboardMemoryManager_2.7.4428.exe",
            "C:\Users\" . A_UserName . "\Downloads\OnboardMemoryManager_2.1.7479.exe",
            A_ScriptDir . "\tools\OMM.exe",
            A_ScriptDir . "\OMM.exe"
        ]
        for p in candidatePaths {
            if FileExist(p) {
                try {
                    Run(p)
                    Sleep(800)
                    hw := this.FindOMMWindow()
                    if (hw)
                        WinActivate(hw)
                    return true
                }
            }
        }
        return false
    }

    static StartCountdown(keyName, statusCtrl := "") {
        if (this.isInjecting)
            return

        this.targetKey := this.NormalizeKey(keyName)
        this.statusControl := statusCtrl
        this.secondsLeft := 4
        this.isInjecting := true

        ; Automatically bring OMM to the front so the user can see and click it
        this.EnsureOMMActive()

        this.UpdateStatus("Focus OMM record field! Injecting " . this.targetKey . " in " . this.secondsLeft . "s...")
        try WebViewGuiManager.PostMessage(Map("type", "ommInjectTick", "secondsLeft", this.secondsLeft, "key", this.targetKey))
        SoundBeep(700, 100)
        if (!this.tickFn)
            this.tickFn := ObjBindMethod(OMMHelper, "Tick")
        SetTimer(this.tickFn, 1000)
    }

    static Tick() {
        OMMHelper.secondsLeft--
        if (OMMHelper.secondsLeft > 0) {
            OMMHelper.UpdateStatus("Switching to OMM! Injecting " . OMMHelper.targetKey . " in " . OMMHelper.secondsLeft . "s...")
            try WebViewGuiManager.PostMessage(Map("type", "ommInjectTick", "secondsLeft", OMMHelper.secondsLeft, "key", OMMHelper.targetKey))
            SoundBeep(700 + (4 - OMMHelper.secondsLeft) * 150, 100)
        } else {
            SetTimer(OMMHelper.tickFn, 0)
            OMMHelper.PerformInjection()
        }
    }

    static PerformInjection() {
        Key := OMMHelper.targetKey
        OMMHelper.UpdateStatus(">>> SENT {" . Key . "} TO ACTIVE WINDOW! <<<")
        
        ; If OMM window is open, ensure it has focus before sending
        hw := OMMHelper.FindOMMWindow()
        if (hw) {
            try WinActivate(hw)
            Sleep(50)
        }

        ; Send virtual key with deliberate down/up duration so low-level hook recorders capture it reliably
        SetKeyDelay(35, 55)
        SendEvent("{" . Key . " down}")
        Sleep(55)
        SendEvent("{" . Key . " up}")
        
        ; Sound beep feedback
        SoundBeep(1400, 250)
        
        try WebViewGuiManager.PostMessage(Map("type", "ommInjectDone", "key", Key))

        ; Reset after 2.5 seconds
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
