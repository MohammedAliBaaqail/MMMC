#Requires AutoHotkey v2.0

/**
 * Dynamic Profile & Macro Execution Engine for Logitech G502 X
 * Supports customizable button mappings and keyboard combinations per profile,
 * persisted via settings.ini.
 */
class ProfileEngine {
    static Profiles := ["Desktop", "Productivity", "Gaming", "Media"]
    static CurrentProfile := "Desktop"
    static IsGShiftActive := false
    static ChordTriggered := false
    static DpiShiftPressTime := 0
    static RapidFireEnabled := false
    static RapidFireActive := false
    static RapidFireInterval := 50 ; ms (~20 CPS)
    static ConfigPath := ""

    ; Macro execution states
    static ActiveHoldTimers := Map()
    static ActiveToggleTimers := Map()
    static ActiveSequences := Map()

    ; Callback for GUI updates
    static OnProfileChanged := ""
    static OnButtonStateChanged := ""

    ; Default Mappings for all 4 profiles
    static DefaultMappings := Map(
        "Desktop", Map(
            "TiltLeft",     { Normal: { Type: "Send", Cmd: "^+{Tab}", Label: "Prev Browser Tab" }, GShift: { Type: "Send", Cmd: "#{Left}", Label: "Snap Win Left" } },
            "TiltRight",    { Normal: { Type: "Send", Cmd: "^{Tab}", Label: "Next Browser Tab" }, GShift: { Type: "Send", Cmd: "#{Right}", Label: "Snap Win Right" } },
            "Middle",       { Normal: { Type: "Send", Cmd: "{MButton}", Label: "Middle Click" }, GShift: { Type: "Send", Cmd: "^w", Label: "Close Tab" } },
            "G8",           { Normal: { Type: "Send", Cmd: "{Volume_Up 2}", Label: "Volume Up" }, GShift: { Type: "Send", Cmd: "#{Up}", Label: "Maximize Win" } },
            "G7",           { Normal: { Type: "Send", Cmd: "{Volume_Down 2}", Label: "Volume Down" }, GShift: { Type: "Send", Cmd: "#{Down}", Label: "Minimize Win" } },
            "DpiShift",     { Normal: { Type: "Special", Cmd: "GShift", Label: "G-Shift / Task View" }, GShift: { Type: "Special", Cmd: "GShift", Label: "G-Shift Layer" } },
            "Forward",      { Normal: { Type: "Send", Cmd: "!{Right}", Label: "Browser Forward" }, GShift: { Type: "Send", Cmd: "^w", Label: "Close Tab" } },
            "Back",         { Normal: { Type: "Send", Cmd: "!{Left}", Label: "Browser Back" }, GShift: { Type: "Send", Cmd: "^+t", Label: "Reopen Tab" } },
            "ProfileCycle", { Normal: { Type: "Special", Cmd: "CycleProfile", Label: "Next Profile" }, GShift: { Type: "Special", Cmd: "CycleProfile", Label: "Next Profile" } }
        ),
        "Productivity", Map(
            "TiltLeft",     { Normal: { Type: "Send", Cmd: "!{Left}", Label: "Cursor History Back" }, GShift: { Type: "Send", Cmd: "^{PgUp}", Label: "Prev Editor Tab" } },
            "TiltRight",    { Normal: { Type: "Send", Cmd: "!{Right}", Label: "Cursor History Fwd" }, GShift: { Type: "Send", Cmd: "^{PgDn}", Label: "Next Editor Tab" } },
            "Middle",       { Normal: { Type: "Send", Cmd: "{MButton}", Label: "Middle Click" }, GShift: { Type: "Send", Cmd: "^w", Label: "Close Tab" } },
            "G8",           { Normal: { Type: "Send", Cmd: "!+{Down}", Label: "Duplicate Line" }, GShift: { Type: "Send", Cmd: "^d", Label: "Select Next Word" } },
            "G7",           { Normal: { Type: "Send", Cmd: "^+k", Label: "Delete Line" }, GShift: { Type: "Send", Cmd: "^/", Label: "Toggle Comment" } },
            "DpiShift",     { Normal: { Type: "Special", Cmd: "GShift", Label: "G-Shift / Command Pal" }, GShift: { Type: "Special", Cmd: "GShift", Label: "G-Shift Layer" } },
            "Forward",      { Normal: { Type: "Send", Cmd: "^y", Label: "Redo (Ctrl+Y)" }, GShift: { Type: "Send", Cmd: "+!f", Label: "Format Document" } },
            "Back",         { Normal: { Type: "Send", Cmd: "^z", Label: "Undo (Ctrl+Z)" }, GShift: { Type: "Send", Cmd: "^s", Label: "Save (Ctrl+S)" } },
            "ProfileCycle", { Normal: { Type: "Special", Cmd: "CycleProfile", Label: "Next Profile" }, GShift: { Type: "Special", Cmd: "CycleProfile", Label: "Next Profile" } }
        ),
        "Gaming", Map(
            "TiltLeft",     { Normal: { Type: "Send", Cmd: "1", Label: "Weapon Slot 1" }, GShift: { Type: "Send", Cmd: "1", Label: "Weapon Slot 1" } },
            "TiltRight",    { Normal: { Type: "Send", Cmd: "2", Label: "Weapon Slot 2" }, GShift: { Type: "Send", Cmd: "2", Label: "Weapon Slot 2" } },
            "Middle",       { Normal: { Type: "Send", Cmd: "{MButton}", Label: "Middle Click" }, GShift: { Type: "Send", Cmd: "{MButton}", Label: "Middle Click" } },
            "G8",           { Normal: { Type: "Special", Cmd: "ToggleRapidFire", Label: "Toggle Rapid Fire" }, GShift: { Type: "Special", Cmd: "ToggleRapidFire", Label: "Toggle Rapid Fire" } },
            "G7",           { Normal: { Type: "Send", Cmd: "z", Label: "Quick Ping (Z)" }, GShift: { Type: "Send", Cmd: "z", Label: "Quick Ping (Z)" } },
            "DpiShift",     { Normal: { Type: "Special", Cmd: "GShift", Label: "Sniper Aim / Melee" }, GShift: { Type: "Special", Cmd: "GShift", Label: "G-Shift Layer" } },
            "Forward",      { Normal: { Type: "Send", Cmd: "g", Label: "Grenade (G)" }, GShift: { Type: "Send", Cmd: "g", Label: "Grenade (G)" } },
            "Back",         { Normal: { Type: "Send", Cmd: "r", Label: "Reload (R)" }, GShift: { Type: "Send", Cmd: "r", Label: "Reload (R)" } },
            "ProfileCycle", { Normal: { Type: "Special", Cmd: "CycleProfile", Label: "Next Profile" }, GShift: { Type: "Special", Cmd: "CycleProfile", Label: "Next Profile" } }
        ),
        "Media", Map(
            "TiltLeft",     { Normal: { Type: "Send", Cmd: "{Media_Prev}", Label: "Previous Track" }, GShift: { Type: "Send", Cmd: "{Media_Prev}", Label: "Previous Track" } },
            "TiltRight",    { Normal: { Type: "Send", Cmd: "{Media_Next}", Label: "Next Track" }, GShift: { Type: "Send", Cmd: "{Media_Next}", Label: "Next Track" } },
            "Middle",       { Normal: { Type: "Send", Cmd: "{MButton}", Label: "Middle Click" }, GShift: { Type: "Send", Cmd: "{Media_Play_Pause}", Label: "Play / Pause" } },
            "G8",           { Normal: { Type: "Send", Cmd: "{Volume_Up 2}", Label: "Volume Up" }, GShift: { Type: "Send", Cmd: "{Volume_Up 4}", Label: "Fast Vol Up" } },
            "G7",           { Normal: { Type: "Send", Cmd: "{Volume_Down 2}", Label: "Volume Down" }, GShift: { Type: "Send", Cmd: "{Volume_Down 4}", Label: "Fast Vol Down" } },
            "DpiShift",     { Normal: { Type: "Special", Cmd: "GShift", Label: "G-Shift / Play-Pause" }, GShift: { Type: "Special", Cmd: "GShift", Label: "G-Shift Layer" } },
            "Forward",      { Normal: { Type: "Send", Cmd: "{Right}", Label: "Seek Forward 10s" }, GShift: { Type: "Send", Cmd: "{Right 2}", Label: "Seek Forward 20s" } },
            "Back",         { Normal: { Type: "Send", Cmd: "{Left}", Label: "Seek Back 10s" }, GShift: { Type: "Send", Cmd: "{Left 2}", Label: "Seek Back 20s" } },
            "ProfileCycle", { Normal: { Type: "Special", Cmd: "CycleProfile", Label: "Next Profile" }, GShift: { Type: "Special", Cmd: "CycleProfile", Label: "Next Profile" } }
        )
    )

