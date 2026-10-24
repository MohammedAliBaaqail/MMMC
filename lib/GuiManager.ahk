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
        g.Add("Text", "x20 y36 w700", "Click any button on the mouse to select it, then click any action on the left to map it immediately.")

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
            g.SetFont("s9 bold cCDD6F4", "Segoe UI")
            card := g.Add("Text", "x" . b.x . " y" . b.y . " w145 h22 0x200 Background1E1E2E Center +Border", b.name)
            card.ButtonId := b.id
            card.ButtonName := b.name
            card.OnEvent("Click", (ctrl, *) => this.SelectButton(ctrl.ButtonId, ctrl.ButtonName))
            card.OnEvent("DoubleClick", (ctrl, *) => this.OpenMappingEditor(ctrl.ButtonId, ctrl.ButtonName))
            card.OnEvent("ContextMenu", (ctrl, *) => this.OpenMappingEditor(ctrl.ButtonId, ctrl.ButtonName))

            g.SetFont("s8 italic c89B4FA", "Segoe UI")
            actionText := ProfileEngine.GetButtonLabel(ProfileEngine.CurrentProfile, b.id)
            actionCtrl := g.Add("Text", "x" . b.x . " y" . (b.y+22) . " w145 h18 Center Background1E1E2E", actionText)
            actionCtrl.ButtonId := b.id
            actionCtrl.ButtonName := b.name
            actionCtrl.OnEvent("Click", (ctrl, *) => this.SelectButton(ctrl.ButtonId, ctrl.ButtonName))
            actionCtrl.OnEvent("DoubleClick", (ctrl, *) => this.OpenMappingEditor(ctrl.ButtonId, ctrl.ButtonName))
            actionCtrl.OnEvent("ContextMenu", (ctrl, *) => this.OpenMappingEditor(ctrl.ButtonId, ctrl.ButtonName))

            this.MonitorCards[b.id] := card
            this.MonitorActions[b.id] := actionCtrl
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
    ; MODAL COMMAND & COMBINATION BUILDER (Double-Click / Button)
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
