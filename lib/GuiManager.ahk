#Requires AutoHotkey v2.0

/**
 * Modern Dark-Themed GUI for Logitech G502 X Controller
 * Exact Logitech Gaming Software (LGS) style visual layout with precision leader lines
 * pinned directly to each physical button on the mouse.
 * 
 * Double-clicking any button badge opens the Command & Combination Editor.
 */
class GuiManager {
    static MainGui := ""
    static ProfileDropdown := ""
    static GShiftStatusText := ""
    static RapidFireStatusText := ""
    static OMMStatusText := ""
    
    ; Live Monitor Controls
    static MonitorCards := Map()
    static MonitorActions := Map()

    ; Modal Editor Controls
    static EditorGui := ""
    static EditTargetId := ""
    static EditPresetDrop := ""
    static EditChkCtrl := ""
    static EditChkShift := ""
    static EditChkAlt := ""
    static EditChkWin := ""
    static EditKeyDrop := ""
    static EditCustomCmd := ""
    static EditGShiftPresetDrop := ""

    ; Preset Dictionary: Display Name -> { Type, Cmd, Label }
    static Presets := Map(
        "Copy (Ctrl + C)",                         { Type: "Send", Cmd: "^c", Label: "Copy (Ctrl+C)" },
        "Paste (Ctrl + V)",                        { Type: "Send", Cmd: "^v", Label: "Paste (Ctrl+V)" },
        "Cut (Ctrl + X)",                          { Type: "Send", Cmd: "^x", Label: "Cut (Ctrl+X)" },
        "Undo (Ctrl + Z)",                         { Type: "Send", Cmd: "^z", Label: "Undo (Ctrl+Z)" },
        "Redo (Ctrl + Y)",                         { Type: "Send", Cmd: "^y", Label: "Redo (Ctrl+Y)" },
        "Save (Ctrl + S)",                         { Type: "Send", Cmd: "^s", Label: "Save (Ctrl+S)" },
        "Select All (Ctrl + A)",                   { Type: "Send", Cmd: "^a", Label: "Select All" },
        "Find (Ctrl + F)",                         { Type: "Send", Cmd: "^f", Label: "Find (Ctrl+F)" },
        "Close Tab (Ctrl + W)",                    { Type: "Send", Cmd: "^w", Label: "Close Tab" },
        "New Tab (Ctrl + T)",                      { Type: "Send", Cmd: "^t", Label: "New Tab" },
        "Reopen Closed Tab (Ctrl + Shift + T)",    { Type: "Send", Cmd: "^+t", Label: "Reopen Tab" },
        "Next Browser Tab (Ctrl + Tab)",           { Type: "Send", Cmd: "^{Tab}", Label: "Next Browser Tab" },
        "Prev Browser Tab (Ctrl + Shift + Tab)",   { Type: "Send", Cmd: "^+{Tab}", Label: "Prev Browser Tab" },
        "Browser Back (Alt + Left)",               { Type: "Send", Cmd: "!{Left}", Label: "Browser Back" },
        "Browser Forward (Alt + Right)",           { Type: "Send", Cmd: "!{Right}", Label: "Browser Forward" },
        "Windows Task View (Win + Tab)",           { Type: "Send", Cmd: "#{Tab}", Label: "Task View" },
        "Show Desktop (Win + D)",                  { Type: "Send", Cmd: "#d", Label: "Show Desktop" },
        "Snap Window Left (Win + Left)",           { Type: "Send", Cmd: "#{Left}", Label: "Snap Win Left" },
        "Snap Window Right (Win + Right)",         { Type: "Send", Cmd: "#{Right}", Label: "Snap Win Right" },
        "Maximize Window (Win + Up)",              { Type: "Send", Cmd: "#{Up}", Label: "Maximize Win" },
        "Minimize Window (Win + Down)",            { Type: "Send", Cmd: "#{Down}", Label: "Minimize Win" },
        "Volume Up",                               { Type: "Send", Cmd: "{Volume_Up 2}", Label: "Volume Up" },
        "Volume Down",                             { Type: "Send", Cmd: "{Volume_Down 2}", Label: "Volume Down" },
        "Mute Audio",                              { Type: "Send", Cmd: "{Volume_Mute}", Label: "Mute Audio" },
        "Play / Pause",                            { Type: "Send", Cmd: "{Media_Play_Pause}", Label: "Play / Pause" },
        "Next Track",                              { Type: "Send", Cmd: "{Media_Next}", Label: "Next Track" },
        "Previous Track",                          { Type: "Send", Cmd: "{Media_Prev}", Label: "Previous Track" },
        "Cycle Next Profile",                      { Type: "Special", Cmd: "CycleProfile", Label: "Next Profile" },
        "Toggle Rapid-Fire",                       { Type: "Special", Cmd: "ToggleRapidFire", Label: "Toggle Rapid Fire" },
        "G-Shift Layer Modifier",                  { Type: "Special", Cmd: "GShift", Label: "G-Shift Layer" },
        "[Custom Key Combination]",                { Type: "Custom", Cmd: "", Label: "Custom Combo" },
        "[Raw AHK String / Macro]",                { Type: "Raw", Cmd: "", Label: "Raw Macro" }
    )