    ; Runtime active custom mappings: Map(ProfileName, Map(BtnId, { Normal: {...}, GShift: {...} }))
    static ActiveMappings := Map()

    static Init(iniPath) {
        this.ConfigPath := iniPath
        this.LoadAllMappings()
    }

    static LoadAllMappings() {
        for profile in this.Profiles {
            if (!this.ActiveMappings.Has(profile))
                this.ActiveMappings[profile] := Map()

            defaults := this.DefaultMappings[profile]
            for btnId, def in defaults {
                section := "Mapping_" . profile . "_" . btnId
                
                ; Load Normal
                normType := IniRead(this.ConfigPath, section, "Normal_Type", def.Normal.Type)
                normCmd  := IniRead(this.ConfigPath, section, "Normal_Cmd", def.Normal.Cmd)
                normLbl  := IniRead(this.ConfigPath, section, "Normal_Label", def.Normal.Label)
                normPlay := IniRead(this.ConfigPath, section, "Normal_PlayType", "NoRepeat")
                normInt  := Integer(IniRead(this.ConfigPath, section, "Normal_RepeatInterval", "50"))
                normStepsStr    := IniRead(this.ConfigPath, section, "Normal_Steps", "")
                normSeqPressStr := IniRead(this.ConfigPath, section, "Normal_SeqPress", "")
                normSeqHoldStr  := IniRead(this.ConfigPath, section, "Normal_SeqHold", "")
                normSeqRelStr   := IniRead(this.ConfigPath, section, "Normal_SeqRelease", "")

                ; Load GShift
                gsType   := IniRead(this.ConfigPath, section, "GShift_Type", def.GShift.Type)
                gsCmd    := IniRead(this.ConfigPath, section, "GShift_Cmd", def.GShift.Cmd)
                gsLbl    := IniRead(this.ConfigPath, section, "GShift_Label", def.GShift.Label)
                gsPlay   := IniRead(this.ConfigPath, section, "GShift_PlayType", "NoRepeat")
                gsInt    := Integer(IniRead(this.ConfigPath, section, "GShift_RepeatInterval", "50"))
                gsStepsStr    := IniRead(this.ConfigPath, section, "GShift_Steps", "")
                gsSeqPressStr := IniRead(this.ConfigPath, section, "GShift_SeqPress", "")
                gsSeqHoldStr  := IniRead(this.ConfigPath, section, "GShift_SeqHold", "")
                gsSeqRelStr   := IniRead(this.ConfigPath, section, "GShift_SeqRelease", "")

                this.ActiveMappings[profile][btnId] := {
                    Normal: {
                        Type: normType, Cmd: normCmd, Label: normLbl,
                        PlayType: normPlay, RepeatInterval: normInt,
                        Steps: this.DeserializeSteps(normStepsStr),
                        SeqPress: this.DeserializeSteps(normSeqPressStr),
                        SeqHold: this.DeserializeSteps(normSeqHoldStr),
                        SeqRelease: this.DeserializeSteps(normSeqRelStr)
                    },
                    GShift: {
                        Type: gsType, Cmd: gsCmd, Label: gsLbl,
                        PlayType: gsPlay, RepeatInterval: gsInt,
                        Steps: this.DeserializeSteps(gsStepsStr),
                        SeqPress: this.DeserializeSteps(gsSeqPressStr),
                        SeqHold: this.DeserializeSteps(gsSeqHoldStr),
                        SeqRelease: this.DeserializeSteps(gsSeqRelStr)
                    }
                }
            }
        }
    }

