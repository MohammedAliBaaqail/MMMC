#Requires AutoHotkey v2.0

/**
 * QuickRemap — Live System-Wide Keystroke / Combination Recording for Mouse Buttons
 * 
 * Allows remapping any mouse button on the fly from anywhere in Windows via a global hotkey combo.
 * 
 * Steps & Audio:
 * - Step 1: Global Trigger (Ctrl+Shift+F1)
 *   -> Audio 1: Ascending alert chime (750Hz -> 1100Hz)
 *   -> OSD: "Quick Remap Active" — Step 1: Click mouse button to remap
 * - Step 2: Mouse Button Pressed
 *   -> Audio 2: Mid confirmation chime (950Hz)
 *   -> OSD: "Target: [Button Name]" — Step 2: Press key or combination
 * - Step 3: Key / Combination Pressed & Released
 *   -> Audio 3: High victory double-chime (1200Hz -> 1500Hz)
 *   -> OSD: "Remapped: [Button Name]" -> "[Combination]"
 *   -> Mapping saved to active profile in settings.ini & UI updated
 * - Cancel: Escape pressed or 10s inactivity
 *   -> Audio 4: Descending cancel tone (600Hz -> 450Hz)
 *   -> OSD: "Quick Remap Cancelled"
 */
class QuickRemap {
    static State := "IDLE" ; "IDLE", "WAIT_BUTTON", "WAIT_KEY"
    static TargetButton := ""
    static TargetDisplayName := ""
    static TargetLayer := "Normal"
    static HoldingShiftButton := ""
    static PhysicalButtonStates := Map()
    static TimeoutFn := () => QuickRemap.OnTimeout()
    static FinalizeComboFn := () => QuickRemap.FinalizeRecordedCombo()
    static InputHookObj := ""

    ; Tracking keys pressed in Step 3
    static KeysDown := Map()
    static Modifiers := Map()
    static ComboKeys := []
    static CapturedResult := ""

    ; State query accessors for #HotIf
    static IsActive => (QuickRemap.State != "IDLE")
    static IsWaitingForButton() => (QuickRemap.State == "WAIT_BUTTON")
    static IsWaitingForKey() => (QuickRemap.State == "WAIT_KEY")

    ; =========================================================================
    ; DISTINCT STEP AUDIO FEEDBACK
    ; =========================================================================

    /**
     * Step 1 Audio: Rising alert chime when recording mode is armed.
     */
    static PlaySoundStep1() {
        try SoundBeep(750, 70)
        Sleep(30)
        try SoundBeep(1100, 90)
    }

    /**
     * Step 2 Audio: Solid mid-frequency confirmation when mouse button is captured.
     */
    static PlaySoundStep2() {
        try SoundBeep(950, 110)
    }

    /**
     * Step 3 Audio: High celebration double-chime when mapping is finalized & saved.
     */
    static PlaySoundStep3() {
        try SoundBeep(1200, 70)
        Sleep(30)
        try SoundBeep(1500, 110)
    }

    /**
     * Cancel Audio: Low falling tone when cancelled by Esc or inactivity timeout.
     */
    static PlaySoundCancel() {
        try SoundBeep(600, 80)
        Sleep(30)
        try SoundBeep(450, 100)
    }

    ; =========================================================================
    ; WORKFLOW LIFECYCLE
    ; =========================================================================

    /**
     * Starts the Quick Remap workflow.
     */
    static Start() {
        if (this.IsActive) {
            this.Cancel()
            return
        }

        ; Release any existing UI recorder hooks
        try WebViewGuiManager.StopRecording()
        try GuiManager.StopKeystrokeRecording(false)

        this.State := "WAIT_BUTTON"
        this.TargetButton := ""
        this.HoldingShiftButton := ""
        this.PhysicalButtonStates.Clear()
        curLayer := "Normal"
        try {
            if (ProfileEngine.CurrentLayer != "")
                curLayer := ProfileEngine.CurrentLayer
        }
        this.TargetLayer := curLayer

        ; Start 10s inactivity safety timeout
        SetTimer(this.TimeoutFn, 0)
        SetTimer(this.TimeoutFn, -10000)

        ; Audio 1: Activation Chime (App Synth Beeps)
        this.PlaySoundStep1()

        ; App HUD Notification
        OSD.Show("⚡ Quick Remap Active", "Step 1: Click the mouse button you want to remap (Esc to cancel)", 6000)
    }

