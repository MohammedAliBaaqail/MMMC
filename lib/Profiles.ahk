#Requires AutoHotkey v2.0

/**
 * Dynamic Profile & Macro Execution Engine — My Mouse My Choice
 * Supports customizable button mappings and keyboard combinations per profile,
 * persisted via settings.ini.
 */
class ProfileEngine {
    static Profiles := ["Desktop"]
    static CurrentProfile := "Desktop"
    static AutoSwitchEnabled := true
    static LockedProfile := ""
    static LastActiveProcess := ""
    static AutoSwitchTimerFn := ""
    static IsMasterSuspended := false
    static OnMasterSuspensionChanged := ""

    ; Profile Metadata: Map(profileName, { TargetExe: "...", Icon: "...", IsDefault: bool, SwitchOnHover: bool, FocusOnHover: bool, OsdIconOnly: bool, Desc: "..." })
    static ProfileMetadata := Map(
        "Desktop",      { TargetExe: "", Icon: "desktop", IsDefault: true, SwitchOnHover: false, FocusOnHover: false, OsdIconOnly: false, Desc: "Default System & Desktop Profile" }
    )

    static IsGShiftActive := false
    static IsGShift1Active := false
    static IsGShift2Active := false
    static ShiftHolders := Map()
    static ButtonDispatchedLayer := Map()
    static CurrentLayer => (this.IsGShift2Active ? "GShift2" : ((this.IsGShift1Active || this.IsGShiftActive) ? "GShift" : "Normal"))
    static OnShiftStateChanged := ""
    static RapidFireEnabled := false
    static RapidFireActive := false
    static RapidFireInterval := 50 ; ms (~20 CPS)
    static MuteWhenStudioFocused := true
    static DefaultHardwareFKeys := Map(
        "Middle", "F13",
        "Back", "F14",
        "DpiShift", "F15",
        "Forward", "F16",
        "TiltLeft", "F17",
        "TiltRight", "F18",
        "ProfileCycle", "F19",
        "G8", "F20",
        "G7", "F21"
    )
    static ButtonToFKeyMap := Map()
    static FKeyToButtonMap := Map()

    ; Macro execution states
    static ActiveHoldTimers := Map()
    static ActiveToggleTimers := Map()
    static ActiveSequences := Map()
    static SequenceTokens := Map()
    static NextSeqToken := 0
    static PhysicalButtonStates := Map()
    static ActiveHeldButtons := Map()
    static ActiveHeldPressTimes := Map()
    static GameKeyDelay := 20
    static ExecutingMacroCount := 0
    static IsExecutingMacro := false

    ; Callback for GUI updates
    static OnProfileChanged := ""
    static OnButtonStateChanged := ""
    static OnProfilesListChanged := ""

    ; Default Mappings for all 4 profiles
    static DefaultMappings := Map(
        "Desktop", Map(
            "TiltLeft",     { Normal: { Type: "Send", Cmd: "^+{Tab}", Label: "Prev Browser Tab" }, GShift: { Type: "Send", Cmd: "#{Left}", Label: "Snap Win Left" } },
            "TiltRight",    { Normal: { Type: "Send", Cmd: "^{Tab}", Label: "Next Browser Tab" }, GShift: { Type: "Send", Cmd: "#{Right}", Label: "Snap Win Right" } },
            "Middle",       { Normal: { Type: "Send", Cmd: "{MButton}", Label: "Middle Click" }, GShift: { Type: "Send", Cmd: "^w", Label: "Close Tab" } },
            "G8",           { Normal: { Type: "Send", Cmd: "{Volume_Up 2}", Label: "Volume Up" }, GShift: { Type: "Send", Cmd: "#{Up}", Label: "Maximize Win" } },
            "G7",           { Normal: { Type: "Send", Cmd: "{Volume_Down 2}", Label: "Volume Down" }, GShift: { Type: "Send", Cmd: "#{Down}", Label: "Minimize Win" } },
            "DpiShift",     { Normal: { Type: "Default", Cmd: "", Label: "DPI Shift" }, GShift: { Type: "Default", Cmd: "", Label: "Default" } },
            "Forward",      { Normal: { Type: "Send", Cmd: "!{Right}", Label: "Browser Forward" }, GShift: { Type: "Send", Cmd: "^w", Label: "Close Tab" } },
            "Back",         { Normal: { Type: "Send", Cmd: "!{Left}", Label: "Browser Back" }, GShift: { Type: "Send", Cmd: "^+t", Label: "Reopen Tab" } },
            "ProfileCycle", { Normal: { Type: "Special", Cmd: "CycleProfile", Label: "Next Profile" }, GShift: { Type: "Special", Cmd: "CycleProfile", Label: "Next Profile" } },
            "WheelUp",      { Normal: { Type: "Default", Cmd: "{WheelUp}", Label: "Default Scroll Up" }, GShift: { Type: "Send", Cmd: "{Volume_Up 2}", Label: "Volume Up" } },
            "WheelDown",    { Normal: { Type: "Default", Cmd: "{WheelDown}", Label: "Default Scroll Down" }, GShift: { Type: "Send", Cmd: "{Volume_Down 2}", Label: "Volume Down" } },
            "LeftClick",    { Normal: { Type: "Default", Cmd: "{LButton}", Label: "Left Click" }, GShift: { Type: "Default", Cmd: "{LButton}", Label: "Default Left Click" } },
            "RightClick",   { Normal: { Type: "Default", Cmd: "{RButton}", Label: "Right Click" }, GShift: { Type: "Default", Cmd: "{RButton}", Label: "Default Right Click" } }
        )
    )

    ; Runtime active custom mappings: Map(ProfileName, Map(BtnId, { Normal: {...}, GShift: {...} }))
    static ActiveMappings := Map()

    static Init(iniPath) {
        this.ConfigPath := iniPath
        this.LoadAllMappings()
        this.StartAutoSwitchTimer()
    }