    static SaveMapping(profile, btnId, normalObj, gshiftObj) {
        if (!this.ActiveMappings.Has(profile))
            this.ActiveMappings[profile] := Map()

        this.ActiveMappings[profile][btnId] := {
            Normal: normalObj,
            GShift: gshiftObj
        }

        if (this.ConfigPath != "") {
            section := "Mapping_" . profile . "_" . btnId
            
            ; Save Normal
            IniWrite(normalObj.Type, this.ConfigPath, section, "Normal_Type")
            IniWrite(normalObj.Cmd, this.ConfigPath, section, "Normal_Cmd")
            IniWrite(normalObj.Label, this.ConfigPath, section, "Normal_Label")
            playType := normalObj.HasOwnProp("PlayType") ? normalObj.PlayType : "NoRepeat"
            interval := normalObj.HasOwnProp("RepeatInterval") ? normalObj.RepeatInterval : 50
            IniWrite(playType, this.ConfigPath, section, "Normal_PlayType")
            IniWrite(interval, this.ConfigPath, section, "Normal_RepeatInterval")
            stepsStr := normalObj.HasOwnProp("Steps") ? this.SerializeSteps(normalObj.Steps) : ""
            IniWrite(stepsStr, this.ConfigPath, section, "Normal_Steps")
            seqPressStr := normalObj.HasOwnProp("SeqPress") ? this.SerializeSteps(normalObj.SeqPress) : ""
            IniWrite(seqPressStr, this.ConfigPath, section, "Normal_SeqPress")
            seqHoldStr := normalObj.HasOwnProp("SeqHold") ? this.SerializeSteps(normalObj.SeqHold) : ""
            IniWrite(seqHoldStr, this.ConfigPath, section, "Normal_SeqHold")
            seqRelStr := normalObj.HasOwnProp("SeqRelease") ? this.SerializeSteps(normalObj.SeqRelease) : ""
            IniWrite(seqRelStr, this.ConfigPath, section, "Normal_SeqRelease")

            ; Save GShift
            IniWrite(gshiftObj.Type, this.ConfigPath, section, "GShift_Type")
            IniWrite(gshiftObj.Cmd, this.ConfigPath, section, "GShift_Cmd")
            IniWrite(gshiftObj.Label, this.ConfigPath, section, "GShift_Label")
            gsPlay := gshiftObj.HasOwnProp("PlayType") ? gshiftObj.PlayType : "NoRepeat"
            gsInt  := gshiftObj.HasOwnProp("RepeatInterval") ? gshiftObj.RepeatInterval : 50
            IniWrite(gsPlay, this.ConfigPath, section, "GShift_PlayType")
            IniWrite(gsInt, this.ConfigPath, section, "GShift_RepeatInterval")
            gsStepsStr := gshiftObj.HasOwnProp("Steps") ? this.SerializeSteps(gshiftObj.Steps) : ""
            IniWrite(gsStepsStr, this.ConfigPath, section, "GShift_Steps")
            gsSeqPressStr := gshiftObj.HasOwnProp("SeqPress") ? this.SerializeSteps(gshiftObj.SeqPress) : ""
            IniWrite(gsSeqPressStr, this.ConfigPath, section, "GShift_SeqPress")
            gsSeqHoldStr := gshiftObj.HasOwnProp("SeqHold") ? this.SerializeSteps(gshiftObj.SeqHold) : ""
            IniWrite(gsSeqHoldStr, this.ConfigPath, section, "GShift_SeqHold")
            gsSeqRelStr := gshiftObj.HasOwnProp("SeqRelease") ? this.SerializeSteps(gshiftObj.SeqRelease) : ""
            IniWrite(gsSeqRelStr, this.ConfigPath, section, "GShift_SeqRelease")
        }
    }