    /**
     * Step 2: Called when any remappable mouse button is pressed or released.
     * B-Shift modifier buttons are NEVER remapped; instead holding them engages
     * the B-Shift layer so only their combined button gets remapped on that layer.
     */
    static OnMouseButtonEvent(rawBtnId, isDown := true) {
        if (this.State != "WAIT_BUTTON")
            return

        ; Resolve hardware F-key to actual logical button ID if needed
        btnId := rawBtnId
        if (ProfileEngine.FKeyToButtonMap.Has(rawBtnId)) {
            btnId := ProfileEngine.FKeyToButtonMap[rawBtnId]
        }

        ; Filter Windows OS typematic auto-repeat while button is physically held
        if (isDown) {
            if (this.PhysicalButtonStates.Has(btnId) && this.PhysicalButtonStates[btnId])
                return ; Ignore typematic repeat event while button is physically held
            this.PhysicalButtonStates[btnId] := true
        } else {
            if (this.PhysicalButtonStates.Has(btnId))
                this.PhysicalButtonStates.Delete(btnId)
        }

        ; -------------------------------------------------------------
        ; B-SHIFT MODIFIER KEY HANDLING
        ; The B-Shift button itself must NEVER be remapped!
        ; Holding it engages the B-Shift layer to remap the combined button.
        ; -------------------------------------------------------------
        isAnotherShiftHeld := (this.HoldingShiftButton != "" && this.HoldingShiftButton != btnId)
        if (!isAnotherShiftHeld && ProfileEngine.IsShiftModifierButton(btnId)) {
            shiftLayer := ProfileEngine.GetShiftModifierLayer(btnId)
            if (isDown) {
                if (this.HoldingShiftButton == btnId)
                    return ; Already holding this shift button, do not re-trigger sound or OSD
                this.HoldingShiftButton := btnId
                this.TargetLayer := shiftLayer
                if (shiftLayer = "GShift2")
                    ProfileEngine.HandleShift2Modifier(btnId, true)
                else
                    ProfileEngine.HandleShift1Modifier(btnId, true)

                ; Distinct feedback tone for B-Shift layer engagement
                try SoundBeep(1200, 60)
                OSD.Show("⚡ B-Shift Layer Active", "Step 1: Click the mouse button to remap on B-Shift layer (Esc to cancel)", 4000)
            } else {
                if (this.HoldingShiftButton == btnId)
                    this.HoldingShiftButton := ""
                if (shiftLayer = "GShift2")
                    ProfileEngine.HandleShift2Modifier(btnId, false)
                else
                    ProfileEngine.HandleShift1Modifier(btnId, false)

                if (this.State == "WAIT_BUTTON") {
                    this.TargetLayer := "Normal"
                    OSD.Show("⚡ Quick Remap Active", "Step 1: Click the mouse button you want to remap (Esc to cancel)", 4000)
                }
            }
            return
        }

        ; Button release for regular non-shift buttons during WAIT_BUTTON is ignored
        if (!isDown)
            return

        ; -------------------------------------------------------------
        ; REGULAR (COMBINED) BUTTON SELECTION
        ; -------------------------------------------------------------
        isShiftHeld := (this.TargetLayer = "GShift" || this.TargetLayer = "GShift2" || ProfileEngine.IsGShiftActive || ProfileEngine.IsGShift1Active || ProfileEngine.IsGShift2Active)
        targetLayer := isShiftHeld ? ((ProfileEngine.IsGShift2Active || this.TargetLayer = "GShift2") ? "GShift2" : "GShift") : "Normal"

        ; Guard: Left/Right click on Normal layer cannot be remapped without B-Shift
        if ((btnId = "LeftClick" || btnId = "RightClick") && targetLayer = "Normal") {
            try SoundBeep(650, 100)
            OSD.Show("B-Shift Required", "Hold B-Shift + Click to remap Left/Right click.", 3000)
            return
        }

        this.TargetButton := btnId
        this.TargetLayer := targetLayer
        baseName := this.GetButtonDisplayName(btnId)
        this.TargetDisplayName := (targetLayer != "Normal" ? ("B-Shift + ") : "") . baseName
        this.State := "WAIT_KEY"

        ; Audio 2: Button Captured Chime (App Synth Beeps)
        this.PlaySoundStep2()

        ; App HUD Notification
        OSD.Show("🎯 Target: " . this.TargetDisplayName, "Step 2: Press any key or combination to assign (Esc to cancel)", 6000)

        ; Transition to Step 3: Start InputHook
        this.StartKeyRecording()
    }

