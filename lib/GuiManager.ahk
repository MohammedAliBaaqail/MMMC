#Requires AutoHotkey v2.0

/**
 * Modern Dark-Themed GUI for Logitech G502 X Controller
 * Logitech Gaming Software (LGS) & G-HUB Hybrid Interface:
 *   - Precision leader lines pinned directly to hardware buttons
 *   - Interactive Left Sidebar Command Drawer (Search, Categories & Click-to-Assign)
 *   - Single-click to select button target; double-click for modal combo builder
 */
class GuiManager {
    static MainGui := ""
    static ProfileDropdown := ""
    static GShiftStatusText := ""
    static RapidFireStatusText := ""
    static OMMStatusText := ""
    
    ; Selected Button for assignment
    static SelectedButtonId := "G8"
    static SelectedButtonName := "G8 (DPI Up)"
    static TargetLabelText := ""
    static CurrentActionText := ""

    ; Sidebar Controls
    static SearchEdit := ""
    static CommandListView := ""

    ; Live Monitor Controls
    static MonitorCards := Map()
    static MonitorActions := Map()
    static MonitorSubtitles := Map()
    static ShowButtonNames := false
    static ToggleNamesBtn := ""

    ; Keystroke Recorder Modal & Macro Studio Controls
    static RecorderGui := ""
    static RecTargetId := ""
    static RecTargetName := ""
    static RecTabs := ""
    static RecPreviewText := ""
    static RecorderHook := ""
    static RecCapturedCmd := ""
    static RecCapturedLabel := ""
    static RecActiveCombo := []
    static RecKeysDown := Map()
    static RecDdlSingleMode := ""
    static RecEdtSingleInt := ""
    static RecTxtSingleExplain := ""
    static RecMacroHook := ""
    static RecIsRecordingMacro := false
    static RecDdlMacroMode := ""
    static RecTxtMacroExplain := ""
    static RecActivePhase := "ON PRESS"
    static RecBtnPhasePress := ""
    static RecBtnPhaseHold := ""
    static RecBtnPhaseRel := ""
    static RecChkRealDelays := ""
    static RecEdtDefDelay := ""
    static RecBtnRecordMacro := ""
    static RecLvMacro := ""
    static RecTxtMacroSummary := ""
    static RecStepsPress := []
    static RecStepsHold := []
    static RecStepsRelease := []
    static RecMacroActiveKeys := Map()
    static RecMacroLastTime := 0

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

    ; Complete Command Catalog for Sidebar (Category, Display Name, Type, Command, Label)
    static CommandCatalog := [
        ; --- Editing ---
        { Cat: "Editing", Name: "Undo",                  Type: "Send", Cmd: "^z",            Label: "Undo (Ctrl+Z)" },
        { Cat: "Editing", Name: "Redo",                  Type: "Send", Cmd: "^y",            Label: "Redo (Ctrl+Y)" },
        { Cat: "Editing", Name: "Copy",                  Type: "Send", Cmd: "^c",            Label: "Copy (Ctrl+C)" },
        { Cat: "Editing", Name: "Paste",                 Type: "Send", Cmd: "^v",            Label: "Paste (Ctrl+V)" },
        { Cat: "Editing", Name: "Cut",                   Type: "Send", Cmd: "^x",            Label: "Cut (Ctrl+X)" },
        { Cat: "Editing", Name: "Save",                  Type: "Send", Cmd: "^s",            Label: "Save (Ctrl+S)" },
        { Cat: "Editing", Name: "Select All",            Type: "Send", Cmd: "^a",            Label: "Select All" },
        { Cat: "Editing", Name: "Find",                  Type: "Send", Cmd: "^f",            Label: "Find (Ctrl+F)" },
        { Cat: "Editing", Name: "Duplicate Line",        Type: "Send", Cmd: "!+{Down}",      Label: "Duplicate Line" },
        { Cat: "Editing", Name: "Delete Line",           Type: "Send", Cmd: "^+k",           Label: "Delete Line" },
        
        { Cat: "Navigation", Name: "Middle Click",       Type: "Send", Cmd: "{MButton}",     Label: "Middle Click" },
        { Cat: "Navigation", Name: "Previous Tab",       Type: "Send", Cmd: "^+{Tab}",       Label: "Prev Tab" },
        { Cat: "Navigation", Name: "Next Tab",           Type: "Send", Cmd: "^{Tab}",        Label: "Next Tab" },
        { Cat: "Navigation", Name: "Close Tab",          Type: "Send", Cmd: "^w",            Label: "Close Tab" },
        { Cat: "Navigation", Name: "New Tab",            Type: "Send", Cmd: "^t",            Label: "New Tab" },
        { Cat: "Navigation", Name: "Reopen Closed Tab",  Type: "Send", Cmd: "^+t",           Label: "Reopen Tab" },
        { Cat: "Navigation", Name: "Browser Back",       Type: "Send", Cmd: "!{Left}",       Label: "Browser Back" },
        { Cat: "Navigation", Name: "Browser Forward",    Type: "Send", Cmd: "!{Right}",      Label: "Browser Forward" },
        { Cat: "Navigation", Name: "Refresh Page",       Type: "Send", Cmd: "{F5}",          Label: "Refresh (F5)" },
        
        ; --- System & Windows ---
        { Cat: "System", Name: "Windows Task View",      Type: "Send", Cmd: "#{Tab}",        Label: "Task View" },
        { Cat: "System", Name: "Show Desktop",           Type: "Send", Cmd: "#d",            Label: "Show Desktop" },
        { Cat: "System", Name: "Snap Window Left",       Type: "Send", Cmd: "#{Left}",       Label: "Snap Left" },
        { Cat: "System", Name: "Snap Window Right",      Type: "Send", Cmd: "#{Right}",      Label: "Snap Right" },
        { Cat: "System", Name: "Maximize Window",        Type: "Send", Cmd: "#{Up}",         Label: "Maximize Win" },
        { Cat: "System", Name: "Minimize Window",        Type: "Send", Cmd: "#{Down}",       Label: "Minimize Win" },
        { Cat: "System", Name: "Snipping Tool",          Type: "Send", Cmd: "#+s",           Label: "Screenshot" },
        { Cat: "System", Name: "File Explorer",          Type: "Send", Cmd: "#e",            Label: "Explorer" },
        { Cat: "System", Name: "Run Dialog",             Type: "Send", Cmd: "#r",            Label: "Run (Win+R)" },

        ; --- Media & Audio ---
        { Cat: "Media", Name: "Volume Up",               Type: "Send", Cmd: "{Volume_Up 2}", Label: "Volume Up" },
        { Cat: "Media", Name: "Volume Down",             Type: "Send", Cmd: "{Volume_Down 2}", Label: "Volume Down" },
        { Cat: "Media", Name: "Mute Audio",              Type: "Send", Cmd: "{Volume_Mute}", Label: "Mute Audio" },
        { Cat: "Media", Name: "Play / Pause",            Type: "Send", Cmd: "{Media_Play_Pause}", Label: "Play / Pause" },
        { Cat: "Media", Name: "Next Track",              Type: "Send", Cmd: "{Media_Next}",  Label: "Next Track" },
        { Cat: "Media", Name: "Previous Track",          Type: "Send", Cmd: "{Media_Prev}",  Label: "Previous Track" },
        { Cat: "Media", Name: "Stop Media",              Type: "Send", Cmd: "{Media_Stop}",  Label: "Stop Media" },

        ; --- Device & Special ---
        { Cat: "Device", Name: "G-Shift Layer Modifier", Type: "Special", Cmd: "GShift",     Label: "G-Shift Layer" },
        { Cat: "Device", Name: "Onboard Profile Cycle",  Type: "Special", Cmd: "CycleProfile", Label: "Next Profile" },
        { Cat: "Device", Name: "Toggle Rapid-Fire",      Type: "Special", Cmd: "ToggleRapidFire", Label: "Toggle Rapid Fire" }
    ]

    static Presets := Map(
        "Middle Click",                            { Type: "Send", Cmd: "{MButton}", Label: "Middle Click" },
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
        "F13","F14","F15","F16","F17","F18","F19","F20","F21","F22","F23","F24",
        "Space","Enter","Escape","Tab","Backspace","Delete","Insert",
        "Home","End","PgUp","PgDn","Up","Down","Left","Right","PrintScreen"
    ]

