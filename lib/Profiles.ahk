#Requires AutoHotkey v2.0

/**
 * Dynamic Profile & Macro Execution Engine for Logitech G502 X
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

    ; Profile Metadata: Map(profileName, { TargetExe: "...", Icon: "...", IsDefault: bool, SwitchOnHover: bool, Desc: "..." })
    static ProfileMetadata := Map(
        "Desktop",      { TargetExe: "", Icon: "desktop", IsDefault: true, SwitchOnHover: false, Desc: "Default System & Desktop Profile" }
    )

    static IsGShiftActive := false
    static IsGShift1Active := false
    static IsGShift2Active := false
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
    static PhysicalButtonStates := Map()
    static ActiveHeldButtons := Map()

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
        }

        ; Load metadata for each profile
        for prof in this.Profiles {
            if (!this.ProfileMetadata.Has(prof)) {
                this.ProfileMetadata[prof] := { TargetExe: "", Icon: (prof = "Desktop" ? "desktop" : "auto"), IsDefault: (prof = "Desktop"), SwitchOnHover: false, Desc: prof . " Profile" }
            }
            sec := "Profile_" . prof
            try {
                savedExe := IniRead(this.ConfigPath, sec, "TargetExe", this.ProfileMetadata[prof].TargetExe)
                savedIcon := IniRead(this.ConfigPath, sec, "Icon", this.ProfileMetadata[prof].Icon)
                savedDef := (IniRead(this.ConfigPath, sec, "IsDefault", this.ProfileMetadata[prof].IsDefault ? "1" : "0") = "1")
                savedHover := (IniRead(this.ConfigPath, sec, "SwitchOnHover", "0") = "1")
                this.ProfileMetadata[prof].TargetExe := savedExe
                if (prof != "Desktop" && (savedIcon == "generic" || savedIcon == ""))
                    savedIcon := "auto"
                this.ProfileMetadata[prof].Icon := savedIcon
                this.ProfileMetadata[prof].IsDefault := savedDef
                this.ProfileMetadata[prof].SwitchOnHover := savedHover
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

        for btnId, holdKey in this.ActiveHeldButtons {
            Send("{Blind}{" . holdKey . " up}")
        }
        this.ActiveHeldButtons.Clear()
        this.PhysicalButtonStates.Clear()
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
            this.AutoSwitchTimerFn := () => ProfileEngine.CheckActiveWindow()
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
                IniWrite((meta.HasOwnProp("SwitchOnHover") && meta.SwitchOnHover) ? "1" : "0", this.ConfigPath, sec, "SwitchOnHover")
                if (meta.HasOwnProp("Desc"))
                    IniWrite(meta.Desc, this.ConfigPath, sec, "Desc")
            }
        }
    }

    static AddProfile(name, targetExe := "", icon := "", switchOnHover := false) {
        name := Trim(name)
        if (name == "" || this.HasProfile(name))
            return false
            
        this.Profiles.Push(name)
        if (icon == "" || icon == "generic")
            icon := (name = "Desktop") ? "desktop" : "auto"
            
        this.ProfileMetadata[name] := { TargetExe: targetExe, Icon: icon, IsDefault: false, SwitchOnHover: switchOnHover, Desc: name . " Profile" }
        
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
            
        this.SaveProfileConfig()
        return true
    }

    static UpdateProfile(name, targetExe, icon := "", switchOnHover := -1) {
        name := Trim(name)
        if (!this.HasProfile(name))
            return false
            
        ; The default Desktop profile can never be bound to any executable
        if (name = "Desktop" || (this.ProfileMetadata.Has(name) && this.ProfileMetadata[name].IsDefault))
            targetExe := ""

        if (!this.ProfileMetadata.Has(name))
            this.ProfileMetadata[name] := { TargetExe: targetExe, Icon: (icon != "" ? icon : (name = "Desktop" ? "desktop" : "auto")), IsDefault: (name = "Desktop"), SwitchOnHover: false, Desc: name . " Profile" }
        else {
            this.ProfileMetadata[name].TargetExe := targetExe
            if (icon != "")
                this.ProfileMetadata[name].Icon := icon
            if (switchOnHover != -1)
                this.ProfileMetadata[name].SwitchOnHover := switchOnHover ? true : false
        }
        
        this.SaveProfileConfig()
        this.EnsureProfileIcon(name, targetExe)
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

    static CopySingleButtonMapping(profile, fromBtnId, toBtnId) {
        if (!this.ActiveMappings.Has(profile))
            return false
        pMap := this.ActiveMappings[profile]
        if (!pMap.Has(fromBtnId))
            return false

        fromMapping := pMap[fromBtnId]
        norm := fromMapping.Normal.Clone()
        gs := fromMapping.GShift.Clone()
        gs2 := (fromMapping.HasOwnProp("GShift2") && IsObject(fromMapping.GShift2)) ? fromMapping.GShift2.Clone() : norm.Clone()

        this.SaveButtonLayer(profile, toBtnId, "Normal", norm)
        this.SaveButtonLayer(profile, toBtnId, "GShift", gs)
        this.SaveButtonLayer(profile, toBtnId, "GShift2", gs2)
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

        if (FileExist(exePathOrName))
            return exePathOrName

        cleanName := RegExReplace(exePathOrName, "i)\.exe$", "") . ".exe"
        try {
            pid := ProcessExist(cleanName)
            if (pid) {
                p := ProcessGetPath(pid)
                if (FileExist(p))
                    return p
            }
        }
        try {
            p := RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\" . cleanName, "")
            if (p != "" && FileExist(p))
                return p
        }
        try {
            p := RegRead("HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\" . cleanName, "")
            if (p != "" && FileExist(p))
                return p
        }
        candidates := [
            A_AppData . "\..\Local\" . RegExReplace(cleanName, "i)\.exe$", "") . "\Application\" . cleanName,
            "C:\Program Files\" . RegExReplace(cleanName, "i)\.exe$", "") . "\" . cleanName,
            "C:\Program Files (x86)\" . RegExReplace(cleanName, "i)\.exe$", "") . "\" . cleanName
        ]
        for c in candidates {
            if (FileExist(c))
                return c
        }
        return ""
    }

    static ExtractExeIcon(fullPath, outPng) {
        try {
            if (!GdipHelper.Init())
                return false

            pathBuf := Buffer(520, 0)
            StrPut(fullPath, pathBuf, "UTF-16")
            index := 0
            hIcon := DllCall("shell32\ExtractAssociatedIcon", "Ptr", 0, "Ptr", pathBuf.Ptr, "Short*", &index, "Ptr")
            if (hIcon) {
                pBitmap := 0
                DllCall("gdiplus\GdipCreateBitmapFromHICON", "Ptr", hIcon, "Ptr*", &pBitmap)
                DllCall("user32\DestroyIcon", "Ptr", hIcon)
                
                if (pBitmap) {
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

    ; Dynamic execution engine
    static DispatchButton(btnId, isDown) {
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

        ; If Studio app is in focus and MuteWhenStudioFocused is active,
        ; prevent any mapping from executing (only visual highlight in NotifyButton fires)
        if (this.MuteWhenStudioFocused && WebViewGuiManager.IsStudioFocused()) {
            return
        }

        ; If not a shift modifier, execute based on currently held shift layer
        layer := "Normal"
        if (this.IsGShift2Active) {
            layer := "GShift2"
        } else if (this.IsGShift1Active || this.IsGShiftActive) {
            layer := "GShift"
        }

        this.ExecuteButtonEvent(btnId, layer, isDown)
    }

    static HandleShift1Modifier(btnId, isDown) {
        if (isDown) {
            this.IsGShift1Active := true
            this.IsGShiftActive := true
            this.NotifyShift(1, true)
        } else {
            this.IsGShift1Active := false
            this.IsGShiftActive := this.IsGShift2Active
            this.NotifyShift(1, false)
        }
    }

    static HandleShift2Modifier(btnId, isDown) {
        if (isDown) {
            this.IsGShift2Active := true
            this.IsGShiftActive := true
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
                    if (this.ActiveSequences.Has(btnId)) {
                        this.FinishSequence(btnId, act)
                    }
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
        ; (Exclude scroll wheel or multi-count like {Volume_Down 2})
        if (RegExMatch(cmd, "i)^\{([A-Za-z0-9_]+)\}$", &m)) {
            k := m[1]
            if (k != "WheelUp" && k != "WheelDown" && !InStr(k, "Volume_") && !InStr(k, "Media_"))
                return k
        }
        
        ; Single character: e.g. "d", "a", "1"
        if (StrLen(cmd) = 1)
            return StrLower(cmd)
            
        return ""
    }

    static ExecuteActionDown(act, btnId) {
        if ((act.Type = "Send" || act.Type = "Default") && act.Cmd != "") {
            holdKey := this.GetHoldableKey(act.Cmd)
            if (holdKey != "") {
                this.ActiveHeldButtons[btnId] := "{" . holdKey . " up}"
                Send("{Blind}{" . holdKey . " down}")
                return
            }
            ; Modifier + Mouse button hold support (e.g. ^{LButton}, !{RButton}, +{MButton})
            if (RegExMatch(act.Cmd, "^([!^#]+)\{(LButton|RButton|MButton|XButton1|XButton2)\}$", &modMbMatch)) {
                mods := modMbMatch[1]
                mb := modMbMatch[2]
                this.ActiveHeldButtons[btnId] := "{" . mb . " up}"
                Send("{Blind}" . mods . "{" . mb . " down}")
                return
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
        if ((act.Type = "Send" || act.Type = "Default") && act.Cmd != "") {
            if (act.Cmd = "{WheelUp}" || act.Cmd = "{WheelDown}") {
                Send("{Blind}" . act.Cmd)
            } else {
                cmd := this.NormalizeSendCmd(act.Cmd)
                Send(cmd)
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

    static PlaySteps(steps) {
        if (!IsObject(steps) || steps.Length = 0)
            return
        for step in steps {
            k := step.Key
            if (StrLen(k) = 1 && !InStr(k, "+")) {
                k := StrLower(k)
            }
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
    ; Matches Logitech Onboard Memory Manager (OMM) physical layout with dynamic swapping support

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
        if (!this.IsGShiftActive && !this.IsGShift1Active && !this.IsGShift2Active)
            return false

        mapping := this.GetButtonMapping(this.CurrentProfile, "LeftClick")
        act := (this.IsGShift2Active) ? mapping.GShift2 : mapping.GShift
        return this.IsCustomClickAction(act, "LButton")
    }

    static NeedsRightClickIntercept() {
        if (!this.IsGShiftActive && !this.IsGShift1Active && !this.IsGShift2Active)
            return false

        mapping := this.GetButtonMapping(this.CurrentProfile, "RightClick")
        act := (this.IsGShift2Active) ? mapping.GShift2 : mapping.GShift
        return this.IsCustomClickAction(act, "RButton")
    }

    static IsCustomClickAction(act, defaultKey) {
        if (!IsObject(act))
            return false
        if (act.Type = "Macro" || act.Type = "Special")
            return true
        if (act.Type = "Send") {
            if (act.Cmd != "" && act.Cmd != "{" . defaultKey . "}")
                return true
        }
        return false
    }

    static HandleLeftClick(isDown) {
        this.NotifyButton("LeftClick", isDown)
        if (this.MuteWhenStudioFocused && WebViewGuiManager.IsStudioFocused()) {
            return
        }
        this.DispatchButton("LeftClick", isDown)
    }

    static HandleRightClick(isDown) {
        this.NotifyButton("RightClick", isDown)
        if (this.MuteWhenStudioFocused && WebViewGuiManager.IsStudioFocused()) {
            return
        }
        this.DispatchButton("RightClick", isDown)
    }

    static LastWheelNotifyTime := 0

    ; Determines if WheelUp/WheelDown should be intercepted by AHK hook
    static NeedsWheelIntercept() {
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
        if (act.Type = "Macro" || act.Type = "Special")
            return true
        if (act.Cmd != "" && act.Cmd != "{" . defaultBtnId . "}")
            return true
        return false
    }

    ; Native Scroll Wheel Mapping & Dispatch (No F-key required)
    static DispatchWheel(direction) {
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

        ; Throttled GUI visual feedback (max once per 200ms)
        now := A_TickCount
        if (now - this.LastWheelNotifyTime > 200) {
            this.LastWheelNotifyTime := now
            this.NotifyButton(btnId, true)
            SetTimer(() => this.NotifyButton(btnId, false), -150)
        }

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
        ; Suppress redundant UI flash on OS typematic repeats
        if (isPressed && this.PhysicalButtonStates.Has(btnName) && this.PhysicalButtonStates[btnName])
            return
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