    static OnMouseButtonPressed(rawBtnId) {
        this.OnMouseButtonEvent(rawBtnId, true)
    }

    /**
     * Step 3: Starts InputHook to capture keystroke combinations system-wide.
     */
    static StartKeyRecording() {
        this.KeysDown.Clear()
        this.Modifiers.Clear()
        this.ComboKeys := []
        this.CapturedResult := ""

        ; Reset 10s timeout
        SetTimer(this.TimeoutFn, 0)
        SetTimer(this.TimeoutFn, -10000)

        ; Low-level keyboard hook with +S (Suppress) and +N (Notify)
        ; Prevents system hotkeys (Win+D, Win+E, etc.) from executing while capturing!
        ih := InputHook("I0")
        ih.KeyOpt("{All}", "+S +N")
        ih.VisibleNonText := false

        ih.OnKeyDown := (hook, vk, sc) => this.OnKeyDown(vk, sc)
        ih.OnKeyUp   := (hook, vk, sc) => this.OnKeyUp(vk, sc)

        this.InputHookObj := ih
        ih.Start()
    }

    static OnKeyDown(vk, sc) {
        if (this.State != "WAIT_KEY")
            return

        ; Reset timeout
        SetTimer(this.TimeoutFn, 0)
        SetTimer(this.TimeoutFn, -10000)

        ; Cancel finalize debounce if user is actively pressing more keys
        SetTimer(this.FinalizeComboFn, 0)

        kName := this.NormalizeKey(vk, sc)
        if (kName = "")
            return

        ; Ignore mouse hardware F-keys (F13 - F24) and mouse button mappings
        ; (e.g. B-Shift modifier button being held down physically)
        if (RegExMatch(kName, "^F(1[3-9]|2[0-4])$") || ProfileEngine.FKeyToButtonMap.Has(kName))
            return

        ; If Escape pressed alone with no other keys down, cancel!
        if (kName = "Escape" && this.KeysDown.Count = 0 && this.Modifiers.Count = 0 && this.ComboKeys.Length = 0) {
            this.Cancel()
            return
        }

        this.KeysDown[kName] := true

        if (kName = "Ctrl" || kName = "Alt" || kName = "Shift" || kName = "Win") {
            this.Modifiers[kName] := true
        } else {
            hasKey := false
            for existing in this.ComboKeys {
                if (existing = kName) {
                    hasKey := true
                    break
                }
            }
            if (!hasKey) {
                this.ComboKeys.Push(kName)
            }
        }

        ; Sync physical modifier state
        if (GetKeyState("Ctrl", "P") && !this.Modifiers.Has("Ctrl"))
            this.Modifiers["Ctrl"] := true
        if (GetKeyState("Alt", "P") && !this.Modifiers.Has("Alt"))
            this.Modifiers["Alt"] := true
        if (GetKeyState("Shift", "P") && !this.Modifiers.Has("Shift"))
            this.Modifiers["Shift"] := true
        if ((GetKeyState("LWin", "P") || GetKeyState("RWin", "P")) && !this.Modifiers.Has("Win"))
            this.Modifiers["Win"] := true

        this.CapturedResult := this.BuildSingleCombo(this.Modifiers, this.ComboKeys)

        if (this.CapturedResult.Label != "") {
            OSD.Show("Recording: " . this.CapturedResult.Label, "Release keys to apply to " . this.TargetDisplayName, 4000)
        }
    }