    static Show() {
        if (this.MainGui != "") {
            this.MainGui.Show()
            return
        }

        ; Create Main GUI (Wide G-HUB Studio Layout)
        g := Gui("+AlwaysOnTop -MaximizeBox", "Logitech G502 X — Advanced Controller (LGS & G-HUB Studio)")
        g.BackColor := "181825"
        g.MarginX := 15
        g.MarginY := 15
        this.MainGui := g

        ; Header Row
        g.SetFont("s13 bold c89B4FA", "Segoe UI")
        g.Add("Text", "x20 y14 w700", "LOGITECH G502 X  //  INTERACTIVE STUDIO")
        
        g.SetFont("s9 norm cA6ADC8", "Segoe UI")
        g.Add("Text", "x20 y36 w700", "Double-click any mouse button to record a key or combination. Use the left panel for presets and custom combos.")

        ; Tab Control
        g.SetFont("s10 norm cCDD6F4", "Segoe UI")
        tab := g.Add("Tab3", "x15 y60 w1110 h635", ["Live Monitor", "Profiles && Cheatsheet", "OMM Setup Assistant"])

        diagramPath := A_ScriptDir . "\assets\g502x_diagram.png"

        ; ========================================================
        ; TAB 1: Live Monitor (Sidebar Command Drawer + Mouse Diagram)
        ; ========================================================
        tab.UseTab(1)

        ; --- LEFT SIDEBAR: G-HUB Command Drawer ---
        g.SetFont("s9 bold c89B4FA", "Segoe UI")
        g.Add("Text", "x30 y95 w250", "SYSTEM COMMANDS")

        ; Target Button Header Card
        g.SetFont("s9 bold cA6E3A1", "Segoe UI")
        this.TargetLabelText := g.Add("Text", "x30 y118 w250 h20", "TARGET: G8 (DPI Up) [F20]")
        
        g.SetFont("s8 italic cA6ADC8", "Segoe UI")
        this.CurrentActionText := g.Add("Text", "x30 y138 w250 h18", "Action: Volume Up")

        ; Search Bar with cue
        g.SetFont("s9 norm c181825", "Segoe UI")
        this.SearchEdit := g.Add("Edit", "x30 y162 w250 h24", "")
        this.SearchEdit.OnEvent("Change", (*) => this.FilterCommandList())

        ; Commands List (ListView)
        g.SetFont("s9 norm cCDD6F4", "Segoe UI")
        this.CommandListView := g.Add("ListView", "x30 y192 w250 h370 Background1E1E2E +Report -Hdr +LV0x10000", ["Category", "Action", "Key"])
        this.CommandListView.ModifyCol(1, 0)   ; Hidden category col for sorting
        this.CommandListView.ModifyCol(2, 140) ; Action name
        this.CommandListView.ModifyCol(3, 95)  ; Shortcut / detail
        this.CommandListView.OnEvent("ItemSelect", (lv, item, selected) => this.OnSidebarItemSelected(lv, item, selected))
        this.CommandListView.OnEvent("DoubleClick", (*) => this.ApplySidebarAction())

        ; Populate Command List
        this.PopulateCommandList("")

        ; Sidebar Action Buttons
        g.SetFont("s9 bold c181825", "Segoe UI")
        btnAssign := g.Add("Button", "x30 y570 w250 h32 Default", "Map to Selected Button")
        btnAssign.OnEvent("Click", (*) => this.ApplySidebarAction())

        g.SetFont("s8 bold c89B4FA", "Segoe UI")
        btnCombo := g.Add("Button", "x30 y608 w120 h28", "Custom Combo...")
        btnCombo.OnEvent("Click", (*) => this.OpenMappingEditor(this.SelectedButtonId, this.SelectedButtonName))

        btnReset := g.Add("Button", "x160 y608 w120 h28", "Reset Default")
        btnReset.OnEvent("Click", (*) => this.ResetSelectedButton())

        ; --- RIGHT AREA: Status Row & Mouse Diagram ---

        ; Status bar row
        g.SetFont("s10 bold c89B4FA", "Segoe UI")
        g.Add("Text", "Section x305 y95", "Profile:")
        
        g.SetFont("s9 norm c181825", "Segoe UI")
        this.ProfileDropdown := g.Add("DropDownList", "ys-2 w140", ProfileEngine.Profiles)
        this.ProfileDropdown.Choose(ProfileEngine.CurrentProfile)
        this.ProfileDropdown.OnEvent("Change", (ctrl, *) => ProfileEngine.SetProfile(ctrl.Text))

        g.SetFont("s10 bold c89B4FA", "Segoe UI")
        g.Add("Text", "ys+2 x+18", "G-Shift:")
        g.SetFont("s10 bold cF38BA8", "Segoe UI")
        this.GShiftStatusText := g.Add("Text", "ys+2 x+6 w75", "INACTIVE")

        g.SetFont("s10 bold c89B4FA", "Segoe UI")
        g.Add("Text", "ys+2 x+14", "Rapid Fire:")
        g.SetFont("s10 bold cA6ADC8", "Segoe UI")
        this.RapidFireStatusText := g.Add("Text", "ys+2 x+6 w70", "OFF")

        ; Toggle switch on the top right to show / hide hardware button names
        g.SetFont("s9 bold c89B4FA", "Segoe UI")
        this.ToggleNamesBtn := g.Add("Button", "x940 y90 w170 h28", "Show Button Names: OFF")
        this.ToggleNamesBtn.OnEvent("Click", (*) => this.ToggleNameVisibility())

        ; Precision Diagram (Mouse and leader lines)
        if FileExist(diagramPath) {
            g.Add("Picture", "x280 y140 w820 h490 +BackgroundTrans", diagramPath)
        }

        ; Callout pill badges placed at the ends of the leader lines (Synced with OMM F13-F21)
        callouts := [
            { id: "TiltLeft",     name: "Tilt Left  [F17]",      x: 295, y: 165 },
            { id: "G8",           name: "G8 (DPI Up)  [F20]",    x: 295, y: 240 },
            { id: "G7",           name: "G7 (DPI Down)  [F21]",  x: 295, y: 300 },
            { id: "DpiShift",     name: "DPI Shift  [F15]",      x: 295, y: 375 },
            { id: "Forward",      name: "G5 (Forward)  [F16]",   x: 295, y: 445 },
            { id: "Back",         name: "G4 (Back)  [F14]",      x: 295, y: 515 },
            { id: "TiltRight",    name: "Tilt Right  [F18]",     x: 825, y: 165 },
            { id: "Middle",       name: "Middle Click  [F13]",   x: 825, y: 235 },
            { id: "ProfileCycle", name: "G9 (Profile)  [F19]",   x: 825, y: 305 }
        ]

        for b in callouts {
            actionText := ProfileEngine.GetButtonLabel(ProfileEngine.CurrentProfile, b.id)

            ; Top framed box: Action / Command Name
            g.SetFont("s9 bold cCDD6F4", "Segoe UI")
            card := g.Add("Text", "x" . b.x . " y" . b.y . " w145 h22 0x200 Background1E1E2E Center +Border", actionText)
            card.ButtonId := b.id
            card.ButtonName := b.name
            card.OnEvent("Click", (ctrl, *) => this.SelectButton(ctrl.ButtonId, ctrl.ButtonName))
            card.OnEvent("DoubleClick", (ctrl, *) => this.StartKeystrokeRecording(ctrl.ButtonId, ctrl.ButtonName))
            card.OnEvent("ContextMenu", (ctrl, *) => this.StartKeystrokeRecording(ctrl.ButtonId, ctrl.ButtonName))

            ; Bottom subtitle: Hardware Button Identifier & F-Key (Hidden by default)
            g.SetFont("s8 italic c89B4FA", "Segoe UI")
            btnSub := g.Add("Text", "x" . b.x . " y" . (b.y+22) . " w145 h18 Center Background1E1E2E", b.name)
            btnSub.ButtonId := b.id
            btnSub.ButtonName := b.name
            btnSub.Visible := this.ShowButtonNames
            btnSub.OnEvent("Click", (ctrl, *) => this.SelectButton(ctrl.ButtonId, ctrl.ButtonName))
            btnSub.OnEvent("DoubleClick", (ctrl, *) => this.StartKeystrokeRecording(ctrl.ButtonId, ctrl.ButtonName))
            btnSub.OnEvent("ContextMenu", (ctrl, *) => this.StartKeystrokeRecording(ctrl.ButtonId, ctrl.ButtonName))

            this.MonitorCards[b.id] := card
            this.MonitorActions[b.id] := card
            this.MonitorSubtitles[b.id] := btnSub
        }

        ; G-Shift Quick Guide Box (Right Column)
        g.SetFont("s9 bold c89B4FA", "Segoe UI")
        g.Add("Text", "x980 y165 w135 Center", "G-SHIFT CHORDS")
        g.SetFont("s8 norm cA6ADC8", "Segoe UI")
        g.Add("Text", "x980 y190 w135 h195 Background1E1E2E +Border", 
            " Hold DPI Shift (F15):`n`n"
            . " • Wheel = Vol Knob`n"
            . " • Middle = Close Tab`n"
            . " • Tilt L/R = Snap Win`n"
            . " • G8 = Maximize Win`n"
            . " • G7 = Minimize Win`n"
            . " • G5 = Close Tab`n"
            . " • G4 = Reopen Tab"
        )

        ; Highlight initial default selected button
        this.SelectButton("G8", "G8 (DPI Up) [F20]")

        ; ========================================================
        ; TAB 2: Profiles & Cheatsheet
        ; ========================================================
        tab.UseTab(2)

        g.SetFont("s9 norm cCDD6F4", "Segoe UI")
        cheatsheet := 
            "1. DESKTOP PROFILE:`n"
            . "   • Middle Click (F13): Default Middle Click | G-Shift: Close Tab (Ctrl+W)`n"
            . "   • G4 Back (F14) / G5 Forward (F16): Browser Back / Forward`n"
            . "   • DPI Shift (F15): Tap: Windows Task View (Win+Tab) | Hold: G-Shift Layer`n"
            . "   • Tilt Left (F17) / Right (F18): Prev / Next Browser Tab`n"
            . "   • G9 Profile (F19): Cycle Profiles`n"
            . "   • G8 (F20) / G7 (F21): Volume Up / Volume Down`n"
            . "   • [G-Shift + Tilt]: Snap Window Left / Right (Win+Left/Right)`n"
            . "   • [G-Shift + G8/G7]: Maximize / Minimize Window`n"
            . "   • [G-Shift + G5/G4]: Close Tab (Ctrl+W) / Reopen Tab (Ctrl+Shift+T)`n"
            . "   • [G-Shift + Wheel]: Fast Volume Control`n`n"
            . "2. PRODUCTIVITY & CODE PROFILE:`n"
            . "   • Middle Click (F13): Middle Click | G-Shift: Close Editor Tab (Ctrl+W)`n"
            . "   • G4 Back (F14) / G5 Forward (F16): Undo (Ctrl+Z) / Redo (Ctrl+Y)`n"
            . "   • DPI Shift (F15): VS Code Command Palette (Ctrl+Shift+P)`n"
            . "   • Tilt Left (F17) / Right (F18): Navigate Back / Forward Cursor History`n"
            . "   • G9 Profile (F19): Cycle Profiles`n"
            . "   • G8 (F20) / G7 (F21): Duplicate Line Down / Delete Line`n"
            . "   • [G-Shift + G5/G4]: Format Document (Shift+Alt+F) / Save (Ctrl+S)`n`n"
            . "3. GAMING & TURBO PROFILE:`n"
            . "   • Middle Click (F13): Middle Click / Ping / Secondary Attack`n"
            . "   • G4 Back (F14) / G5 Forward (F16): Reload (R) / Grenade (G)`n"
            . "   • DPI Shift (F15): Hold for Sniper Steady Aim | Tap for Melee (V)`n"
            . "   • Tilt Left (F17) / Right (F18): Weapon Slot 1 / Weapon Slot 2`n"
            . "   • G9 Profile (F19): Cycle Profiles`n"
            . "   • G8 (F20): Toggle Rapid-Fire Turbo Clicker (20 CPS)`n"
            . "   • G7 (F21): Quick Ping / Tactical (Z)`n`n"
            . "4. MEDIA & STREAMING PROFILE:`n"
            . "   • Middle Click (F13): Play / Pause Toggle`n"
            . "   • G4 Back (F14) / G5 Forward (F16): Fast Rewind / Forward 10s`n"
            . "   • DPI Shift (F15): Play / Pause`n"
            . "   • Tilt Left (F17) / Right (F18): Previous / Next Track`n"
            . "   • G9 Profile (F19): Cycle Profiles`n"
            . "   • G8 (F20) / G7 (F21): Volume Up / Down`n"

        g.Add("Edit", "x30 y95 w1050 h520 ReadOnly -VScroll -HScroll Background1E1E2E cCDD6F4", cheatsheet)

        ; ========================================================
        ; TAB 3: OMM Setup Assistant (Precision Key Injector)
        ; ========================================================
        tab.UseTab(3)

        g.SetFont("s9 norm cCDD6F4", "Segoe UI")
        g.Add("Text", "x30 y95 w1050", 
            "HOW TO BIND IN LOGITECH ONBOARD MEMORY MANAGER (OMM):`n"
            . "1. Open Logitech Onboard Memory Manager (OMM.exe).`n"
            . "2. Click a button on your G502 X in OMM and choose 'Keystroke' -> 'Record'.`n"
            . "3. Click the matching button below. A 3-second countdown will begin.`n"
            . "4. Switch back to OMM during the countdown. AHK will inject the dedicated virtual key for you!`n"
            . "5. Save to onboard memory and close OMM forever."
        )

        g.SetFont("s10 bold cFAB387", "Segoe UI")
        this.OMMStatusText := g.Add("Text", "x30 y175 w1050 Center", "Ready. Click any button below to inject into OMM.")

        if FileExist(diagramPath) {
            g.Add("Picture", "x280 y200 w820 h490 +BackgroundTrans", diagramPath)
        }

        ; Injectors mapped 1:1 to OMM buttons 3 to 11
        injectors := [
            { key: "F17", label: "Inject F17 (Tilt L)",    x: 295, y: 225 },
            { key: "F20", label: "Inject F20 (G8 Up)",     x: 295, y: 300 },
            { key: "F21", label: "Inject F21 (G7 Down)",   x: 295, y: 360 },
            { key: "F15", label: "Inject F15 (DPI Shift)", x: 295, y: 435 },
            { key: "F16", label: "Inject F16 (G5 Fwd)",    x: 295, y: 505 },
            { key: "F14", label: "Inject F14 (G4 Back)",   x: 295, y: 575 },
            { key: "F18", label: "Inject F18 (Tilt R)",    x: 825, y: 225 },
            { key: "F13", label: "Inject F13 (Middle)",    x: 825, y: 295 },
            { key: "F19", label: "Inject F19 (G9)",        x: 825, y: 365 }
        ]

        for k in injectors {
            btn := g.Add("Button", "x" . k.x . " y" . k.y . " w145 h38", k.label)
            btn.TargetKey := k.key
            btn.OnEvent("Click", (ctrl, *) => OMMHelper.StartCountdown(ctrl.TargetKey, GuiManager.OMMStatusText))
        }

        tab.UseTab() ; Exit tabs

        ; Bottom action row
        g.SetFont("s9 bold c89B4FA", "Segoe UI")
        btnHide := g.Add("Button", "x900 y705 w105 h30", "Minimize")
        btnHide.OnEvent("Click", (*) => g.Hide())

        btnExit := g.Add("Button", "x1020 y705 w105 h30", "Exit App")
        btnExit.OnEvent("Click", (*) => ExitApp())

        ; Hook into profile engine events
        ProfileEngine.OnProfileChanged := (profileName) => this.UpdateProfileDisplay(profileName)
        ProfileEngine.OnButtonStateChanged := (btnName, isPressed) => this.FlashButton(btnName, isPressed)

        g.OnEvent("Close", (*) => g.Hide())
        g.Show("w1145 h748")
    }