    static SerializeSteps(stepArr) {
        if (!IsObject(stepArr) || stepArr.Length = 0)
            return ""
        str := ""
        for i, s in stepArr {
            actChar := (s.Action = "Down") ? "D" : "U"
            del := s.HasOwnProp("Delay") ? s.Delay : 50
            part := actChar . ":" . s.Key . ":" . del
            str .= (i = 1 ? "" : "|") . part
        }
        return str
    }

    static DeserializeSteps(stepStr) {
        steps := []
        if (stepStr = "")
            return steps
        parts := StrSplit(stepStr, "|")
        for p in parts {
            if (p = "")
                continue
            items := StrSplit(p, ":")
            if (items.Length >= 2) {
                act := (items[1] = "D") ? "Down" : "Up"
                k := items[2]
                del := (items.Length >= 3 && IsInteger(items[3])) ? Integer(items[3]) : 50
                steps.Push({ Action: act, Key: k, Delay: del })
            }
        }
        return steps
    }

    static ResetMappingToDefault(profile, btnId) {
        if (this.DefaultMappings.Has(profile) && this.DefaultMappings[profile].Has(btnId)) {
            def := this.DefaultMappings[profile][btnId]
            this.SaveMapping(profile, btnId, def.Normal, def.GShift)
        }
    }

