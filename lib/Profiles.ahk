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
    static IsGShift1Active := false
    static IsGShift2Active := false
    static Shift1PressTime := 0
    static Shift2PressTime := 0
    static Shift1ChordTriggered := false
    static Shift2ChordTriggered := false
    static OnShiftStateChanged := ""
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

                ; Load GShift2
                gs2Type   := IniRead(this.ConfigPath, section, "GShift2_Type", def.Normal.Type)
                gs2Cmd    := IniRead(this.ConfigPath, section, "GShift2_Cmd", def.Normal.Cmd)
                gs2Lbl    := IniRead(this.ConfigPath, section, "GShift2_Label", def.Normal.Label)
                gs2Play   := IniRead(this.ConfigPath, section, "GShift2_PlayType", "NoRepeat")
                gs2Int    := Integer(IniRead(this.ConfigPath, section, "GShift2_RepeatInterval", "50"))
                gs2StepsStr    := IniRead(this.ConfigPath, section, "GShift2_Steps", "")
                gs2SeqPressStr := IniRead(this.ConfigPath, section, "GShift2_SeqPress", "")
                gs2SeqHoldStr  := IniRead(this.ConfigPath, section, "GShift2_SeqHold", "")
                gs2SeqRelStr   := IniRead(this.ConfigPath, section, "GShift2_SeqRelease", "")

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
                    },
                    GShift2: {
                        Type: gs2Type, Cmd: gs2Cmd, Label: gs2Lbl,
                        PlayType: gs2Play, RepeatInterval: gs2Int,
                        Steps: this.DeserializeSteps(gs2StepsStr),
                        SeqPress: this.DeserializeSteps(gs2SeqPressStr),
                        SeqHold: this.DeserializeSteps(gs2SeqHoldStr),
                        SeqRelease: this.DeserializeSteps(gs2SeqRelStr)
                    }
                }
            }
        }
    }

    static SaveButtonLayer(profile, btnId, layer, actionObj) {
        if (!this.ActiveMappings.Has(profile))
            this.ActiveMappings[profile] := Map()

        mapping := this.GetButtonMapping(profile, btnId)
        if (layer = "GShift2")
            mapping.GShift2 := actionObj
        else if (layer = "GShift" || layer = "GShift1")
            mapping.GShift := actionObj
        else
            mapping.Normal := actionObj

        this.ActiveMappings[profile][btnId] := mapping

        if (this.ConfigPath != "") {
            prefix := (layer = "GShift2") ? "GShift2_" : ((layer = "GShift" || layer = "GShift1") ? "GShift_" : "Normal_")
            section := "Mapping_" . profile . "_" . btnId
            IniWrite(actionObj.Type, this.ConfigPath, section, prefix . "Type")
            IniWrite(actionObj.Cmd, this.ConfigPath, section, prefix . "Cmd")
            IniWrite(actionObj.Label, this.ConfigPath, section, prefix . "Label")
            playType := actionObj.HasOwnProp("PlayType") ? actionObj.PlayType : "NoRepeat"
            interval := actionObj.HasOwnProp("RepeatInterval") ? actionObj.RepeatInterval : 50
            IniWrite(playType, this.ConfigPath, section, prefix . "PlayType")
            IniWrite(interval, this.ConfigPath, section, prefix . "RepeatInterval")
            stepsStr := actionObj.HasOwnProp("Steps") ? this.SerializeSteps(actionObj.Steps) : ""
            IniWrite(stepsStr, this.ConfigPath, section, prefix . "Steps")
            seqPressStr := actionObj.HasOwnProp("SeqPress") ? this.SerializeSteps(actionObj.SeqPress) : ""
            IniWrite(seqPressStr, this.ConfigPath, section, prefix . "SeqPress")
            seqHoldStr := actionObj.HasOwnProp("SeqHold") ? this.SerializeSteps(actionObj.SeqHold) : ""
            IniWrite(seqHoldStr, this.ConfigPath, section, prefix . "SeqHold")
            seqRelStr := actionObj.HasOwnProp("SeqRelease") ? this.SerializeSteps(actionObj.SeqRelease) : ""
            IniWrite(seqRelStr, this.ConfigPath, section, prefix . "SeqRelease")
        }
    }

    static SaveMapping(profile, btnId, normalObj, gshiftObj, gshift2Obj := "") {
        this.SaveButtonLayer(profile, btnId, "Normal", normalObj)
        this.SaveButtonLayer(profile, btnId, "GShift", gshiftObj)
        if (IsObject(gshift2Obj))
            this.SaveButtonLayer(profile, btnId, "GShift2", gshift2Obj)
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
            m := this.ActiveMappings[profile][btnId]
            if (!m.HasOwnProp("GShift2"))
                m.GShift2 := m.Normal.Clone()
            return m
        }
        if (this.DefaultMappings.Has(profile) && this.DefaultMappings[profile].Has(btnId)) {
            def := this.DefaultMappings[profile][btnId]
            return {
                Normal: def.Normal,
                GShift: def.GShift,
                GShift2: def.HasOwnProp("GShift2") ? def.GShift2 : def.Normal
            }
        }
        none := { Type: "Send", Cmd: "", Label: "None", PlayType: "NoRepeat", RepeatInterval: 50 }
        return { Normal: none, GShift: none, GShift2: none }
    }

    static GetButtonLabel(profile, btnId, layer := "Normal") {
        mapping := this.GetButtonMapping(profile, btnId)
        if (layer = "GShift2" && mapping.HasOwnProp("GShift2") && mapping.GShift2.Label != "")
            return mapping.GShift2.Label
        if ((layer = "GShift" || layer = "GShift1") && mapping.HasOwnProp("GShift") && mapping.GShift.Label != "")
            return mapping.GShift.Label
        return mapping.Normal.Label
    }

    static GetShiftButtons(profile := "") {
        if (profile = "")
            profile := this.CurrentProfile
        shiftBtns := []
        if (!this.ActiveMappings.Has(profile))
            return shiftBtns
            
        for btnId, mapping in this.ActiveMappings[profile] {
            norm := mapping.Normal
            if (norm.Type = "Special") {
                if (norm.Cmd = "GShift" || norm.Cmd = "GShift1") {
                    shiftBtns.Push({ Id: btnId, Type: "GShift1", Label: "B-Shift 1" })
                } else if (norm.Cmd = "GShift2") {
                    shiftBtns.Push({ Id: btnId, Type: "GShift2", Label: "B-Shift 2" })
                }
            }
        }
        return shiftBtns
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
        mapping := this.GetButtonMapping(this.CurrentProfile, btnId)
        normCmd := mapping.Normal.Cmd
        normType := mapping.Normal.Type

        ; Check if this button is assigned as a Shift layer modifier
        if (normType = "Special" && (normCmd = "GShift" || normCmd = "GShift1")) {
            this.HandleShift1Modifier(btnId, isDown)
            return
        }
        if (normType = "Special" && normCmd = "GShift2") {
            this.HandleShift2Modifier(btnId, isDown)
            return
        }

        ; If not a shift modifier, execute based on currently held shift layer
        layer := "Normal"
        if (this.IsGShift2Active) {
            layer := "GShift2"
            if (isDown)
                this.Shift2ChordTriggered := true
        } else if (this.IsGShift1Active) {
            layer := "GShift"
            if (isDown)
                this.Shift1ChordTriggered := true
        }

        this.ExecuteButtonEvent(btnId, layer, isDown)
    }

    static HandleShift1Modifier(btnId, isDown) {
        if (isDown) {
            this.IsGShift1Active := true
            this.IsGShiftActive := true
            this.Shift1ChordTriggered := false
            this.Shift1PressTime := A_TickCount
            this.NotifyShift(1, true)
        } else {
            this.IsGShift1Active := false
            this.IsGShiftActive := this.IsGShift2Active
            this.NotifyShift(1, false)
            elapsed := A_TickCount - this.Shift1PressTime
            if (elapsed < 280 && !this.Shift1ChordTriggered) {
                this.ExecuteDpiShiftTap()
            }
        }
    }

    static HandleShift2Modifier(btnId, isDown) {
        if (isDown) {
            this.IsGShift2Active := true
            this.IsGShiftActive := true
            this.Shift2ChordTriggered := false
            this.Shift2PressTime := A_TickCount
            this.NotifyShift(2, true)
        } else {
            this.IsGShift2Active := false
            this.IsGShiftActive := this.IsGShift1Active
            this.NotifyShift(2, false)
        }
    }

    static NotifyShift(layerNum, isActive) {
        fn := this.OnShiftStateChanged
        if (fn)
            fn(layerNum, isActive)
    }

    static ExecuteButtonEvent(btnId, layer, isDown) {
        mapping := this.GetButtonMapping(this.CurrentProfile, btnId)
        act := (layer = "GShift2") ? mapping.GShift2 : ((layer = "GShift" || layer = "GShift1") ? mapping.GShift : mapping.Normal)
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
        this.NotifyButton("DpiShift", isDown)
        this.DispatchButton("DpiShift", isDown)
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
        this.DispatchButton("ProfileCycle", isDown)
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