    static ToggleNameVisibility() {
        this.ShowButtonNames := !this.ShowButtonNames

        for btnId, subCtrl in this.MonitorSubtitles {
            subCtrl.Visible := this.ShowButtonNames
        }

        if (this.ToggleNamesBtn != "") {
            if (this.ShowButtonNames) {
                this.ToggleNamesBtn.Text := "Show Button Names: ON"
            } else {
                this.ToggleNamesBtn.Text := "Show Button Names: OFF"
            }
        }
    }

    ; ========================================================
    ; SELECTION & SIDEBAR LOGIC
    ; ========================================================
    static SelectButton(btnId, btnName) {
        ; Un-highlight previously selected
        if (this.SelectedButtonId != "" && this.MonitorCards.Has(this.SelectedButtonId)) {
            this.MonitorCards[this.SelectedButtonId].SetFont("bold cCDD6F4")
        }

        this.SelectedButtonId := btnId
        this.SelectedButtonName := btnName

        ; Highlight newly selected card in vibrant cyan
        if (this.MonitorCards.Has(btnId)) {
            this.MonitorCards[btnId].SetFont("bold c89B4FA")
        }

        currentProf := ProfileEngine.CurrentProfile
        currentAction := ProfileEngine.GetButtonLabel(currentProf, btnId)

        if (this.TargetLabelText != "") {
            this.TargetLabelText.Value := "TARGET: " . btnName
        }
        if (this.CurrentActionText != "") {
            this.CurrentActionText.Value := "Action: " . currentAction
        }
    }