    static GetButtonMapping(profile, btnId) {
        if (this.ActiveMappings.Has(profile) && this.ActiveMappings[profile].Has(btnId)) {
            return this.ActiveMappings[profile][btnId]
        }
        if (this.DefaultMappings.Has(profile) && this.DefaultMappings[profile].Has(btnId)) {
            return this.DefaultMappings[profile][btnId]
        }
        return { Normal: { Type: "Send", Cmd: "", Label: "None", PlayType: "NoRepeat", RepeatInterval: 50 }, GShift: { Type: "Send", Cmd: "", Label: "None", PlayType: "NoRepeat", RepeatInterval: 50 } }
    }

    static GetButtonLabel(profile, btnId) {
        mapping := this.GetButtonMapping(profile, btnId)
        return mapping.Normal.Label
    }

    ; Switch to a specific profile
    static SetProfile(profileName) {
        for p in this.Profiles {
            if (p = profileName) {
                this.StopAllRunningMacros()
                this.CurrentProfile := p
                OSD.Show("Profile: " . p, this.GetProfileDescription(p))
                fn := this.OnProfileChanged
                if (fn)
                    fn(p)
                return
            }
        }
    }

    ; Cycle to the next profile
    static CycleProfile() {
        currentIndex := 1
        for i, p in this.Profiles {
            if (p = this.CurrentProfile) {
                currentIndex := i
                break
            }
        }
        nextIndex := (currentIndex >= this.Profiles.Length) ? 1 : currentIndex + 1
        this.SetProfile(this.Profiles[nextIndex])
        SoundBeep(900, 80)
    }

    static StopAllRunningMacros() {
        for btnId, fn in this.ActiveHoldTimers {
            SetTimer(fn, 0)
        }
        this.ActiveHoldTimers.Clear()

        for btnId, fn in this.ActiveToggleTimers {
            SetTimer(fn, 0)
        }
        this.ActiveToggleTimers.Clear()

        for btnId, seq in this.ActiveSequences {
            SetTimer(seq.fn, 0)
        }
        this.ActiveSequences.Clear()
    }

    static GetProfileDescription(p) {
        switch p {
            case "Desktop": return "Tabs, Media, Snap Windows & G-Shift"
            case "Productivity": return "VS Code, Undo/Redo, Duplication & Format"
            case "Gaming": return "Rapid Fire, Sniper Aim, Weapon Shortcuts"
            case "Media": return "Track Controls, Volume Wheel & Play/Pause"
            default: return ""
        }
    }

    ; Dynamic execution engine
    static DispatchButton(btnId, isDown) {
        if (this.IsGShiftActive) {
            if (isDown)
                this.ChordTriggered := true
            this.ExecuteButtonEvent(btnId, true, isDown)
        } else {
            this.ExecuteButtonEvent(btnId, false, isDown)
        }
    }

    static ExecuteButtonEvent(btnId, isGShift, isDown) {
        mapping := this.GetButtonMapping(this.CurrentProfile, btnId)
        act := isGShift ? mapping.GShift : mapping.Normal
        playType := act.HasOwnProp("PlayType") ? act.PlayType : "NoRepeat"

        if (isDown) {
            ; If toggle is active on this button, second press stops it!
            if (this.ActiveToggleTimers.Has(btnId)) {
                this.StopToggle(btnId)
                return
            }

            switch playType {
                case "NoRepeat", "No Repeat":
                    this.ExecuteActionOnce(act)
                case "RepeatWhileHolding", "Repeat While Holding":
                    this.StartHold(btnId, act)
                case "Toggle":
                    this.StartToggle(btnId, act)
                case "Sequence":
                    this.StartSequence(btnId, act)
                default:
                    this.ExecuteActionOnce(act)
            }
        } else {
            ; Button released!
            if (this.ActiveHoldTimers.Has(btnId)) {
                this.StopHold(btnId)
            }
            if (this.ActiveSequences.Has(btnId)) {
                this.FinishSequence(btnId, act)
            }
        }
    }