    static KeysList := [
        "A","B","C","D","E","F","G","H","I","J","K","L","M",
        "N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
        "0","1","2","3","4","5","6","7","8","9",
        "F1","F2","F3","F4","F5","F6","F7","F8","F9","F10","F11","F12",
        "Space","Enter","Escape","Tab","Backspace","Delete","Insert",
        "Home","End","PgUp","PgDn","Up","Down","Left","Right","PrintScreen"
    ]

    static Show() {
        if (this.MainGui != "") {
            this.MainGui.Show()
            return
        }

        ; Create Main GUI
        g := Gui("+AlwaysOnTop -MaximizeBox", "Logitech G502 X — Advanced Controller (LGS Precision Visuals)")
        g.BackColor := "181825"
        g.MarginX := 15
        g.MarginY := 15
        this.MainGui := g

        ; Header Row
        g.SetFont("s13 bold c89B4FA", "Segoe UI")
        g.Add("Text", "x20 y14 w550", "LOGITECH G502 X  //  INTERACTIVE CONTROLLER")
        
        g.SetFont("s9 norm cA6ADC8", "Segoe UI")
        g.Add("Text", "x20 y36 w550", "Double-click any button badge to customize commands and button combinations.")

        ; Tab Control
        g.SetFont("s10 norm cCDD6F4", "Segoe UI")
        tab := g.Add("Tab3", "x15 y60 w875 h620", ["Live Monitor", "Profiles && Cheatsheet", "OMM Setup Assistant"])

        ; Path to precision diagram with leader lines
        diagramPath := A_ScriptDir . "\assets\g502x_diagram.png"

        ; ========================================================
        ; TAB 1: Live Monitor (LGS Visual Mouse)
        ; ========================================================
        tab.UseTab(1)
        
        ; Status bar row
        g.SetFont("s10 bold c89B4FA", "Segoe UI")
        g.Add("Text", "Section x30 y95", "Active Profile:")
        
        g.SetFont("s9 norm c181825", "Segoe UI")
        this.ProfileDropdown := g.Add("DropDownList", "ys-2 w150", ProfileEngine.Profiles)
        this.ProfileDropdown.Choose(ProfileEngine.CurrentProfile)
        this.ProfileDropdown.OnEvent("Change", (ctrl, *) => ProfileEngine.SetProfile(ctrl.Text))

        g.SetFont("s10 bold c89B4FA", "Segoe UI")
        g.Add("Text", "ys+2 x+20", "G-Shift State:")
        g.SetFont("s10 bold cF38BA8", "Segoe UI")
        this.GShiftStatusText := g.Add("Text", "ys+2 x+6 w75", "INACTIVE")

        g.SetFont("s10 bold c89B4FA", "Segoe UI")
        g.Add("Text", "ys+2 x+16", "Rapid Fire:")
        g.SetFont("s10 bold cA6ADC8", "Segoe UI")
        this.RapidFireStatusText := g.Add("Text", "ys+2 x+6 w75", "OFF")

        ; Diagram with mouse and leader lines
        if FileExist(diagramPath) {
            g.Add("Picture", "x20 y140 w860 h500 +BackgroundTrans", diagramPath)
        }

        ; Callout pill badges placed exactly at the start of each leader line
        callouts := [
            { id: "TiltLeft",     name: "Tilt Left  [F13]",      x: 20,  y: 165 },
            { id: "G8",           name: "G8 (DPI Up)  [F15]",    x: 20,  y: 240 },
            { id: "G7",           name: "G7 (DPI Down)  [F16]",  x: 20,  y: 300 },
            { id: "DpiShift",     name: "DPI Shift  [F17]",      x: 20,  y: 375 },
            { id: "Forward",      name: "G5 (Forward)  [F18]",   x: 20,  y: 445 },
            { id: "Back",         name: "G4 (Back)  [F19]",      x: 20,  y: 515 },
            { id: "TiltRight",    name: "Tilt Right  [F14]",     x: 570, y: 165 },
            { id: "ProfileCycle", name: "G9 (Profile)  [F20]",   x: 700, y: 240 }
        ]

        for b in callouts {
            g.SetFont("s9 bold cCDD6F4", "Segoe UI")
            card := g.Add("Text", "x" . b.x . " y" . b.y . " w155 h22 0x200 Background1E1E2E Center +Border", b.name)
            card.ButtonId := b.id
            card.ButtonName := b.name
            card.OnEvent("DoubleClick", (ctrl, *) => this.OpenMappingEditor(ctrl.ButtonId, ctrl.ButtonName))

            g.SetFont("s8 italic c89B4FA", "Segoe UI")
            actionText := ProfileEngine.GetButtonLabel(ProfileEngine.CurrentProfile, b.id)
            actionCtrl := g.Add("Text", "x" . b.x . " y" . (b.y+22) . " w155 h18 Center Background1E1E2E", actionText)
            actionCtrl.ButtonId := b.id
            actionCtrl.ButtonName := b.name
            actionCtrl.OnEvent("DoubleClick", (ctrl, *) => this.OpenMappingEditor(ctrl.ButtonId, ctrl.ButtonName))

            this.MonitorCards[b.id] := card
            this.MonitorActions[b.id] := actionCtrl
        }

        ; G-Shift Quick Guide Box (Lower Right)
        g.SetFont("s9 bold c89B4FA", "Segoe UI")
        g.Add("Text", "x700 y320 w155 Center", "G-SHIFT CHORDS")
        g.SetFont("s8 norm cA6ADC8", "Segoe UI")
        g.Add("Text", "x700 y342 w155 h170 Background1E1E2E +Border", 
            " Hold DPI Shift (F17):`n`n"
            . " • Wheel = Vol Knob`n"
            . " • Tilt L/R = Snap Win`n"
            . " • G8 = Maximize Win`n"
            . " • G7 = Minimize Win`n"
            . " • G5 = Close Tab`n"
            . " • G4 = Reopen Tab"
        )

        ; Live status tip
        g.SetFont("s9 italic cA6ADC8", "Segoe UI")
        g.Add("Text", "x20 y580 w750", "💡 TIP: Double-click any button badge above to change its mapping & create custom combinations.")

        ; ========================================================
        ; TAB 2: Profiles & Cheatsheet
        ; ========================================================
        tab.UseTab(2)

        g.SetFont("s9 norm cCDD6F4", "Segoe UI")
        cheatsheet := 
            "1. DESKTOP PROFILE:`n"
            . "   • Tilt Left / Right: Prev / Next Browser Tab`n"
            . "   • G8 / G7: Volume Up / Volume Down`n"
            . "   • DPI Shift Tap: Windows Task View (Win+Tab) | Hold: G-Shift Layer`n"
            . "   • G5 (Forward) / G4 (Back): Browser Forward / Back`n"
            . "   • [G-Shift + Tilt]: Snap Window Left / Right (Win+Left/Right)`n"
            . "   • [G-Shift + G8/G7]: Maximize / Minimize Window`n"
            . "   • [G-Shift + G5/G4]: Close Tab (Ctrl+W) / Reopen Tab (Ctrl+Shift+T)`n"
            . "   • [G-Shift + Wheel]: Fast Volume Control`n`n"
            . "2. PRODUCTIVITY & CODE PROFILE:`n"
            . "   • Tilt Left / Right: Navigate Back / Forward Cursor History`n"
            . "   • G8 / G7: Duplicate Line Down / Delete Line`n"
            . "   • DPI Shift Tap: VS Code Command Palette (Ctrl+Shift+P)`n"
            . "   • G5 / G4: Redo (Ctrl+Y) / Undo (Ctrl+Z)`n"
            . "   • [G-Shift + G5/G4]: Format Document (Shift+Alt+F) / Save (Ctrl+S)`n`n"
            . "3. GAMING & TURBO PROFILE:`n"
            . "   • Tilt Left / Right: Weapon Slot 1 / Weapon Slot 2`n"
            . "   • G8: Toggle Rapid-Fire Turbo Clicker (20 CPS)`n"
            . "   • G7: Quick Ping / Tactical (Z)`n"
            . "   • DPI Shift: Hold for Sniper Steady Aim | Tap for Melee (V)`n"
            . "   • G5 / G4: Grenade (G) / Reload (R)`n`n"
            . "4. MEDIA & STREAMING PROFILE:`n"
            . "   • Tilt Left / Right: Previous / Next Track`n"
            . "   • G8 / G7: Volume Up / Down`n"
            . "   • DPI Shift Tap: Play / Pause`n"
            . "   • G5 / G4: Fast Forward / Rewind 10s"

        g.Add("Edit", "x30 y95 w815 h490 ReadOnly -VScroll -HScroll Background1E1E2E cCDD6F4", cheatsheet)

        ; ========================================================
        ; TAB 3: OMM Setup Assistant (Precision Key Injector)
        ; ========================================================
        tab.UseTab(3)

        g.SetFont("s9 norm cCDD6F4", "Segoe UI")
        g.Add("Text", "x30 y95 w815", 
            "HOW TO BIND IN LOGITECH ONBOARD MEMORY MANAGER (OMM):`n"
            . "1. Open Logitech Onboard Memory Manager (OMM.exe).`n"
            . "2. Click a button on your G502 X in OMM and choose 'Keystroke' -> 'Record'.`n"
            . "3. Click the matching button below. A 3-second countdown will begin.`n"
            . "4. Switch back to OMM during the countdown. AHK will inject the dedicated virtual key for you!`n"
            . "5. Save to onboard memory and close OMM forever."
        )

        g.SetFont("s10 bold cFAB387", "Segoe UI")
        this.OMMStatusText := g.Add("Text", "x30 y175 w815 Center", "Ready. Click any button below to inject into OMM.")

        ; Diagram in Tab 3 as well
        if FileExist(diagramPath) {
            g.Add("Picture", "x20 y200 w860 h500 +BackgroundTrans", diagramPath)
        }

        ; Push buttons placed right at the leader lines
        injectors := [
            { key: "F13", label: "Inject F13 (Tilt L)",    x: 20,  y: 225 },
            { key: "F15", label: "Inject F15 (G8 Up)",     x: 20,  y: 300 },
            { key: "F16", label: "Inject F16 (G7 Down)",   x: 20,  y: 360 },
            { key: "F17", label: "Inject F17 (DPI Shift)", x: 20,  y: 435 },
            { key: "F18", label: "Inject F18 (G5 Fwd)",    x: 20,  y: 505 },
            { key: "F19", label: "Inject F19 (G4 Back)",   x: 20,  y: 575 },
            { key: "F14", label: "Inject F14 (Tilt R)",    x: 570, y: 225 },
            { key: "F20", label: "Inject F20 (G9)",        x: 700, y: 300 }
        ]

        for k in injectors {
            btn := g.Add("Button", "x" . k.x . " y" . k.y . " w155 h38", k.label)
            btn.TargetKey := k.key
            btn.OnEvent("Click", (ctrl, *) => OMMHelper.StartCountdown(ctrl.TargetKey, GuiManager.OMMStatusText))
        }

        tab.UseTab() ; Exit tabs

        ; Bottom action row
        g.SetFont("s9 bold c89B4FA", "Segoe UI")
        btnHide := g.Add("Button", "x665 y688 w105 h30", "Minimize")
        btnHide.OnEvent("Click", (*) => g.Hide())

        btnExit := g.Add("Button", "x785 y688 w105 h30", "Exit App")
        btnExit.OnEvent("Click", (*) => ExitApp())

        ; Hook into profile engine events
        ProfileEngine.OnProfileChanged := (profileName) => this.UpdateProfileDisplay(profileName)
        ProfileEngine.OnButtonStateChanged := (btnName, isPressed) => this.FlashButton(btnName, isPressed)

        g.OnEvent("Close", (*) => g.Hide())
        g.Show("w905 h730")
    }