    static PopulateCommandList(filterText := "") {
        this.CommandListView.Delete()
        filterLower := StrLower(Trim(filterText))

        for cmd in this.CommandCatalog {
            if (filterLower = "" || InStr(StrLower(cmd.Name), filterLower) || InStr(StrLower(cmd.Cat), filterLower) || InStr(StrLower(cmd.Label), filterLower)) {
                this.CommandListView.Add("", cmd.Cat, cmd.Name, cmd.Label)
            }
        }
    }

    static FilterCommandList() {
        this.PopulateCommandList(this.SearchEdit.Value)
    }

    static OnSidebarItemSelected(lv, item, selected) {
        if (!selected)
            return
        ; Single-click selects; user can click "Map" or double click to apply
    }

    static ApplySidebarAction() {
        row := this.CommandListView.GetNext(0)
        if (row = 0) {
            OSD.Show("Select Command First", "Click an action in the list on the left.")
            return
        }

        cmdName := this.CommandListView.GetText(row, 2)
        btnId := this.SelectedButtonId
        currentProf := ProfileEngine.CurrentProfile

        ; Find command object from catalog
        targetCmdObj := ""
        for item in this.CommandCatalog {
            if (item.Name = cmdName) {
                targetCmdObj := item
                break
            }
        }

        if (targetCmdObj = "")
            return

        normalObj := { Type: targetCmdObj.Type, Cmd: targetCmdObj.Cmd, Label: targetCmdObj.Label }
        
        ; Keep current GShift mapping
        currMap := ProfileEngine.GetButtonMapping(currentProf, btnId)
        gshiftObj := currMap.GShift

        ; Save & Apply
        ProfileEngine.SaveMapping(currentProf, btnId, normalObj, gshiftObj)

        ; Update GUI badge
        if (this.MonitorActions.Has(btnId)) {
            this.MonitorActions[btnId].Value := normalObj.Label
        }
        if (this.CurrentActionText != "") {
            this.CurrentActionText.Value := "Action: " . normalObj.Label
        }

        OSD.Show("Mapped: " . this.SelectedButtonName, "-> " . normalObj.Label)
        SoundBeep(1100, 80)
    }

    static ResetSelectedButton() {
        btnId := this.SelectedButtonId
        currentProf := ProfileEngine.CurrentProfile
        ProfileEngine.ResetMappingToDefault(currentProf, btnId)

        newLabel := ProfileEngine.GetButtonLabel(currentProf, btnId)
        if (this.MonitorActions.Has(btnId)) {
            this.MonitorActions[btnId].Value := newLabel
        }
        if (this.CurrentActionText != "") {
            this.CurrentActionText.Value := "Action: " . newLabel
        }

        OSD.Show("Reset to Default", btnId)
        SoundBeep(800, 80)
    }