    static ExecuteActionOnce(act) {
        if (act.Type = "Send" && act.Cmd != "") {
            Send(act.Cmd)
        } else if (act.Type = "Macro") {
            if (act.HasOwnProp("Steps") && act.Steps.Length > 0) {
                this.PlaySteps(act.Steps)
            }
        } else if (act.Type = "Special") {
            if (act.Cmd = "CycleProfile") {
                this.CycleProfile()
            } else if (act.Cmd = "ToggleRapidFire") {
                this.ToggleRapidFire()
            } else if (act.Cmd = "GShift") {
                this.ExecuteDpiShiftTap()
            }
        }
    }

    static PlaySteps(steps) {
        if (!IsObject(steps) || steps.Length = 0)
            return
        for step in steps {
            k := step.Key
            if (step.Action = "Down") {
                SendEvent("{" . k . " down}")
            } else if (step.Action = "Up") {
                SendEvent("{" . k . " up}")
            }
            if (step.HasOwnProp("Delay") && step.Delay > 0) {
                Sleep(step.Delay)
            }
        }
    }

    static StartHold(btnId, act) {
        this.StopHold(btnId)
        this.ExecuteActionOnce(act)
        interval := (act.HasOwnProp("RepeatInterval") && act.RepeatInterval > 0) ? act.RepeatInterval : 50
        fn := () => ProfileEngine.ExecuteActionOnce(act)
        this.ActiveHoldTimers[btnId] := fn
        SetTimer(fn, interval)
    }

    static StopHold(btnId) {
        if (this.ActiveHoldTimers.Has(btnId)) {
            fn := this.ActiveHoldTimers[btnId]
            SetTimer(fn, 0)
            this.ActiveHoldTimers.Delete(btnId)
        }
    }

    static StartToggle(btnId, act) {
        this.StopToggle(btnId)
        this.ExecuteActionOnce(act)
        interval := (act.HasOwnProp("RepeatInterval") && act.RepeatInterval > 0) ? act.RepeatInterval : 50
        fn := () => ProfileEngine.ExecuteActionOnce(act)
        this.ActiveToggleTimers[btnId] := fn
        SetTimer(fn, interval)
        OSD.Show("Toggle: RUNNING", act.Label)
        SoundBeep(1200, 60)
    }

    static StopToggle(btnId) {
        if (this.ActiveToggleTimers.Has(btnId)) {
            fn := this.ActiveToggleTimers[btnId]
            SetTimer(fn, 0)
            this.ActiveToggleTimers.Delete(btnId)
            OSD.Show("Toggle: STOPPED", "Idle")
            SoundBeep(700, 60)
        }
    }

    static StartSequence(btnId, act) {
        ; 1. Play ON PRESS steps once
        if (act.HasOwnProp("SeqPress") && act.SeqPress.Length > 0) {
            this.PlaySteps(act.SeqPress)
        }

        ; 2. Start WHILE HOLDING loop timer
        if (act.HasOwnProp("SeqHold") && act.SeqHold.Length > 0) {
            fn := () => ProfileEngine.PlaySteps(act.SeqHold)
            this.ActiveSequences[btnId] := { fn: fn, act: act }
            interval := (act.HasOwnProp("RepeatInterval") && act.RepeatInterval > 0) ? act.RepeatInterval : 50
            SetTimer(fn, interval)
        }
    }

    static FinishSequence(btnId, act) {
        ; 1. Stop WHILE HOLDING loop
        if (this.ActiveSequences.Has(btnId)) {
            seqObj := this.ActiveSequences[btnId]
            SetTimer(seqObj.fn, 0)
            this.ActiveSequences.Delete(btnId)
        }

        ; 2. Play ON RELEASE steps once
        if (act.HasOwnProp("SeqRelease") && act.SeqRelease.Length > 0) {
            this.PlaySteps(act.SeqRelease)
        }
    }

    ; --- Button Event Handlers (F13 - F21) ---
    ; Matches Logitech Onboard Memory Manager (OMM) physical layout