    static OnKeyUp(vk, sc) {
        if (this.State != "WAIT_KEY")
            return

        kName := this.NormalizeKey(vk, sc)
        if (kName = "")
            return

        ; Ignore mouse hardware F-keys (F13 - F24) and mouse button mappings
        if (RegExMatch(kName, "^F(1[3-9]|2[0-4])$") || ProfileEngine.FKeyToButtonMap.Has(kName))
            return

        if (this.KeysDown.Has(kName))
            this.KeysDown.Delete(kName)

        ; When all pressed keys are physically released, wait 200ms debounce
        ; If no further key is pressed within 200ms, finalize!
        if (this.KeysDown.Count = 0 && this.CapturedResult != "") {
            SetTimer(this.FinalizeComboFn, -200)
        }
    }

    /**
     * Handles mouse buttons pressed during combination recording (e.g. Ctrl + Left Click).
     */
    static OnMouseButtonInCombo(mouseBtn) {
        if (this.State != "WAIT_KEY")
            return

        ; Do not inject mouse buttons that act as B-Shift modifiers
        logicalBtn := (mouseBtn = "XButton1") ? "Back" : ((mouseBtn = "XButton2") ? "Forward" : ((mouseBtn = "MButton") ? "Middle" : mouseBtn))
        if (ProfileEngine.IsShiftModifierButton(logicalBtn) || ProfileEngine.IsShiftModifierButton(mouseBtn))
            return

        SetTimer(this.TimeoutFn, 0)
        SetTimer(this.TimeoutFn, -10000)
        SetTimer(this.FinalizeComboFn, 0)

        hasKey := false
        for existing in this.ComboKeys {
            if (existing = mouseBtn) {
                hasKey := true
                break
            }
        }
        if (!hasKey) {
            this.ComboKeys.Push(mouseBtn)
        }

        this.CapturedResult := this.BuildSingleCombo(this.Modifiers, this.ComboKeys)
        if (this.CapturedResult.Label != "") {
            OSD.Show("Recording: " . this.CapturedResult.Label, "Release keys to apply to " . this.TargetDisplayName, 4000)
        }

        ; Debounce finalize
        SetTimer(this.FinalizeComboFn, -250)
    }

    /**
     * Step 3 Completion: Finalizes the recorded combination, applies it, and saves it.
     */
    static FinalizeRecordedCombo() {
        if (this.State != "WAIT_KEY" || this.CapturedResult = "")
            return

        res := this.CapturedResult
        this.StopHook()
        this.State := "IDLE"

        btnId := this.TargetButton
        btnName := this.TargetDisplayName
        curProf := ProfileEngine.CurrentProfile
        layer := this.TargetLayer

        ; Construct action mapping object
        actionObj := {
            Type: "Send",
            Cmd: res.Cmd,
            Label: res.Label,
            PlayType: "NoRepeat",
            RepeatInterval: 50
        }

        ; Save mapping via ProfileEngine
        ProfileEngine.SaveButtonLayer(curProf, btnId, layer, actionObj)

        ; Audio 3: High Victory Double-Chime!
        this.PlaySoundStep3()

        ; App HUD Notification
        OSD.Show("✅ Remapped " . btnName, "Assigned: " . res.Label . " (" . curProf . ")", 3500)

        ; Notify modern WebView2 Studio if running so cards & UI update live
        try {
            currMap := ProfileEngine.GetButtonMapping(curProf, btnId)
            WebViewGuiManager.PostMessage(Map(
                "type", "mappingSaved",
                "profile", curProf,
                "btnId", btnId,
                "mapping", WebViewGuiManager.ExportButtonMapping(currMap)
            ))
            WebViewGuiManager.PostMessage(Map(
                "type", "quickRemapCompleted",
                "btnId", btnId,
                "label", res.Label,
                "cmd", res.Cmd,
                "profile", curProf,
                "layer", layer
            ))
        }

        this.Reset()
    }