    ; ========================================================
    ; MODAL KEYSTROKE & COMBINATION RECORDER (Double-Click)
    ; ========================================================
    ; ========================================================
    ; BUTTON STUDIO MODAL (Single / Combo & G-HUB Macro Recorder)
    ; ========================================================
    static StartKeystrokeRecording(btnId, btnDisplayName) {
        ; Stop any ongoing recorder or editor
        this.StopKeystrokeRecording(false)
        if (this.EditorGui != "") {
            this.EditorGui.Destroy()
            this.EditorGui := ""
        }

        this.RecTargetId := btnId
        this.RecTargetName := btnDisplayName
        this.RecIsRecordingMacro := false
        this.RecActivePhase := "ON PRESS"
        this.RecMacroActiveKeys.Clear()
        this.RecMacroLastTime := 0

        currMap := ProfileEngine.GetButtonMapping(ProfileEngine.CurrentProfile, btnId)
        norm := currMap.Normal

        ; Create Studio modal window
        rg := Gui("+AlwaysOnTop -MaximizeBox +Owner" . this.MainGui.Hwnd, "Button Studio — " . btnDisplayName)
        rg.BackColor := "181825"
        rg.MarginX := 20
        rg.MarginY := 18
        this.RecorderGui := rg

        ; Header
        rg.SetFont("s11 bold c89B4FA", "Segoe UI")
        rg.Add("Text", "x25 y15 w590 Center", "LOGITECH G502 X — BUTTON STUDIO")

        rg.SetFont("s9 bold cCDD6F4", "Segoe UI")
        rg.Add("Text", "x25 y38 w590 Center", "Target: " . btnDisplayName . "  •  Profile: " . ProfileEngine.CurrentProfile)

        ; Dual Mode Tabs
        rg.SetFont("s9 bold cCDD6F4", "Segoe UI")
        tabs := rg.Add("Tab3", "x25 y62 w590 h445 Choose1 -Theme", ["  ⌨  Single / Keystroke Combination  ", "  🗂  Macro Recorder (G-HUB Style)  "])
        this.RecTabs := tabs

        ; ========================================================
        ; TAB 1: SINGLE / COMBINATION OF BUTTONS
        ; ========================================================
        tabs.UseTab(1)

        rg.SetFont("s9 bold cCDD6F4", "Segoe UI")
        rg.Add("Text", "x45 y105 w240", "Playback Mode (How button is pressed):")
        this.RecDdlSingleMode := rg.Add("DropDownList", "x45 y125 w250 Choose1", ["No Repeat", "Repeat While Holding", "Toggle", "Sequence"])
        
        lblSingleInt := rg.Add("Text", "x315 y105 w150 cCDD6F4", "Repeat Delay (ms):")
        this.RecEdtSingleInt := rg.Add("Edit", "x315 y125 w90 Number", "50")

        rg.SetFont("s8 italic cA6ADC8", "Segoe UI")
        this.RecTxtSingleExplain := rg.Add("Text", "x45 y160 w550", "• Executes the keystroke once when the mouse button is pressed.")

        ; Live keystroke preview box
        rg.SetFont("s13 bold c89B4FA", "Segoe UI")
        this.RecPreviewText := rg.Add("Text", "x45 y188 w550 h54 0x200 Center Background11111B +Border", "[ Press Any Key or Combination ]")

        rg.SetFont("s8 norm cA6ADC8", "Segoe UI")
        rg.Add("Text", "x45 y252 w550 Center", "Press any key or combination (e.g. Q, Enter, Q + H, Ctrl + C, Shift + G + Enter).")

        rg.SetFont("s9 bold cCDD6F4", "Segoe UI")
        btnSingleReRecord := rg.Add("Button", "x180 y280 w130 h30", "🔄 Re-record Key")
        btnSingleClear    := rg.Add("Button", "x330 y280 w130 h30", "🗑 Clear Key")

        btnSingleReRecord.OnEvent("Click", (*) => this.ClearSingleKey())
        btnSingleClear.OnEvent("Click", (*) => this.ClearSingleKey())
        this.RecDdlSingleMode.OnEvent("Change", (*) => this.UpdateSingleModeExplain())

        ; ========================================================
        ; TAB 2: G-HUB MACRO RECORDER
        ; ========================================================
        tabs.UseTab(2)

        rg.SetFont("s9 bold cCDD6F4", "Segoe UI")
        rg.Add("Text", "x45 y105 w240", "Macro Type (Playback Mode):")
        this.RecDdlMacroMode := rg.Add("DropDownList", "x45 y125 w250 Choose1", ["No Repeat", "Repeat While Holding", "Toggle", "Sequence"])

        rg.SetFont("s8 italic cA6ADC8", "Segoe UI")
        this.RecTxtMacroExplain := rg.Add("Text", "x45 y158 w550", "• Standard macro. Plays the recorded sequence once.")

        ; Sequence Target Phase Selector
        rg.SetFont("s9 bold cFAB387", "Segoe UI")
        rg.Add("Text", "x45 y182 w110", "Target Section:")
        this.RecBtnPhasePress   := rg.Add("Button", "x160 y178 w125 h26", "ON PRESS")
        this.RecBtnPhaseHold    := rg.Add("Button", "x295 y178 w140 h26", "WHILE HOLDING")
        this.RecBtnPhaseRel     := rg.Add("Button", "x445 y178 w140 h26", "ON RELEASE")

        this.RecBtnPhasePress.OnEvent("Click", (*) => this.SetMacroPhase("ON PRESS"))
        this.RecBtnPhaseHold.OnEvent("Click", (*) => this.SetMacroPhase("WHILE HOLDING"))
        this.RecBtnPhaseRel.OnEvent("Click", (*) => this.SetMacroPhase("ON RELEASE"))

        ; Timing options
        rg.SetFont("s9 norm cCDD6F4", "Segoe UI")
        this.RecChkRealDelays := rg.Add("Checkbox", "x45 y213 w280", "Record delays from user input (real-time ms)")
        rg.Add("Text", "x340 y214 w145 cA6ADC8", "Default delay (ms):")
        this.RecEdtDefDelay := rg.Add("Edit", "x490 y211 w85 Number", "50")

        ; Recording and macro action buttons
        rg.SetFont("s9 bold cCDD6F4", "Segoe UI")
        this.RecBtnRecordMacro := rg.Add("Button", "x45 y244 w145 h32", "● Start Recording")
        btnClearSec   := rg.Add("Button", "x200 y244 w125 h32", "🗑 Clear Section")
        btnClearAll   := rg.Add("Button", "x335 y244 w115 h32", "🗑 Clear All")
        btnTestMacro  := rg.Add("Button", "x460 y244 w125 h32", "▶ Test Playback")

        this.RecBtnRecordMacro.OnEvent("Click", (*) => this.ToggleMacroRecording())
        btnClearSec.OnEvent("Click", (*) => this.ClearMacroSection())
        btnClearAll.OnEvent("Click", (*) => this.ClearAllMacroSteps())
        btnTestMacro.OnEvent("Click", (*) => this.TestMacroPlayback())
        this.RecDdlMacroMode.OnEvent("Change", (*) => this.UpdateMacroModeExplain())

        ; Recorded steps ListView
        rg.SetFont("s9 norm cCDD6F4", "Segoe UI")
        this.RecLvMacro := rg.Add("ListView", "x45 y284 w550 h180 Background11111B cCDD6F4 +Grid -Multi", ["#", "Section", "Event", "Key", "Delay (ms)"])
        this.RecLvMacro.ModifyCol(1, 40)
        this.RecLvMacro.ModifyCol(2, 120)
        this.RecLvMacro.ModifyCol(3, 110)
        this.RecLvMacro.ModifyCol(4, 150)
        this.RecLvMacro.ModifyCol(5, 110)

        ; Macro summary line
        rg.SetFont("s9 bold cA6E3A1", "Segoe UI")
        this.RecTxtMacroSummary := rg.Add("Text", "x45 y472 w550 h20", "Total Steps: 0  |  Press: 0  |  Hold: 0  |  Release: 0")

        ; ========================================================
        ; BOTTOM ACTION BAR (Universal Save & Cancel)
        ; ========================================================
        tabs.UseTab()

        rg.SetFont("s10 bold c11111B", "Segoe UI")
        btnSave := rg.Add("Button", "x160 y518 w190 h36", "✔ Save & Apply")
        rg.SetFont("s10 bold cCDD6F4", "Segoe UI")
        btnCancel := rg.Add("Button", "x370 y518 w130 h36", "Cancel (Esc)")

        btnSave.OnEvent("Click", (*) => this.SaveStudioMapping())
        btnCancel.OnEvent("Click", (*) => this.StopKeystrokeRecording(false))
        rg.OnEvent("Close", (*) => this.StopKeystrokeRecording(false))

        tabs.OnEvent("Change", (ctl, *) => this.OnStudioTabChanged(ctl.Value))

        ; ========================================================
        ; PRE-POPULATE DATA FROM CURRENT MAPPING
        ; ========================================================
        this.RecStepsPress := []
        this.RecStepsHold := []
        this.RecStepsRelease := []
        this.RecCapturedCmd := ""
        this.RecCapturedLabel := ""

        if (norm.Type = "Macro") {
            tabs.Value := 2
            this.RecDdlMacroMode.Choose(this.PlayTypeToIndex(norm.HasOwnProp("PlayType") ? norm.PlayType : "NoRepeat"))
            this.RecEdtDefDelay.Value := String(norm.HasOwnProp("RepeatInterval") ? norm.RepeatInterval : 50)
            if (norm.HasOwnProp("SeqPress") && norm.SeqPress.Length > 0)
                this.RecStepsPress := norm.SeqPress.Clone()
            else if (norm.HasOwnProp("Steps") && norm.Steps.Length > 0)
                this.RecStepsPress := norm.Steps.Clone()
            if (norm.HasOwnProp("SeqHold") && norm.SeqHold.Length > 0)
                this.RecStepsHold := norm.SeqHold.Clone()
            if (norm.HasOwnProp("SeqRelease") && norm.SeqRelease.Length > 0)
                this.RecStepsRelease := norm.SeqRelease.Clone()

            this.RefreshMacroListView()
            this.UpdateMacroModeExplain()
        } else {
            tabs.Value := 1
            if (norm.Cmd != "") {
                this.RecCapturedCmd := norm.Cmd
                this.RecCapturedLabel := norm.Label
                this.RecPreviewText.SetFont("c" . "A6E3A1")
                this.RecPreviewText.Value := "✔  " . norm.Label
            }
            this.RecDdlSingleMode.Choose(this.PlayTypeToIndex(norm.HasOwnProp("PlayType") ? norm.PlayType : "NoRepeat"))
            this.RecEdtSingleInt.Value := String(norm.HasOwnProp("RepeatInterval") ? norm.RepeatInterval : 50)
            this.UpdateSingleModeExplain()
            this.StartSingleKeyListening()
        }

        rg.Show("w640 h570")
        try this.RecPreviewText.Focus()
    }

    static PlayTypeToIndex(pt) {
        switch pt {
            case "NoRepeat", "No Repeat": return 1
            case "RepeatWhileHolding", "Repeat While Holding": return 2
            case "Toggle": return 3
            case "Sequence": return 4
            default: return 1
        }
    }

    static DisplayToPlayType(disp) {
        switch disp {
            case "No Repeat": return "NoRepeat"
            case "Repeat While Holding": return "RepeatWhileHolding"
            case "Toggle": return "Toggle"
            case "Sequence": return "Sequence"
            default: return "NoRepeat"
        }
    }

    static OnStudioTabChanged(tabIndex) {
        if (tabIndex = 1) {
            this.StopMacroRecordingHook()
            this.StartSingleKeyListening()
        } else {
            this.StopSingleKeyListening()
        }
    }

    static UpdateSingleModeExplain() {
        if (this.RecDdlSingleMode = "" || this.RecTxtSingleExplain = "" || this.RecorderGui = "" || !WinExist(this.RecorderGui.Hwnd))
            return
        try {
            switch this.RecDdlSingleMode.Text {
                case "No Repeat":
                    this.RecTxtSingleExplain.Value := "• Executes once when the mouse button is pressed."
                case "Repeat While Holding":
                    this.RecTxtSingleExplain.Value := "• Repeats the keystroke continuously while the mouse button is held down."
                case "Toggle":
                    this.RecTxtSingleExplain.Value := "• Press once to start continuous repeating; press again to stop."
                case "Sequence":
                    this.RecTxtSingleExplain.Value := "• Standard sequence playback on mouse button press."
            }
        }
    }

