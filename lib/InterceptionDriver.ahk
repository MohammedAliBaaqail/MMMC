#Requires AutoHotkey v2.0
#Include "AutoHotInterception.ahk"

/**
 * InterceptionDriver — Genuine Windows Kernel-Mode Mouse & Keyboard Injection Bridge
 * Interfaces directly with the Interception kernel filter drivers (mouclass.sys & kbdclass.sys)
 * via the AutoHotInterception .NET CLR bridge.
 *
 * Injects genuine hardware mouse & keyboard packets with zero synthetic user-mode flags
 * (LLMHF_INJECTED = 0 and LLKHF_INJECTED = 0).
 */
class InterceptionDriver {
    static Enabled := false
    static IsInstalled := false
    static IsAvailable := false
    static AHI := 0
    static MouseId := 11
    static MouseDevices := []
    static KeyboardId := 1
    static KeyboardDevices := []

    static Init(iniPath := "") {
        if (iniPath != "") {
            this.Enabled := (IniRead(iniPath, "General", "UseInterceptionDriver", "0") = "1")
        }

        try {
            if (!this.AHI) {
                this.AHI := AutoHotInterception()
            }
            if (this.AHI) {
                check := this.AHI.GetInstance().OkCheck()
                if (check = "OK") {
                    this.IsInstalled := true
                    this.IsAvailable := true

                    ; Auto-detect attached hardware mouse and keyboard devices
                    this.DetectDevices()
                    return true
                }
            }
        } catch as err {
            this.AHI := 0
            this.IsInstalled := false
            this.IsAvailable := false
            this.MouseDevices := []
            this.KeyboardDevices := []
            return false
        }
        return false
    }

    static DetectDevices() {
        this.MouseDevices := []
        this.KeyboardDevices := []
        this.MouseId := 11
        this.KeyboardId := 1
        if (!this.AHI)
            return

        try {
            devList := this.AHI.GetDeviceList()
            primaryMouse := 0
            primaryKb := 0
            for id, dev in devList {
                if (dev.IsMouse) {
                    this.MouseDevices.Push(dev.ID)
                    ; Prioritize Logitech hardware (VID 0x046D = 1133), picking first primary endpoint
                    if ((dev.VID = 0x046D || dev.VID = 1133) && primaryMouse = 0) {
                        primaryMouse := dev.ID
                    } else if (primaryMouse = 0) {
                        primaryMouse := dev.ID
                    }
                } else {
                    this.KeyboardDevices.Push(dev.ID)
                    ; Prioritize Logitech hardware (VID 0x046D = 1133), picking first primary endpoint
                    if ((dev.VID = 0x046D || dev.VID = 1133) && primaryKb = 0) {
                        primaryKb := dev.ID
                    } else if (primaryKb = 0) {
                        primaryKb := dev.ID
                    }
                }
            }
            if (primaryMouse != 0)
                this.MouseId := primaryMouse
            else if (this.MouseDevices.Length > 0)
                this.MouseId := this.MouseDevices[1]
            else
                this.MouseId := 11

            if (primaryKb != 0)
                this.KeyboardId := primaryKb
            else if (this.KeyboardDevices.Length > 0)
                this.KeyboardId := this.KeyboardDevices[1]
            else
                this.KeyboardId := 1
        } catch {
            this.MouseId := 11
            this.KeyboardId := 1
        }
    }

    static SetEnabled(enable, iniPath := "") {
        this.Enabled := enable ? true : false
        if (this.Enabled && !this.IsAvailable) {
            this.Init()
        }
        if (iniPath != "") {
            try IniWrite(this.Enabled ? "1" : "0", iniPath, "General", "UseInterceptionDriver")
        }
    }

    ; =========================================================
    ; MOUSE INJECTION
    ; =========================================================

    static IsMouseButton(keyName) {
        k := StrLower(RegExReplace(keyName, "[\{\}]", ""))
        return (k = "lbutton" || k = "rbutton" || k = "mbutton" || k = "xbutton1" || k = "xbutton2")
    }