    ; ========================================================
    ; MODAL COMMAND & COMBINATION EDITOR
    ; ========================================================
    static OpenMappingEditor(btnId, btnDisplayName) {
        if (this.EditorGui != "") {
            this.EditorGui.Destroy()
            this.EditorGui := ""
        }

        this.EditTargetId := btnId
        currentProf := ProfileEngine.CurrentProfile
        currentMapping := ProfileEngine.GetButtonMapping(currentProf, btnId)

        eg := Gui("+AlwaysOnTop -MaximizeBox +Owner" . this.MainGui.Hwnd, "Edit Command — " . btnDisplayName)
        eg.BackColor := "181825"
        eg.MarginX := 20
        eg.MarginY := 18
        this.EditorGui := eg

        ; Header
        eg.SetFont("s12 bold c89B4FA", "Segoe UI")
        eg.Add("Text", "w520", "CUSTOMIZE BUTTON: " . btnDisplayName)
        eg.SetFont("s9 norm cA6ADC8", "Segoe UI")
        eg.Add("Text", "w520 y+2", "Profile: " . currentProf . "  |  Hardware Target: " . btnId)

        ; Section 1: Primary (Normal) Action
        eg.SetFont("s10 bold cCDD6F4", "Segoe UI")
        eg.Add("GroupBox", "w520 h225 y+16", "Normal Action (Standard Press)")

        eg.SetFont("s9 bold c89B4FA", "Segoe UI")
        eg.Add("Text", "xp+15 yp+28", "Select Command Preset or Combination:")

        presetNames := []
        for name in this.Presets {
            presetNames.Push(name)
        }

        eg.SetFont("s9 norm c181825", "Segoe UI")
        this.EditPresetDrop := eg.Add("DropDownList", "xp y+6 w490", presetNames)
        
        ; Match current mapping to preset
        matchedPreset := "[Custom Key Combination]"
        for pName, pData in this.Presets {
            if (pData.Type = currentMapping.Normal.Type && pData.Cmd = currentMapping.Normal.Cmd) {
                matchedPreset := pName
                break
            }
        }
        this.EditPresetDrop.Choose(matchedPreset)
        this.EditPresetDrop.OnEvent("Change", (*) => this.OnPresetChanged())

        ; Custom Combination Controls
        eg.SetFont("s9 bold cCDD6F4", "Segoe UI")
        eg.Add("Text", "xp y+16", "Or Build Custom Combination:")

        eg.SetFont("s9 norm cCDD6F4", "Segoe UI")
        this.EditChkCtrl  := eg.Add("CheckBox", "xp y+6", "Ctrl")
        this.EditChkShift := eg.Add("CheckBox", "x+16 yp", "Shift")
        this.EditChkAlt   := eg.Add("CheckBox", "x+16 yp", "Alt")
        this.EditChkWin   := eg.Add("CheckBox", "x+16 yp", "Win")

        eg.Add("Text", "x+20 yp+1", "+ Key:")
        eg.SetFont("s9 norm c181825", "Segoe UI")
        this.EditKeyDrop := eg.Add("DropDownList", "x+8 yp-3 w120", this.KeysList)
        this.EditKeyDrop.Choose("C")

        eg.SetFont("s9 bold c89B4FA", "Segoe UI")
        eg.Add("Text", "xp-240 y+16", "Raw AHK Command / String (Optional):")
        eg.SetFont("s9 norm cCDD6F4", "Segoe UI")
        this.EditCustomCmd := eg.Add("Edit", "xp y+6 w490 h24 Background1E1E2E cCDD6F4", currentMapping.Normal.Cmd)

        ; Section 2: G-Shift Secondary Action
        eg.SetFont("s10 bold cCDD6F4", "Segoe UI")
        eg.Add("GroupBox", "x20 y+24 w520 h90", "G-Shift Action (While DPI Shift is physically held)")

        eg.SetFont("s9 norm c181825", "Segoe UI")
        this.EditGShiftPresetDrop := eg.Add("DropDownList", "xp+15 yp+32 w490", presetNames)
        
        matchedGSPreset := "Snap Window Left (Win + Left)"
        for pName, pData in this.Presets {
            if (pData.Type = currentMapping.GShift.Type && pData.Cmd = currentMapping.GShift.Cmd) {
                matchedGSPreset := pName
                break
            }
        }
        this.EditGShiftPresetDrop.Choose(matchedGSPreset)

        ; Bottom Action Buttons
        eg.SetFont("s9 bold c181825", "Segoe UI")
        btnSave := eg.Add("Button", "x170 y+35 w120 h34 Default", "Save & Apply")
        btnSave.OnEvent("Click", (*) => this.SaveEditorMapping())

        btnReset := eg.Add("Button", "x+12 yp w120 h34", "Reset Default")
        btnReset.OnEvent("Click", (*) => this.ResetEditorMapping())

        btnCancel := eg.Add("Button", "x+12 yp w100 h34", "Cancel")
        btnCancel.OnEvent("Click", (*) => eg.Destroy())

        eg.OnEvent("Close", (*) => eg.Destroy())
        eg.Show("w560 h480")
    }