    /**
     * Cancels the Quick Remap workflow.
     */
    static Cancel() {
        if (!this.IsActive)
            return

        this.StopHook()
        this.State := "IDLE"

        ; Audio 4: Descending Cancel Tone
        this.PlaySoundCancel()

        OSD.Show("Quick Remap Cancelled", "No changes were made.", 2500)
        this.Reset()
    }

    static OnTimeout() {
        if (this.IsActive) {
            OSD.Show("Quick Remap Timed Out", "Recording cancelled due to inactivity.", 2500)
            this.Cancel()
        }
    }

    static StopHook() {
        SetTimer(this.TimeoutFn, 0)
        SetTimer(this.FinalizeComboFn, 0)

        if (this.InputHookObj != "") {
            try this.InputHookObj.Stop()
            this.InputHookObj := ""
        }
    }

    static Reset() {
        this.StopHook()
        this.State := "IDLE"
        this.TargetButton := ""
        this.TargetDisplayName := ""
        this.TargetLayer := "Normal"
        this.HoldingShiftButton := ""
        this.PhysicalButtonStates.Clear()
        this.KeysDown.Clear()
        this.Modifiers.Clear()
        this.ComboKeys := []
        this.CapturedResult := ""
        try ProfileEngine.ReleaseAllShiftModifiers()
    }

    ; =========================================================================
    ; KEY & COMBINATION NORMALIZATION
    ; =========================================================================

    static NormalizeKey(vk, sc) {
        ; 1. Hardware Virtual Key codes for letters A-Z (completely immune to Arabic/international layouts!)
        if (vk >= 0x41 && vk <= 0x5A)
            return Chr(vk)

        ; 2. Digits 0-9
        if (vk >= 0x30 && vk <= 0x39)
            return Chr(vk)

        ; 3. Numpad digits 0-9
        if (vk >= 0x60 && vk <= 0x69)
            return "Numpad" . (vk - 0x60)

        ; 4. Function keys F1 - F24
        if (vk >= 0x70 && vk <= 0x87)
            return "F" . (vk - 0x6F)

        ; 5. Specific virtual keys with standard English names
        switch vk {
            case 0x11, 0xA2, 0xA3: return "Ctrl"
            case 0x10, 0xA0, 0xA1: return "Shift"
            case 0x12, 0xA4, 0xA5: return "Alt"
            case 0x5B, 0x5C:       return "Win"
            case 0x1B:             return "Escape"
            case 0x20:             return "Space"
            case 0x09:             return "Tab"
            case 0x0D:             return "Enter"
            case 0x08:             return "Backspace"
            case 0x2E:             return "Delete"
            case 0x2D:             return "Insert"
            case 0x24:             return "Home"
            case 0x23:             return "End"
            case 0x21:             return "PgUp"
            case 0x22:             return "PgDn"
            case 0x26:             return "Up"
            case 0x28:             return "Down"
            case 0x25:             return "Left"
            case 0x27:             return "Right"
            case 0x14:             return "CapsLock"
            case 0x90:             return "NumLock"
            case 0x91:             return "ScrollLock"
            case 0x2C:             return "PrintScreen"
            case 0x13:             return "Pause"
            case 0x6A:             return "NumpadMult"
            case 0x6B:             return "NumpadAdd"
            case 0x6D:             return "NumpadSub"
            case 0x6E:             return "NumpadDot"
            case 0x6F:             return "NumpadDiv"
            case 0xBA:             return ";"
            case 0xBB:             return "="
            case 0xBC:             return ","
            case 0xBD:             return "-"
            case 0xBE:             return "."
            case 0xBF:             return "/"
            case 0xC0:             return "``"
            case 0xDB:             return "["
            case 0xDC:             return "\"
            case 0xDD:             return "]"
            case 0xDE:             return "'"
        }

        ; Fallback to GetKeyName
        kName := GetKeyName(Format("vk{:02x}sc{:03x}", vk, sc))
        if (kName = "")
            return ""

        switch kName {
            case "Control", "Ctrl", "LControl", "RControl", "LCtrl", "RCtrl": return "Ctrl"
            case "Shift", "LShift", "RShift":                                 return "Shift"
            case "Alt", "LAlt", "RAlt":                                       return "Alt"
            case "Win", "LWin", "RWin":                                       return "Win"
        }

        return kName
    }