    static UpdateMacroModeExplain() {
        if (this.RecDdlMacroMode = "" || this.RecTxtMacroExplain = "" || this.RecorderGui = "" || !WinExist(this.RecorderGui.Hwnd))
            return
        try {
            m := this.RecDdlMacroMode.Text
            switch m {
                case "No Repeat":
                    this.RecTxtMacroExplain.Value := "• Standard macro. Plays the recorded sequence once."
                case "Repeat While Holding":
                    this.RecTxtMacroExplain.Value := "• Repeats the sequence continuously while mouse button is held down."
                case "Toggle":
                    this.RecTxtMacroExplain.Value := "• Press mouse button to start looping; press again to stop."
                case "Sequence":
                    this.RecTxtMacroExplain.Value := "• Executes 'On Press' once, loops 'While Holding' while held, executes 'On Release' on release."
            }
        }
    }

    static SetMacroPhase(phaseName) {
        this.RecActivePhase := phaseName
        OSD.Show("Macro Target Section", phaseName)
        SoundBeep(850, 50)
    }

    static ClearSingleKey() {
        this.RecCapturedCmd := ""
        this.RecCapturedLabel := ""
        this.RecActiveCombo := []
        this.RecKeysDown.Clear()
        if (this.RecPreviewText != "") {
            this.RecPreviewText.SetFont("c" . "89B4FA")
            this.RecPreviewText.Value := "[ Press Any Key or Combination ]"
        }
        this.StartSingleKeyListening()
    }

    static StartSingleKeyListening() {
        if (this.RecorderHook != "") {
            try this.RecorderHook.Stop()
            this.RecorderHook := ""
        }

        this.RecActiveCombo := []
        this.RecKeysDown.Clear()

        ih := InputHook("V I0")
        ih.KeyOpt("{All}", "N")
        this.RecorderHook := ih

        ih.OnKeyDown := (hook, vk, sc) => this.OnSingleKeyDown(vk, sc)
        ih.OnKeyUp   := (hook, vk, sc) => this.OnSingleKeyUp(vk, sc)
        ih.Start()
    }

    static StopSingleKeyListening() {
        if (this.RecorderHook != "") {
            try this.RecorderHook.Stop()
            this.RecorderHook := ""
        }
        this.RecActiveCombo := []
        this.RecKeysDown.Clear()
    }

    static NormalizeKeyName(vk, sc) {
        kName := GetKeyName(Format("vk{:02x}sc{:03x}", vk, sc))
        if (kName = "")
            return ""

        switch kName {
            case "Control", "Ctrl", "LCtrl", "RCtrl": return "Ctrl"
            case "Shift", "LShift", "RShift":         return "Shift"
            case "Alt", "LAlt", "RAlt":               return "Alt"
            case "LWin", "RWin":                     return "Win"
        }

        if (StrLen(kName) = 1)
            return StrUpper(kName)

        return kName
    }

    static OnSingleKeyDown(vk, sc) {
        if (this.RecorderGui = "" || !WinExist(this.RecorderGui.Hwnd))
            return

        kName := this.NormalizeKeyName(vk, sc)
        if (kName = "")
            return

        ; When all previous keys were released, start a fresh chord
        if (this.RecKeysDown.Count = 0) {
            this.RecActiveCombo := []
        }

        if (!this.RecKeysDown.Has(kName)) {
            this.RecKeysDown[kName] := true
            this.RecActiveCombo.Push(kName)
        }

        ; Live preview while holding down keys
        if (this.RecPreviewText != "" && this.RecActiveCombo.Length > 0) {
            liveTxt := ""
            for i, k in this.RecActiveCombo {
                liveTxt .= (i = 1 ? "" : " + ") . k
            }
            this.RecPreviewText.SetFont("c" . "89B4FA")
            this.RecPreviewText.Value := liveTxt . " ..."
        }
    }

    static OnSingleKeyUp(vk, sc) {
        if (this.RecorderGui = "" || !WinExist(this.RecorderGui.Hwnd))
            return

        kName := this.NormalizeKeyName(vk, sc)
        if (this.RecKeysDown.Has(kName)) {
            this.RecKeysDown.Delete(kName)
        }

        ; When all keys in the chord are released, finalize the combination
        if (this.RecKeysDown.Count = 0 && this.RecActiveCombo.Length > 0) {
            res := this.FormatCombination(this.RecActiveCombo)
            this.RecCapturedCmd := res.Cmd
            this.RecCapturedLabel := res.Label

            if (this.RecPreviewText != "") {
                this.RecPreviewText.SetFont("c" . "A6E3A1")
                this.RecPreviewText.Value := "✔  " . res.Label
            }
            SoundBeep(1100, 70)
        }
    }

    static FormatCombination(comboList) {
        if (!IsObject(comboList) || comboList.Length = 0)
            return { Cmd: "", Label: "" }

        label := ""
        for i, k in comboList {
            label .= (i = 1 ? "" : " + ") . k
        }

        if (comboList.Length = 1) {
            k := comboList[1]
            cmd := (StrLen(k) = 1) ? StrLower(k) : "{" . k . "}"
            return { Cmd: cmd, Label: label }
        }

        isStandardModCombo := true
        lastIdx := comboList.Length
        for i, k in comboList {
            if (i < lastIdx) {
                if (k != "Ctrl" && k != "Shift" && k != "Alt" && k != "Win") {
                    isStandardModCombo := false
                    break
                }
            }
        }

        if (isStandardModCombo) {
            prefix := ""
            for i, k in comboList {
                if (i < lastIdx) {
                    switch k {
                        case "Ctrl":  prefix .= "^"
                        case "Shift": prefix .= "+"
                        case "Alt":   prefix .= "!"
                        case "Win":   prefix .= "#"
                    }
                }
            }
            lastK := comboList[lastIdx]
            keyPart := (StrLen(lastK) = 1) ? StrLower(lastK) : "{" . lastK . "}"
            return { Cmd: prefix . keyPart, Label: label }
        }

        downSeq := ""
        upSeq := ""
        for k in comboList {
            kPart := (StrLen(k) = 1) ? StrLower(k) : k
            downSeq .= "{" . kPart . " down}"
        }
        idx := comboList.Length
        while (idx >= 1) {
            k := comboList[idx]
            kPart := (StrLen(k) = 1) ? StrLower(k) : k
            upSeq .= "{" . kPart . " up}"
            idx--
        }
        return { Cmd: downSeq . upSeq, Label: label }
    }

    ; ========================================================
    ; TAB 2 MACRO RECORDER LOGIC
    ; ========================================================
    static ToggleMacroRecording() {
        if (this.RecIsRecordingMacro) {
            ; Stop Recording
            this.StopMacroRecordingHook()
            this.RecBtnRecordMacro.Text := "● Start Recording"
            this.RecIsRecordingMacro := false
            OSD.Show("Recording Stopped", "Macro captured successfully")
            SoundBeep(800, 80)
        } else {
            ; Start Recording
            this.StopSingleKeyListening()
            this.RecIsRecordingMacro := true
            this.RecBtnRecordMacro.Text := "■ Stop Recording"
            this.RecMacroActiveKeys.Clear()
            this.RecMacroLastTime := A_TickCount

            ih := InputHook("V")
            ih.KeyOpt("{All}", "N")
            ih.OnKeyDown := (hook, vk, sc) => this.OnMacroKeyDown(vk, sc)
            this.RecMacroHook := ih
            ih.Start()

            OSD.Show("Recording Macro (" . this.RecActivePhase . ")", "Press keys on keyboard. Click Stop when done.")
            SoundBeep(1200, 100)
        }
    }

    static StopMacroRecordingHook() {
        if (this.RecMacroHook != "") {
            try this.RecMacroHook.Stop()
            this.RecMacroHook := ""
        }
        ; Resolve any still-held down keys if GUI is alive
        if (this.RecorderGui != "" && WinExist(this.RecorderGui.Hwnd)) {
            for kName, tDown in this.RecMacroActiveKeys {
                del := 50
                try {
                    if (this.RecEdtDefDelay != "")
                        del := Integer(this.RecEdtDefDelay.Value)
                }
                this.AddMacroStep(this.RecActivePhase, "Up", kName, del)
            }
            try {
                if (this.RecBtnRecordMacro != "")
                    this.RecBtnRecordMacro.Text := "● Start Recording"
            }
        }
        this.RecMacroActiveKeys.Clear()
        this.RecIsRecordingMacro := false
    }