    static OnPresetChanged() {
        presetChoice := this.EditPresetDrop.Text
        if (this.Presets.Has(presetChoice)) {
            data := this.Presets[presetChoice]
            if (data.Type = "Send" || data.Type = "Special") {
                this.EditCustomCmd.Value := data.Cmd
            }
        }
    }

    static SaveEditorMapping() {
        btnId := this.EditTargetId
        currentProf := ProfileEngine.CurrentProfile
        presetChoice := this.EditPresetDrop.Text

        normalObj := {}

        if (presetChoice = "[Custom Key Combination]") {
            ; Assemble combination from checkboxes and key
            cmd := ""
            lblParts := []
            if (this.EditChkCtrl.Value)  { cmd .= "^", lblParts.Push("Ctrl") }
            if (this.EditChkShift.Value) { cmd .= "+", lblParts.Push("Shift") }
            if (this.EditChkAlt.Value)   { cmd .= "!", lblParts.Push("Alt") }
            if (this.EditChkWin.Value)   { cmd .= "#", lblParts.Push("Win") }
            
            chosenKey := this.EditKeyDrop.Text
            if (StrLen(chosenKey) = 1) {
                cmd .= StrLower(chosenKey)
            } else {
                cmd .= "{" . chosenKey . "}"
            }
            lblParts.Push(chosenKey)

            lbl := ""
            for i, p in lblParts {
                lbl .= (i > 1 ? " + " : "") . p
            }
            normalObj := { Type: "Send", Cmd: cmd, Label: lbl }
        } else if (presetChoice = "[Raw AHK String / Macro]") {
            raw := this.EditCustomCmd.Value
            normalObj := { Type: "Send", Cmd: raw, Label: "Raw: " . SubStr(raw, 1, 14) }
        } else if (this.Presets.Has(presetChoice)) {
            presetData := this.Presets[presetChoice]
            normalObj := { Type: presetData.Type, Cmd: presetData.Cmd, Label: presetData.Label }
        }

        ; G-Shift Action
        gsChoice := this.EditGShiftPresetDrop.Text
        gshiftObj := {}
        if (this.Presets.Has(gsChoice)) {
            gsData := this.Presets[gsChoice]
            gshiftObj := { Type: gsData.Type, Cmd: gsData.Cmd, Label: gsData.Label }
        } else {
            gshiftObj := { Type: "Send", Cmd: "", Label: "None" }
        }

        ; Save in ProfileEngine and write to settings.ini
        ProfileEngine.SaveMapping(currentProf, btnId, normalObj, gshiftObj)

        ; Update badge subtitle in GUI
        if (this.MonitorActions.Has(btnId)) {
            this.MonitorActions[btnId].Value := normalObj.Label
        }

        OSD.Show("Mapping Saved", btnId . " -> " . normalObj.Label)
        SoundBeep(1100, 100)

        if (this.EditorGui != "") {
            this.EditorGui.Destroy()
            this.EditorGui := ""
        }
    }

