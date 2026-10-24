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

                ; Load GShift
                gsType   := IniRead(this.ConfigPath, section, "GShift_Type", def.GShift.Type)
                gsCmd    := IniRead(this.ConfigPath, section, "GShift_Cmd", def.GShift.Cmd)
                gsLbl    := IniRead(this.ConfigPath, section, "GShift_Label", def.GShift.Label)

                this.ActiveMappings[profile][btnId] := {
                    Normal: { Type: normType, Cmd: normCmd, Label: normLbl },
                    GShift: { Type: gsType, Cmd: gsCmd, Label: gsLbl }
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
            IniWrite(normalObj.Type, this.ConfigPath, section, "Normal_Type")
            IniWrite(normalObj.Cmd, this.ConfigPath, section, "Normal_Cmd")
            IniWrite(normalObj.Label, this.ConfigPath, section, "Normal_Label")

            IniWrite(gshiftObj.Type, this.ConfigPath, section, "GShift_Type")
            IniWrite(gshiftObj.Cmd, this.ConfigPath, section, "GShift_Cmd")
            IniWrite(gshiftObj.Label, this.ConfigPath, section, "GShift_Label")
        }
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
        return { Normal: { Type: "Send", Cmd: "", Label: "None" }, GShift: { Type: "Send", Cmd: "", Label: "None" } }
    }

    static GetButtonLabel(profile, btnId) {
        mapping := this.GetButtonMapping(profile, btnId)
        return mapping.Normal.Label
    }

    ; Switch to a specific profile
    static SetProfile(profileName) {
        for p in this.Profiles {
            if (p = profileName) {
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
    static ExecuteAction(btnId, isGShift) {
        mapping := this.GetButtonMapping(this.CurrentProfile, btnId)
        act := isGShift ? mapping.GShift : mapping.Normal

        if (act.Type = "Send" && act.Cmd != "") {
            Send(act.Cmd)
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

    ; --- Button Event Handlers (F13 - F21) ---
    ; Matches Logitech Onboard Memory Manager (OMM) physical layout

    ; Button 3: Middle Click (Mouse 3) -> F13
    static HandleF13_Middle(isDown) {
        if (!isDown)
            return
        this.NotifyButton("Middle", true)

        if (this.IsGShiftActive) {
            this.ChordTriggered := true
            this.ExecuteAction("Middle", true)
        } else {
            this.ExecuteAction("Middle", false)
        }
    }

    ; Button 4: Back Button Click (Mouse 4 / G4) -> F14
    static HandleF14_Back(isDown) {
        if (!isDown)
            return
        this.NotifyButton("Back", true)

        if (this.IsGShiftActive) {
            this.ChordTriggered := true
            this.ExecuteAction("Back", true)
        } else {
            this.ExecuteAction("Back", false)
        }
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
                this.ExecuteAction("DpiShift", false)
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
        if (!isDown)
            return
        this.NotifyButton("Forward", true)

        if (this.IsGShiftActive) {
            this.ChordTriggered := true
            this.ExecuteAction("Forward", true)
        } else {
            this.ExecuteAction("Forward", false)
        }
    }

    ; Button 7: Tilt Left -> F17
    static HandleF17_TiltLeft(isDown) {
        if (!isDown)
            return
        this.NotifyButton("TiltLeft", true)

        if (this.IsGShiftActive) {
            this.ChordTriggered := true
            this.ExecuteAction("TiltLeft", true)
        } else {
            this.ExecuteAction("TiltLeft", false)
        }
    }

    ; Button 8: Tilt Right -> F18
    static HandleF18_TiltRight(isDown) {
        if (!isDown)
            return
        this.NotifyButton("TiltRight", true)

        if (this.IsGShiftActive) {
            this.ChordTriggered := true
            this.ExecuteAction("TiltRight", true)
        } else {
            this.ExecuteAction("TiltRight", false)
        }
    }

    ; Button 9: Cycle Profiles (G9) -> F19
    static HandleF19_ProfileCycle(isDown) {
        if (!isDown)
            return
        this.NotifyButton("ProfileCycle", true)
        this.ExecuteAction("ProfileCycle", false)
    }

    ; Button 10: Next DPI (G8 / DPI Up) -> F20
    static HandleF20_G8(isDown) {
        if (!isDown)
            return
        this.NotifyButton("G8", true)

        if (this.IsGShiftActive) {
            this.ChordTriggered := true
            this.ExecuteAction("G8", true)
        } else {
            this.ExecuteAction("G8", false)
        }
    }

    ; Button 11: Previous DPI (G7 / DPI Down) -> F21
    static HandleF21_G7(isDown) {
        if (!isDown)
            return
        this.NotifyButton("G7", true)

        if (this.IsGShiftActive) {
            this.ChordTriggered := true
            this.ExecuteAction("G7", true)
        } else {
            this.ExecuteAction("G7", false)
        }
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
