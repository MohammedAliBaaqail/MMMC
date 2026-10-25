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

    ; Profile Metadata: Map(profileName, { TargetExe: "...", Icon: "...", IsDefault: bool, Desc: "..." })
    static ProfileMetadata := Map(
        "Desktop",      { TargetExe: "", Icon: "desktop", IsDefault: true, Desc: "Default System & Desktop Profile" }
    )

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
            "DpiShift",     { Normal: { Type: "Default", Cmd: "", Label: "DPI Shift" }, GShift: { Type: "Default", Cmd: "", Label: "Default" } },
            "Forward",      { Normal: { Type: "Send", Cmd: "!{Right}", Label: "Browser Forward" }, GShift: { Type: "Send", Cmd: "^w", Label: "Close Tab" } },
            "Back",         { Normal: { Type: "Send", Cmd: "!{Left}", Label: "Browser Back" }, GShift: { Type: "Send", Cmd: "^+t", Label: "Reopen Tab" } },
            "ProfileCycle", { Normal: { Type: "Special", Cmd: "CycleProfile", Label: "Next Profile" }, GShift: { Type: "Special", Cmd: "CycleProfile", Label: "Next Profile" } },
            "WheelUp",      { Normal: { Type: "Default", Cmd: "{WheelUp}", Label: "Default Scroll Up" }, GShift: { Type: "Send", Cmd: "{Volume_Up 2}", Label: "Volume Up" } },
            "WheelDown",    { Normal: { Type: "Default", Cmd: "{WheelDown}", Label: "Default Scroll Down" }, GShift: { Type: "Send", Cmd: "{Volume_Down 2}", Label: "Volume Down" } }
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
        }

        ; Load metadata for each profile
        for prof in this.Profiles {
            if (!this.ProfileMetadata.Has(prof)) {
                this.ProfileMetadata[prof] := { TargetExe: "", Icon: "generic", IsDefault: (prof = "Desktop"), Desc: prof . " Profile" }
            }
            sec := "Profile_" . prof
            try {
                savedExe := IniRead(this.ConfigPath, sec, "TargetExe", this.ProfileMetadata[prof].TargetExe)
                savedIcon := IniRead(this.ConfigPath, sec, "Icon", this.ProfileMetadata[prof].Icon)
                savedDef := (IniRead(this.ConfigPath, sec, "IsDefault", this.ProfileMetadata[prof].IsDefault ? "1" : "0") = "1")
                this.ProfileMetadata[prof].TargetExe := savedExe
                this.ProfileMetadata[prof].Icon := savedIcon
                this.ProfileMetadata[prof].IsDefault := savedDef
            }
            this.EnsureProfileIcon(prof, this.ProfileMetadata[prof].TargetExe)
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
    ; AUTOMATIC PROFILE SWITCHING BY WINDOW FOCUS (LGS STYLE)
    ; =========================================================================
    static StartAutoSwitchTimer() {
        if (!this.AutoSwitchTimerFn) {
            this.AutoSwitchTimerFn := () => ProfileEngine.CheckActiveWindow()
        }
        SetTimer(this.AutoSwitchTimerFn, 250)
    }

    static StopAutoSwitchTimer() {
        if (this.AutoSwitchTimerFn) {
            SetTimer(this.AutoSwitchTimerFn, 0)
        }
    }

    static CheckActiveWindow() {
        if (!this.AutoSwitchEnabled || this.LockedProfile != "")
            return
            
        try {
            activeHwnd := WinExist("A")
            if (!activeHwnd)
                return
                
            guiHwnd := (HasProp(WebViewGuiManager, "MainGui") && WebViewGuiManager.MainGui != "") ? WebViewGuiManager.MainGui.Hwnd : 0
            if (guiHwnd && (activeHwnd == guiHwnd || DllCall("IsChild", "ptr", guiHwnd, "ptr", activeHwnd)))
                return
                
            activeProc := WinGetProcessName(activeHwnd)
            if (activeProc == "" || activeProc = "AutoHotkey64.exe" || activeProc = "msedgewebview2.exe")
                return

            ; Ignore transient shell and system navigation windows:
            ; Taskbar, Start Menu, Search, Alt+Tab, System Tray, DWM
            winClass := WinGetClass(activeHwnd)
            if (winClass = "Shell_TrayWnd" || winClass = "Shell_SecondaryTrayWnd" || winClass = "Windows.UI.Core.CoreWindow" || winClass = "XamlExplorerHostIslandWindow")
                return

            if (activeProc = "SearchHost.exe" || activeProc = "StartMenuExperienceHost.exe" || activeProc = "ShellExperienceHost.exe" || activeProc = "MultitaskingView.exe" || activeProc = "dwm.exe")
                return

            ; If explorer.exe is focused, only switch to Desktop if it's the actual desktop wallpaper (Progman/WorkerW) or File Explorer (CabinetWClass)
            if (activeProc = "explorer.exe" && winClass != "Progman" && winClass != "WorkerW" && winClass != "CabinetWClass")
                return

            ; Find matching profile for activeProc
            matchedProfile := ""
            cleanProc := RegExReplace(activeProc, "i)\.exe$", "")

            for profName, meta in this.ProfileMetadata {
                ; 1. Match against TargetExe list
                if (meta.TargetExe != "") {
                    for exe in StrSplit(meta.TargetExe, [",", ";", "`n", "`r", " "]) {
                        exe := Trim(exe)
                        if (exe == "")
                            continue
                        cleanExe := RegExReplace(exe, "i)\.exe$", "")
                        if (StrCompare(cleanExe, cleanProc, false) == 0) {
                            matchedProfile := profName
                            break 2
                        }
                    }
                }
                ; 2. Match if profile name directly matches process name (e.g. "Vivaldi" profile matches vivaldi.exe)
                if (profName != "Desktop" && StrCompare(profName, cleanProc, false) == 0) {
                    matchedProfile := profName
                    break
                }
            }
            
            ; If no specific app profile matched, fallback to default profile ("Desktop")
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
            
            ; Switch if profile changed
            if (matchedProfile != this.CurrentProfile && this.HasProfile(matchedProfile)) {
                this.LastActiveProcess := activeProc
                WebViewGuiManager.Log("AutoSwitch: Active=" . activeProc . " -> Switch to Profile: " . matchedProfile . " (was: " . this.CurrentProfile . ")")
                this.SetProfile(matchedProfile)
            } else {
                this.LastActiveProcess := activeProc
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
                if (meta.HasOwnProp("Desc"))
                    IniWrite(meta.Desc, this.ConfigPath, sec, "Desc")
            }
        }
    }

    static AddProfile(name, targetExe := "", icon := "") {
        name := Trim(name)
        if (name == "" || this.HasProfile(name))
            return false
            
        this.Profiles.Push(name)
        if (icon == "")
            icon := "generic"
            
        this.ProfileMetadata[name] := { TargetExe: targetExe, Icon: icon, IsDefault: false, Desc: name . " Profile" }
        
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

    static UpdateProfile(name, targetExe, icon := "") {
        name := Trim(name)
        if (!this.HasProfile(name))
            return false
            
        if (!this.ProfileMetadata.Has(name))
            this.ProfileMetadata[name] := { TargetExe: targetExe, Icon: "generic", IsDefault: (name = "Desktop"), Desc: name . " Profile" }
        else {
            this.ProfileMetadata[name].TargetExe := targetExe
            if (icon != "")
                this.ProfileMetadata[name].Icon := icon
        }
        
        this.SaveProfileConfig()
        this.EnsureProfileIcon(name, targetExe)
        return true
    }

    static EnsureProfileIcon(profName, targetExe) {
        if (profName = "Desktop")
            return
        outDir := A_ScriptDir . "\web\icons"
        if (!DirExist(outDir)) {
            try DirCreate(outDir)
        }
        outPng := outDir . "\" . profName . ".png"
        if (FileExist(outPng))
            return
            
        fullPath := this.ResolveExePath(targetExe)
        if (fullPath != "" && FileExist(fullPath)) {
            this.ExtractExeIcon(fullPath, outPng)
        }
    }

    static ResolveExePath(exePathOrName) {
        exePathOrName := Trim(exePathOrName)
        if (exePathOrName == "")
            return ""
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
            token := 0
            si := Buffer(24, 0)
            NumPut("UInt", 1, si, 0)
            if (DllCall("gdiplus\GdiplusStartup", "Ptr*", &token, "Ptr", si.Ptr, "Ptr", 0) != 0)
                return false

            index := 0
            hIcon := DllCall("shell32\ExtractAssociatedIcon", "Ptr", 0, "Str", fullPath, "Short*", &index, "Ptr")
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
            DllCall("gdiplus\GdiplusShutdown", "Ptr", token)
            return FileExist(outPng) ? true : false
        } catch {
            return false
        }
    }

    static GetRunningProcesses() {
        procs := Map()
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
                            procs[pname] := title
                        }
                    }
                }
            }
        }
        out := []
        for pname, title in procs {
            out.Push(Map("process", pname, "title", title))
        }
        return out
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
        if ((act.Type = "Send" || act.Type = "Default") && act.Cmd != "") {
            if (act.Cmd = "{WheelUp}" || act.Cmd = "{WheelDown}") {
                Send("{Blind}" . act.Cmd)
            } else {
                Send(act.Cmd)
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
            this.Shift2ChordTriggered := true
        } else if (this.IsGShift1Active || this.IsGShiftActive) {
            layer := "GShift"
            this.Shift1ChordTriggered := true
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
        fn := this.OnButtonStateChanged
        if (fn) {
            fn(btnName, isPressed)
        }
    }
}