    static BuildSingleCombo(mods, keys) {
        if (!IsObject(keys)) {
            keys := (keys != "") ? [keys] : []
        }

        prefix := ""
        lblParts := []

        if (mods.Has("Ctrl")) {
            prefix .= "^"
            lblParts.Push("Ctrl")
        }
        if (mods.Has("Alt")) {
            prefix .= "!"
            lblParts.Push("Alt")
        }
        if (mods.Has("Shift")) {
            prefix .= "+"
            lblParts.Push("Shift")
        }
        if (mods.Has("Win")) {
            prefix .= "#"
            lblParts.Push("Win")
        }

        cleanKeys := []
        for k in keys {
            if (k = "Ctrl" || k = "Alt" || k = "Shift" || k = "Win")
                continue

            niceKey := (k = "LButton") ? "Left Click" :
                       (k = "RButton") ? "Right Click" :
                       (k = "MButton") ? "Middle Click" :
                       (k = "XButton1") ? "Back" :
                       (k = "XButton2") ? "Forward" :
                       (StrLen(k) = 1 ? StrUpper(k) : k)
            lblParts.Push(niceKey)

            ahkKey := (k = "LButton" || k = "RButton" || k = "MButton" || k = "XButton1" || k = "XButton2") ? k :
                      (StrLen(k) = 1 ? StrLower(k) : k)
            cleanKeys.Push(ahkKey)
        }

        if (cleanKeys.Length = 0) {
            if (lblParts.Length > 0) {
                lastMod := lblParts[lblParts.Length]
                return { Cmd: "{" . lastMod . "}", Label: this.JoinComboParts(lblParts) }
            }
            return { Cmd: "", Label: "" }
        }

        if (cleanKeys.Length = 1) {
            k := cleanKeys[1]
            cmd := prefix . "{" . k . "}"
            lbl := this.JoinComboParts(lblParts)
            return { Cmd: cmd, Label: lbl }
        }

        downSeq := ""
        upSeq := ""
        for k in cleanKeys {
            downSeq .= "{" . k . " down}"
            upSeq := "{" . k . " up}" . upSeq
        }

        cmd := "{Blind}" . prefix . downSeq . upSeq
        lbl := this.JoinComboParts(lblParts)
        return { Cmd: cmd, Label: lbl }
    }

    static JoinComboParts(parts) {
        res := ""
        for idx, p in parts {
            res .= (idx = 1 ? "" : " + ") . p
        }
        return res
    }

    static GetButtonDisplayName(btnId) {
        iniPath := A_ScriptDir . "\settings.ini"
        try {
            customName := IniRead(iniPath, "ButtonNames", btnId, "")
            if (customName != "")
                return customName
        }
        switch btnId {
            case "TiltLeft":     return "Tilt Left"
            case "TiltRight":    return "Tilt Right"
            case "Middle":       return "Middle Click"
            case "G8":           return "G8 (DPI Up)"
            case "G7":           return "G7 (DPI Down)"
            case "DpiShift":     return "DPI Shift (Sniper)"
            case "Forward":      return "G5 (Forward)"
            case "Back":         return "G4 (Back)"
            case "ProfileCycle": return "G9 (Profile Cycle)"
            case "WheelUp":      return "Scroll Up"
            case "WheelDown":    return "Scroll Down"
            case "LeftClick":    return "Left Click"
            case "RightClick":   return "Right Click"
            default:             return btnId
        }
    }
}