    static LoadAllMappings() {
        ; Load Profile List & Options from settings.ini
        try {
            savedList := IniRead(this.ConfigPath, "Profiles", "List", "")
            if (savedList != "") {
                arr := StrSplit(savedList, ",")
                loadedList := []
                for item in arr {
                    pName := Trim(item)
                    if (pName != "")
                        loadedList.Push(pName)
                }
                if (loadedList.Length > 0)
                    this.Profiles := loadedList
            }
            this.AutoSwitchEnabled := (IniRead(this.ConfigPath, "Profiles", "AutoSwitchEnabled", "1") = "1")
            this.LockedProfile := IniRead(this.ConfigPath, "Profiles", "LockedProfile", "")
            OSD.Enabled := (IniRead(this.ConfigPath, "Settings", "ShowOSD", "1") = "1")
            this.MuteWhenStudioFocused := (IniRead(this.ConfigPath, "Settings", "MuteWhenFocused", "1") = "1")
            this.GameKeyDelay := Integer(IniRead(this.ConfigPath, "General", "GameKeyDelay", "20"))
        }

        ; Load metadata for each profile
        for prof in this.Profiles {
            if (!this.ProfileMetadata.Has(prof)) {
                this.ProfileMetadata[prof] := { TargetExe: "", Icon: (prof = "Desktop" ? "desktop" : "auto"), IsDefault: (prof = "Desktop"), SwitchOnHover: false, FocusOnHover: false, OsdIconOnly: false, Desc: prof . " Profile" }
            }
            sec := "Profile_" . prof
            try {
                savedExe := IniRead(this.ConfigPath, sec, "TargetExe", this.ProfileMetadata[prof].TargetExe)
                savedIcon := IniRead(this.ConfigPath, sec, "Icon", this.ProfileMetadata[prof].Icon)
                savedDef := (IniRead(this.ConfigPath, sec, "IsDefault", this.ProfileMetadata[prof].IsDefault ? "1" : "0") = "1")
                savedHover := (IniRead(this.ConfigPath, sec, "SwitchOnHover", "0") = "1")
                savedFocusHover := (IniRead(this.ConfigPath, sec, "FocusOnHover", "0") = "1")
                savedOsdIconOnly := (IniRead(this.ConfigPath, sec, "OsdIconOnly", "0") = "1")
                this.ProfileMetadata[prof].TargetExe := savedExe
                if (prof != "Desktop" && (savedIcon == "generic" || savedIcon == ""))
                    savedIcon := "auto"
                this.ProfileMetadata[prof].Icon := savedIcon
                this.ProfileMetadata[prof].IsDefault := savedDef
                this.ProfileMetadata[prof].SwitchOnHover := savedHover
                this.ProfileMetadata[prof].FocusOnHover := savedFocusHover
                this.ProfileMetadata[prof].OsdIconOnly := savedOsdIconOnly
            }
            this.EnsureProfileIcon(prof, this.ProfileMetadata[prof].TargetExe)
        }

        ; Load Hardware F-Key assignments (enforcing strict 1-to-1 uniqueness)
        this.ButtonToFKeyMap := Map()
        this.FKeyToButtonMap := Map()
        for btnId, defFKey in this.DefaultHardwareFKeys {
            assignedFKey := IniRead(this.ConfigPath, "HardwareFKeys", btnId, defFKey)
            if (assignedFKey != "" && !this.FKeyToButtonMap.Has(assignedFKey)) {
                this.ButtonToFKeyMap[btnId] := assignedFKey
                this.FKeyToButtonMap[assignedFKey] := btnId
            }
        }
        ; Load custom button hardware key assignments
        try {
            customBtns := this.LoadCustomButtons()
            for btn in customBtns {
                bId := btn.Has("id") ? btn["id"] : ""
                if (bId != "" && btn.Has("hardwareKey") && btn["hardwareKey"] != "") {
                    hKey := btn["hardwareKey"]
                    ; If duplicate key found, revoke it from the previous button
                    if (this.FKeyToButtonMap.Has(hKey)) {
                        oldB := this.FKeyToButtonMap[hKey]
                        if (oldB != bId && this.ButtonToFKeyMap.Has(oldB)) {
                            this.ButtonToFKeyMap.Delete(oldB)
                        }
                    }
                    this.ButtonToFKeyMap[bId] := hKey
                    this.FKeyToButtonMap[hKey] := bId
                }
            }
        }

        for profile in this.Profiles {
            if (!this.ActiveMappings.Has(profile))
                this.ActiveMappings[profile] := Map()

            defaults := this.DefaultMappings.Has(profile) ? this.DefaultMappings[profile] : this.DefaultMappings["Desktop"]
            for btnId, def in defaults {
                section := "Mapping_" . profile . "_" . btnId
                
                ; Load Normal
                normType := IniRead(this.ConfigPath, section, "Normal_Type", def.Normal.Type)
                normCmd  := IniRead(this.ConfigPath, section, "Normal_Cmd", def.Normal.Cmd)
                normLbl  := this.CleanLabel(IniRead(this.ConfigPath, section, "Normal_Label", def.Normal.Label))
                normPlay := IniRead(this.ConfigPath, section, "Normal_PlayType", "NoRepeat")
                normInt  := Integer(IniRead(this.ConfigPath, section, "Normal_RepeatInterval", "50"))
                normStepsStr    := IniRead(this.ConfigPath, section, "Normal_Steps", "")
                normSeqPressStr := IniRead(this.ConfigPath, section, "Normal_SeqPress", "")
                normSeqHoldStr  := IniRead(this.ConfigPath, section, "Normal_SeqHold", "")
                normSeqRelStr   := IniRead(this.ConfigPath, section, "Normal_SeqRelease", "")

                ; Load GShift
                gsType   := IniRead(this.ConfigPath, section, "GShift_Type", def.GShift.Type)
                gsCmd    := IniRead(this.ConfigPath, section, "GShift_Cmd", def.GShift.Cmd)
                gsLbl    := this.CleanLabel(IniRead(this.ConfigPath, section, "GShift_Label", def.GShift.Label))
                gsPlay   := IniRead(this.ConfigPath, section, "GShift_PlayType", "NoRepeat")
                gsInt    := Integer(IniRead(this.ConfigPath, section, "GShift_RepeatInterval", "50"))
                gsStepsStr    := IniRead(this.ConfigPath, section, "GShift_Steps", "")
                gsSeqPressStr := IniRead(this.ConfigPath, section, "GShift_SeqPress", "")
                gsSeqHoldStr  := IniRead(this.ConfigPath, section, "GShift_SeqHold", "")
                gsSeqRelStr   := IniRead(this.ConfigPath, section, "GShift_SeqRelease", "")

                ; Load GShift2
                gs2Type   := IniRead(this.ConfigPath, section, "GShift2_Type", def.Normal.Type)
                gs2Cmd    := IniRead(this.ConfigPath, section, "GShift2_Cmd", def.Normal.Cmd)
                gs2Lbl    := this.CleanLabel(IniRead(this.ConfigPath, section, "GShift2_Label", def.Normal.Label))
                gs2Play   := IniRead(this.ConfigPath, section, "GShift2_PlayType", "NoRepeat")
                gs2Int    := Integer(IniRead(this.ConfigPath, section, "GShift2_RepeatInterval", "50"))
                gs2StepsStr    := IniRead(this.ConfigPath, section, "GShift2_Steps", "")
                gs2SeqPressStr := IniRead(this.ConfigPath, section, "GShift2_SeqPress", "")
                gs2SeqHoldStr  := IniRead(this.ConfigPath, section, "GShift2_SeqHold", "")
                gs2SeqRelStr   := IniRead(this.ConfigPath, section, "GShift2_SeqRelease", "")

                if (normType = "Text") {
                    normCmd := StrReplace(normCmd, "\n", "`n")
                    normCmd := StrReplace(normCmd, "\\", "\")
                }
                if (gsType = "Text") {
                    gsCmd := StrReplace(gsCmd, "\n", "`n")
                    gsCmd := StrReplace(gsCmd, "\\", "\")
                }
                if (gs2Type = "Text") {
                    gs2Cmd := StrReplace(gs2Cmd, "\n", "`n")
                    gs2Cmd := StrReplace(gs2Cmd, "\\", "\")
                }

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

    static CleanLabel(str) {
        if (!InStr(str, "<svg") && !InStr(str, "⚡") && !InStr(str, "? B-Shift"))
            return str
        cleaned := RegExReplace(str, "<svg[^>]*>.*?</svg>", "")
        cleaned := RegExReplace(cleaned, "[⚡\?]", "")
        cleaned := Trim(cleaned)
        return (cleaned != "") ? cleaned : "B-Shift 1 Layer"
    }

    static SaveButtonLayer(profile, btnId, layer, actionObj) {
        if (!this.ActiveMappings.Has(profile))
            this.ActiveMappings[profile] := Map()

        ; B-Shift layer modifiers always belong to the Normal layer
        if (actionObj.HasOwnProp("Type") && actionObj.Type = "Special" && (actionObj.Cmd = "GShift1" || actionObj.Cmd = "GShift2" || actionObj.Cmd = "GShift")) {
            layer := "Normal"
        }

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
            savedCmd := actionObj.Cmd
            if (actionObj.HasOwnProp("Type") && actionObj.Type = "Text") {
                savedCmd := StrReplace(savedCmd, "\", "\\")
                savedCmd := StrReplace(savedCmd, "`r`n", "\n")
                savedCmd := StrReplace(savedCmd, "`n", "\n")
                savedCmd := StrReplace(savedCmd, "`r", "\n")
            }
            IniWrite(savedCmd, this.ConfigPath, section, prefix . "Cmd")
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
            if (!IsObject(s))
                continue
            act := "Down"
            key := ""
            del := 50
            if (Type(s) = "Map") {
                act := s.Has("Action") ? s["Action"] : (s.Has("action") ? s["action"] : "Down")
                key := s.Has("Key") ? s["Key"] : (s.Has("key") ? s["key"] : "")
                del := s.Has("Delay") ? Integer(s["Delay"]) : (s.Has("delay") ? Integer(s["delay"]) : 50)
            } else {
                act := s.HasOwnProp("Action") ? s.Action : (s.HasOwnProp("action") ? s.action : "Down")
                key := s.HasOwnProp("Key") ? s.Key : (s.HasOwnProp("key") ? s.key : "")
                del := s.HasOwnProp("Delay") ? Integer(s.Delay) : (s.HasOwnProp("delay") ? Integer(s.delay) : 50)
            }
            if (key = "")
                continue
            actChar := (act = "Down" || act = "D") ? "D" : "U"
            part := actChar . ":" . key . ":" . del
            str .= (str = "" ? "" : "|") . part
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
        defProfile := this.DefaultMappings.Has(profile) ? profile : "Desktop"
        if (!this.DefaultMappings.Has(defProfile))
            defProfile := "Desktop"

        if (this.DefaultMappings.Has(defProfile) && this.DefaultMappings[defProfile].Has(btnId)) {
            def := this.DefaultMappings[defProfile][btnId]
            gs2 := def.HasOwnProp("GShift2") ? def.GShift2 : def.Normal
            this.SaveMapping(profile, btnId, def.Normal, def.GShift, gs2)
        }
    }

    static ResetProfileDefaults(profile) {
        defProfile := this.DefaultMappings.Has(profile) ? profile : "Desktop"
        if (!this.DefaultMappings.Has(defProfile))
            defProfile := "Desktop"

        defaults := this.DefaultMappings[defProfile]
        for btnId, def in defaults {
            gs2 := def.HasOwnProp("GShift2") ? def.GShift2 : def.Normal
            this.SaveMapping(profile, btnId, def.Normal, def.GShift, gs2)
        }
    }

    static SaveButtonMapping(profile, btnId, normalObj, gshiftObj, gshift2Obj := "") {
        this.SaveMapping(profile, btnId, normalObj, gshiftObj, gshift2Obj)
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

    static HasProfile(profileName) {
        for p in this.Profiles {
            if (p = profileName)
                return true
        }
        return false
    }

    static SelectProfile(profileName) => this.SetProfile(profileName)

    ; Switch to a specific profile
    static SetProfile(profileName) {
        for p in this.Profiles {
            if (p = profileName) {
                this.StopAllRunningMacros()
                this.CurrentProfile := p
                meta := this.ProfileMetadata.Has(p) ? this.ProfileMetadata[p] : ""
                isIconOnly := (meta && meta.HasOwnProp("OsdIconOnly") && (meta.OsdIconOnly = 1 || meta.OsdIconOnly = true || meta.OsdIconOnly = "1" || meta.OsdIconOnly = "true"))
                if (isIconOnly) {
                    OSD.ShowIcon(this.GetProfileIconPath(p))
                } else {
                    OSD.Show("Profile: " . p, this.GetProfileDescription(p))
                }
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

        this.SequenceTokens.Clear()
        for btnId, seq in this.ActiveSequences {
            if (seq.HasOwnProp("fn") && seq.fn != "")
                SetTimer(seq.fn, 0)
            if (seq.HasOwnProp("act") && IsObject(seq.act) && seq.act.HasOwnProp("SeqRelease") && seq.act.SeqRelease.Length > 0)
                try this.PlaySteps(seq.act.SeqRelease, btnId, 0, true)
        }
        this.ActiveSequences.Clear()

        for btnId, releaseCmd in this.ActiveHeldButtons {
            if (!InStr(releaseCmd, "{"))
                releaseCmd := "{" . releaseCmd . " up}"
            try Send("{Blind}" . releaseCmd)
        }
        this.ActiveHeldButtons.Clear()
        this.ActiveHeldPressTimes.Clear()
        if (!GetKeyState("LButton", "P") && GetKeyState("LButton"))
            try Send("{Blind}{LButton up}")
        if (!GetKeyState("RButton", "P") && GetKeyState("RButton"))
            try Send("{Blind}{RButton up}")
        if (!GetKeyState("MButton", "P") && GetKeyState("MButton"))
            try Send("{Blind}{MButton up}")
        if (!GetKeyState("Shift", "P") && GetKeyState("Shift"))
            try Send("{Blind}{Shift up}")
        if (!GetKeyState("Ctrl", "P") && GetKeyState("Ctrl"))
            try Send("{Blind}{Ctrl up}")
        if (!GetKeyState("Alt", "P") && GetKeyState("Alt"))
            try Send("{Blind}{Alt up}")
        this.PhysicalButtonStates.Clear()
        this.ShiftHolders.Clear()
        this.ButtonDispatchedLayer.Clear()
    }

    static ReleaseAllHeldButtons() {
        this.SequenceTokens.Clear()
        for btnId, seq in this.ActiveSequences {
            if (seq.HasOwnProp("fn") && seq.fn != "")
                SetTimer(seq.fn, 0)
            if (seq.HasOwnProp("act") && IsObject(seq.act) && seq.act.HasOwnProp("SeqRelease") && seq.act.SeqRelease.Length > 0)
                try this.PlaySteps(seq.act.SeqRelease, btnId, 0, true)
        }
        this.ActiveSequences.Clear()

        for btnId, releaseCmd in this.ActiveHeldButtons {
            if (!InStr(releaseCmd, "{"))
                releaseCmd := "{" . releaseCmd . " up}"
            try Send("{Blind}" . releaseCmd)
        }
        this.ActiveHeldButtons.Clear()
        this.ActiveHeldPressTimes.Clear()
        if (!GetKeyState("LButton", "P") && GetKeyState("LButton"))
            try Send("{Blind}{LButton up}")
        if (!GetKeyState("RButton", "P") && GetKeyState("RButton"))
            try Send("{Blind}{RButton up}")
        if (!GetKeyState("MButton", "P") && GetKeyState("MButton"))
            try Send("{Blind}{MButton up}")
        if (!GetKeyState("Shift", "P") && GetKeyState("Shift"))
            try Send("{Blind}{Shift up}")
        if (!GetKeyState("Ctrl", "P") && GetKeyState("Ctrl"))
            try Send("{Blind}{Ctrl up}")
        if (!GetKeyState("Alt", "P") && GetKeyState("Alt"))
            try Send("{Blind}{Alt up}")
    }

    static ToggleMasterSuspension(forceState := "") {
        if (forceState !== "") {
            newState := (forceState = 1 || forceState = true || forceState = "1" || forceState = "true") ? true : false
        } else {
            newState := !this.IsMasterSuspended
        }

        if (newState = this.IsMasterSuspended)
            return

        this.IsMasterSuspended := newState

        if (this.IsMasterSuspended) {
            ; 1. Cleanly stop any running macro sequences, repeat timers, and releases
            this.StopAllRunningMacros()

            ; 2. Stop rapid fire if active
            this.RapidFireActive := false
            if (this.rapidFireFn != "")
                SetTimer(this.rapidFireFn, 0)

            ; 3. Reset shift states and holders
            this.IsGShiftActive := false
            this.IsGShift1Active := false
            this.IsGShift2Active := false
            this.ShiftHolders.Clear()
            if (this.OnShiftStateChanged) {
                try this.OnShiftStateChanged(1, false)
                try this.OnShiftStateChanged(2, false)
            }

            ; 4. Pause background timers
            if (this.AutoSwitchTimerFn != "")
                SetTimer(this.AutoSwitchTimerFn, 0)
            if (FocusFollowsMouse.TimerFn != "")
                SetTimer(FocusFollowsMouse.TimerFn, 0)

            ; 5. Suspend all non-exempt hotkeys in AutoHotkey
            Suspend(1)

            ; 6. Update tray tip
            try A_IconTip := "My Mouse My Choice (STOPPED)"

            ; 7. Sound feedback & notification
            try SoundBeep(450, 160)
            OSD.Show("My Mouse My Choice: STOPPED", "All functions completely suspended (Ctrl+Shift+F4 to Resume)")

            ; 8. WebView IPC & Activity Log
            try WebViewGuiManager.PostMessage(Map("type", "masterSuspendedChanged", "suspended", true))
            WebViewGuiManager.LogActivity("SYSTEM", "App Functions STOPPED / SUSPENDED", "All mouse intercepts, macros & timers are completely disabled (Ctrl+Shift+F4 to Resume)")
        } else {
            ; 1. Unsuspend AutoHotkey hotkeys
            Suspend(0)

            ; 2. Resume auto-switch timer if enabled
            if (this.AutoSwitchEnabled)
                this.StartAutoSwitchTimer()

            ; 3. Resume FocusFollowsMouse
            FocusFollowsMouse.UpdateTimerState()

            ; 4. Update tray tip
            try A_IconTip := "My Mouse My Choice"

            ; 5. Sound feedback & notification
            try SoundBeep(920, 160)
            OSD.Show("My Mouse My Choice: ACTIVE", "Normal mouse intercepts and macros resumed (Ctrl+Shift+F4)")

            ; 6. WebView IPC & Activity Log
            try WebViewGuiManager.PostMessage(Map("type", "masterSuspendedChanged", "suspended", false))
            WebViewGuiManager.LogActivity("SYSTEM", "App Functions RESUMED / ACTIVE", "Profile: " . this.CurrentProfile . " | All functions fully operational")
        }

        if (this.OnMasterSuspensionChanged) {
            try this.OnMasterSuspensionChanged(this.IsMasterSuspended)
        }
    }

    static SyncShiftState() {
        if (!this.IsGShiftActive && !this.IsGShift1Active && !this.IsGShift2Active && this.ShiftHolders.Count = 0)
            return

        ; If any sequence macro is actively running or a button is currently dispatched on shift,
        ; do NOT prematurely deactivate shift layers!
        if (this.ActiveSequences.Count > 0 || this.ButtonDispatchedLayer.Count > 0 || this.IsExecutingMacro)
            return

        ; Verify all buttons in ShiftHolders are actually physically held
        stuckButtons := []
        for btnId, shiftLayerNum in this.ShiftHolders {
            hwKey := this.ButtonToFKeyMap.Has(btnId) ? this.ButtonToFKeyMap[btnId] : ""
            if (hwKey != "") {
                if (!GetKeyState(hwKey, "P"))
                    stuckButtons.Push(btnId)
            } else {
                ahkKey := (btnId = "Back") ? "XButton1" : ((btnId = "Forward") ? "XButton2" : ((btnId = "Middle") ? "MButton" : ((btnId = "DpiShift") ? "F15" : "")))
                if (ahkKey != "" && !GetKeyState(ahkKey, "P"))
                    stuckButtons.Push(btnId)
            }
        }

        for _, btnId in stuckButtons {
            this.ShiftHolders.Delete(btnId)
        }

        if (this.ShiftHolders.Count = 0) {
            if (this.IsGShiftActive || this.IsGShift1Active || this.IsGShift2Active) {
                this.ReleaseAllShiftModifiers()
            }
        }
    }

    static SyncActiveHeldButtons() {
        ; If any sequence macro is actively running, it manages its own held keys and must not be interrupted!
        if (this.ActiveSequences.Count > 0 || this.IsExecutingMacro)
            return

        if (this.ActiveHeldButtons.Count = 0) {
            ; Check if logical Shift, Ctrl, Alt is stuck down when physically up
            if (!GetKeyState("Shift", "P") && GetKeyState("Shift"))
                try Send("{Blind}{Shift up}")
            if (!GetKeyState("Ctrl", "P") && GetKeyState("Ctrl"))
                try Send("{Blind}{Ctrl up}")
            if (!GetKeyState("Alt", "P") && GetKeyState("Alt"))
                try Send("{Blind}{Alt up}")
            return
        }

        ; If Studio is focused, release all active held buttons immediately
        if (WebViewGuiManager.IsStudioFocused()) {
            this.ReleaseAllHeldButtons()
            return
        }

        ; Check if held buttons are still physically held
        stuck := []
        for btnId, releaseCmd in this.ActiveHeldButtons {
            if (btnId = "LeftClick" && !GetKeyState("LButton", "P"))
                stuck.Push(btnId)
            else if (btnId = "RightClick" && !GetKeyState("RButton", "P"))
                stuck.Push(btnId)
            else if (this.ButtonToFKeyMap.Has(btnId)) {
                hwKey := this.ButtonToFKeyMap[btnId]
                if (!GetKeyState(hwKey, "P"))
                    stuck.Push(btnId)
            }
        }

        for _, btnId in stuck {
            if (this.ActiveHeldButtons.Has(btnId)) {
                releaseCmd := this.ActiveHeldButtons[btnId]
                this.ActiveHeldButtons.Delete(btnId)
                if (!InStr(releaseCmd, "{"))
                    releaseCmd := "{" . releaseCmd . " up}"
                try Send("{Blind}" . releaseCmd)
            }
        }
    }

    static PeriodicMaintenance() {
        if (this.IsExecutingMacro || this.ActiveSequences.Count > 0)
            return
        this.SyncShiftState()
        this.SyncActiveHeldButtons()
        this.CheckActiveWindow()
    }

    static GetProfileDescription(p) {
        if (this.ProfileMetadata.Has(p) && this.ProfileMetadata[p].HasOwnProp("Desc") && this.ProfileMetadata[p].Desc != "")
            return this.ProfileMetadata[p].Desc
        switch p {
            case "Desktop": return "Tabs, Media, Snap Windows & G-Shift"
            case "Productivity": return "VS Code, Undo/Redo, Duplication & Format"
            case "Gaming": return "Rapid Fire, Sniper Aim, Weapon Shortcuts"
            case "Media": return "Track Controls, Volume Wheel & Play/Pause"
            default: return p . " Profile"
        }
    }

    ; =========================================================================
    ; AUTOMATIC PROFILE SWITCHING BY WINDOW FOCUS & HOVER (LGS STYLE)
    ; =========================================================================
    static StartAutoSwitchTimer() {
        if (!this.AutoSwitchTimerFn) {
            this.AutoSwitchTimerFn := () => ProfileEngine.PeriodicMaintenance()
        }
        SetTimer(this.AutoSwitchTimerFn, 100)
    }

    static StopAutoSwitchTimer() {
        if (this.AutoSwitchTimerFn) {
            SetTimer(this.AutoSwitchTimerFn, 0)
        }
    }

    static FindProfileForProcess(procName, requireHoverSwitch := false) {
        if (procName == "")
            return ""
        cleanProc := RegExReplace(procName, "i)\.exe$", "")
        for profName, meta in this.ProfileMetadata {
            if (requireHoverSwitch && (!meta.HasOwnProp("SwitchOnHover") || !meta.SwitchOnHover))
                continue

            ; 1. Match against TargetExe list
            if (meta.TargetExe != "") {
                for exe in StrSplit(meta.TargetExe, [",", ";", "`n", "`r", " "]) {
                    exe := Trim(exe)
                    if (exe == "")
                        continue
                    cleanExe := RegExReplace(exe, "i)\.exe$", "")
                    if (StrCompare(cleanExe, cleanProc, false) == 0) {
                        return profName
                    }
                }
            }
            ; 2. Match if profile name directly matches process name (e.g. "Vivaldi" profile matches vivaldi.exe)
            if (profName != "Desktop" && StrCompare(profName, cleanProc, false) == 0) {
                return profName
            }
        }
        return ""
    }

    static CheckActiveWindow() {
        if (!this.AutoSwitchEnabled || this.LockedProfile != "")
            return
            
        try {
            matchedProfile := ""
            triggerProc := ""

            guiHwnd := (HasProp(WebViewGuiManager, "MainGui") && WebViewGuiManager.MainGui != "") ? WebViewGuiManager.MainGui.Hwnd : 0

            ; 1. First check if mouse is hovering over an app window whose profile has SwitchOnHover enabled
            try {
                MouseGetPos(&mX, &mY, &mHwnd)
                if (mHwnd) {
                    if (!guiHwnd || (mHwnd != guiHwnd && !DllCall("IsChild", "ptr", guiHwnd, "ptr", mHwnd))) {
                        hoverProc := WinGetProcessName(mHwnd)
                        if (hoverProc != "" && hoverProc != "AutoHotkey64.exe" && hoverProc != "msedgewebview2.exe") {
                            hoverProf := this.FindProfileForProcess(hoverProc, true)
                            if (hoverProf != "") {
                                matchedProfile := hoverProf
                                triggerProc := hoverProc . " (hover)"
                            } else {
                                ; If default profile has SwitchOnHover enabled, check if hovering over desktop or unassigned app
                                defProf := "Desktop"
                                for pName, pMeta in this.ProfileMetadata {
                                    if (pMeta.HasOwnProp("IsDefault") && pMeta.IsDefault) {
                                        defProf := pName
                                        break
                                    }
                                }
                                if (this.ProfileMetadata.Has(defProf)) {
                                    defMeta := this.ProfileMetadata[defProf]
                                    if (defMeta.HasOwnProp("SwitchOnHover") && defMeta.SwitchOnHover) {
                                        otherProf := this.FindProfileForProcess(hoverProc, false)
                                        if (otherProf == "") {
                                            matchedProfile := defProf
                                            triggerProc := hoverProc . " (default hover)"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            ; 2. If not hovering over a hover-enabled profile, check active/focused window
            if (matchedProfile == "") {
                activeHwnd := WinExist("A")
                if (!activeHwnd)
                    return
                    
                if (guiHwnd && (activeHwnd == guiHwnd || DllCall("IsChild", "ptr", guiHwnd, "ptr", activeHwnd)))
                    return
                    
                activeProc := WinGetProcessName(activeHwnd)
                if (activeProc == "" || activeProc = "AutoHotkey64.exe" || activeProc = "msedgewebview2.exe")
                    return

                ; Ignore transient shell and system navigation windows:
                winClass := WinGetClass(activeHwnd)
                if (winClass = "Shell_TrayWnd" || winClass = "Shell_SecondaryTrayWnd" || winClass = "Windows.UI.Core.CoreWindow" || winClass = "XamlExplorerHostIslandWindow")
                    return

                if (activeProc = "SearchHost.exe" || activeProc = "StartMenuExperienceHost.exe" || activeProc = "ShellExperienceHost.exe" || activeProc = "MultitaskingView.exe" || activeProc = "dwm.exe")
                    return

                if (activeProc = "explorer.exe" && winClass != "Progman" && winClass != "WorkerW" && winClass != "CabinetWClass")
                    return

                matchedProfile := this.FindProfileForProcess(activeProc, false)
                triggerProc := activeProc . " (focus)"
            }

            ; 3. Fallback to default profile if nothing matched
            if (matchedProfile == "") {
                for profName, meta in this.ProfileMetadata {
                    if (meta.IsDefault) {
                        matchedProfile := profName
                        break
                    }
                }
                if (matchedProfile == "")
                    matchedProfile := "Desktop"
            }
            
            ; 4. Switch if profile changed
            if (matchedProfile != this.CurrentProfile && this.HasProfile(matchedProfile)) {
                this.LastActiveProcess := triggerProc
                WebViewGuiManager.Log("AutoSwitch: " . triggerProc . " -> Switch to Profile: " . matchedProfile . " (was: " . this.CurrentProfile . ")")
                this.SetProfile(matchedProfile)
            }
        } catch as err {
            WebViewGuiManager.Log("Error in CheckActiveWindow: " . err.Message)
        }
    }

    static SaveProfileConfig() {
        if (this.ConfigPath == "")
            return
        listStr := ""
        for i, p in this.Profiles
            listStr .= (i = 1 ? "" : ",") . p
        IniWrite(listStr, this.ConfigPath, "Profiles", "List")
        IniWrite(this.AutoSwitchEnabled ? "1" : "0", this.ConfigPath, "Profiles", "AutoSwitchEnabled")
        IniWrite(this.LockedProfile, this.ConfigPath, "Profiles", "LockedProfile")
        
        for prof in this.Profiles {
            sec := "Profile_" . prof
            if (this.ProfileMetadata.Has(prof)) {
                meta := this.ProfileMetadata[prof]
                IniWrite(meta.TargetExe, this.ConfigPath, sec, "TargetExe")
                IniWrite(meta.Icon, this.ConfigPath, sec, "Icon")
                IniWrite(meta.IsDefault ? "1" : "0", this.ConfigPath, sec, "IsDefault")
                isHover := (meta.HasOwnProp("SwitchOnHover") && (meta.SwitchOnHover = 1 || meta.SwitchOnHover = true || meta.SwitchOnHover = "1" || meta.SwitchOnHover = "true"))
                isFocusHover := (meta.HasOwnProp("FocusOnHover") && (meta.FocusOnHover = 1 || meta.FocusOnHover = true || meta.FocusOnHover = "1" || meta.FocusOnHover = "true"))
                isIconOnly := (meta.HasOwnProp("OsdIconOnly") && (meta.OsdIconOnly = 1 || meta.OsdIconOnly = true || meta.OsdIconOnly = "1" || meta.OsdIconOnly = "true"))
                IniWrite(isHover ? "1" : "0", this.ConfigPath, sec, "SwitchOnHover")
                IniWrite(isFocusHover ? "1" : "0", this.ConfigPath, sec, "FocusOnHover")
                IniWrite(isIconOnly ? "1" : "0", this.ConfigPath, sec, "OsdIconOnly")
                if (meta.HasOwnProp("Desc"))
                    IniWrite(meta.Desc, this.ConfigPath, sec, "Desc")
            }
        }
    }

    static AddProfile(name, targetExe := "", icon := "", switchOnHover := false, osdIconOnly := false, focusOnHover := false) {
        name := Trim(name)
        if (name == "" || this.HasProfile(name))
            return false
            
        this.Profiles.Push(name)
        if (icon == "" || icon == "generic")
            icon := (name = "Desktop") ? "desktop" : "auto"
            
        this.ProfileMetadata[name] := { TargetExe: targetExe, Icon: icon, IsDefault: false, SwitchOnHover: switchOnHover, FocusOnHover: focusOnHover, OsdIconOnly: osdIconOnly, Desc: name . " Profile" }
        
        ; Initialize ActiveMappings for this profile by copying Desktop defaults
        this.ActiveMappings[name] := Map()
        defMap := this.DefaultMappings.Has("Desktop") ? this.DefaultMappings["Desktop"] : Map()
        for btnId, def in defMap {
            this.ActiveMappings[name][btnId] := {
                Normal: { Type: def.Normal.Type, Cmd: def.Normal.Cmd, Label: def.Normal.Label, PlayType: "NoRepeat", RepeatInterval: 50, Steps: [], SeqPress: [], SeqHold: [], SeqRelease: [] },
                GShift: { Type: def.GShift.Type, Cmd: def.GShift.Cmd, Label: def.GShift.Label, PlayType: "NoRepeat", RepeatInterval: 50, Steps: [], SeqPress: [], SeqHold: [], SeqRelease: [] },
                GShift2: { Type: def.Normal.Type, Cmd: def.Normal.Cmd, Label: def.Normal.Label, PlayType: "NoRepeat", RepeatInterval: 50, Steps: [], SeqPress: [], SeqHold: [], SeqRelease: [] }
            }
        }
        
        this.SaveProfileConfig()
        this.EnsureProfileIcon(name, targetExe)
        if (this.OnProfilesListChanged) {
            try this.OnProfilesListChanged()
        }
        return true
    }

    static DeleteProfile(name) {
        name := Trim(name)
        if (name == "Desktop" || !this.HasProfile(name))
            return false
            
        if (this.ProfileMetadata.Has(name) && this.ProfileMetadata[name].IsDefault)
            return false
            
        newProfiles := []
        for p in this.Profiles {
            if (p != name)
                newProfiles.Push(p)
        }
        this.Profiles := newProfiles
        
        if (this.ProfileMetadata.Has(name))
            this.ProfileMetadata.Delete(name)
            
        if (this.ActiveMappings.Has(name))
            this.ActiveMappings.Delete(name)
            
        if (this.CurrentProfile = name)
            this.SetProfile("Desktop")
            
        if (this.ConfigPath != "") {
            try IniDelete(this.ConfigPath, "Profile_" . name)
        }

        this.SaveProfileConfig()
        if (this.OnProfilesListChanged) {
            try this.OnProfilesListChanged()
        }
        return true
    }

    static RenameProfile(oldName, newName) {
        oldName := Trim(oldName)
        newName := Trim(newName)
        if (oldName == "" || newName == "")
            return false
        if (oldName == newName)
            return true
        if (oldName == "Desktop" || (this.ProfileMetadata.Has(oldName) && this.ProfileMetadata[oldName].IsDefault))
            return false
        if (!this.HasProfile(oldName))
            return false
        if (this.HasProfile(newName))
            return false

        ; 1. Update this.Profiles array in place to preserve user ordering
        for idx, p in this.Profiles {
            if (p = oldName) {
                this.Profiles[idx] := newName
                break
            }
        }

        ; 2. Update ProfileMetadata
        if (this.ProfileMetadata.Has(oldName)) {
            meta := this.ProfileMetadata[oldName]
            this.ProfileMetadata.Delete(oldName)
            meta.Desc := newName . " Profile"
            if (meta.HasOwnProp("Icon") && meta.Icon = oldName)
                meta.Icon := newName
            this.ProfileMetadata[newName] := meta
        } else {
            this.ProfileMetadata[newName] := { TargetExe: "", Icon: "auto", IsDefault: false, SwitchOnHover: false, FocusOnHover: false, OsdIconOnly: false, Desc: newName . " Profile" }
        }

        ; 3. Migrate ActiveMappings
        if (this.ActiveMappings.Has(oldName)) {
            mappings := this.ActiveMappings[oldName]
            this.ActiveMappings.Delete(oldName)
            this.ActiveMappings[newName] := mappings
        }

        ; 4. Update CurrentProfile and LockedProfile if active
        if (this.CurrentProfile = oldName)
            this.CurrentProfile := newName
        if (this.LockedProfile = oldName)
            this.LockedProfile := newName

        ; 5. Migrate INI sections
        if (this.ConfigPath != "") {
            try IniDelete(this.ConfigPath, "Profile_" . oldName)
            if (this.ActiveMappings.Has(newName)) {
                for btnId, mapping in this.ActiveMappings[newName] {
                    this.SaveButtonLayer(newName, btnId, "Normal", mapping.Normal)
                    this.SaveButtonLayer(newName, btnId, "GShift", mapping.GShift)
                    if (mapping.HasOwnProp("GShift2") && IsObject(mapping.GShift2))
                        this.SaveButtonLayer(newName, btnId, "GShift2", mapping.GShift2)
                    try IniDelete(this.ConfigPath, "Mapping_" . oldName . "_" . btnId)
                }
            }
        }

        ; 6. Rename profile icon file if one was named after the old profile
        outDir := A_ScriptDir . "\web\icons"
        oldIconPng := outDir . "\" . oldName . ".png"
        newIconPng := outDir . "\" . newName . ".png"
        if (FileExist(oldIconPng) && !FileExist(newIconPng)) {
            try FileMove(oldIconPng, newIconPng, 1)
        }

        this.SaveProfileConfig()
        if (this.OnProfilesListChanged) {
            try this.OnProfilesListChanged()
        }
        if (this.OnProfileChanged && this.CurrentProfile = newName) {
            try this.OnProfileChanged(newName)
        }
        return true
    }

    static UpdateProfile(name, targetExe, icon := "", switchOnHover := -1, osdIconOnly := -1, oldName := "", focusOnHover := -1) {
        name := Trim(name)
        oldName := Trim(oldName)
        
        ; If renaming is requested
        if (oldName != "" && oldName != name && this.HasProfile(oldName)) {
            if (!this.RenameProfile(oldName, name))
                return false
        }
        
        if (!this.HasProfile(name))
            return false
            
        ; The default Desktop profile can never be bound to any executable
        if (name = "Desktop" || (this.ProfileMetadata.Has(name) && this.ProfileMetadata[name].IsDefault))
            targetExe := ""

        if (!this.ProfileMetadata.Has(name))
            this.ProfileMetadata[name] := { TargetExe: targetExe, Icon: (icon != "" ? icon : (name = "Desktop" ? "desktop" : "auto")), IsDefault: (name = "Desktop"), SwitchOnHover: false, FocusOnHover: false, OsdIconOnly: (osdIconOnly != -1 ? (osdIconOnly ? true : false) : false), Desc: name . " Profile" }
        else {
            this.ProfileMetadata[name].TargetExe := targetExe
            if (icon != "")
                this.ProfileMetadata[name].Icon := icon
            if (switchOnHover != -1)
                this.ProfileMetadata[name].SwitchOnHover := (switchOnHover = 1 || switchOnHover = true || switchOnHover = "1" || switchOnHover = "true") ? true : false
            if (focusOnHover != -1)
                this.ProfileMetadata[name].FocusOnHover := (focusOnHover = 1 || focusOnHover = true || focusOnHover = "1" || focusOnHover = "true") ? true : false
            if (osdIconOnly != -1)
                this.ProfileMetadata[name].OsdIconOnly := (osdIconOnly = 1 || osdIconOnly = true || osdIconOnly = "1" || osdIconOnly = "true") ? true : false
        }
        
        this.SaveProfileConfig()
        this.EnsureProfileIcon(name, targetExe)
        if (this.OnProfilesListChanged) {
            try this.OnProfilesListChanged()
        }
        return true
    }

    /**
     * Creates a new profile bound to the currently focused application window.
     * Triggered via global shortcut: Ctrl + Shift + F2
     * Disallows duplicates, system processes, or unrecognized applications.
     */
    static CreateProfileFromActiveWindow() => this.CreateProfileFromFocusedWindow()

    static CreateProfileFromFocusedWindow() {
        activeHwnd := WinExist("A")
        if (!activeHwnd) {
            try SoundBeep(600, 100)
            OSD.Show("No Active Window", "Could not detect focused application.", 2500)
            return false
        }

        ; Do not create profile for My Mouse My Choice itself
        guiHwnd := (HasProp(WebViewGuiManager, "MainGui") && WebViewGuiManager.MainGui != "") ? WebViewGuiManager.MainGui.Hwnd : 0
        if (guiHwnd && (activeHwnd == guiHwnd || DllCall("IsChild", "ptr", guiHwnd, "ptr", activeHwnd))) {
            try SoundBeep(600, 100)
            OSD.Show("My Mouse My Choice Focused", "Switch to an external application window to create a profile.", 3000)
            return false
        }

        classicHwnd := (HasProp(GuiManager, "MainGui") && GuiManager.MainGui != "") ? GuiManager.MainGui.Hwnd : 0
        if (classicHwnd && (activeHwnd == classicHwnd || DllCall("IsChild", "ptr", classicHwnd, "ptr", activeHwnd))) {
            try SoundBeep(600, 100)
            OSD.Show("My Mouse My Choice Focused", "Switch to an external application window to create a profile.", 3000)
            return false
        }

        procName := ""
        try procName := WinGetProcessName(activeHwnd)
        fullPath := ""
        try fullPath := WinGetProcessPath(activeHwnd)
        winClass := ""
        try winClass := WinGetClass(activeHwnd)

        ; Resolve UWP applications hosted inside ApplicationFrameHost
        if (procName = "ApplicationFrameHost.exe") {
            try {
                childHwnd := DllCall("FindWindowEx", "ptr", activeHwnd, "ptr", 0, "str", "Windows.UI.Core.CoreWindow", "ptr", 0, "ptr")
                if (childHwnd) {
                    realProc := WinGetProcessName(childHwnd)
                    if (realProc != "" && realProc != "ApplicationFrameHost.exe") {
                        procName := realProc
                        try fullPath := WinGetProcessPath(childHwnd)
                    }
                }
            }
        }

        ; Validate if application can be recognized
        if (procName == "" || !RegExMatch(procName, "i)\.exe$")) {
            try SoundBeep(600, 100)
            OSD.Show("Unrecognized App", "Focused window does not belong to a recognizable application.", 3000)
            return false
        }

        ; Disallow Windows system, shell, and internal host processes
        isSystemProc := (
            procName = "AutoHotkey64.exe" || procName = "msedgewebview2.exe" ||
            procName = "G502X_Studio.exe" || procName = "MyMouseMyChoice.exe" || procName = "My_Mouse_My_Choice.exe" ||
            procName = "SearchHost.exe" || procName = "StartMenuExperienceHost.exe" ||
            procName = "ShellExperienceHost.exe" || procName = "MultitaskingView.exe" ||
            procName = "dwm.exe" || procName = "TextInputHost.exe" || procName = "LockApp.exe" ||
            procName = "SystemSettings.exe" ||
            (procName = "explorer.exe" && (winClass = "Shell_TrayWnd" || winClass = "Shell_SecondaryTrayWnd" || winClass = "Progman" || winClass = "WorkerW")) ||
            winClass = "Windows.UI.Core.CoreWindow" || winClass = "XamlExplorerHostIslandWindow"
        )
        if (isSystemProc) {
            try SoundBeep(600, 100)
            OSD.Show("Unrecognized App", "Cannot create a profile for Windows system shell (" . procName . ").", 3000)
            return false
        }

        ; 1. Check if an existing profile is already bound to this executable
        existingByExe := this.FindProfileForProcess(procName, false)
        if (existingByExe != "" && existingByExe != "Desktop") {
            this.SetProfile(existingByExe)
            try SoundBeep(900, 70)
            Sleep(30)
            try SoundBeep(1100, 90)
            OSD.Show("Profile Already Exists", "Switched to '" . existingByExe . "' (bound to " . procName . ").", 3500)
            return false
        }

        ; 2. Derive human-friendly clean profile name (e.g. Notepad.exe -> Notepad)
        cleanName := RegExReplace(procName, "i)\.exe$", "")
        if (StrLen(cleanName) > 1) {
            cleanName := StrUpper(SubStr(cleanName, 1, 1)) . SubStr(cleanName, 2)
        }

        ; Check if a profile with this clean name already exists
        if (this.HasProfile(cleanName)) {
            this.SetProfile(cleanName)
            try SoundBeep(900, 70)
            Sleep(30)
            try SoundBeep(1100, 90)
            OSD.Show("Profile Already Exists", "Switched to existing profile: " . cleanName, 3500)
            return false
        }

        ; Extract icon from application executable
        iconName := "auto"
        if (fullPath != "" && FileExist(fullPath)) {
            try iconName := this.EnsureExeIconDirect(fullPath, cleanName)
        }

        ; Create the new profile
        success := this.AddProfile(cleanName, procName, iconName, false, false)
        if (!success) {
            try SoundBeep(600, 100)
            OSD.Show("Creation Failed", "Could not create profile '" . cleanName . "'.", 3000)
            return false
        }

        ; Switch to newly created profile
        this.SetProfile(cleanName)
        try WebViewGuiManager.SendProfilesUpdated()
        if (this.OnProfilesListChanged) {
            try this.OnProfilesListChanged()
        }

        ; Victorious double-beep audio confirmation and HUD notification
        try SoundBeep(1000, 70)
        Sleep(30)
        try SoundBeep(1400, 110)
        OSD.Show("✨ New Profile Created", cleanName . " • Bound to " . procName, 4000)
        return true
    }

    static CopyProfileMappings(fromProfile, toProfile) {
        if (!this.ActiveMappings.Has(fromProfile) || !this.HasProfile(toProfile))
            return false

        fromMap := this.ActiveMappings[fromProfile]
        if (!this.ActiveMappings.Has(toProfile))
            this.ActiveMappings[toProfile] := Map()

        for btnId, mapping in fromMap {
            norm := mapping.Normal.Clone()
            gs := mapping.GShift.Clone()
            gs2 := (mapping.HasOwnProp("GShift2") && IsObject(mapping.GShift2)) ? mapping.GShift2.Clone() : norm.Clone()
            this.SaveButtonLayer(toProfile, btnId, "Normal", norm)
            this.SaveButtonLayer(toProfile, btnId, "GShift", gs)
            this.SaveButtonLayer(toProfile, btnId, "GShift2", gs2)
        }
        return true
    }

    static CopySingleButtonMapping(fromProfile, toProfile, fromBtnId := "", toBtnId := "", mappingPayload := "") {
        ; Legacy 3-arg support: CopySingleButtonMapping(profile, fromBtnId, toBtnId)
        if (toBtnId == "" && mappingPayload == "") {
            toBtnId := fromBtnId
            fromBtnId := toProfile
            toProfile := fromProfile
        }

        if (!this.HasProfile(toProfile))
            return false

        ; 1. If mapping payload was directly provided as a Map/object
        if (IsObject(mappingPayload)) {
            norm := (mappingPayload.Has("Normal") && IsObject(mappingPayload["Normal"])) ? mappingPayload["Normal"] : Map("Type", "Default", "Cmd", "", "Label", "Default")
            gs := (mappingPayload.Has("GShift") && IsObject(mappingPayload["GShift"])) ? mappingPayload["GShift"] : norm
            gs2 := (mappingPayload.Has("GShift2") && IsObject(mappingPayload["GShift2"])) ? mappingPayload["GShift2"] : norm

            this.SaveButtonLayer(toProfile, toBtnId, "Normal", norm)
            this.SaveButtonLayer(toProfile, toBtnId, "GShift", gs)
            this.SaveButtonLayer(toProfile, toBtnId, "GShift2", gs2)
            return true
        }

        ; 2. Or copy across ActiveMappings
        if (!this.ActiveMappings.Has(fromProfile) || !this.ActiveMappings[fromProfile].Has(fromBtnId))
            return false

        fromMapping := this.ActiveMappings[fromProfile][fromBtnId]
        norm := fromMapping.Normal.Clone()
        gs := fromMapping.GShift.Clone()
        gs2 := (fromMapping.HasOwnProp("GShift2") && IsObject(fromMapping.GShift2)) ? fromMapping.GShift2.Clone() : norm.Clone()

        this.SaveButtonLayer(toProfile, toBtnId, "Normal", norm)
        this.SaveButtonLayer(toProfile, toBtnId, "GShift", gs)
        this.SaveButtonLayer(toProfile, toBtnId, "GShift2", gs2)
        return true
    }

    static SwapHardwareFKeys(btnId1, btnId2) {
        if (btnId1 == "" || btnId2 == "")
            return false

        fKey1 := this.ButtonToFKeyMap.Has(btnId1) ? this.ButtonToFKeyMap[btnId1] : ""
        fKey2 := this.ButtonToFKeyMap.Has(btnId2) ? this.ButtonToFKeyMap[btnId2] : ""

        if (fKey1 == "" && fKey2 == "")
            return false

        ; Remove old mappings
        if (this.ButtonToFKeyMap.Has(btnId1)) {
            this.ButtonToFKeyMap.Delete(btnId1)
            IniDelete(this.ConfigPath, "HardwareFKeys", btnId1)
        }
        if (fKey1 != "" && this.FKeyToButtonMap.Has(fKey1)) {
            this.FKeyToButtonMap.Delete(fKey1)
        }

        if (this.ButtonToFKeyMap.Has(btnId2)) {
            this.ButtonToFKeyMap.Delete(btnId2)
            IniDelete(this.ConfigPath, "HardwareFKeys", btnId2)
        }
        if (fKey2 != "" && this.FKeyToButtonMap.Has(fKey2)) {
            this.FKeyToButtonMap.Delete(fKey2)
        }

        ; Reassign fKey2 to btnId1
        if (fKey2 != "") {
            this.ButtonToFKeyMap[btnId1] := fKey2
            this.FKeyToButtonMap[fKey2] := btnId1
            IniWrite(fKey2, this.ConfigPath, "HardwareFKeys", btnId1)
            IniWrite(fKey2, this.ConfigPath, "Button_" . btnId1, "Key")
        } else {
            IniWrite("", this.ConfigPath, "Button_" . btnId1, "Key")
        }

        ; Reassign fKey1 to btnId2
        if (fKey1 != "") {
            this.ButtonToFKeyMap[btnId2] := fKey1
            this.FKeyToButtonMap[fKey1] := btnId2
            IniWrite(fKey1, this.ConfigPath, "HardwareFKeys", btnId2)
            IniWrite(fKey1, this.ConfigPath, "Button_" . btnId2, "Key")
        } else {
            IniWrite("", this.ConfigPath, "Button_" . btnId2, "Key")
        }

        return true
    }

    static SetHardwareFKey(btnId, newFKey) {
        if (btnId == "")
            return false

        ; Enforce strict 1-to-1 uniqueness: remove newFKey from any other button that has it
        if (newFKey != "") {
            for b, k in this.ButtonToFKeyMap {
                if (k == newFKey && b != btnId) {
                    this.ButtonToFKeyMap.Delete(b)
                    IniDelete(this.ConfigPath, "HardwareFKeys", b)
                    IniWrite("", this.ConfigPath, "Button_" . b, "Key")
                    break
                }
            }
            if (this.FKeyToButtonMap.Has(newFKey)) {
                this.FKeyToButtonMap.Delete(newFKey)
            }
        }

        ; Remove old key from btnId
        if (this.ButtonToFKeyMap.Has(btnId)) {
            oldKey := this.ButtonToFKeyMap[btnId]
            this.ButtonToFKeyMap.Delete(btnId)
            if (this.FKeyToButtonMap.Has(oldKey)) {
                this.FKeyToButtonMap.Delete(oldKey)
            }
            IniDelete(this.ConfigPath, "HardwareFKeys", btnId)
        }

        ; Assign new key
        if (newFKey != "") {
            this.ButtonToFKeyMap[btnId] := newFKey
            this.FKeyToButtonMap[newFKey] := btnId
            IniWrite(newFKey, this.ConfigPath, "HardwareFKeys", btnId)
            IniWrite(newFKey, this.ConfigPath, "Button_" . btnId, "Key")
        } else {
            IniWrite("", this.ConfigPath, "Button_" . btnId, "Key")
        }

        return true
    }

    static GetHardwareFKeysExport() {
        out := Map()
        for btnId, fKey in this.ButtonToFKeyMap {
            out[btnId] := fKey
        }
        return out
    }

    static EnsureExeIconDirect(fullPath, profName) {
        if (!FileExist(fullPath))
            return "generic"
        outDir := A_ScriptDir . "\web\icons"
        if (!DirExist(outDir)) {
            try DirCreate(outDir)
        }
        outPng := outDir . "\" . profName . ".png"
        this.ExtractExeIcon(fullPath, outPng)
        return FileExist(outPng) ? profName : "generic"
    }

    static EnsureProfileIcon(profName, targetExe) {
        if (profName = "Desktop")
            return
        outDir := A_ScriptDir . "\web\icons"
        if (!DirExist(outDir)) {
            try DirCreate(outDir)
        }
        
        fullPath := this.ResolveExePath(targetExe)
        if (fullPath != "" && FileExist(fullPath)) {
            outPng := outDir . "\" . profName . ".png"
            this.ExtractExeIcon(fullPath, outPng)

            SplitPath(fullPath, &eFile, , , &eNameNoExt)
            cleanPng := outDir . "\" . eNameNoExt . ".png"
            if (!FileExist(cleanPng)) {
                this.ExtractExeIcon(fullPath, cleanPng)
            }
        }
    }

    static GetProfileIconPath(p) {
        outDir := A_ScriptDir . "\web\icons"
        profPng := outDir . "\" . p . ".png"
        if (FileExist(profPng))
            return profPng

        if (this.ProfileMetadata.Has(p)) {
            meta := this.ProfileMetadata[p]

            ; 1. Custom icon or named icon in web/icons
            iconVal := meta.HasOwnProp("Icon") ? meta.Icon : ""
            if (iconVal != "" && iconVal != "generic" && iconVal != "auto" && iconVal != "desktop") {
                customPng := outDir . "\" . iconVal . ".png"
                if (FileExist(customPng))
                    return customPng
            }

            ; 2. Target executable icon
            targetExe := meta.HasOwnProp("TargetExe") ? meta.TargetExe : ""
            if (targetExe != "") {
                for part in StrSplit(targetExe, ",") {
                    clean := Trim(part)
                    if (clean == "")
                        continue
                    SplitPath(clean, &cFile, , , &cName)
                    cleanPng := outDir . "\" . cName . ".png"
                    if (FileExist(cleanPng))
                        return cleanPng

                    resolved := this.ResolveExePath(clean)
                    if (resolved != "" && FileExist(resolved)) {
                        this.EnsureProfileIcon(p, resolved)
                        if (FileExist(profPng))
                            return profPng
                        if (FileExist(cleanPng))
                            return cleanPng
                        return resolved
                    }
                }
            }
        }

        ; 3. Fallbacks
        if (FileExist(A_ScriptDir . "\assets\app.png"))
            return A_ScriptDir . "\assets\app.png"
        if (FileExist(A_ScriptDir . "\assets\app.ico"))
            return A_ScriptDir . "\assets\app.ico"
        return ""
    }

    static SaveImageAsPng(sourcePath, outPng) {
        try {
            outDir := A_ScriptDir . "\web\icons"
            if (!DirExist(outDir))
                try DirCreate(outDir)
            SplitPath(sourcePath, , , &ext)
            extLower := StrLower(ext)
            if (extLower = "png") {
                FileCopy(sourcePath, outPng, 1)
                return FileExist(outPng) ? true : false
            }
            if (extLower = "exe" || extLower = "ico") {
                return this.ExtractExeIcon(sourcePath, outPng)
            }
            ; For JPG / JPEG / BMP / other image files: load with GDI+ and save as PNG
            if (!GdipHelper.Init())
                return false
            pBitmap := 0
            DllCall("gdiplus\GdipCreateBitmapFromFile", "WStr", sourcePath, "Ptr*", &pBitmap)
            if (pBitmap) {
                clsidPng := Buffer(16)
                DllCall("ole32\CLSIDFromString", "Str", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "Ptr", clsidPng.Ptr)
                DllCall("gdiplus\GdipSaveImageToFile", "Ptr", pBitmap, "Str", outPng, "Ptr", clsidPng.Ptr, "Ptr", 0)
                DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)
            }
            return FileExist(outPng) ? true : false
        } catch {
            return false
        }
    }

    static ResolveExePath(exePathOrName) {
        exePathOrName := Trim(exePathOrName)
        if (exePathOrName == "")
            return ""

        ; If multiple executables are comma-separated, try each until one is found
        if (InStr(exePathOrName, ",")) {
            for part in StrSplit(exePathOrName, ",") {
                p := this.ResolveExePath(Trim(part))
                if (p != "")
                    return p
            }
            return ""
        }

        exeClean := Trim(exePathOrName, ' "`t')
        if (FileExist(exeClean))
            return exeClean

        cleanName := RegExReplace(exePathOrName, "i)\.exe$", "") . ".exe"
        cleanBase := RegExReplace(cleanName, "i)\.exe$", "")

        ; 1. Active running process path
        try {
            pid := ProcessExist(cleanName)
            if (pid) {
                p := ProcessGetPath(pid)
                p := Trim(p, ' "`t')
                if (FileExist(p))
                    return p
            }
        }

        ; 2. Windows App Paths registry keys (HKLM, HKCU, and WOW6432Node)
        regKeys := [
            "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\" . cleanName,
            "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\" . cleanName,
            "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\" . cleanName,
            "HKEY_CURRENT_USER\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\" . cleanName
        ]
        for rk in regKeys {
            try {
                p := RegRead(rk, "")
                p := Trim(p, ' "`t')
                if (p != "" && FileExist(p))
                    return p
            }
        }

        ; 3. Common installation directories
        progFilesX86 := EnvGet("ProgramFiles(x86)")
        if (progFilesX86 == "")
            progFilesX86 := "C:\Program Files (x86)"

        candidates := [
            "C:\Program Files\" . cleanBase . "\" . cleanName,
            progFilesX86 . "\" . cleanBase . "\" . cleanName,
            A_AppData . "\..\Local\Programs\" . cleanBase . "\" . cleanName,
            A_AppData . "\..\Local\Programs\" . cleanName,
            A_AppData . "\..\Local\" . cleanBase . "\Application\" . cleanName,
            A_AppData . "\..\Local\" . cleanBase . "\" . cleanName,
            A_WinDir . "\System32\" . cleanName,
            A_WinDir . "\" . cleanName
        ]
        for c in candidates {
            c := Trim(c, ' "`t')
            if (FileExist(c))
                return c
        }
        return ""
    }

    static ExtractExeIcon(fullPath, outPng) {
        try {
            if (!GdipHelper.Init())
                return false

            hIcon := 0
            ; 1. Try high-quality PrivateExtractIconsW (preserves 32-bit ARGB 48x48 icon)
            hIcons := Buffer(A_PtrSize, 0)
            hIconIds := Buffer(4, 0)
            if (DllCall("user32\PrivateExtractIconsW", "Str", fullPath, "Int", 0, "Int", 48, "Int", 48, "Ptr", hIcons.Ptr, "Ptr", hIconIds.Ptr, "UInt", 1, "UInt", 0) > 0) {
                hIcon := NumGet(hIcons, 0, "Ptr")
            }

            ; 2. Fallback to ExtractAssociatedIcon
            if (!hIcon) {
                pathBuf := Buffer(520, 0)
                StrPut(fullPath, pathBuf, "UTF-16")
                index := 0
                hIcon := DllCall("shell32\ExtractAssociatedIcon", "Ptr", 0, "Ptr", pathBuf.Ptr, "Short*", &index, "Ptr")
            }

            if (hIcon) {
                pBitmap := 0
                DllCall("gdiplus\GdipCreateBitmapFromHICON", "Ptr", hIcon, "Ptr*", &pBitmap)
                DllCall("user32\DestroyIcon", "Ptr", hIcon)
                
                if (pBitmap) {
                    this.CleanWhiteCorners(pBitmap)
                    clsidPng := Buffer(16)
                    DllCall("ole32\CLSIDFromString", "Str", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "Ptr", clsidPng.Ptr)
                    DllCall("gdiplus\GdipSaveImageToFile", "Ptr", pBitmap, "Str", outPng, "Ptr", clsidPng.Ptr, "Ptr", 0)
                    DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)
                }
            }
            return FileExist(outPng) ? true : false
        } catch {
            return false
        }
    }

    static CleanWhiteCorners(pBitmap) {
        try {
            width := 0, height := 0
            DllCall("gdiplus\GdipGetImageWidth", "Ptr", pBitmap, "UInt*", &width)
            DllCall("gdiplus\GdipGetImageHeight", "Ptr", pBitmap, "UInt*", &height)
            if (width < 4 || height < 4)
                return

            ; Check if top-left corner is solid white (common GDI+ artifact from masked icons)
            argb0 := 0
            DllCall("gdiplus\GdipBitmapGetPixel", "Ptr", pBitmap, "Int", 0, "Int", 0, "UInt*", &argb0)
            if ((argb0 & 0xFFFFFFFF) != 0xFFFFFFFF)
                return

            ; Flood-fill from 4 outer corners to convert connected white background to alpha 0
            queue := [[0, 0], [width - 1, 0], [0, height - 1], [width - 1, height - 1]]
            visited := Map()
            while (queue.Length > 0) {
                pt := queue.Pop()
                x := pt[1], y := pt[2]
                if (x < 0 || x >= width || y < 0 || y >= height)
                    continue
                key := x . "," . y
                if (visited.Has(key))
                    continue
                visited[key] := true

                curArgb := 0
                DllCall("gdiplus\GdipBitmapGetPixel", "Ptr", pBitmap, "Int", x, "Int", y, "UInt*", &curArgb)
                a := (curArgb >> 24) & 0xFF
                r := (curArgb >> 16) & 0xFF
                g := (curArgb >> 8) & 0xFF
                b := curArgb & 0xFF
                if (a == 255 && r > 240 && g > 240 && b > 240) {
                    DllCall("gdiplus\GdipBitmapSetPixel", "Ptr", pBitmap, "Int", x, "Int", y, "UInt", 0x00000000)
                    queue.Push([x + 1, y])
                    queue.Push([x - 1, y])
                    queue.Push([x, y + 1])
                    queue.Push([x, y - 1])
                }
            }
        }
    }

    static ExtractWindowIcon(hwnd, outPng) {
        try {
            hIcon := SendMessage(0x007F, 1, 0, hwnd) ; WM_GETICON, ICON_BIG
            if (!hIcon)
                hIcon := SendMessage(0x007F, 0, 0, hwnd) ; WM_GETICON, ICON_SMALL
            if (!hIcon)
                hIcon := DllCall("GetClassLongPtr", "Ptr", hwnd, "Int", -14, "Ptr") ; GCLP_HICON
            if (!hIcon)
                hIcon := DllCall("GetClassLongPtr", "Ptr", hwnd, "Int", -34, "Ptr") ; GCLP_HICONSM
            if (hIcon) {
                if (GdipHelper.Init()) {
                    pBitmap := 0
                    DllCall("gdiplus\GdipCreateBitmapFromHICON", "Ptr", hIcon, "Ptr*", &pBitmap)
                    if (pBitmap) {
                        this.CleanWhiteCorners(pBitmap)
                        clsidPng := Buffer(16)
                        DllCall("ole32\CLSIDFromString", "Str", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "Ptr", clsidPng.Ptr)
                        DllCall("gdiplus\GdipSaveImageToFile", "Ptr", pBitmap, "Str", outPng, "Ptr", clsidPng.Ptr, "Ptr", 0)
                        DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)
                    }
                }
            }
            return FileExist(outPng) ? true : false
        } catch {
            return false
        }
    }

    static GetRunningProcesses() {
        procs := Map()
        outDir := A_ScriptDir . "\web\icons"
        if (!DirExist(outDir)) {
            try DirCreate(outDir)
        }
        try {
            hwndList := WinGetList()
            for hwnd in hwndList {
                if (!DllCall("IsWindowVisible", "Ptr", hwnd))
                    continue
                title := WinGetTitle(hwnd)
                if (title == "" || title == "Program Manager")
                    continue
                try {
                    pname := WinGetProcessName(hwnd)
                    if (pname != "" && !procs.Has(pname)) {
                        if (pname != "explorer.exe" && pname != "AutoHotkey64.exe" && pname != "msedgewebview2.exe" && pname != "ApplicationFrameHost.exe" && pname != "SystemSettings.exe") {
                            cleanProc := RegExReplace(pname, "i)\.exe$", "")
                            iconFile := outDir . "\" . cleanProc . ".png"
                            
                            ; Try extracting icon if not yet cached on disk
                            if (!FileExist(iconFile)) {
                                exePath := ""
                                try exePath := WinGetProcessPath(hwnd)
                                if (exePath == "" || !FileExist(exePath))
                                    exePath := this.ResolveExePath(pname)
                                if (exePath != "" && FileExist(exePath)) {
                                    this.ExtractExeIcon(exePath, iconFile)
                                }
                                ; Fallback to extracting icon directly from the HWND
                                if (!FileExist(iconFile)) {
                                    this.ExtractWindowIcon(hwnd, iconFile)
                                }
                            }

                            hasIcon := FileExist(iconFile) ? 1 : 0
                            procs[pname] := { title: title, icon: cleanProc, hasIcon: hasIcon }
                        }
                    }
                }
            }
        }
        out := []
        for pname, info in procs {
            out.Push(Map("process", pname, "title", info.title, "icon", info.icon, "hasIcon", info.hasIcon))
        }
        return out
    }

    static HasShift1Holder() {
        for btn, num in this.ShiftHolders {
            if (num = 1)
                return true
        }
        return false
    }

    static HasShift2Holder() {
        for btn, num in this.ShiftHolders {
            if (num = 2)
                return true
        }
        return false
    }

    ; Dynamic execution engine
    static DispatchButton(btnId, isDown) {
        if (this.IsMasterSuspended)
            return

        ; Filter Windows OS typematic auto-repeat on hold (for F-key mapped mouse buttons)
        if (isDown) {
            if (this.PhysicalButtonStates.Has(btnId) && this.PhysicalButtonStates[btnId])
                return ; Ignore typematic repeat event while button is physically held
            this.PhysicalButtonStates[btnId] := true
        } else {
            if (this.PhysicalButtonStates.Has(btnId))
                this.PhysicalButtonStates.Delete(btnId)
        }

        mapping := this.GetButtonMapping(this.CurrentProfile, btnId)

        ; -------------------------------------------------------------
        ; 1. HANDLE BUTTON RELEASE (isDown = false)
        ; -------------------------------------------------------------
        if (!isDown) {
            relLayer := this.ButtonDispatchedLayer.Has(btnId) ? this.ButtonDispatchedLayer[btnId] : (this.IsGShift2Active ? "GShift2" : ((this.IsGShift1Active || this.IsGShiftActive) ? "GShift" : "Normal"))
            WebViewGuiManager.LogActivity("BUTTON", "Release (Up) ▴ " . btnId, "Layer: " . relLayer . " | Profile: " . this.CurrentProfile)

            ; Check if this button was currently holding a Shift layer
            if (this.ShiftHolders.Has(btnId)) {
                shiftNum := this.ShiftHolders[btnId]
                this.ShiftHolders.Delete(btnId)
                if (shiftNum = 2) {
                    if (!this.HasShift2Holder())
                        this.HandleShift2Modifier(btnId, false)
                } else {
                    if (!this.HasShift1Holder())
                        this.HandleShift1Modifier(btnId, false)
                }
                return
            }

            ; Check if this button was dispatched on a specific layer
            if (this.ButtonDispatchedLayer.Has(btnId)) {
                dispLayer := this.ButtonDispatchedLayer[btnId]
                this.ButtonDispatchedLayer.Delete(btnId)
                this.ExecuteButtonEvent(btnId, dispLayer, false)
                return
            }

            ; If Studio app is in focus and MuteWhenStudioFocused is active, do NOT execute fallback release!
            if (this.MuteWhenStudioFocused && WebViewGuiManager.IsStudioFocused()) {
                return
            }

            ; Fallback regular release on current layer
            currentLayer := (this.IsGShift2Active ? "GShift2" : ((this.IsGShift1Active || this.IsGShiftActive) ? "GShift" : "Normal"))
            this.ExecuteButtonEvent(btnId, currentLayer, false)
            return
        }

        ; -------------------------------------------------------------
        ; 2. HANDLE BUTTON PRESS (isDown = true)
        ; -------------------------------------------------------------
        isShiftActive := (this.ShiftHolders.Count > 0 || this.IsGShiftActive || this.IsGShift1Active || this.IsGShift2Active)
        currentLayer := (this.IsGShift2Active ? "GShift2" : ((this.IsGShift1Active || this.IsGShiftActive) ? "GShift" : "Normal"))
        WebViewGuiManager.LogActivity("BUTTON", "Press (Down) ▾ " . btnId, "Layer: " . currentLayer . " | Profile: " . this.CurrentProfile)

        normCmd := mapping.Normal.Cmd
        normType := mapping.Normal.Type

        ; If a shift layer is ALREADY held by another button:
        if (isShiftActive && !this.ShiftHolders.Has(btnId)) {
            ; Check this button's action on the CURRENT active layer:
            act := (currentLayer = "GShift2") ? mapping.GShift2 : ((currentLayer = "GShift" || currentLayer = "GShift1") ? mapping.GShift : mapping.Normal)
            isActShift := (act.HasOwnProp("Type") && act.Type = "Special" && (act.Cmd = "GShift" || act.Cmd = "GShift1" || act.Cmd = "GShift2"))

            ; If this button on the current shift layer is NOT explicitly another shift modifier,
            ; execute its mapping on the current shift layer! (Do NOT let its Normal shift setting override!)
            if (!isActShift) {
                if (this.MuteWhenStudioFocused && WebViewGuiManager.IsStudioFocused()) {
                    actLabel := act.HasOwnProp("Label") ? act.Label : (act.HasOwnProp("Cmd") ? act.Cmd : "Action")
                    WebViewGuiManager.LogActivity("TEST", "Muted in Studio (Test Mode is ON) — " . actLabel, "Turn off Shield icon in header to execute in Studio")
                    return
                }
                this.ButtonDispatchedLayer[btnId] := currentLayer
                this.ExecuteButtonEvent(btnId, currentLayer, true)
                return
            }
        }

        ; If no other button is holding shift, or this button is explicitly a shift modifier on the active layer:
        if (normType = "Special" && (normCmd = "GShift" || normCmd = "GShift1")) {
            this.ShiftHolders[btnId] := 1
            this.HandleShift1Modifier(btnId, true)
            return
        }
        if (normType = "Special" && normCmd = "GShift2") {
            this.ShiftHolders[btnId] := 2
            this.HandleShift2Modifier(btnId, true)
            return
        }

        ; If Studio app is in focus and MuteWhenStudioFocused is active,
        ; prevent any mapping from executing (only visual highlight in NotifyButton fires)
        if (this.MuteWhenStudioFocused && WebViewGuiManager.IsStudioFocused()) {
            actLabel := mapping.Normal.HasOwnProp("Label") ? mapping.Normal.Label : (mapping.Normal.HasOwnProp("Cmd") ? mapping.Normal.Cmd : "Action")
            WebViewGuiManager.LogActivity("TEST", "Muted in Studio (Test Mode is ON) — " . actLabel, "Turn off Shield icon in header to execute in Studio")
            return
        }

        ; Regular button press on current layer
        this.ButtonDispatchedLayer[btnId] := currentLayer
        this.ExecuteButtonEvent(btnId, currentLayer, true)
    }

    static HandleShift1Modifier(btnId, isDown) {
        WebViewGuiManager.LogActivity("SHIFT", (isDown ? "Hold ▾ " : "Release ▴ ") . "B-Shift 1", "Trigger: " . btnId)
        if (isDown) {
            this.IsGShift1Active := true
            this.IsGShiftActive := true
            this.NotifyShift(1, true)
        } else {
            this.IsGShift1Active := false
            this.IsGShiftActive := this.IsGShift2Active
            this.NotifyShift(1, false)
            this.OnShiftLayerDeactivated("GShift1")
        }
    }

    static HandleShift2Modifier(btnId, isDown) {
        WebViewGuiManager.LogActivity("SHIFT", (isDown ? "Hold ▾ " : "Release ▴ ") . "B-Shift 2", "Trigger: " . btnId)
        if (isDown) {
            this.IsGShift2Active := true
            this.IsGShiftActive := true
            this.NotifyShift(2, true)
        } else {
            this.IsGShift2Active := false
            this.IsGShiftActive := this.IsGShift1Active
            this.NotifyShift(2, false)
            this.OnShiftLayerDeactivated("GShift2")
        }
    }

    static NotifyShift(layerNum, isActive) {
        fn := this.OnShiftStateChanged
        if (fn)
            fn(layerNum, isActive)
    }

    static IsShiftModifierButton(btnId) {
        if (!this.ActiveMappings.Has(this.CurrentProfile) && !this.DefaultMappings.Has(this.CurrentProfile))
            return false
        try {
            mapping := this.GetButtonMapping(this.CurrentProfile, btnId)
            if (!IsObject(mapping) || !mapping.HasOwnProp("Normal"))
                return false
            normCmd := mapping.Normal.HasOwnProp("Cmd") ? mapping.Normal.Cmd : ""
            normType := mapping.Normal.HasOwnProp("Type") ? mapping.Normal.Type : ""
            return (normType = "Special" && (normCmd = "GShift" || normCmd = "GShift1" || normCmd = "GShift2"))
        }
        return false
    }

    static GetShiftModifierLayer(btnId) {
        try {
            mapping := this.GetButtonMapping(this.CurrentProfile, btnId)
            if (IsObject(mapping) && mapping.HasOwnProp("Normal")) {
                normCmd := mapping.Normal.HasOwnProp("Cmd") ? mapping.Normal.Cmd : ""
                if (normCmd = "GShift2")
                    return "GShift2"
            }
        }
        return "GShift"
    }

    static ReleaseAllShiftModifiers() {
        this.OnShiftLayerDeactivated("All")
        this.ShiftHolders.Clear()
        this.ButtonDispatchedLayer.Clear()
        this.IsGShiftActive := false
        this.IsGShift1Active := false
        this.IsGShift2Active := false
        this.NotifyShift(1, false)
        this.NotifyShift(2, false)
    }

    static OnShiftLayerDeactivated(layerName := "All") {
        ; 1. Collect all buttons that were dispatched on the deactivated shift layer
        buttonsToRelease := []
        for btnId, dispLayer in this.ButtonDispatchedLayer {
            if (layerName == "All" 
                || dispLayer == layerName 
                || (layerName == "GShift1" && (dispLayer == "GShift" || dispLayer == "GShift1"))
                || (layerName == "GShift" && (dispLayer == "GShift" || dispLayer == "GShift1"))) {
                buttonsToRelease.Push({ btnId: btnId, layer: dispLayer })
            }
        }

        ; 2. Trigger the on-release / finish handler for each button
        for item in buttonsToRelease {
            if (this.ButtonDispatchedLayer.Has(item.btnId)) {
                this.ButtonDispatchedLayer.Delete(item.btnId)
            }
            this.ExecuteButtonEvent(item.btnId, item.layer, false)
        }

        ; 3. Catch any active sequences that were initiated on shift but might not be in ButtonDispatchedLayer
        seqsToFinish := []
        for btnId, seq in this.ActiveSequences {
            seqsToFinish.Push({ btnId: btnId, act: seq.act })
        }
        for item in seqsToFinish {
            if (this.ActiveSequences.Has(item.btnId)) {
                this.FinishSequence(item.btnId, item.act)
            }
        }

        ; 4. Release any hold timers if shift is completely inactive
        if (layerName == "All" || !this.IsGShiftActive) {
            for btnId, fn in this.ActiveHoldTimers {
                this.StopHold(btnId)
            }
        }

        ; 5. Failsafe modifier unstick: if Shift, Ctrl, or Alt is logically down but physically not held on keyboard
        if (!this.IsExecutingMacro) {
            if (!GetKeyState("Shift", "P") && GetKeyState("Shift"))
                try Send("{Blind}{Shift up}")
            if (!GetKeyState("Ctrl", "P") && GetKeyState("Ctrl"))
                try Send("{Blind}{Ctrl up}")
            if (!GetKeyState("Alt", "P") && GetKeyState("Alt"))
                try Send("{Blind}{Alt up}")
            if (!GetKeyState("LButton", "P") && GetKeyState("LButton"))
                try Send("{Blind}{LButton up}")
            if (!GetKeyState("RButton", "P") && GetKeyState("RButton"))
                try Send("{Blind}{RButton up}")
        }
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
                    this.ExecuteActionDown(act, btnId)
                case "RepeatWhileHolding", "Repeat While Holding":
                    this.StartHold(btnId, act)
                case "Toggle":
                    this.StartToggle(btnId, act)
                case "Sequence":
                    this.StartSequence(btnId, act)
                default:
                    this.ExecuteActionDown(act, btnId)
            }
        } else {
            ; Button released!
            switch playType {
                case "NoRepeat", "No Repeat":
                    this.ExecuteActionUp(act, btnId)
                case "RepeatWhileHolding", "Repeat While Holding":
                    if (this.ActiveHoldTimers.Has(btnId)) {
                        this.StopHold(btnId)
                    }
                case "Sequence":
                    this.FinishSequence(btnId, act)
                default:
                    this.ExecuteActionUp(act, btnId)
            }
        }
    }

    static GetHoldableKey(cmd) {
        if (cmd == "")
            return ""
        
        ; Mouse buttons: LButton, RButton, MButton, XButton1, XButton2
        if (RegExMatch(cmd, "i)^\{(LButton|RButton|MButton|XButton1|XButton2)\}$", &m))
            return m[1]
            
        ; Standard single brace keys: {Space}, {Enter}, {Tab}, {Escape}, {Delete}, {F1}-{F24}, etc.
        ; (Exclude scroll wheel, double/triple clicks, or multi-count like {Volume_Down 2})
        if (RegExMatch(cmd, "i)^\{([A-Za-z0-9_]+)\}$", &m)) {
            k := m[1]
            if (k != "WheelUp" && k != "WheelDown" && k != "WheelLeft" && k != "WheelRight"
                && k != "DoubleClick" && k != "TripleClick"
                && !InStr(k, "Volume_") && !InStr(k, "Media_"))
                return k
        }
        
        ; Single character: e.g. "d", "a", "1"
        if (StrLen(cmd) = 1)
            return StrLower(cmd)
            
        return ""
    }

    static ExecuteActionDown(act, btnId) {
        if (act.Type = "Text" && act.Cmd != "") {
            SendText(act.Cmd)
            return
        }
        if ((act.Type = "Send" || act.Type = "Default") && act.Cmd != "") {
            ; One-shot clicks and wheel actions must execute once immediately without holding state
            if (act.Cmd = "{DoubleClick}" || act.Cmd = "{LButton 2}" || act.Cmd = "{TripleClick}" || act.Cmd = "{LButton 3}"
                || act.Cmd = "{WheelUp}" || act.Cmd = "{WheelDown}" || act.Cmd = "{WheelLeft}" || act.Cmd = "{WheelRight}") {
                this.ExecuteActionOnce(act)
                return
            }
            holdKey := this.GetHoldableKey(act.Cmd)
            if (holdKey != "") {
                this.ActiveHeldButtons[btnId] := "{" . holdKey . " up}"
                this.ActiveHeldPressTimes[btnId] := A_TickCount
                Send("{Blind}{" . holdKey . " down}")
                return
            }
            ; Modifier + Key/Mouse button hold support (e.g. ^{LButton}, +{w}, !{Space}, ^{c}, etc.)
            if (RegExMatch(act.Cmd, "i)^([!^#]+)\{?([A-Za-z0-9_]+)\}?$", &modKeyMatch)) {
                mods := modKeyMatch[1]
                k := modKeyMatch[2]
                if (k != "WheelUp" && k != "WheelDown" && k != "WheelLeft" && k != "WheelRight"
                    && k != "DoubleClick" && k != "TripleClick"
                    && !InStr(k, "Volume_") && !InStr(k, "Media_")) {
                    if (StrLen(k) = 1 && !InStr(mods, "+"))
                        k := StrLower(k)
                    relCmd := "{" . k . " up}"
                    if (InStr(mods, "^"))
                        relCmd .= "{Ctrl up}"
                    if (InStr(mods, "!"))
                        relCmd .= "{Alt up}"
                    if (InStr(mods, "+"))
                        relCmd .= "{Shift up}"
                    if (InStr(mods, "#"))
                        relCmd .= "{LWin up}"
                    this.ActiveHeldButtons[btnId] := relCmd
                    this.ActiveHeldPressTimes[btnId] := A_TickCount
                    Send("{Blind}" . mods . "{" . k . " down}")
                    return
                }
            }
            ; Combo hold support: e.g. multi-key chords ({w down}{d down}), or mouse combos ({s down}{LButton}{s up})
            if (InStr(act.Cmd, " down}")) {
                downCmd := ""
                upCmd := ""
                pos := 1
                while (RegExMatch(act.Cmd, "i)\{([A-Za-z0-9_]+)\s+down\}", &kMatch, pos)) {
                    keyName := kMatch[1]
                    downCmd .= "{" . keyName . " down}"
                    upCmd := "{" . keyName . " up}" . upCmd
                    pos := kMatch.Pos + kMatch.Len
                }
                if (RegExMatch(act.Cmd, "i)\{(LButton|RButton|MButton|XButton1|XButton2)\}", &mbMatch)) {
                    mbName := mbMatch[1]
                    downCmd .= "{" . mbName . " down}"
                    upCmd := "{" . mbName . " up}" . upCmd
                }
                if (downCmd != "") {
                    modPrefix := ""
                    if (RegExMatch(act.Cmd, "i)\{Blind\}([!^#]+)", &modMatch))
                        modPrefix := modMatch[1]
                    else if (RegExMatch(act.Cmd, "^([!^#]+)", &modMatch))
                        modPrefix := modMatch[1]
                    this.ActiveHeldButtons[btnId] := upCmd
                    this.ActiveHeldPressTimes[btnId] := A_TickCount
                    Send("{Blind}" . modPrefix . downCmd)
                    return
                }
            }
        }
        this.ExecuteActionOnce(act)
    }

    static ExecuteActionUp(act, btnId) {
        if (this.ActiveHeldButtons.Has(btnId)) {
            releaseCmd := this.ActiveHeldButtons[btnId]
            this.ActiveHeldButtons.Delete(btnId)

            ; Enforce minimum key hold duration (Game Key Delay) to prevent rapid taps from being missed by game engine ticks
            if (this.ActiveHeldPressTimes.Has(btnId)) {
                pressTime := this.ActiveHeldPressTimes[btnId]
                this.ActiveHeldPressTimes.Delete(btnId)
                elapsed := A_TickCount - pressTime
                if (this.GameKeyDelay > 0 && elapsed < this.GameKeyDelay) {
                    Sleep(this.GameKeyDelay - elapsed)
                }
            }

            if (!InStr(releaseCmd, "{"))
                releaseCmd := "{" . releaseCmd . " up}"
            Send("{Blind}" . releaseCmd)
        }
    }

    static NormalizeSendCmd(cmd) {
        if (cmd == "")
            return ""
        ; If command is a single character or braces like {D} without explicit +,
        ; ensure it is lowercase so AutoHotkey does not inject an unwanted Shift key.
        ; Matches: "{D}", "{S}", "D", etc., but preserves "+{D}", "^d", "!{Tab}", etc.
        if (RegExMatch(cmd, "^([!^#]*)\{?([A-Za-z])\}?$", &m)) {
            mods := m[1]
            char := m[2]
            if (!InStr(mods, "+")) {
                char := StrLower(char)
            }
            return mods . "{" . char . "}"
        }
        return cmd
    }

    static ExecuteActionOnce(act) {
        if (act.Type = "Text" && act.Cmd != "") {
            SendText(act.Cmd)
            return
        }
        if ((act.Type = "Send" || act.Type = "Default") && act.Cmd != "") {
            if (act.Cmd = "{DoubleClick}" || act.Cmd = "{LButton 2}") {
                Click(2)
            } else if (act.Cmd = "{TripleClick}" || act.Cmd = "{LButton 3}") {
                Click(3)
            } else if (act.Cmd = "{WheelUp}" || act.Cmd = "{WheelDown}" || act.Cmd = "{WheelLeft}" || act.Cmd = "{WheelRight}") {
                Send("{Blind}" . act.Cmd)
            } else {
                cmd := this.NormalizeSendCmd(act.Cmd)
                if (this.GameKeyDelay > 0) {
                    ; Use SendEvent with SetKeyDelay to guarantee keys remain down across game engine frames
                    ; Delay between sequential keystrokes = half of GameKeyDelay (min 10ms); PressDuration = GameKeyDelay
                    interDelay := Max(10, this.GameKeyDelay // 2)
                    SetKeyDelay(interDelay, this.GameKeyDelay)
                    SendEvent(cmd)
                } else {
                    Send(cmd)
                }
            }
        } else if (act.Type = "Macro") {
            if (act.HasOwnProp("Steps") && act.Steps.Length > 0) {
                this.PlaySteps(act.Steps)
            }
        } else if (act.Type = "Special") {
            if (act.Cmd = "CycleProfile") {
                this.CycleProfile()
            } else if (act.Cmd = "ToggleRapidFire") {
                this.ToggleRapidFire()
            }
        }
    }

    static PlaySteps(steps, btnId := "", token := 0, isRelease := false) {
        if (!IsObject(steps) || steps.Length = 0)
            return
        this.ExecutingMacroCount++
        this.IsExecutingMacro := true
        try {
            totalSteps := steps.Length
            for idx, step in steps {
                ; Check sequence token before executing step
                if (btnId != "" && token != 0) {
                    if (!this.SequenceTokens.Has(btnId) || this.SequenceTokens[btnId] != token)
                        return
                }

                k := step.Key
                if (k = "DoubleClick") {
                    Click(2)
                    WebViewGuiManager.LogActivity("STEP", "Double Click", "")
                    continue
                } else if (k = "TripleClick") {
                    Click(3)
                    WebViewGuiManager.LogActivity("STEP", "Triple Click", "")
                    continue
                }
                if (StrLen(k) = 1 && !InStr(k, "+")) {
                    k := StrLower(k)
                }
                if (step.Action = "Down") {
                    Send("{Blind}{" . k . " down}")
                    WebViewGuiManager.LogActivity("STEP", "{" . k . " down}", (!isRelease && step.HasOwnProp("Delay") && step.Delay > 0) ? (step.Delay . "ms delay") : "")
                } else if (step.Action = "Up") {
                    Send("{Blind}{" . k . " up}")
                    WebViewGuiManager.LogActivity("STEP", "{" . k . " up}", (!isRelease && step.HasOwnProp("Delay") && step.Delay > 0) ? (step.Delay . "ms delay") : "")
                }

                ; Delays: only sleep between intermediate steps (no useless sleep after the final step!)
                if (idx < totalSteps && step.HasOwnProp("Delay") && step.Delay > 0) {
                    sleepMs := isRelease ? Min(step.Delay, 30) : step.Delay
                    if (sleepMs > 0) {
                        Sleep(sleepMs)
                        ; Check sequence token again after sleep — if released during sleep, abort immediately!
                        if (btnId != "" && token != 0) {
                            if (!this.SequenceTokens.Has(btnId) || this.SequenceTokens[btnId] != token)
                                return
                        }
                    }
                }
            }
        } finally {
            this.ExecutingMacroCount--
            if (this.ExecutingMacroCount <= 0) {
                this.ExecutingMacroCount := 0
                this.IsExecutingMacro := false
            }
        }
    }

    static StartHold(btnId, act) {
        this.StopHold(btnId)
        interval := (act.HasOwnProp("RepeatInterval") && act.RepeatInterval > 0) ? act.RepeatInterval : 50
        
        fn() {
            if (!ProfileEngine.ActiveHoldTimers.Has(btnId))
                return
            ProfileEngine.ExecuteActionOnce(act)
            if (ProfileEngine.ActiveHoldTimers.Has(btnId))
                SetTimer(fn, -interval)
        }
        
        this.ActiveHoldTimers[btnId] := fn
        this.ExecuteActionOnce(act)
        if (this.ActiveHoldTimers.Has(btnId))
            SetTimer(fn, -interval)
    }

    static StopHold(btnId) {
        if (this.ActiveHoldTimers.Has(btnId)) {
            fn := this.ActiveHoldTimers[btnId]
            if (IsObject(fn))
                SetTimer(fn, 0)
            this.ActiveHoldTimers.Delete(btnId)
        }
    }

    static StartToggle(btnId, act) {
        this.StopToggle(btnId)
        interval := (act.HasOwnProp("RepeatInterval") && act.RepeatInterval > 0) ? act.RepeatInterval : 50
        
        fn() {
            if (!ProfileEngine.ActiveToggleTimers.Has(btnId))
                return
            ProfileEngine.ExecuteActionOnce(act)
            if (ProfileEngine.ActiveToggleTimers.Has(btnId))
                SetTimer(fn, -interval)
        }
        
        this.ActiveToggleTimers[btnId] := fn
        this.ExecuteActionOnce(act)
        if (this.ActiveToggleTimers.Has(btnId))
            SetTimer(fn, -interval)
            
        OSD.Show("Toggle: RUNNING", act.Label)
        SoundBeep(1200, 60)
    }

    static StopToggle(btnId) {
        if (this.ActiveToggleTimers.Has(btnId)) {
            fn := this.ActiveToggleTimers[btnId]
            if (IsObject(fn))
                SetTimer(fn, 0)
            this.ActiveToggleTimers.Delete(btnId)
            OSD.Show("Toggle: STOPPED", "Idle")
            SoundBeep(700, 60)
        }
    }

    static StartSequence(btnId, act) {
        ; 1. Invalidate any prior sequence on this button and generate new cancellation token
        this.NextSeqToken++
        currToken := this.NextSeqToken
        this.SequenceTokens[btnId] := currToken

        ; 2. Stop any existing hold timer on this button
        if (this.ActiveSequences.Has(btnId)) {
            seqObj := this.ActiveSequences[btnId]
            if (seqObj.HasOwnProp("fn") && seqObj.fn != "")
                SetTimer(seqObj.fn, 0)
        }

        ; 3. Setup WHILE HOLDING loop if specified
        fn := ""
        if (act.HasOwnProp("SeqHold") && act.SeqHold.Length > 0) {
            fn := () => ProfileEngine.PlaySteps(act.SeqHold, btnId, currToken, false)
            interval := (act.HasOwnProp("RepeatInterval") && act.RepeatInterval > 0) ? act.RepeatInterval : 50
            SetTimer(fn, interval)
        }
        this.ActiveSequences[btnId] := { fn: fn, act: act, token: currToken }

        WebViewGuiManager.LogActivity("MACRO", "Sequence Start: " . (act.HasOwnProp("Label") ? act.Label : "Macro"), "OnPress: " . (act.HasOwnProp("SeqPress") ? act.SeqPress.Length : 0) . " steps | WhileHold: " . (act.HasOwnProp("SeqHold") ? act.SeqHold.Length : 0) . " steps")

        ; 4. Play ON PRESS steps once with token cancellation tracking
        if (act.HasOwnProp("SeqPress") && act.SeqPress.Length > 0) {
            this.PlaySteps(act.SeqPress, btnId, currToken, false)
        }
    }

    static FinishSequence(btnId, act := "") {
        ; 1. Invalidate any in-progress StartSequence thread for this button immediately!
        ; Any sleeping StartSequence thread will detect this and abort immediately upon waking up.
        if (this.SequenceTokens.Has(btnId)) {
            this.SequenceTokens.Delete(btnId)
        }

        seqAct := act
        ; 2. Stop WHILE HOLDING loop
        if (this.ActiveSequences.Has(btnId)) {
            seqObj := this.ActiveSequences[btnId]
            if (seqObj.HasOwnProp("fn") && seqObj.fn != "") {
                SetTimer(seqObj.fn, 0)
            }
            if (seqAct == "" || !seqAct.HasOwnProp("SeqRelease") || seqAct.SeqRelease.Length == 0) {
                if (seqObj.HasOwnProp("act") && IsObject(seqObj.act))
                    seqAct := seqObj.act
            }
            this.ActiveSequences.Delete(btnId)
        }

        WebViewGuiManager.LogActivity("MACRO", "Sequence Finish: " . (IsObject(seqAct) && seqAct.HasOwnProp("Label") ? seqAct.Label : "Macro"), "OnRelease: " . (IsObject(seqAct) && seqAct.HasOwnProp("SeqRelease") ? seqAct.SeqRelease.Length : 0) . " steps")

        ; 3. Play ON RELEASE steps immediately (isRelease = true for zero-delay instant execution)
        if (IsObject(seqAct) && seqAct.HasOwnProp("SeqRelease") && seqAct.SeqRelease.Length > 0) {
            this.PlaySteps(seqAct.SeqRelease, btnId, 0, true)
        }

        ; 4. Failsafe modifier cleanup: if any modifier was logically stuck down by an interrupted macro
        ; but is physically not held on the keyboard, release it now.
        if (!this.IsExecutingMacro) {
            if (!GetKeyState("Shift", "P") && GetKeyState("Shift"))
                try Send("{Blind}{Shift up}")
            if (!GetKeyState("Ctrl", "P") && GetKeyState("Ctrl"))
                try Send("{Blind}{Ctrl up}")
            if (!GetKeyState("Alt", "P") && GetKeyState("Alt"))
                try Send("{Blind}{Alt up}")
            if (btnId != "LeftClick" && !GetKeyState("LButton", "P") && GetKeyState("LButton"))
                try Send("{Blind}{LButton up}")
            if (btnId != "RightClick" && !GetKeyState("RButton", "P") && GetKeyState("RButton"))
                try Send("{Blind}{RButton up}")
        }
    }

    ; --- Button Event Handlers (F13 - F21) ---
    ; Matches Onboard Memory Manager (OMM) physical layout with dynamic swapping support

    static HandleFKey(fKey, isDown) {
        btnId := this.FKeyToButtonMap.Has(fKey) ? this.FKeyToButtonMap[fKey] : ""
        if (btnId != "") {
            this.NotifyButton(btnId, isDown)
            this.DispatchButton(btnId, isDown)
        }
    }

    ; Button 3: Middle Click (Mouse 3) -> F13
    static HandleF13_Middle(isDown) {
        this.HandleFKey("F13", isDown)
    }

    ; Button 4: Back Button Click (Mouse 4 / G4) -> F14
    static HandleF14_Back(isDown) {
        this.HandleFKey("F14", isDown)
    }

    ; Button 5: G-Shift / Sniper Thumb Button (DPI Shift) -> F15
    static HandleF15_DpiShift(isDown) {
        this.HandleFKey("F15", isDown)
    }

    ; Button 6: Forward Button Click (Mouse 5 / G5) -> F16
    static HandleF16_Forward(isDown) {
        this.HandleFKey("F16", isDown)
    }

    ; Button 7: Tilt Left -> F17
    static HandleF17_TiltLeft(isDown) {
        this.HandleFKey("F17", isDown)
    }

    ; Button 8: Tilt Right -> F18
    static HandleF18_TiltRight(isDown) {
        this.HandleFKey("F18", isDown)
    }

    ; Button 9: Cycle Profiles (G9) -> F19
    static HandleF19_ProfileCycle(isDown) {
        this.HandleFKey("F19", isDown)
    }

    ; Button 10: Next DPI (G8 / DPI Up) -> F20
    static HandleF20_G8(isDown) {
        this.HandleFKey("F20", isDown)
    }

    ; Button 11: Previous DPI (G7 / DPI Down) -> F21
    static HandleF21_G7(isDown) {
        this.HandleFKey("F21", isDown)
    }

    ; --- Left & Right Click Handlers (B-Shift Layer Only) ---
    static NeedsLeftClickIntercept() {
        if (this.IsMasterSuspended)
            return false

        ; If this button is currently dispatched on a custom layer or has an active sequence,
        ; we MUST intercept the release so the macro's OnRelease steps and cleanup execute reliably!
        if (this.ButtonDispatchedLayer.Has("LeftClick") || this.ActiveSequences.Has("LeftClick"))
            return true

        ; If a macro is actively executing synthetic clicks, do not intercept non-dispatched clicks
        if (this.IsExecutingMacro)
            return false

        if (!this.IsGShiftActive && !this.IsGShift1Active && !this.IsGShift2Active)
            return false

        mapping := this.GetButtonMapping(this.CurrentProfile, "LeftClick")
        act := (this.IsGShift2Active) ? mapping.GShift2 : mapping.GShift
        return this.IsCustomClickAction(act, "LButton")
    }

    static NeedsRightClickIntercept() {
        if (this.IsMasterSuspended)
            return false

        ; If this button is currently dispatched on a custom layer or has an active sequence,
        ; we MUST intercept the release so the macro's OnRelease steps and cleanup execute reliably!
        if (this.ButtonDispatchedLayer.Has("RightClick") || this.ActiveSequences.Has("RightClick"))
            return true

        ; If a macro is actively executing synthetic clicks, do not intercept non-dispatched clicks
        if (this.IsExecutingMacro)
            return false

        if (!this.IsGShiftActive && !this.IsGShift1Active && !this.IsGShift2Active)
            return false

        mapping := this.GetButtonMapping(this.CurrentProfile, "RightClick")
        act := (this.IsGShift2Active) ? mapping.GShift2 : mapping.GShift
        return this.IsCustomClickAction(act, "RButton")
    }

    static IsCustomClickAction(act, defaultKey) {
        if (!IsObject(act))
            return false
        if (act.Type = "Macro" || act.Type = "Special" || act.Type = "Text")
            return true
        if (act.Type = "Send") {
            if (act.Cmd != "" && act.Cmd != "{" . defaultKey . "}")
                return true
        }
        return false
    }

    static HandleLeftClick(isDown) {
        if (this.IsMasterSuspended)
            return
        ; Decouple execution from OS low-level mouse hook (WH_MOUSE_LL)
        ; Returns to Windows immediately in < 0.05ms to prevent cursor lag & OS hook watchdog timeouts
        SetTimer(() => ProfileEngine._DoHandleLeftClick(isDown), -1)
    }

    static _DoHandleLeftClick(isDown) {
        if (this.IsMasterSuspended)
            return
        this.NotifyButton("LeftClick", isDown)
        this.DispatchButton("LeftClick", isDown)
    }

    static HandleRightClick(isDown) {
        if (this.IsMasterSuspended)
            return
        ; Decouple execution from OS low-level mouse hook (WH_MOUSE_LL)
        ; Returns to Windows immediately in < 0.05ms to prevent cursor lag & OS hook watchdog timeouts
        SetTimer(() => ProfileEngine._DoHandleRightClick(isDown), -1)
    }

    static _DoHandleRightClick(isDown) {
        if (this.IsMasterSuspended)
            return
        this.NotifyButton("RightClick", isDown)
        this.DispatchButton("RightClick", isDown)
    }

    ; Determines if WheelUp/WheelDown should be intercepted by AHK hook
    static NeedsWheelIntercept() {
        if (this.IsMasterSuspended)
            return false

        if (this.IsGShiftActive || this.IsGShift1Active || this.IsGShift2Active)
            return true
            
        mappingUp := this.GetButtonMapping(this.CurrentProfile, "WheelUp")
        if (this.IsCustomWheelAction(mappingUp.Normal, "WheelUp"))
            return true
            
        mappingDown := this.GetButtonMapping(this.CurrentProfile, "WheelDown")
        if (this.IsCustomWheelAction(mappingDown.Normal, "WheelDown"))
            return true
            
        return false
    }

    static IsCustomWheelAction(act, defaultBtnId) {
        if (!IsObject(act))
            return false
        if (act.Type = "Macro" || act.Type = "Special" || act.Type = "Text")
            return true
        if (act.Cmd != "" && act.Cmd != "{" . defaultBtnId . "}")
            return true
        return false
    }

    static LastWheelNotifyTime := 0

    static NotifyWheel(btnId) {
        if (this.IsMasterSuspended)
            return
        now := A_TickCount
        if (now - this.LastWheelNotifyTime > 80) {
            this.LastWheelNotifyTime := now
            this.NotifyButton(btnId, true)
            SetTimer(() => this.NotifyButton(btnId, false), -140)
        }
    }

    ; Native Scroll Wheel Mapping & Dispatch (No F-key required)
    static DispatchWheel(direction) {
        if (this.IsMasterSuspended)
            return
        btnId := (direction = "Up") ? "WheelUp" : "WheelDown"

        ; Determine active layer
        layer := "Normal"
        if (this.IsGShift2Active) {
            layer := "GShift2"
        } else if (this.IsGShift1Active || this.IsGShiftActive) {
            layer := "GShift"
        }

        mapping := this.GetButtonMapping(this.CurrentProfile, btnId)
        act := (layer = "GShift2") ? mapping.GShift2 : ((layer = "GShift" || layer = "GShift1") ? mapping.GShift : mapping.Normal)

        ; Throttled GUI visual feedback
        this.NotifyWheel(btnId)

        ; If Studio app is in focus and MuteWhenStudioFocused is active,
        ; allow native wheel scrolling inside Studio GUI instead of triggering custom macro/mapping
        if (this.MuteWhenStudioFocused && WebViewGuiManager.IsStudioFocused()) {
            if (direction = "Up") {
                Send("{Blind}{WheelUp}")
            } else {
                Send("{Blind}{WheelDown}")
            }
            return
        }

        ; If action is unassigned or Default native wheel, pass-through natively!
        if ((act.Type = "Default" && (act.Cmd == "" || act.Cmd == "{" . btnId . "}")) || act.Cmd == "" || (act.Type = "Send" && act.Cmd == "{" . btnId . "}")) {
            if (direction = "Up") {
                Send("{Blind}{WheelUp}")
            } else {
                Send("{Blind}{WheelDown}")
            }
            return
        }

        ; Otherwise execute custom mapped action
        this.ExecuteActionOnce(act)
    }

    ; Scroll Wheel G-Shift Chording (Legacy delegate)
    static HandleWheel(direction) {
        this.DispatchWheel(direction)
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
        if (this.IsMasterSuspended)
            return

        ; Suppress redundant UI flash on OS typematic repeats
        if (isPressed && this.PhysicalButtonStates.Has(btnName) && this.PhysicalButtonStates[btnName])
            return

        ; If this is a pass-through click or scroll on normal layer, log it for complete visibility
        if (btnName = "LeftClick" || btnName = "RightClick" || btnName = "WheelUp" || btnName = "WheelDown") {
            if (!this.IsGShiftActive && !this.IsGShift1Active && !this.IsGShift2Active) {
                if (!WebViewGuiManager.IsStudioFocused()) {
                    WebViewGuiManager.LogActivity("BUTTON", (isPressed ? "Press (Down) ▾ " : "Release (Up) ▴ ") . btnName . " (Native)", "Layer: Normal | Profile: " . this.CurrentProfile)
                }
            }
        }

        fn := this.OnButtonStateChanged
        if (fn) {
            fn(btnName, isPressed)
        }
    }

    ; ========================================================
    ; CUSTOM BUTTONS PERSISTENCE & MANAGEMENT
    ; ========================================================
    static LoadCustomButtons() {
        btnListStr := IniRead(this.ConfigPath, "Buttons", "List", "")
        if (btnListStr = "")
            return []

        btnArray := []
        Loop Parse, btnListStr, "," {
            bId := Trim(A_LoopField)
            if (bId = "")
                continue
            sec := "Button_" . bId
            name := IniRead(this.ConfigPath, sec, "Name", bId)
            tag := IniRead(this.ConfigPath, sec, "Tag", bId)
            side := IniRead(this.ConfigPath, sec, "Side", "left")
            key := IniRead(this.ConfigPath, sec, "Key", "")
            xVal := IniRead(this.ConfigPath, "DiagramPoints", bId . "_X", "250")
            yVal := IniRead(this.ConfigPath, "DiagramPoints", bId . "_Y", "250")

            btnObj := Map(
                "id", bId,
                "name", name,
                "tag", tag,
                "side", side,
                "hardwareKey", key,
                "x", Integer(xVal),
                "y", Integer(yVal)
            )
            btnArray.Push(btnObj)
        }
        return btnArray
    }

    static SaveCustomButtons(buttonsList) {
        idList := []
        assignedKeys := Map()

        for _, btn in buttonsList {
            bId := btn.Has("id") ? btn["id"] : ""
            if (bId = "") {
                continue
            }
            idList.Push(bId)
            sec := "Button_" . bId
            if (btn.Has("name")) {
                IniWrite(btn["name"], this.ConfigPath, sec, "Name")
            }
            if (btn.Has("tag")) {
                IniWrite(btn["tag"], this.ConfigPath, sec, "Tag")
            }
            if (btn.Has("side")) {
                IniWrite(btn["side"], this.ConfigPath, sec, "Side")
            }

            key := btn.Has("hardwareKey") ? btn["hardwareKey"] : (btn.Has("fkey") ? btn["fkey"] : "")
            ; Enforce strict 1-to-1 uniqueness: if this key was already assigned to a previous button, revoke it
            if (key != "" && assignedKeys.Has(key)) {
                key := ""
            }
            if (key != "") {
                assignedKeys[key] := bId
            }
            IniWrite(key, this.ConfigPath, sec, "Key")

            ; Hotspot coordinates
            if (btn.Has("x")) {
                IniWrite(String(btn["x"]), this.ConfigPath, "DiagramPoints", bId . "_X")
            }
            if (btn.Has("y")) {
                IniWrite(String(btn["y"]), this.ConfigPath, "DiagramPoints", bId . "_Y")
            }
        }

        ; Rebuild HardwareFKeys cleanly so no orphan or duplicate keys remain in settings.ini
        this.ButtonToFKeyMap := Map()
        this.FKeyToButtonMap := Map()
        try IniDelete(this.ConfigPath, "HardwareFKeys")

        for key, bId in assignedKeys {
            this.ButtonToFKeyMap[bId] := key
            this.FKeyToButtonMap[key] := bId
            IniWrite(key, this.ConfigPath, "HardwareFKeys", bId)
        }

        ; Save list of buttons
        listStr := ""
        for idx, id in idList {
            listStr .= (idx = 1 ? "" : ",") . id
        }
        IniWrite(listStr, this.ConfigPath, "Buttons", "List")
    }

    static DeleteCustomButton(btnId) {
        if (btnId = "") {
            return
        }

        ; Clean from ButtonToFKeyMap and HardwareFKeys
        if (this.ButtonToFKeyMap.Has(btnId)) {
            key := this.ButtonToFKeyMap[btnId]
            this.ButtonToFKeyMap.Delete(btnId)
            if (this.FKeyToButtonMap.Has(key)) {
                this.FKeyToButtonMap.Delete(key)
            }
            IniDelete(this.ConfigPath, "HardwareFKeys", btnId)
        }

        ; Delete button metadata and calibration
        IniDelete(this.ConfigPath, "Button_" . btnId)
        IniDelete(this.ConfigPath, "DiagramPoints", btnId . "_X")
        IniDelete(this.ConfigPath, "DiagramPoints", btnId . "_Y")
        IniDelete(this.ConfigPath, "CardOffsets", btnId . "_X")
        IniDelete(this.ConfigPath, "CardOffsets", btnId . "_Y")

        ; Delete from all profile mappings
        for prof in this.Profiles {
            IniDelete(this.ConfigPath, "Mapping_" . prof . "_" . btnId)
            if (this.ActiveMappings.Has(prof) && this.ActiveMappings[prof].Has(btnId)) {
                this.ActiveMappings[prof].Delete(btnId)
            }
        }

        ; Remove from Buttons List
        currList := IniRead(this.ConfigPath, "Buttons", "List", "")
        newList := []
        Loop Parse, currList, "," {
            id := Trim(A_LoopField)
            if (id != "" && id != btnId) {
                newList.Push(id)
            }
        }
        newListStr := ""
        for idx, id in newList {
            newListStr .= (idx = 1 ? "" : ",") . id
        }
        IniWrite(newListStr, this.ConfigPath, "Buttons", "List")
    }

    static ResetCustomButtons() {
        currList := IniRead(this.ConfigPath, "Buttons", "List", "")
        Loop Parse, currList, "," {
            id := Trim(A_LoopField)
            if (id != "") {
                IniDelete(this.ConfigPath, "Button_" . id)
            }
        }
        IniDelete(this.ConfigPath, "Buttons")
    }
}