    static OnMacroKeyDown(vk, sc) {
        if (!this.RecIsRecordingMacro || this.RecorderGui = "" || !WinExist(this.RecorderGui.Hwnd))
            return

        kName := GetKeyName(Format("vk{:02x}sc{:03x}", vk, sc))
        if (kName = "")
            return

        if (kName = "Escape") {
            this.ToggleMacroRecording()
            return
        }

        if (this.RecMacroActiveKeys.Has(kName))
            return ; Ignore auto-repeat keydown

        tNow := A_TickCount
        del := (this.RecChkRealDelays.Value && this.RecMacroLastTime > 0) ? Max(10, tNow - this.RecMacroLastTime) : Integer(this.RecEdtDefDelay.Value)
        this.RecMacroLastTime := tNow
        this.RecMacroActiveKeys[kName] := tNow

        this.AddMacroStep(this.RecActivePhase, "Down", kName, del)

        fn := () => this.CheckMacroKeyRelease(kName, fn)
        SetTimer(fn, 15)
    }

    static CheckMacroKeyRelease(kName, fn) {
        if (!this.RecMacroActiveKeys.Has(kName)) {
            SetTimer(fn, 0)
            return
        }

        if (!GetKeyState(kName, "P")) {
            tNow := A_TickCount
            tDown := this.RecMacroActiveKeys[kName]
            del := this.RecChkRealDelays.Value ? Max(10, tNow - tDown) : Integer(this.RecEdtDefDelay.Value)
            this.RecMacroLastTime := tNow
            this.RecMacroActiveKeys.Delete(kName)
            SetTimer(fn, 0)

            this.AddMacroStep(this.RecActivePhase, "Up", kName, del)
        }
    }

    static AddMacroStep(phase, action, key, delay) {
        stepObj := { Action: action, Key: key, Delay: delay }
        switch phase {
            case "ON PRESS":      this.RecStepsPress.Push(stepObj)
            case "WHILE HOLDING": this.RecStepsHold.Push(stepObj)
            case "ON RELEASE":    this.RecStepsRelease.Push(stepObj)
        }

        if (this.RecLvMacro != "" && this.RecorderGui != "" && WinExist(this.RecorderGui.Hwnd)) {
            try {
                row := this.RecLvMacro.GetCount() + 1
                actionLbl := (action = "Down") ? "Key Down ▼" : "Key Up ▲"
                this.RecLvMacro.Add("", row, phase, actionLbl, key, delay)
                this.RecLvMacro.Modify(row, "Vis")
            }
        }

        this.UpdateMacroSummary()
    }

    static RefreshMacroListView() {
        if (this.RecLvMacro = "" || this.RecorderGui = "" || !WinExist(this.RecorderGui.Hwnd))
            return
        try {
            this.RecLvMacro.Delete()
            row := 1

            for s in this.RecStepsPress {
                this.RecLvMacro.Add("", row++, "ON PRESS", (s.Action = "Down" ? "Key Down ▼" : "Key Up ▲"), s.Key, s.Delay)
            }
            for s in this.RecStepsHold {
                this.RecLvMacro.Add("", row++, "WHILE HOLDING", (s.Action = "Down" ? "Key Down ▼" : "Key Up ▲"), s.Key, s.Delay)
            }
            for s in this.RecStepsRelease {
                this.RecLvMacro.Add("", row++, "ON RELEASE", (s.Action = "Down" ? "Key Down ▼" : "Key Up ▲"), s.Key, s.Delay)
            }
        }

        this.UpdateMacroSummary()
    }

    static UpdateMacroSummary() {
        if (this.RecTxtMacroSummary = "" || this.RecorderGui = "" || !WinExist(this.RecorderGui.Hwnd))
            return
        tot := this.RecStepsPress.Length + this.RecStepsHold.Length + this.RecStepsRelease.Length
        try {
            this.RecTxtMacroSummary.Value := "Total Steps: " . tot . "  |  Press: " . this.RecStepsPress.Length . "  |  Hold: " . this.RecStepsHold.Length . "  |  Release: " . this.RecStepsRelease.Length
        }
    }

    static ClearMacroSection() {
        switch this.RecActivePhase {
            case "ON PRESS":      this.RecStepsPress := []
            case "WHILE HOLDING": this.RecStepsHold := []
            case "ON RELEASE":    this.RecStepsRelease := []
        }
        this.RefreshMacroListView()
        OSD.Show("Cleared Section", this.RecActivePhase)
        SoundBeep(650, 70)
    }

    static ClearAllMacroSteps() {
        this.RecStepsPress := []
        this.RecStepsHold := []
        this.RecStepsRelease := []
        this.RefreshMacroListView()
        OSD.Show("Cleared All", "All macro phases emptied")
        SoundBeep(600, 70)
    }

    static TestMacroPlayback() {
        stepsToPlay := []
        if (this.RecActivePhase = "ON PRESS" && this.RecStepsPress.Length > 0)
            stepsToPlay := this.RecStepsPress
        else if (this.RecActivePhase = "WHILE HOLDING" && this.RecStepsHold.Length > 0)
            stepsToPlay := this.RecStepsHold
        else if (this.RecActivePhase = "ON RELEASE" && this.RecStepsRelease.Length > 0)
            stepsToPlay := this.RecStepsRelease
        else if (this.RecStepsPress.Length > 0)
            stepsToPlay := this.RecStepsPress

        if (stepsToPlay.Length = 0) {
            OSD.Show("Nothing to Play", "Record macro steps first")
            return
        }

        OSD.Show("Testing Macro...", "Playing " . stepsToPlay.Length . " steps")
        ProfileEngine.PlaySteps(stepsToPlay)
        OSD.Show("Playback Finished", "Macro test complete")
    }

    ; ========================================================
    ; UNIVERSAL SAVE AND CLOSE
    ; ========================================================
    static SaveStudioMapping() {
        btnId := this.RecTargetId
        currentProf := ProfileEngine.CurrentProfile
        currMap := ProfileEngine.GetButtonMapping(currentProf, btnId)

        activeTab := this.RecTabs.Value

        if (activeTab = 1) {
            ; Save Single / Combination
            if (this.RecCapturedCmd = "") {
                OSD.Show("No Key Recorded", "Please press a key or combo first")
                return
            }
            playType := this.DisplayToPlayType(this.RecDdlSingleMode.Text)
            intVal := IsInteger(this.RecEdtSingleInt.Value) ? Integer(this.RecEdtSingleInt.Value) : 50
            normalObj := {
                Type: "Send",
                Cmd: this.RecCapturedCmd,
                Label: this.RecCapturedLabel,
                PlayType: playType,
                RepeatInterval: intVal
            }
            ProfileEngine.SaveMapping(currentProf, btnId, normalObj, currMap.GShift)
            label := normalObj.Label
        } else {
            ; Save Macro Recorder
            playType := this.DisplayToPlayType(this.RecDdlMacroMode.Text)
            defDelay := IsInteger(this.RecEdtDefDelay.Value) ? Integer(this.RecEdtDefDelay.Value) : 50

            if (playType = "Sequence") {
                tot := this.RecStepsPress.Length + this.RecStepsHold.Length + this.RecStepsRelease.Length
                if (tot = 0) {
                    OSD.Show("No Steps Recorded", "Record at least one key event")
                    return
                }
                label := "Seq Macro (" . tot . " steps)"
                normalObj := {
                    Type: "Macro",
                    Cmd: "Sequence",
                    Label: label,
                    PlayType: "Sequence",
                    RepeatInterval: defDelay,
                    SeqPress: this.RecStepsPress,
                    SeqHold: this.RecStepsHold,
                    SeqRelease: this.RecStepsRelease,
                    Steps: this.RecStepsPress
                }
            } else {
                if (this.RecStepsPress.Length = 0) {
                    OSD.Show("No Steps Recorded", "Record at least one key event in ON PRESS")
                    return
                }
                label := "Macro: " . playType . " (" . this.RecStepsPress.Length . " steps)"
                normalObj := {
                    Type: "Macro",
                    Cmd: "Macro",
                    Label: label,
                    PlayType: playType,
                    RepeatInterval: defDelay,
                    Steps: this.RecStepsPress
                }
            }
            ProfileEngine.SaveMapping(currentProf, btnId, normalObj, currMap.GShift)
        }

        ; Update badge and sidebar
        if (this.MonitorActions.Has(btnId)) {
            this.MonitorActions[btnId].Value := label
        }
        if (this.CurrentActionText != "") {
            this.CurrentActionText.Value := "Action: " . label
        }

        OSD.Show("Mapping Saved", this.RecTargetName . " -> " . label)
        SoundBeep(1200, 100)
        this.StopKeystrokeRecording(true)
    }