    static ResetEditorMapping() {
        btnId := this.EditTargetId
        currentProf := ProfileEngine.CurrentProfile
        ProfileEngine.ResetMappingToDefault(currentProf, btnId)

        ; Update badge subtitle
        if (this.MonitorActions.Has(btnId)) {
            this.MonitorActions[btnId].Value := ProfileEngine.GetButtonLabel(currentProf, btnId)
        }

        OSD.Show("Reset to Default", btnId)
        SoundBeep(800, 100)

        if (this.EditorGui != "") {
            this.EditorGui.Destroy()
            this.EditorGui := ""
        }
    }

    static UpdateProfileDisplay(profileName) {
        if (this.ProfileDropdown != "") {
            this.ProfileDropdown.Choose(profileName)
        }

        ; Update action texts on all callout cards
        for btnId, ctrl in this.MonitorActions {
            ctrl.Value := ProfileEngine.GetButtonLabel(profileName, btnId)
        }

        ; Update Rapid Fire display
        if (this.RapidFireStatusText != "") {
            if (ProfileEngine.RapidFireEnabled) {
                this.RapidFireStatusText.SetFont("c" . "A6E3A1")
                this.RapidFireStatusText.Value := "ON"
            } else {
                this.RapidFireStatusText.SetFont("c" . "A6ADC8")
                this.RapidFireStatusText.Value := "OFF"
            }
        }
    }

    static FlashButton(btnName, isPressed) {
        if (this.MainGui = "" || !WinExist(this.MainGui.Hwnd))
            return

        ; Update GShift status text if DPI Shift
        if (btnName = "DpiShift") {
            if (isPressed) {
                this.GShiftStatusText.SetFont("c" . "A6E3A1")
                this.GShiftStatusText.Value := "ACTIVE"
            } else {
                this.GShiftStatusText.SetFont("c" . "F38BA8")
                this.GShiftStatusText.Value := "INACTIVE"
            }
        }

        ; Highlight corresponding box
        if (this.MonitorCards.Has(btnName)) {
            card := this.MonitorCards[btnName]
            card.SetFont("bold cA6E3A1")

            ; Reset color after 300ms
            SetTimer(() => this.ResetButtonColor(btnName), -300)
        }
    }

    static ResetButtonColor(btnName) {
        if (this.MainGui != "" && this.MonitorCards.Has(btnName)) {
            card := this.MonitorCards[btnName]
            card.SetFont("bold cCDD6F4")
        }
    }
}