    static GetButtonIndex(btnName) {
        switch StrLower(RegExReplace(btnName, "[\{\}]", "")) {
            case "lbutton", "leftclick", "left", "1":
                return 0
            case "rbutton", "rightclick", "right", "2":
                return 1
            case "mbutton", "middleclick", "middle", "3":
                return 2
            case "xbutton1", "back", "mouse4", "4":
                return 3
            case "xbutton2", "forward", "mouse5", "5":
                return 4
            case "wheel", "wheelup", "wheeldown":
                return 5
            default:
                return -1
        }
    }

    static SendMouseButtonEvent(btnIndex, state) {
        if (!this.Enabled || !this.IsAvailable || !this.AHI)
            return false

        targetId := (this.MouseId != 0) ? this.MouseId : ((this.MouseDevices.Length > 0) ? this.MouseDevices[1] : 11)
        try {
            this.AHI.SendMouseButtonEvent(targetId, btnIndex, state)
            return true
        } catch {
            ; Fallback: try other detected mouse devices one by one until one succeeds
            for devId in this.MouseDevices {
                if (devId != targetId) {
                    try {
                        this.AHI.SendMouseButtonEvent(devId, btnIndex, state)
                        this.MouseId := devId
                        return true
                    }
                }
            }
            return false
        }
    }

    static SendMouseDown(btnName) {
        btnIndex := this.GetButtonIndex(btnName)
        if (btnIndex < 0)
            return false
        return this.SendMouseButtonEvent(btnIndex, 1)
    }

    static SendMouseUp(btnName) {
        btnIndex := this.GetButtonIndex(btnName)
        if (btnIndex < 0)
            return false
        return this.SendMouseButtonEvent(btnIndex, 0)
    }

    static SendMouseClick(btnName, holdDelayMs := 25) {
        btnIndex := this.GetButtonIndex(btnName)
        if (btnIndex < 0)
            return false

        resDown := this.SendMouseButtonEvent(btnIndex, 1)
        if (holdDelayMs > 0)
            Sleep(holdDelayMs)
        resUp := this.SendMouseButtonEvent(btnIndex, 0)
        return resDown && resUp
    }

    static SendWheel(wheelDelta) {
        if (!this.Enabled || !this.IsAvailable || !this.AHI)
            return false

        ; AutoHotInterception multiplies state by 120 (1 = +120, -1 = -120)
        state := wheelDelta > 0 ? 1 : -1
        return this.SendMouseButtonEvent(5, state)
    }

    static SendMouseMove(x, y) {
        if (!this.Enabled || !this.IsAvailable || !this.AHI)
            return false

        try {
            this.AHI.SendMouseMove(this.MouseId, x, y)
            return true
        } catch {
            return false
        }
    }

    ; =========================================================
    ; KEYBOARD INJECTION (kbdclass.sys)
    ; =========================================================

    static ParseKeyToSc(keyName) {
        k := RegExReplace(keyName, "[\{\}]", "")
        return GetKeySC(k)
    }

    static SendKeyboardEvent(sc, state) {
        if (!this.Enabled || !this.IsAvailable || !this.AHI)
            return false

        targetId := (this.KeyboardId != 0) ? this.KeyboardId : ((this.KeyboardDevices.Length > 0) ? this.KeyboardDevices[1] : 1)
        try {
            this.AHI.SendKeyEvent(targetId, sc, state)
            return true
        } catch {
            for devId in this.KeyboardDevices {
                if (devId != targetId) {
                    try {
                        this.AHI.SendKeyEvent(devId, sc, state)
                        this.KeyboardId := devId
                        return true
                    }
                }
            }
            return false
        }
    }

    static SendKeyDown(keyName) {
        sc := this.ParseKeyToSc(keyName)
        if (sc == 0)
            return false
        ; AutoHotInterception expects state: 1 = Down, 0 = Up
        return this.SendKeyboardEvent(sc, 1)
    }

    static SendKeyUp(keyName) {
        sc := this.ParseKeyToSc(keyName)
        if (sc == 0)
            return false
        ; AutoHotInterception expects state: 1 = Down, 0 = Up
        return this.SendKeyboardEvent(sc, 0)
    }