    static StopKeystrokeRecording(wasMapped := false) {
        this.StopSingleKeyListening()
        this.StopMacroRecordingHook()

        if (this.RecorderGui != "") {
            try {
                this.RecorderGui.Destroy()
            }
            this.RecorderGui := ""
        }

        ; Null out all control references to avoid "control is destroyed" errors
        this.RecTabs := ""
        this.RecPreviewText := ""
        this.RecDdlSingleMode := ""
        this.RecEdtSingleInt := ""
        this.RecTxtSingleExplain := ""
        this.RecDdlMacroMode := ""
        this.RecTxtMacroExplain := ""
        this.RecBtnPhasePress := ""
        this.RecBtnPhaseHold := ""
        this.RecBtnPhaseRel := ""
        this.RecChkRealDelays := ""
        this.RecEdtDefDelay := ""
        this.RecBtnRecordMacro := ""
        this.RecLvMacro := ""
        this.RecTxtMacroSummary := ""

        if (!wasMapped && this.RecTargetName != "") {
            OSD.Show("Studio Closed", "No changes applied")
        }
        this.RecTargetId := ""
        this.RecTargetName := ""
    }

    static IsRecording() {
        return (this.RecorderGui != "" && WinExist(this.RecorderGui.Hwnd))
    }

    ; ========================================================
    ; MODAL COMMAND & COMBINATION BUILDER (Left Sidebar Button)
    ; ========================================================
    static OpenMappingEditor(btnId, btnDisplayName) {
        if (this.EditorGui != "") {
            this.EditorGui.Destroy()
            this.EditorGui := ""
        }

        this.EditTargetId := btnId
        currentProf := ProfileEngine.CurrentProfile
        currentMapping := ProfileEngine.GetButtonMapping(currentProf, btnId)

        eg := Gui("+AlwaysOnTop -MaximizeBox +Owner" . this.MainGui.Hwnd, "Custom Combination Builder — " . btnDisplayName)
        eg.BackColor := "181825"
        eg.MarginX := 20
        eg.MarginY := 18
        this.EditorGui := eg

        ; Header
        eg.SetFont("s12 bold c89B4FA", "Segoe UI")
        eg.Add("Text", "w520", "CUSTOMIZE BUTTON: " . btnDisplayName)
        eg.SetFont("s9 norm cA6ADC8", "Segoe UI")
        eg.Add("Text", "w520 y+2", "Profile: " . currentProf . "  |  Hardware Target: " . btnId)

        ; Section 1: Primary Action
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

        this.EditChkCtrl.OnEvent("Click", (*) => this.OnCustomCombinationChanged())
        this.EditChkShift.OnEvent("Click", (*) => this.OnCustomCombinationChanged())
        this.EditChkAlt.OnEvent("Click", (*) => this.OnCustomCombinationChanged())
        this.EditChkWin.OnEvent("Click", (*) => this.OnCustomCombinationChanged())
        this.EditKeyDrop.OnEvent("Change", (*) => this.OnCustomCombinationChanged())

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

    static OnCustomCombinationChanged() {
        this.EditPresetDrop.Choose("[Custom Key Combination]")
        cmd := ""
        if (this.EditChkCtrl.Value)
            cmd .= "^"
        if (this.EditChkShift.Value)
            cmd .= "+"
        if (this.EditChkAlt.Value)
            cmd .= "!"
        if (this.EditChkWin.Value)
            cmd .= "#"
        
        chosenKey := this.EditKeyDrop.Text
        if (StrLen(chosenKey) = 1) {
            cmd .= StrLower(chosenKey)
        } else {
            cmd .= "{" . chosenKey . "}"
        }
        this.EditCustomCmd.Value := cmd
    }

    static SaveEditorMapping() {
        btnId := this.EditTargetId
        currentProf := ProfileEngine.CurrentProfile
        presetChoice := this.EditPresetDrop.Text

        normalObj := {}

        if (presetChoice = "[Custom Key Combination]") {
            cmd := ""
            lblParts := []
            if (this.EditChkCtrl.Value) {
                cmd .= "^"
                lblParts.Push("Ctrl")
            }
            if (this.EditChkShift.Value) {
                cmd .= "+"
                lblParts.Push("Shift")
            }
            if (this.EditChkAlt.Value) {
                cmd .= "!"
                lblParts.Push("Alt")
            }
            if (this.EditChkWin.Value) {
                cmd .= "#"
                lblParts.Push("Win")
            }
            
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
        } else {
            normalObj := { Type: "Send", Cmd: "^c", Label: "Copy (Ctrl+C)" }
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

        ProfileEngine.SaveMapping(currentProf, btnId, normalObj, gshiftObj)

        if (this.MonitorActions.Has(btnId)) {
            this.MonitorActions[btnId].Value := normalObj.Label
        }
        if (btnId = this.SelectedButtonId && this.CurrentActionText != "") {
            this.CurrentActionText.Value := "Action: " . normalObj.Label
        }

        OSD.Show("Mapping Saved", btnId . " -> " . normalObj.Label)
        SoundBeep(1100, 80)

        if (this.EditorGui != "") {
            this.EditorGui.Destroy()
            this.EditorGui := ""
        }
    }

    static ResetEditorMapping() {
        btnId := this.EditTargetId
        currentProf := ProfileEngine.CurrentProfile
        ProfileEngine.ResetMappingToDefault(currentProf, btnId)

        newLabel := ProfileEngine.GetButtonLabel(currentProf, btnId)
        if (this.MonitorActions.Has(btnId)) {
            this.MonitorActions[btnId].Value := newLabel
        }
        if (btnId = this.SelectedButtonId && this.CurrentActionText != "") {
            this.CurrentActionText.Value := "Action: " . newLabel
        }

        OSD.Show("Reset to Default", btnId)
        SoundBeep(800, 80)

        if (this.EditorGui != "") {
            this.EditorGui.Destroy()
            this.EditorGui := ""
        }
    }

    static UpdateProfileDisplay(profileName) {
        if (this.ProfileDropdown != "") {
            this.ProfileDropdown.Choose(profileName)
        }

        for btnId, ctrl in this.MonitorActions {
            ctrl.Value := ProfileEngine.GetButtonLabel(profileName, btnId)
        }

        if (this.CurrentActionText != "") {
            this.CurrentActionText.Value := "Action: " . ProfileEngine.GetButtonLabel(profileName, this.SelectedButtonId)
        }

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

        ; Automatically select the physical button that was clicked on hardware!
        if (isPressed) {
            btnDisplayName := btnName
            if (this.MonitorCards.Has(btnName) && HasProp(this.MonitorCards[btnName], "ButtonName")) {
                btnDisplayName := this.MonitorCards[btnName].ButtonName
            }
            this.SelectButton(btnName, btnDisplayName)
        }

        if (btnName = "DpiShift") {
            if (isPressed) {
                this.GShiftStatusText.SetFont("c" . "A6E3A1")
                this.GShiftStatusText.Value := "ACTIVE"
            } else {
                this.GShiftStatusText.SetFont("c" . "F38BA8")
                this.GShiftStatusText.Value := "INACTIVE"
            }
        }

        if (this.MonitorCards.Has(btnName)) {
            card := this.MonitorCards[btnName]
            card.SetFont("bold cA6E3A1")
            SetTimer(() => this.ResetButtonColor(btnName), -300)
        }
    }

    static ResetButtonColor(btnName) {
        if (this.MainGui != "" && this.MonitorCards.Has(btnName)) {
            card := this.MonitorCards[btnName]
            ; If it is the currently selected button, keep cyan; else reset to CDD6F4
            if (btnName = this.SelectedButtonId) {
                card.SetFont("bold c89B4FA")
            } else {
                card.SetFont("bold cCDD6F4")
            }
        }
    }
}