    ; Button 3: Middle Click (Mouse 3) -> F13
    static HandleF13_Middle(isDown) {
        this.NotifyButton("Middle", isDown)
        this.DispatchButton("Middle", isDown)
    }

    ; Button 4: Back Button Click (Mouse 4 / G4) -> F14
    static HandleF14_Back(isDown) {
        this.NotifyButton("Back", isDown)
        this.DispatchButton("Back", isDown)
    }

    ; Button 5: G-Shift / Sniper Thumb Button (DPI Shift) -> F15
    static HandleF15_DpiShift(isDown) {
        if (isDown) {
            this.NotifyButton("DpiShift", true)
            this.IsGShiftActive := true
            this.ChordTriggered := false
            this.DpiShiftPressTime := A_TickCount
        } else {
            this.NotifyButton("DpiShift", false)
            this.IsGShiftActive := false
            elapsed := A_TickCount - this.DpiShiftPressTime

            ; If released quickly without triggering any chord, execute Tap action!
            if (elapsed < 280 && !this.ChordTriggered) {
                this.ExecuteDpiShiftTap()
            }
        }
    }

    static ExecuteDpiShiftTap() {
        switch this.CurrentProfile {
            case "Desktop": 
                Send("#{Tab}") ; Windows Task View
            case "Productivity": 
                Send("^+p") ; VS Code / IDE Command Palette
            case "Gaming": 
                Send("v") ; Melee attack
            case "Media": 
                Send("{Media_Play_Pause}") ; Play/Pause
        }
    }

    ; Button 6: Forward Button Click (Mouse 5 / G5) -> F16
    static HandleF16_Forward(isDown) {
        this.NotifyButton("Forward", isDown)
        this.DispatchButton("Forward", isDown)
    }

    ; Button 7: Tilt Left -> F17
    static HandleF17_TiltLeft(isDown) {
        this.NotifyButton("TiltLeft", isDown)
        this.DispatchButton("TiltLeft", isDown)
    }

    ; Button 8: Tilt Right -> F18
    static HandleF18_TiltRight(isDown) {
        this.NotifyButton("TiltRight", isDown)
        this.DispatchButton("TiltRight", isDown)
    }

    ; Button 9: Cycle Profiles (G9) -> F19
    static HandleF19_ProfileCycle(isDown) {
        this.NotifyButton("ProfileCycle", isDown)
        if (isDown)
            this.ExecuteActionOnce({ Type: "Special", Cmd: "CycleProfile" })
    }

    ; Button 10: Next DPI (G8 / DPI Up) -> F20
    static HandleF20_G8(isDown) {
        this.NotifyButton("G8", isDown)
        this.DispatchButton("G8", isDown)
    }

    ; Button 11: Previous DPI (G7 / DPI Down) -> F21
    static HandleF21_G7(isDown) {
        this.NotifyButton("G7", isDown)
        this.DispatchButton("G7", isDown)
    }

    ; Scroll Wheel G-Shift Chording (Volume / Zoom knob)
    static HandleWheel(direction) {
        if (!this.IsGShiftActive)
            return false

        this.ChordTriggered := true
        if (direction = "Up") {
            Send("{Volume_Up 2}")
        } else {
            Send("{Volume_Down 2}")
        }
        return true
    }

    ; Rapid-Fire / Auto-Clicker System
    static rapidFireFn := () => ProfileEngine.RapidFireLoop()

    static ToggleRapidFire() {
        this.RapidFireEnabled := !this.RapidFireEnabled
        statusText := this.RapidFireEnabled ? "ENABLED (" . (1000 // this.RapidFireInterval) . " CPS)" : "DISABLED"
        OSD.Show("Rapid Fire: " . statusText, "Left click while holding or toggle")
        SoundBeep(this.RapidFireEnabled ? 1100 : 650, 100)
    }

    static RapidFireLoop() {
        if (!ProfileEngine.RapidFireActive || !ProfileEngine.RapidFireEnabled) {
            SetTimer(ProfileEngine.rapidFireFn, 0)
            return
        }
        Click()
    }

    static NotifyButton(btnName, isPressed) {
        fn := this.OnButtonStateChanged
        if (fn) {
            fn(btnName, isPressed)
        }
    }
}