    static SendKeyClick(keyName, holdDelayMs := 25) {
        sc := this.ParseKeyToSc(keyName)
        if (sc == 0)
            return false

        resDown := this.SendKeyboardEvent(sc, 1)
        if (holdDelayMs > 0)
            Sleep(holdDelayMs)
        resUp := this.SendKeyboardEvent(sc, 0)
        return resDown && resUp
    }

    ; =========================================================
    ; UNIFIED DISPATCH & CHORD / SEQUENCE EXECUTION
    ; =========================================================

    static SendKeyOrButtonDown(keyName) {
        if (this.IsMouseButton(keyName))
            return this.SendMouseDown(keyName)
        return this.SendKeyDown(keyName)
    }

    static SendKeyOrButtonUp(keyName) {
        if (this.IsMouseButton(keyName))
            return this.SendMouseUp(keyName)
        return this.SendKeyUp(keyName)
    }

    static SendKeyOrButtonClick(keyName, holdDelayMs := 25) {
        if (this.IsMouseButton(keyName))
            return this.SendMouseClick(keyName, holdDelayMs)
        return this.SendKeyClick(keyName, holdDelayMs)
    }

    static ParseChordDown(chordCmd) {
        keys := []
        rem := chordCmd

        ; 1. Extract leading modifiers (e.g. ^, !, +, #, with optional {Blind})
        if (RegExMatch(rem, "i)^(?:\{Blind\})?([!^#+]+)", &mMod)) {
            mods := mMod[1]
            if (InStr(mods, "^"))
                keys.Push("Ctrl")
            if (InStr(mods, "!"))
                keys.Push("Alt")
            if (InStr(mods, "+"))
                keys.Push("Shift")
            if (InStr(mods, "#"))
                keys.Push("LWin")
            rem := SubStr(rem, mMod.Pos + mMod.Len)
        }

        ; 2. If explicit {key down} tokens exist
        if (InStr(rem, " down}")) {
            pos := 1
            while (RegExMatch(rem, "i)\{([A-Za-z0-9_]+)\s+down\}", &mKey, pos)) {
                keys.Push(mKey[1])
                pos := mKey.Pos + mKey.Len
            }
            ; Also catch any unflagged mouse buttons in the chord
            if (RegExMatch(rem, "i)\{(LButton|RButton|MButton|XButton1|XButton2)\}(?!\s*up)", &mMb)) {
                keys.Push(mMb[1])
            }
        } else {
            ; 3. Single key or {Key} remaining
            cleanKey := RegExReplace(rem, "[\{\}\s]", "")
            if (cleanKey != "") {
                keys.Push(cleanKey)
            }
        }
        return keys
    }

    static ParseChordUp(releaseCmd) {
        keys := []
        pos := 1
        while (RegExMatch(releaseCmd, "i)\{([A-Za-z0-9_]+)\s+up\}", &mKey, pos)) {
            keys.Push(mKey[1])
            pos := mKey.Pos + mKey.Len
        }
        if (keys.Length = 0) {
            cleanKey := RegExReplace(releaseCmd, "[\{\}\s]", "")
            if (cleanKey != "") {
                keys.Push(cleanKey)
            }
        }
        return keys
    }

    static SendChordDown(chordCmd) {
        if (!this.Enabled || !this.IsAvailable || !this.AHI)
            return false
        keys := this.ParseChordDown(chordCmd)
        if (keys.Length = 0)
            return false

        allOk := true
        for k in keys {
            if (!this.SendKeyOrButtonDown(k))
                allOk := false
        }
        return allOk
    }

    static SendChordUp(releaseCmd) {
        if (!this.Enabled || !this.IsAvailable || !this.AHI)
            return false
        keys := this.ParseChordUp(releaseCmd)
        if (keys.Length = 0)
            return false

        allOk := true
        for k in keys {
            if (!this.SendKeyOrButtonUp(k))
                allOk := false
        }
        return allOk
    }

    static SendSequence(cmd, holdDelayMs := 25) {
        if (!this.Enabled || !this.IsAvailable || !this.AHI || cmd == "")
            return false

        ; 1. Double click / Triple click
        if (cmd = "{DoubleClick}" || cmd = "{LButton 2}") {
            this.SendMouseClick("LButton", 15)
            Sleep(50)
            return this.SendMouseClick("LButton", 15)
        }
        if (cmd = "{TripleClick}" || cmd = "{LButton 3}") {
            this.SendMouseClick("LButton", 15)
            Sleep(50)
            this.SendMouseClick("LButton", 15)
            Sleep(50)
            return this.SendMouseClick("LButton", 15)
        }

        ; 2. Mouse Wheel
        if (cmd = "{WheelUp}")
            return this.SendWheel(120)
        if (cmd = "{WheelDown}")
            return this.SendWheel(-120)

        ; 3. Explicit down/up sequence (e.g. "{a down}{s down}{d down}{d up}{s up}{a up}")
        if (InStr(cmd, " down}") && InStr(cmd, " up}")) {
            modPrefix := ""
            if (RegExMatch(cmd, "i)^(?:\{Blind\})?([!^#+]+)", &mMod))
                modPrefix := mMod[1]

            if (modPrefix != "") {
                if (InStr(modPrefix, "^"))
                    this.SendKeyDown("Ctrl")
                if (InStr(modPrefix, "!"))
                    this.SendKeyDown("Alt")
                if (InStr(modPrefix, "+"))
                    this.SendKeyDown("Shift")
                if (InStr(modPrefix, "#"))
                    this.SendKeyDown("LWin")
            }

            pos := 1
            lastAction := ""
            while (RegExMatch(cmd, "i)\{([A-Za-z0-9_]+)\s+(down|up)\}", &m, pos)) {
                k := m[1]
                action := StrLower(m[2])
                if (lastAction = "down" && action = "up" && holdDelayMs > 0) {
                    Sleep(holdDelayMs)
                }
                if (action = "down") {
                    this.SendKeyOrButtonDown(k)
                } else if (action = "up") {
                    this.SendKeyOrButtonUp(k)
                }
                lastAction := action
                pos := m.Pos + m.Len
            }

            if (modPrefix != "") {
                if (InStr(modPrefix, "#"))
                    this.SendKeyUp("LWin")
                if (InStr(modPrefix, "+"))
                    this.SendKeyUp("Shift")
                if (InStr(modPrefix, "!"))
                    this.SendKeyUp("Alt")
                if (InStr(modPrefix, "^"))
                    this.SendKeyUp("Ctrl")
            }
            return true
        }

        ; 4. Single Mouse Button with optional Down/Up state
        if (RegExMatch(cmd, "i)^\{?(LButton|RButton|MButton|XButton1|XButton2)(?:\s+(Down|Up))?\}?$", &m)) {
            btn := m[1]
            subState := m[2]
            if (subState = "Down")
                return this.SendMouseDown(btn)
            else if (subState = "Up")
                return this.SendMouseUp(btn)
            else
                return this.SendMouseClick(btn, holdDelayMs)
        }

        ; 5. Single Keyboard Key with optional Down/Up state
        if (RegExMatch(cmd, "i)^\{?([A-Za-z0-9_]+)(?:\s+(Down|Up))?\}?$", &m)) {
            k := m[1]
            subState := m[2]
            if (subState = "Down")
                return this.SendKeyDown(k)
            else if (subState = "Up")
                return this.SendKeyUp(k)
            else
                return this.SendKeyClick(k, holdDelayMs)
        }

        ; 6. Modifier combination (e.g. "^c", "!{Tab}", "^+{Delete}", "#{d}")
        if (RegExMatch(cmd, "i)^(?:\{Blind\})?([!^#+]+)(.*)$", &mCombo)) {
            keys := this.ParseChordDown(cmd)
            if (keys.Length > 0) {
                for k in keys {
                    this.SendKeyOrButtonDown(k)
                }
                if (holdDelayMs > 0)
                    Sleep(holdDelayMs)
                idx := keys.Length
                while (idx >= 1) {
                    this.SendKeyOrButtonUp(keys[idx])
                    idx--
                }
                return true
            }
        }

        return false
    }

    static Cleanup() {
        this.AHI := 0
        this.IsAvailable := false
    }
}
