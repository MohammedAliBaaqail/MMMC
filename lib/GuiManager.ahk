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
    static IsAlwaysOnTop := true
    static ChkAlwaysOnTop := ""
    
    ; View Layer Control ("Normal", "GShift", or "GShift2")
    static CurrentViewLayer := "Normal"
    static LblDefault1 := ""
    static PicToggle1 := ""
    static LblBShift1 := ""
    static LblDefault2 := ""
    static PicToggle2 := ""
    static LblBShift2 := ""
    
    ; Selected Button for assignment
    static SelectedButtonId := "G8"
    static SelectedButtonName := "G8 (DPI Up)"
    static TargetLabelText := ""
    static CurrentActionText := ""

    ; Sidebar Controls
    static SearchEdit := ""
    static CommandListView := ""
    static CollapsedCategories := Map()

    ; Live Monitor Controls
    static MonitorCards := Map()
    static MonitorActions := Map()
    static MonitorSubtitles := Map()
    static ShowButtonNames := false
    static ToggleNamesBtn := ""
    static MainTab := ""
    static CalibrateBtn := ""
    static DiagramPic := ""
    static OMMDiagramPic := ""

    ; Visual Pointer Calibration Tool State
    static CalibratorDlg := ""
    static CalibratorPoints := Map()
    static CalibratorSelectedId := "G8"
    static CalibratorStepSize := 2
    static CalibratorMarkers := Map()
    static CalibratorSelectorBtns := Map()
    static CalibratorInfoText := ""
    static CalibratorCanvasPic := ""
    static CalibratorCanvasX := 80
    static CalibratorCanvasY := 140
    static CalibratorCanvasW := 860
    static CalibratorCanvasH := 500
    static CalibratorKeyDownHandlerBound := ""

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
    static RecBtnRecordSingle := ""
    static RecIsRecordingSingle := false
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

    static Categories := [
        { Key: "Editing",    Title: "EDITING" },
        { Key: "Navigation", Title: "NAVIGATION & TABS" },
        { Key: "Windows",    Title: "WINDOWS & SYSTEM" },
        { Key: "Media",      Title: "MEDIA & AUDIO" },
        { Key: "Device",     Title: "DEVICE & B-SHIFT" }
    ]

    ; Complete Command Catalog for Sidebar (Category, Display Name, Type, Command, Label)
    static CommandCatalog := [
        ; --- Editing ---
        { Cat: "Editing", Name: "Undo",                  Type: "Send", Cmd: "^z",            Label: "Undo",          Key: "Ctrl + Z" },
        { Cat: "Editing", Name: "Redo",                  Type: "Send", Cmd: "^y",            Label: "Redo",          Key: "Ctrl + Y" },
        { Cat: "Editing", Name: "Copy",                  Type: "Send", Cmd: "^c",            Label: "Copy",          Key: "Ctrl + C" },
        { Cat: "Editing", Name: "Paste",                 Type: "Send", Cmd: "^v",            Label: "Paste",         Key: "Ctrl + V" },
        { Cat: "Editing", Name: "Cut",                   Type: "Send", Cmd: "^x",            Label: "Cut",           Key: "Ctrl + X" },
        { Cat: "Editing", Name: "Save",                  Type: "Send", Cmd: "^s",            Label: "Save",          Key: "Ctrl + S" },
        { Cat: "Editing", Name: "Select All",            Type: "Send", Cmd: "^a",            Label: "Select All",    Key: "Ctrl + A" },
        { Cat: "Editing", Name: "Find",                  Type: "Send", Cmd: "^f",            Label: "Find",          Key: "Ctrl + F" },
        { Cat: "Editing", Name: "Duplicate Line",        Type: "Send", Cmd: "!+{Down}",      Label: "Duplicate Line", Key: "Alt+Shift+Down" },
        { Cat: "Editing", Name: "Delete Line",           Type: "Send", Cmd: "^+k",           Label: "Delete Line",   Key: "Ctrl+Shift+K" },
        
        { Cat: "Navigation", Name: "Middle Click",       Type: "Send", Cmd: "{MButton}",     Label: "Middle Click",  Key: "Mouse 3" },
        { Cat: "Navigation", Name: "Previous Tab",       Type: "Send", Cmd: "^+{Tab}",       Label: "Prev Tab",      Key: "Ctrl+Shift+Tab" },
        { Cat: "Navigation", Name: "Next Tab",           Type: "Send", Cmd: "^{Tab}",        Label: "Next Tab",      Key: "Ctrl + Tab" },
        { Cat: "Navigation", Name: "Close Tab",          Type: "Send", Cmd: "^w",            Label: "Close Tab",     Key: "Ctrl + W" },
        { Cat: "Navigation", Name: "New Tab",            Type: "Send", Cmd: "^t",            Label: "New Tab",       Key: "Ctrl + T" },
        { Cat: "Navigation", Name: "Reopen Closed Tab",  Type: "Send", Cmd: "^+t",           Label: "Reopen Tab",    Key: "Ctrl+Shift+T" },
        { Cat: "Navigation", Name: "Browser Back",       Type: "Send", Cmd: "!{Left}",       Label: "Browser Back",  Key: "Alt + Left" },
        { Cat: "Navigation", Name: "Browser Forward",    Type: "Send", Cmd: "!{Right}",      Label: "Browser Fwd",   Key: "Alt + Right" },
        { Cat: "Navigation", Name: "Refresh Page",       Type: "Send", Cmd: "{F5}",          Label: "Refresh",       Key: "F5" },
        
        ; --- System & Windows ---
        { Cat: "Windows", Name: "Switch Between Apps",   Type: "Send", Cmd: "!{Tab}",        Label: "Switch Apps",   Key: "Alt + Tab" },
        { Cat: "Windows", Name: "Windows Task View",      Type: "Send", Cmd: "#{Tab}",        Label: "Task View",     Key: "Win + Tab" },
        { Cat: "Windows", Name: "Show Desktop",           Type: "Send", Cmd: "#d",            Label: "Desktop",       Key: "Win + D" },
        { Cat: "Windows", Name: "Snap Window Left",       Type: "Send", Cmd: "#{Left}",       Label: "Snap Left",     Key: "Win + Left" },
        { Cat: "Windows", Name: "Snap Window Right",      Type: "Send", Cmd: "#{Right}",      Label: "Snap Right",    Key: "Win + Right" },
        { Cat: "Windows", Name: "Maximize Window",        Type: "Send", Cmd: "#{Up}",         Label: "Maximize",      Key: "Win + Up" },
        { Cat: "Windows", Name: "Minimize Window",        Type: "Send", Cmd: "#{Down}",       Label: "Minimize",      Key: "Win + Down" },
        { Cat: "Windows", Name: "Snipping Tool",          Type: "Send", Cmd: "#+s",           Label: "Screenshot",    Key: "Win+Shift+S" },
        { Cat: "Windows", Name: "File Explorer",          Type: "Send", Cmd: "#e",            Label: "Explorer",      Key: "Win + E" },
        { Cat: "Windows", Name: "Run Dialog",             Type: "Send", Cmd: "#r",            Label: "Run",           Key: "Win + R" },

        ; --- Media & Audio ---
        { Cat: "Media", Name: "Volume Up",               Type: "Send", Cmd: "{Volume_Up 2}", Label: "Volume Up",     Key: "Vol Up" },
        { Cat: "Media", Name: "Volume Down",             Type: "Send", Cmd: "{Volume_Down 2}", Label: "Volume Down", Key: "Vol Down" },
        { Cat: "Media", Name: "Mute Audio",              Type: "Send", Cmd: "{Volume_Mute}", Label: "Mute",          Key: "Mute" },
        { Cat: "Media", Name: "Play / Pause",            Type: "Send", Cmd: "{Media_Play_Pause}", Label: "Play/Pause", Key: "Play/Pause" },
        { Cat: "Media", Name: "Next Track",              Type: "Send", Cmd: "{Media_Next}",  Label: "Next Track",    Key: "Next Track" },
        { Cat: "Media", Name: "Previous Track",          Type: "Send", Cmd: "{Media_Prev}",  Label: "Previous Track", Key: "Prev Track" },
        { Cat: "Media", Name: "Stop Media",              Type: "Send", Cmd: "{Media_Stop}",  Label: "Stop",          Key: "Stop" },

        ; --- Device & Special ---
        { Cat: "Device", Name: "B-Shift Modifier",       Type: "Special", Cmd: "GShift",     Label: "B-Shift Layer",   Key: "⚡ B-Shift" },
        { Cat: "Device", Name: "B-Shift 1 Modifier",     Type: "Special", Cmd: "GShift1",    Label: "B-Shift 1 Layer", Key: "⚡ B-Shift 1" },
        { Cat: "Device", Name: "B-Shift 2 Modifier",     Type: "Special", Cmd: "GShift2",    Label: "B-Shift 2 Layer", Key: "⚡ B-Shift 2" },
        { Cat: "Device", Name: "Onboard Profile Cycle",  Type: "Special", Cmd: "CycleProfile", Label: "Next Profile", Key: "Profile Cycle" },
        { Cat: "Device", Name: "Toggle Rapid-Fire",      Type: "Special", Cmd: "ToggleRapidFire", Label: "Toggle Rapid Fire", Key: "Rapid Fire" }
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
        "B-Shift Modifier",                        { Type: "Special", Cmd: "GShift", Label: "B-Shift Layer" },
        "B-Shift 1 Modifier",                      { Type: "Special", Cmd: "GShift1", Label: "B-Shift 1 Layer" },
        "B-Shift 2 Modifier",                      { Type: "Special", Cmd: "GShift2", Label: "B-Shift 2 Layer" },
        "G-Shift 1 Modifier",                      { Type: "Special", Cmd: "GShift1", Label: "B-Shift 1 Layer" },
        "G-Shift 2 Modifier",                      { Type: "Special", Cmd: "GShift2", Label: "B-Shift 2 Layer" },
        "G-Shift Layer Modifier",                  { Type: "Special", Cmd: "GShift", Label: "B-Shift Layer" },
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

        ; Hook ProfileEngine profile changes
        ProfileEngine.OnProfileChanged := (p) => GuiManager.OnProfileChangedHandler(p)

        ; Create Main GUI (Wide G-HUB Studio Layout)
        opt := this.IsAlwaysOnTop ? "+AlwaysOnTop -MaximizeBox" : "-AlwaysOnTop -MaximizeBox"
        g := Gui(opt, "Logitech G502 X — Advanced Controller (LGS & G-HUB Studio)")
        g.BackColor := "181825"
        g.MarginX := 15
        g.MarginY := 15
        this.MainGui := g

        ; Header Row
        g.SetFont("s13 bold c89B4FA", "Segoe UI")
        g.Add("Text", "x20 y14 w650", "LOGITECH G502 X  //  INTERACTIVE STUDIO")
        
        g.SetFont("s9 norm cA6ADC8", "Segoe UI")
        g.Add("Text", "x20 y36 w650", "Double-click any mouse button to record a key or combination. Use the left panel for presets and custom combos.")

        ; Always on Top Toggle in Header
        g.SetFont("s9 bold cCDD6F4", "Segoe UI")
        this.ChkAlwaysOnTop := g.Add("Checkbox", "x970 y20 w145 h24 " . (this.IsAlwaysOnTop ? "Checked" : ""), "📌 Always on Top")
        this.ChkAlwaysOnTop.OnEvent("Click", (*) => this.ToggleAlwaysOnTop())

        ; Tab Control
        g.SetFont("s10 norm cCDD6F4", "Segoe UI")
        this.MainTab := g.Add("Tab3", "x15 y60 w1110 h635", ["Live Monitor", "OMM Setup Assistant"])
        tab := this.MainTab

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

        ; Search Bar with cue banner
        g.SetFont("s9 norm c181825", "Segoe UI")
        this.SearchEdit := g.Add("Edit", "x30 y162 w250 h24", "")
        DllCall("SendMessage", "Ptr", this.SearchEdit.Hwnd, "UInt", 0x1501, "Ptr", 1, "WStr", "🔍  Search for a command...", "Ptr")
        this.SearchEdit.OnEvent("Change", (*) => this.FilterCommandList())

        ; Commands List (ListView with G-HUB style Subsections & pure shortcut column)
        g.SetFont("s9 norm cCDD6F4", "Segoe UI")
        this.CommandListView := g.Add("ListView", "x30 y192 w250 h370 Background1E1E2E +Report -Hdr +LV0x10000", ["Category", "Action", "Key"])
        this.CommandListView.ModifyCol(1, 0)         ; Hidden category col for sorting & section detection
        this.CommandListView.ModifyCol(2, 142)       ; Action / Section header name
        this.CommandListView.ModifyCol(3, "Right 86") ; Pure shortcut / key (right-aligned)
        this.CommandListView.OnEvent("ItemSelect", (lv, item, selected) => this.OnSidebarItemSelected(lv, item, selected))
        this.CommandListView.OnEvent("Click", (lv, row) => this.OnSidebarClick(lv, row))
        this.CommandListView.OnEvent("DoubleClick", (lv, row) => this.OnSidebarDoubleClick(lv, row))

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
        this.ProfileDropdown.OnEvent("Change", (ctrl, *) => this.OnProfileDropdownChanged(ctrl.Text))

        g.SetFont("s10 bold c89B4FA", "Segoe UI")
        g.Add("Text", "ys+2 x+18", "B-Shift:")
        g.SetFont("s10 bold cF38BA8", "Segoe UI")
        this.GShiftStatusText := g.Add("Text", "ys+2 x+6 w75", "INACTIVE")

        g.SetFont("s10 bold c89B4FA", "Segoe UI")
        g.Add("Text", "ys+2 x+14", "Rapid Fire:")
        g.SetFont("s10 bold cA6ADC8", "Segoe UI")
        this.RapidFireStatusText := g.Add("Text", "ys+2 x+6 w70", "OFF")

        ; Header action controls on the top right
        g.SetFont("s9 bold c89B4FA", "Segoe UI")
        this.ToggleNamesBtn := g.Add("Button", "x760 y90 w170 h28", "Show Button Names: OFF")
        this.ToggleNamesBtn.OnEvent("Click", (*) => this.ToggleNameVisibility())

        g.SetFont("s9 bold cFAB387", "Segoe UI")
        this.CalibrateBtn := g.Add("Button", "x940 y90 w170 h28", "🎯 Calibrate Pointers")
        this.CalibrateBtn.OnEvent("Click", (*) => this.OpenPointerCalibrator())

        ; Precision Diagram (Mouse and leader lines)
        if FileExist(diagramPath) {
            this.DiagramPic := g.Add("Picture", "x280 y140 w860 h500 +BackgroundTrans", diagramPath)
        }

        ; Callout pill badges placed at the ends of the leader lines (Synced with OMM F13-F21)
        callouts := [
            { id: "TiltLeft",     name: "Tilt Left  [F17]",      x: 305, y: 179 },
            { id: "G8",           name: "G8 (DPI Up)  [F20]",    x: 305, y: 244 },
            { id: "G7",           name: "G7 (DPI Down)  [F21]",  x: 305, y: 304 },
            { id: "DpiShift",     name: "DPI Shift  [F15]",      x: 305, y: 374 },
            { id: "Forward",      name: "G5 (Forward)  [F16]",   x: 305, y: 444 },
            { id: "Back",         name: "G4 (Back)  [F14]",      x: 305, y: 514 },
            { id: "TiltRight",    name: "Tilt Right  [F18]",     x: 930, y: 179 },
            { id: "Middle",       name: "Middle Click  [F13]",   x: 930, y: 244 },
            { id: "ProfileCycle", name: "G9 (Profile)  [F19]",   x: 930, y: 309 }
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

        ; (Static G-Shift Chords box removed per user request)

        ; --- G-HUB Style B-Shift Layer Toggle Switches (Bottom of Diagram) ---
        ; Switch 1
        g.SetFont("s10 bold cFFFFFF", "Segoe UI")
        this.LblDefault1 := g.Add("Text", "x520 y642 w75 h26 0x202", "DEFAULT")
        this.LblDefault1.OnEvent("Click", (*) => this.SwitchViewLayer("Normal"))

        this.PicToggle1 := g.Add("Picture", "x600 y643 w46 h24 +BackgroundTrans", A_ScriptDir . "\assets\toggle_off.png")
        this.PicToggle1.OnEvent("Click", (*) => this.ToggleSwitch(1))

        g.SetFont("s10 bold c6C7086", "Segoe UI")
        this.LblBShift1 := g.Add("Text", "x654 y642 w220 h26 0x200", "B-SHIFT")
        this.LblBShift1.OnEvent("Click", (*) => this.SwitchViewLayer("GShift"))

        ; Switch 2 (Shown when a 2nd B-Shift button is mapped)
        g.SetFont("s10 bold cFFFFFF", "Segoe UI")
        this.LblDefault2 := g.Add("Text", "x700 y642 w75 h26 0x202", "DEFAULT")
        this.LblDefault2.OnEvent("Click", (*) => this.SwitchViewLayer("Normal"))

        this.PicToggle2 := g.Add("Picture", "x780 y643 w46 h24 +BackgroundTrans", A_ScriptDir . "\assets\toggle_off.png")
        this.PicToggle2.OnEvent("Click", (*) => this.ToggleSwitch(2))

        g.SetFont("s10 bold c6C7086", "Segoe UI")
        this.LblBShift2 := g.Add("Text", "x834 y642 w170 h26 0x200", "B-SHIFT 2")
        this.LblBShift2.OnEvent("Click", (*) => this.SwitchViewLayer("GShift2"))

        ; Highlight initial default selected button and initialize layer switches
        this.SelectButton("G8", "G8 (DPI Up) [F20]")
        this.UpdateLayerSwitches()

        ; ========================================================
        ; TAB 2: OMM Setup Assistant (Precision Key Injector)
        ; ========================================================
        tab.UseTab(2)

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
            this.OMMDiagramPic := g.Add("Picture", "x280 y200 w860 h500 +BackgroundTrans", diagramPath)
        }

        ; Injectors mapped 1:1 to OMM buttons 3 to 11
        injectors := [
            { key: "F17", label: "Inject F17 (Tilt L)",    x: 305, y: 233 },
            { key: "F20", label: "Inject F20 (G8 Up)",     x: 305, y: 298 },
            { key: "F21", label: "Inject F21 (G7 Down)",   x: 305, y: 358 },
            { key: "F15", label: "Inject F15 (DPI Shift)", x: 305, y: 428 },
            { key: "F16", label: "Inject F16 (G5 Fwd)",    x: 305, y: 498 },
            { key: "F14", label: "Inject F14 (G4 Back)",   x: 305, y: 568 },
            { key: "F18", label: "Inject F18 (Tilt R)",    x: 930, y: 233 },
            { key: "F13", label: "Inject F13 (Middle)",    x: 930, y: 298 },
            { key: "F19", label: "Inject F19 (G9)",        x: 930, y: 363 }
        ]

        for k in injectors {
            btn := g.Add("Button", "x" . k.x . " y" . k.y . " w145 h34", k.label)
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
        ProfileEngine.OnShiftStateChanged := (layerNum, isActive) => this.UpdateLiveShiftIndicator(layerNum, isActive)

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

    static ToggleAlwaysOnTop() {
        this.IsAlwaysOnTop := !this.IsAlwaysOnTop
        if (this.MainGui != "" && WinExist(this.MainGui.Hwnd)) {
            WinSetAlwaysOnTop(this.IsAlwaysOnTop ? 1 : 0, this.MainGui.Hwnd)
            if (this.ChkAlwaysOnTop != "")
                this.ChkAlwaysOnTop.Value := this.IsAlwaysOnTop ? 1 : 0
        }
        try {
            if (this.IsAlwaysOnTop)
                A_TrayMenu.Check("Always on Top")
            else
                A_TrayMenu.Uncheck("Always on Top")
        }
        try {
            IniWrite(this.IsAlwaysOnTop ? "1" : "0", A_ScriptDir . "\settings.ini", "General", "AlwaysOnTop")
        }
        OSD.Show("Always on Top", this.IsAlwaysOnTop ? "Enabled (Pinned)" : "Disabled (Unpinned)")
    }

    ; ========================================================
    ; VISUAL POINTER CALIBRATION TOOL
    ; ========================================================
    static OpenPointerCalibrator() {
        this.LoadCalibratorPoints()

        dlg := Gui("+Owner" . this.MainGui.Hwnd . " +AlwaysOnTop -MinimizeBox", "🎯 G502 X Button Pointer Calibration")
        this.CalibratorDlg := dlg
        dlg.BackColor := "181825"

        ; Header
        dlg.SetFont("s13 bold cCDD6F4", "Segoe UI")
        dlg.Add("Text", "x20 y12 w800", "🎯 Logitech G502 X Button Pointer Calibration")
        dlg.SetFont("s9 norm cA6ADC8", "Segoe UI")
        dlg.Add("Text", "x20 y38 w980", 
            "1. Select a button in the row below.`n"
            . "2. CLICK DIRECTLY ON THE MOUSE IMAGE to place its pointer target at that exact location.`n"
            . "3. Fine-tune with Arrow keys (◄ ▲ ▼ ►) or Nudge buttons.`n"
            . "4. Click 'Preview Lines' to view live leader lines, and 'Save & Apply' when finished.")

        ; Button Order for selector
        order := ["TiltLeft", "Middle", "TiltRight", "G8", "G7", "DpiShift", "Forward", "Back", "ProfileCycle"]

        ; Selector buttons bar
        bx := 20, by := 88, bw := 105, bh := 32
        this.CalibratorSelectorBtns := Map()
        for id in order {
            info := this.CalibratorPoints[id]
            dlg.SetFont("s9 bold cCDD6F4", "Segoe UI")
            btn := dlg.Add("Button", "x" . bx . " y" . by . " w" . bw . " h" . bh, info.tag . ": " . id)
            btn.ButtonId := id
            btn.OnEvent("Click", (ctrl, *) => this.SelectCalibratorButton(ctrl.ButtonId))
            this.CalibratorSelectorBtns[id] := btn
            bx += bw + 5
        }

        ; Coordinate readout & Nudge controls
        canvX := 80, canvY := 140, canvW := 860, canvH := 500
        this.CalibratorCanvasX := canvX
        this.CalibratorCanvasY := canvY
        this.CalibratorCanvasW := canvW
        this.CalibratorCanvasH := canvH

        dlg.SetFont("s10 bold c89B4FA", "Segoe UI")
        this.CalibratorInfoText := dlg.Add("Text", "x20 y" . (canvY + canvH + 15) . " w450 h28 0x200", "")

        ; Nudge controls
        nx := 480, ny := canvY + canvH + 12
        dlg.SetFont("s9 bold cA6ADC8", "Segoe UI")
        dlg.Add("Text", "x" . nx . " y" . (ny + 4) . " w55 h24", "Nudge:")
        btnLeft := dlg.Add("Button", "x" . (nx + 55) . " y" . ny . " w40 h26", "◄")
        btnLeft.OnEvent("Click", (*) => this.NudgeCalibrator(-this.CalibratorStepSize, 0))
        btnUp := dlg.Add("Button", "x+4 y" . ny . " w40 h26", "▲")
        btnUp.OnEvent("Click", (*) => this.NudgeCalibrator(0, -this.CalibratorStepSize))
        btnDown := dlg.Add("Button", "x+4 y" . ny . " w40 h26", "▼")
        btnDown.OnEvent("Click", (*) => this.NudgeCalibrator(0, this.CalibratorStepSize))
        btnRight := dlg.Add("Button", "x+4 y" . ny . " w40 h26", "►")
        btnRight.OnEvent("Click", (*) => this.NudgeCalibrator(this.CalibratorStepSize, 0))

        ; Step toggle
        btnStep := dlg.Add("Button", "x+10 y" . ny . " w85 h26", "Step: " . this.CalibratorStepSize . "px")
        btnStep.OnEvent("Click", (ctrl, *) => this.ToggleCalibratorStep(ctrl))

        ; Bottom action row
        ay := ny + 45
        dlg.SetFont("s10 bold c89B4FA", "Segoe UI")
        btnPreview := dlg.Add("Button", "x340 y" . ay . " w160 h36", "👁️ Preview Lines")
        btnPreview.OnEvent("Click", (*) => this.PreviewCalibratorLines())

        dlg.SetFont("s10 bold cA6E3A1", "Segoe UI")
        btnSave := dlg.Add("Button", "x510 y" . ay . " w160 h36", "💾 Save & Apply")
        btnSave.OnEvent("Click", (*) => this.SaveCalibratorPoints())

        dlg.SetFont("s10 bold cFAB387", "Segoe UI")
        btnReset := dlg.Add("Button", "x680 y" . ay . " w150 h36", "🔄 Reset Defaults")
        btnReset.OnEvent("Click", (*) => this.ResetCalibratorDefaults())

        dlg.SetFont("s10 bold cF38BA8", "Segoe UI")
        btnCancel := dlg.Add("Button", "x840 y" . ay . " w100 h36", "Cancel")
        btnCancel.OnEvent("Click", (*) => this.CloseCalibratorDialog())

        ; Canvas background and diagram
        diagramPath := A_ScriptDir . "\assets\g502x_diagram.png"
        cleanPath   := A_ScriptDir . "\assets\g502x.png"
        bgPath      := FileExist(diagramPath) ? diagramPath : cleanPath

        dlg.Add("Text", "x" . (canvX - 2) . " y" . (canvY - 2) . " w" . (canvW + 4) . " h" . (canvH + 4) . " Background11111B +Border")
        this.CalibratorCanvasPic := dlg.Add("Picture", "x" . canvX . " y" . canvY . " w" . canvW . " h" . canvH . " +BackgroundTrans", bgPath)
        this.CalibratorCanvasPic.OnEvent("Click", (*) => this.OnCalibratorCanvasClick())

        ; Marker badges for each button on top of the canvas
        this.CalibratorMarkers := Map()
        for id in order {
            pt := this.CalibratorPoints[id]
            mx := canvX + pt.tx - 13
            my := canvY + pt.ty - 13
            m := dlg.Add("Text", "x" . mx . " y" . my . " w26 h26 Center 0x200 Background1E1E2E c89B4FA +Border", pt.tag)
            m.ButtonId := id
            m.OnEvent("Click", (ctrl, *) => this.SelectCalibratorButton(ctrl.ButtonId))
            this.CalibratorMarkers[id] := m
        }

        ; Register keyboard handler
        dlg.OnEvent("Close", (*) => this.CloseCalibratorDialog())
        dlg.OnEvent("Escape", (*) => this.CloseCalibratorDialog())
        OnMessage(0x0100, this.CalibratorKeyDownHandlerBound := this.OnCalibratorKeyDown.Bind(this))

        this.SelectCalibratorButton("G8")
        dlg.Show("w1020 h750")
    }

    static SelectCalibratorButton(id) {
        this.CalibratorSelectedId := id
        for bid, btn in this.CalibratorSelectorBtns {
            if (bid = id) {
                btn.SetFont("s9 bold cFAB387")
            } else {
                btn.SetFont("s9 bold cCDD6F4")
            }
        }
        for bid, m in this.CalibratorMarkers {
            if (bid = id) {
                m.Opt("BackgroundFAB387 c11111B")
                m.Redraw()
            } else {
                m.Opt("Background1E1E2E c89B4FA")
                m.Redraw()
            }
        }
        this.UpdateCalibratorStatus()
    }

    static UpdateCalibratorStatus() {
        if (!this.CalibratorPoints.Has(this.CalibratorSelectedId))
            return
        pt := this.CalibratorPoints[this.CalibratorSelectedId]
        this.CalibratorInfoText.Value := "Selected: " . pt.name . " | Target Point: X = " . pt.tx . ", Y = " . pt.ty
    }

    static OnCalibratorCanvasClick() {
        CoordMode("Mouse", "Client")
        MouseGetPos(&mX, &mY)

        targetX := mX - this.CalibratorCanvasX
        targetY := mY - this.CalibratorCanvasY

        targetX := Max(10, Min(this.CalibratorCanvasW - 10, targetX))
        targetY := Max(10, Min(this.CalibratorCanvasH - 10, targetY))

        pt := this.CalibratorPoints[this.CalibratorSelectedId]
        pt.tx := targetX
        pt.ty := targetY

        m := this.CalibratorMarkers[this.CalibratorSelectedId]
        m.Move(this.CalibratorCanvasX + targetX - 13, this.CalibratorCanvasY + targetY - 13)
        this.UpdateCalibratorStatus()
    }

    static NudgeCalibrator(dx, dy) {
        if (!this.CalibratorPoints.Has(this.CalibratorSelectedId))
            return
        pt := this.CalibratorPoints[this.CalibratorSelectedId]
        pt.tx := Max(10, Min(this.CalibratorCanvasW - 10, pt.tx + dx))
        pt.ty := Max(10, Min(this.CalibratorCanvasH - 10, pt.ty + dy))

        m := this.CalibratorMarkers[this.CalibratorSelectedId]
        m.Move(this.CalibratorCanvasX + pt.tx - 13, this.CalibratorCanvasY + pt.ty - 13)
        this.UpdateCalibratorStatus()
    }

    static OnCalibratorKeyDown(wParam, lParam, msg, hwnd) {
        if (!this.CalibratorDlg || !WinExist(this.CalibratorDlg.Hwnd) || !WinActive(this.CalibratorDlg.Hwnd))
            return

        ; 37: Left, 38: Up, 39: Right, 40: Down
        switch wParam {
            case 37:
                this.NudgeCalibrator(-this.CalibratorStepSize, 0)
                return 0
            case 38:
                this.NudgeCalibrator(0, -this.CalibratorStepSize)
                return 0
            case 39:
                this.NudgeCalibrator(this.CalibratorStepSize, 0)
                return 0
            case 40:
                this.NudgeCalibrator(0, this.CalibratorStepSize)
                return 0
        }
    }

    static ToggleCalibratorStep(ctrl) {
        this.CalibratorStepSize := (this.CalibratorStepSize = 1) ? 2 : ((this.CalibratorStepSize = 2) ? 5 : ((this.CalibratorStepSize = 5) ? 10 : 1))
        ctrl.Text := "Step: " . this.CalibratorStepSize . "px"
    }

    static LoadCalibratorPoints() {
        defaults := Map(
            "TiltLeft",     { name: "Tilt Left [F17]",      ax: 170, ay: 50,  tx: 338, ty: 64,  tag: "TL" },
            "Middle",       { name: "Middle Click [F13]",   ax: 650, ay: 115, tx: 355, ty: 58,  tag: "MID" },
            "TiltRight",    { name: "Tilt Right [F18]",     ax: 650, ay: 50,  tx: 374, ty: 64,  tag: "TR" },
            "G8",           { name: "G8 (DPI Up) [F20]",    ax: 170, ay: 115, tx: 228, ty: 106, tag: "G8" },
            "G7",           { name: "G7 (DPI Down) [F21]",  ax: 170, ay: 175, tx: 242, ty: 126, tag: "G7" },
            "DpiShift",     { name: "DPI Shift [F15]",      ax: 170, ay: 245, tx: 270, ty: 264, tag: "DPI" },
            "Forward",      { name: "G5 (Forward) [F16]",   ax: 170, ay: 315, tx: 308, ty: 248, tag: "G5" },
            "Back",         { name: "G4 (Back) [F14]",      ax: 170, ay: 385, tx: 352, ty: 272, tag: "G4" },
            "ProfileCycle", { name: "G9 (Profile) [F19]",   ax: 650, ay: 180, tx: 426, ty: 92,  tag: "G9" }
        )

        this.CalibratorPoints := Map()
        iniPath := A_ScriptDir . "\settings.ini"

        for id, def in defaults {
            defTx := def.tx
            defTy := def.ty
            if FileExist(iniPath) {
                try {
                    iniX := IniRead(iniPath, "DiagramPoints", id . "_X", "")
                    iniY := IniRead(iniPath, "DiagramPoints", id . "_Y", "")
                    if (iniX != "" && IsInteger(iniX))
                        defTx := Integer(iniX)
                    if (iniY != "" && IsInteger(iniY))
                        defTy := Integer(iniY)
                }
            }
            this.CalibratorPoints[id] := { name: def.name, ax: def.ax, ay: def.ay, tx: defTx, ty: defTy, tag: def.tag }
        }
    }

    static PreviewCalibratorLines() {
        iniPath := A_ScriptDir . "\settings.ini"
        for id, pt in this.CalibratorPoints {
            IniWrite(pt.tx, iniPath, "DiagramPoints", id . "_X")
            IniWrite(pt.ty, iniPath, "DiagramPoints", id . "_Y")
        }

        psScript := A_ScriptDir . "\lib\render_diagram.ps1"
        diagramPath := A_ScriptDir . "\assets\g502x_diagram.png"
        if FileExist(psScript) {
            RunWait('powershell -ExecutionPolicy Bypass -File "' . psScript . '"', A_ScriptDir, "Hide")
            if (this.CalibratorCanvasPic != "")
                this.CalibratorCanvasPic.Value := diagramPath
        }
    }

    static SaveCalibratorPoints() {
        iniPath := A_ScriptDir . "\settings.ini"
        for id, pt in this.CalibratorPoints {
            IniWrite(pt.tx, iniPath, "DiagramPoints", id . "_X")
            IniWrite(pt.ty, iniPath, "DiagramPoints", id . "_Y")
        }

        psScript := A_ScriptDir . "\lib\render_diagram.ps1"
        diagramPath := A_ScriptDir . "\assets\g502x_diagram.png"
        if FileExist(psScript) {
            RunWait('powershell -ExecutionPolicy Bypass -File "' . psScript . '"', A_ScriptDir, "Hide")
        }

        ; Refresh picture controls in Main GUI
        if (this.DiagramPic != "")
            this.DiagramPic.Value := diagramPath
        if (this.OMMDiagramPic != "")
            this.OMMDiagramPic.Value := diagramPath

        OSD.Show("Pointer Calibration", "Saved & Applied Successfully!")
        this.CloseCalibratorDialog()
    }

    static ResetCalibratorDefaults() {
        defaults := Map(
            "TiltLeft",     { tx: 338, ty: 64 },
            "Middle",       { tx: 355, ty: 58 },
            "TiltRight",    { tx: 374, ty: 64 },
            "G8",           { tx: 228, ty: 106 },
            "G7",           { tx: 242, ty: 126 },
            "DpiShift",     { tx: 270, ty: 264 },
            "Forward",      { tx: 308, ty: 248 },
            "Back",         { tx: 352, ty: 272 },
            "ProfileCycle", { tx: 426, ty: 92 }
        )

        for id, def in defaults {
            if (this.CalibratorPoints.Has(id)) {
                pt := this.CalibratorPoints[id]
                pt.tx := def.tx
                pt.ty := def.ty
                if (this.CalibratorMarkers.Has(id)) {
                    m := this.CalibratorMarkers[id]
                    m.Move(this.CalibratorCanvasX + pt.tx - 13, this.CalibratorCanvasY + pt.ty - 13)
                }
            }
        }
        this.UpdateCalibratorStatus()
    }

    static CloseCalibratorDialog() {
        if (this.CalibratorKeyDownHandlerBound != "") {
            OnMessage(0x0100, this.CalibratorKeyDownHandlerBound, 0)
            this.CalibratorKeyDownHandlerBound := ""
        }
        if (this.CalibratorDlg != "" && WinExist(this.CalibratorDlg.Hwnd)) {
            this.CalibratorDlg.Destroy()
            this.CalibratorDlg := ""
        }
    }

    ; ========================================================
    ; G-HUB STYLE LAYER SWITCHING & MULTI-SHIFT MANAGEMENT
    ; ========================================================
    static ToggleSwitch(switchNum) {
        if (switchNum = 1) {
            target := (this.CurrentViewLayer = "GShift" || this.CurrentViewLayer = "GShift1") ? "Normal" : "GShift"
            this.SwitchViewLayer(target)
        } else if (switchNum = 2) {
            target := (this.CurrentViewLayer = "GShift2") ? "Normal" : "GShift2"
            this.SwitchViewLayer(target)
        }
    }

    static SwitchViewLayer(newLayer) {
        this.CurrentViewLayer := newLayer
        this.UpdateLayerButtonsVisual()
        this.RefreshAllButtonCards()
        if (this.SelectedButtonId != "") {
            lbl := ProfileEngine.GetButtonLabel(ProfileEngine.CurrentProfile, this.SelectedButtonId, this.CurrentViewLayer)
            shiftBtns := ProfileEngine.GetShiftButtons()
            s1Id := (shiftBtns.Length >= 1) ? shiftBtns[1].Id : ""
            s2Id := (shiftBtns.Length >= 2) ? shiftBtns[2].Id : ""
            if ((this.CurrentViewLayer = "GShift" || this.CurrentViewLayer = "GShift1") && this.SelectedButtonId = s1Id) {
                lbl := "⚡ B-SHIFT 1 TRIGGER"
            } else if (this.CurrentViewLayer = "GShift2" && this.SelectedButtonId = s2Id) {
                lbl := "⚡ B-SHIFT 2 TRIGGER"
            }
            if (this.CurrentActionText != "")
                this.CurrentActionText.Value := "Action: " . lbl
        }
        OSD.Show("Active Layer", this.GetLayerDisplayName(newLayer))
        SoundBeep(950, 60)
    }

    static GetLayerDisplayName(layer) {
        switch layer {
            case "GShift", "GShift1": return "B-Shift 1"
            case "GShift2":           return "B-Shift 2"
            default:                  return "DEFAULT"
        }
    }

    static UpdateLayerButtonsVisual() {
        if (this.PicToggle1 = "" || this.MainGui = "" || !WinExist(this.MainGui.Hwnd))
            return

        isNorm := (this.CurrentViewLayer = "Normal")
        isS1   := (this.CurrentViewLayer = "GShift" || this.CurrentViewLayer = "GShift1")
        isS2   := (this.CurrentViewLayer = "GShift2")

        offPic := A_ScriptDir . "\assets\toggle_off.png"
        onPic  := A_ScriptDir . "\assets\toggle_on.png"

        ; Switch 1 visual
        if (this.PicToggle1 != "") {
            this.PicToggle1.Value := isS1 ? onPic : offPic
        }
        if (this.LblDefault1 != "") {
            this.LblDefault1.SetFont(isNorm ? "s10 bold cFFFFFF" : "s10 bold c6C7086")
        }
        if (this.LblBShift1 != "") {
            this.LblBShift1.SetFont(isS1 ? "s10 bold c89B4FA" : "s10 bold c6C7086")
        }

        ; Switch 2 visual
        if (this.PicToggle2 != "") {
            this.PicToggle2.Value := isS2 ? onPic : offPic
        }
        if (this.LblDefault2 != "") {
            this.LblDefault2.SetFont(isNorm ? "s10 bold cFFFFFF" : "s10 bold c6C7086")
        }
        if (this.LblBShift2 != "") {
            this.LblBShift2.SetFont(isS2 ? "s10 bold cFAB387" : "s10 bold c6C7086")
        }
    }

    static UpdateLayerSwitches() {
        if (this.PicToggle1 = "" || this.MainGui = "" || !WinExist(this.MainGui.Hwnd))
            return

        shiftBtns := ProfileEngine.GetShiftButtons()
        numShifts := shiftBtns.Length

        if (numShifts = 0) {
            ; Hide all shift switches if no shift button is used in this profile
            if (this.LblDefault1 != "") this.LblDefault1.Visible := false
            if (this.PicToggle1 != "")  this.PicToggle1.Visible := false
            if (this.LblBShift1 != "")  this.LblBShift1.Visible := false
            if (this.LblDefault2 != "") this.LblDefault2.Visible := false
            if (this.PicToggle2 != "")  this.PicToggle2.Visible := false
            if (this.LblBShift2 != "")  this.LblBShift2.Visible := false

            if (this.CurrentViewLayer != "Normal")
                this.SwitchViewLayer("Normal")
            return
        }

        s1Name := this.GetButtonDisplayName(shiftBtns[1].Id)

        if (numShifts = 1) {
            ; Exactly 1 shift button exists: Center Switch 1 and hide Switch 2
            if (this.LblDefault1 != "") {
                this.LblDefault1.Move(520, 642, 75, 26)
                this.LblDefault1.Visible := true
            }
            if (this.PicToggle1 != "") {
                this.PicToggle1.Move(600, 643, 46, 24)
                this.PicToggle1.Visible := true
            }
            if (this.LblBShift1 != "") {
                this.LblBShift1.Move(654, 642, 220, 26)
                this.LblBShift1.Value := "B-SHIFT (" . s1Name . ")"
                this.LblBShift1.Visible := true
            }

            if (this.LblDefault2 != "") this.LblDefault2.Visible := false
            if (this.PicToggle2 != "")  this.PicToggle2.Visible := false
            if (this.LblBShift2 != "")  this.LblBShift2.Visible := false

            if (this.CurrentViewLayer = "GShift2")
                this.SwitchViewLayer("GShift")
        } else if (numShifts >= 2) {
            ; Two shift buttons exist: Show both Switch 1 and Switch 2 side by side
            s2Name := this.GetButtonDisplayName(shiftBtns[2].Id)
            if (this.LblDefault1 != "") {
                this.LblDefault1.Move(380, 642, 75, 26)
                this.LblDefault1.Visible := true
            }
            if (this.PicToggle1 != "") {
                this.PicToggle1.Move(460, 643, 46, 24)
                this.PicToggle1.Visible := true
            }
            if (this.LblBShift1 != "") {
                this.LblBShift1.Move(514, 642, 170, 26)
                this.LblBShift1.Value := "B-SHIFT 1 (" . s1Name . ")"
                this.LblBShift1.Visible := true
            }

            if (this.LblDefault2 != "") {
                this.LblDefault2.Move(700, 642, 75, 26)
                this.LblDefault2.Visible := true
            }
            if (this.PicToggle2 != "") {
                this.PicToggle2.Move(780, 643, 46, 24)
                this.PicToggle2.Visible := true
            }
            if (this.LblBShift2 != "") {
                this.LblBShift2.Move(834, 642, 170, 26)
                this.LblBShift2.Value := "B-SHIFT 2 (" . s2Name . ")"
                this.LblBShift2.Visible := true
            }
        }

        this.UpdateLayerButtonsVisual()
    }

    static RefreshAllButtonCards() {
        currentProf := ProfileEngine.CurrentProfile
        shiftBtns := ProfileEngine.GetShiftButtons()
        s1Id := (shiftBtns.Length >= 1) ? shiftBtns[1].Id : ""
        s2Id := (shiftBtns.Length >= 2) ? shiftBtns[2].Id : ""

        for btnId, card in this.MonitorCards {
            lbl := ProfileEngine.GetButtonLabel(currentProf, btnId, this.CurrentViewLayer)
            isSelected := (btnId = this.SelectedButtonId)

            if ((this.CurrentViewLayer = "GShift" || this.CurrentViewLayer = "GShift1") && btnId = s1Id) {
                card.Value := "⚡ SHIFT 1 TRIGGER"
                card.SetFont("bold cFAB387")
            } else if (this.CurrentViewLayer = "GShift2" && btnId = s2Id) {
                card.Value := "⚡ SHIFT 2 TRIGGER"
                card.SetFont("bold cFAB387")
            } else {
                card.Value := lbl
                card.SetFont(isSelected ? "bold c89B4FA" : "bold cCDD6F4")
            }
        }
    }

    static GetButtonDisplayName(btnId) {
        switch btnId {
            case "TiltLeft":     return "Tilt Left"
            case "TiltRight":    return "Tilt Right"
            case "Middle":       return "Middle"
            case "G8":           return "G8"
            case "G7":           return "G7"
            case "DpiShift":     return "DPI Shift"
            case "Forward":      return "G5"
            case "Back":         return "G4"
            case "ProfileCycle": return "G9"
            default:             return btnId
        }
    }

    static UpdateLiveShiftIndicator(layerNum, isActive) {
        if (this.GShiftStatusText = "" || this.MainGui = "" || !WinExist(this.MainGui.Hwnd))
            return
        if (isActive) {
            this.GShiftStatusText.SetFont("c" . (layerNum = 1 ? "89B4FA" : "FAB387"))
            this.GShiftStatusText.Value := "B-SHIFT " . layerNum
        } else {
            this.GShiftStatusText.SetFont("c" . "F38BA8")
            this.GShiftStatusText.Value := "INACTIVE"
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
        currentAction := ProfileEngine.GetButtonLabel(currentProf, btnId, this.CurrentViewLayer)

        shiftBtns := ProfileEngine.GetShiftButtons()
        s1Id := (shiftBtns.Length >= 1) ? shiftBtns[1].Id : ""
        s2Id := (shiftBtns.Length >= 2) ? shiftBtns[2].Id : ""
        if ((this.CurrentViewLayer = "GShift" || this.CurrentViewLayer = "GShift1") && btnId = s1Id) {
            currentAction := "⚡ B-SHIFT 1 TRIGGER"
        } else if (this.CurrentViewLayer = "GShift2" && btnId = s2Id) {
            currentAction := "⚡ B-SHIFT 2 TRIGGER"
        }

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

        for cat in this.Categories {
            ; Find matching items for this category
            matchingItems := []
            for cmd in this.CommandCatalog {
                if (cmd.Cat != cat.Key)
                    continue
                if (filterLower = "" || InStr(StrLower(cmd.Name), filterLower) || InStr(StrLower(cmd.Key), filterLower) || InStr(StrLower(cat.Title), filterLower)) {
                    matchingItems.Push(cmd)
                }
            }

            if (matchingItems.Length = 0)
                continue

            ; Determine if collapsed (when actively filtering, auto-expand to reveal results)
            isCollapsed := (filterLower = "") && this.CollapsedCategories.Get(cat.Key, false)
            icon := isCollapsed ? "▶  " : "▼  "
            chevron := isCollapsed ? "v" : "^"

            ; Add category header row
            this.CommandListView.Add("", "__SECTION__:" . cat.Key, icon . cat.Title, chevron)

            ; If not collapsed, add commands indented
            if (!isCollapsed) {
                for cmd in matchingItems {
                    this.CommandListView.Add("", cmd.Cat, "  " . cmd.Name, cmd.Key)
                }
            }
        }
    }

    static FilterCommandList() {
        this.PopulateCommandList(this.SearchEdit.Value)
    }

    static OnSidebarItemSelected(lv, item, selected) {
        if (!selected)
            return
    }

    static OnSidebarClick(lv, row) {
        if (row <= 0)
            return
        cat := lv.GetText(row, 1)
        if (InStr(cat, "__SECTION__:")) {
            secKey := SubStr(cat, 13)
            this.CollapsedCategories[secKey] := !this.CollapsedCategories.Get(secKey, false)
            this.PopulateCommandList(this.SearchEdit.Value)
        }
    }

    static OnSidebarDoubleClick(lv, row) {
        if (row <= 0)
            return
        cat := lv.GetText(row, 1)
        if (InStr(cat, "__SECTION__:")) {
            secKey := SubStr(cat, 13)
            this.CollapsedCategories[secKey] := !this.CollapsedCategories.Get(secKey, false)
            this.PopulateCommandList(this.SearchEdit.Value)
            return
        }
        this.ApplySidebarAction()
    }

    static ApplySidebarAction() {
        row := this.CommandListView.GetNext(0)
        if (row = 0) {
            OSD.Show("Select Command First", "Click an action in the list on the left.")
            return
        }

        cat := this.CommandListView.GetText(row, 1)
        if (InStr(cat, "__SECTION__:")) {
            ; Clicked on category header: toggle collapse/expand
            secKey := SubStr(cat, 13)
            this.CollapsedCategories[secKey] := !this.CollapsedCategories.Get(secKey, false)
            this.PopulateCommandList(this.SearchEdit.Value)
            return
        }

        cmdName := Trim(this.CommandListView.GetText(row, 2))
        targetCmdObj := ""
        for item in this.CommandCatalog {
            if (item.Name = cmdName) {
                targetCmdObj := item
                break
            }
        }

        if (targetCmdObj = "")
            return

        this.AssignCommandToButton(targetCmdObj, this.SelectedButtonId)
    }

    static AssignCommandToButton(targetCmdObj, btnId) {
        if (targetCmdObj = "" || btnId = "")
            return false

        currentProf := ProfileEngine.CurrentProfile
        btnDisplayName := this.GetButtonDisplayName(btnId)

        isShiftModifier := (targetCmdObj.Type = "Special" && (targetCmdObj.Cmd = "GShift" || targetCmdObj.Cmd = "GShift1" || targetCmdObj.Cmd = "GShift2"))

        existingShifts := ProfileEngine.GetShiftButtons(currentProf)
        s1Id := (existingShifts.Length >= 1) ? existingShifts[1].Id : ""
        s2Id := (existingShifts.Length >= 2) ? existingShifts[2].Id : ""

        ; Guard: Do not allow assigning regular actions to the active layer's trigger button
        if (!isShiftModifier) {
            if ((this.CurrentViewLayer = "GShift" || this.CurrentViewLayer = "GShift1") && btnId = s1Id) {
                OSD.Show("Shift Trigger Button", "Cannot reassign B-Shift 1 trigger while inside B-Shift 1 layer.`nSwitch to DEFAULT layer first.")
                SoundBeep(600, 100)
                return false
            }
            if (this.CurrentViewLayer = "GShift2" && btnId = s2Id) {
                OSD.Show("Shift Trigger Button", "Cannot reassign B-Shift 2 trigger while inside B-Shift 2 layer.`nSwitch to DEFAULT layer first.")
                SoundBeep(600, 100)
                return false
            }
        }

        ; If assigning a B-Shift modifier: enforce max of 2 shift buttons!
        if (isShiftModifier) {
            otherShiftsCount := 0
            hasShift1 := false
            hasShift2 := false
            for s in existingShifts {
                if (s.Id != btnId) {
                    otherShiftsCount++
                    if (s.Type = "GShift1" || s.Type = "GShift")
                        hasShift1 := true
                    if (s.Type = "GShift2")
                        hasShift2 := true
                }
            }

            if (otherShiftsCount >= 2) {
                OSD.Show("Shift Limit Reached", "Max 2 B-Shift buttons allowed! Reassign an existing shift button first.")
                SoundBeep(600, 120)
                return false
            }

            ; Auto-determine slot (Shift 1 vs Shift 2)
            if (targetCmdObj.Cmd = "GShift2" || (targetCmdObj.Cmd != "GShift1" && hasShift1)) {
                targetCmdObj := { Type: "Special", Cmd: "GShift2", Label: "B-Shift 2 Layer" }
            } else {
                targetCmdObj := { Type: "Special", Cmd: "GShift1", Label: "B-Shift 1 Layer" }
            }
        }

        actionObj := { Type: targetCmdObj.Type, Cmd: targetCmdObj.Cmd, Label: targetCmdObj.Label }
        
        ; Save into target layer (Shift modifiers always bind to Normal)
        targetLayer := isShiftModifier ? "Normal" : this.CurrentViewLayer
        ProfileEngine.SaveButtonLayer(currentProf, btnId, targetLayer, actionObj)

        ; Also select this button as active in UI
        this.SelectButton(btnId, btnDisplayName)

        ; Refresh UI, layer switches, and button cards
        this.UpdateLayerSwitches()
        this.RefreshAllButtonCards()

        if (this.CurrentActionText != "") {
            this.CurrentActionText.Value := "Action: " . actionObj.Label
        }

        layerDisp := this.GetLayerDisplayName(targetLayer)
        OSD.Show("Mapped (" . layerDisp . "): " . btnDisplayName, "-> " . actionObj.Label)
        SoundBeep(1100, 80)
        return true
    }

    static ResetSelectedButton() {
        btnId := this.SelectedButtonId
        currentProf := ProfileEngine.CurrentProfile
        ProfileEngine.ResetMappingToDefault(currentProf, btnId)

        this.UpdateLayerSwitches()
        this.RefreshAllButtonCards()

        newLabel := ProfileEngine.GetButtonLabel(currentProf, btnId, this.CurrentViewLayer)
        if (this.CurrentActionText != "") {
            this.CurrentActionText.Value := "Action: " . newLabel
        }

        OSD.Show("Reset to Default", btnId)
    }

    ; ========================================================
    ; MODAL KEYSTROKE & COMBINATION RECORDER (Double-Click)
    ; ========================================================
    ; ========================================================
    ; BUTTON STUDIO MODAL (Single / Combo & G-HUB Macro Recorder)
    ; ========================================================
    static StartKeystrokeRecording(btnId, btnDisplayName) {
        shiftBtns := ProfileEngine.GetShiftButtons()
        s1Id := (shiftBtns.Length >= 1) ? shiftBtns[1].Id : ""
        s2Id := (shiftBtns.Length >= 2) ? shiftBtns[2].Id : ""
        if ((this.CurrentViewLayer = "GShift" || this.CurrentViewLayer = "GShift1") && btnId = s1Id) {
            OSD.Show("Shift Trigger Button", "This button is the physical trigger for B-Shift 1.`nSwitch to DEFAULT layer to edit it.")
            SoundBeep(600, 100)
            return
        }
        if (this.CurrentViewLayer = "GShift2" && btnId = s2Id) {
            OSD.Show("Shift Trigger Button", "This button is the physical trigger for B-Shift 2.`nSwitch to DEFAULT layer to edit it.")
            SoundBeep(600, 100)
            return
        }

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
        norm := (this.CurrentViewLayer = "GShift2") ? currMap.GShift2 : ((this.CurrentViewLayer = "GShift" || this.CurrentViewLayer = "GShift1") ? currMap.GShift : currMap.Normal)

        ; Create Studio modal window
        rg := Gui("+AlwaysOnTop -MaximizeBox +Owner" . this.MainGui.Hwnd, "Button Studio — " . btnDisplayName)
        rg.BackColor := "181825"
        rg.MarginX := 20
        rg.MarginY := 18
        this.RecorderGui := rg

        ; Header
        rg.SetFont("s11 bold c89B4FA", "Segoe UI")
        rg.Add("Text", "x25 y15 w590 Center", "LOGITECH G502 X — BUTTON STUDIO")

        layerName := this.GetLayerDisplayName(this.CurrentViewLayer)
        rg.SetFont("s9 bold cCDD6F4", "Segoe UI")
        rg.Add("Text", "x25 y38 w590 Center", "Target: " . btnDisplayName . "  •  Profile: " . ProfileEngine.CurrentProfile . "  •  Layer: " . layerName)

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
        this.RecBtnRecordSingle := rg.Add("Button", "x75 y280 w150 h32", "● Record Key")
        btnSingleClear          := rg.Add("Button", "x240 y280 w130 h32", "🗑 Clear Key")
        btnSetBShift            := rg.Add("Button", "x385 y280 w170 h32", "⚡ Assign B-Shift")

        this.RecBtnRecordSingle.OnEvent("Click", (*) => this.ToggleSingleRecording())
        btnSingleClear.OnEvent("Click", (*) => this.ClearSingleKey())
        btnSetBShift.OnEvent("Click", (*) => this.AssignBShiftFromStudio())
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
                this.RecIsRecordingSingle := false
                if (this.RecBtnRecordSingle != "") {
                    this.RecBtnRecordSingle.Text := "● Record Key"
                }
            } else {
                ; Empty mapping - auto start listening once so user can immediately press their key
                this.StartSingleRecording()
            }
            this.RecDdlSingleMode.Choose(this.PlayTypeToIndex(norm.HasOwnProp("PlayType") ? norm.PlayType : "NoRepeat"))
            this.RecEdtSingleInt.Value := String(norm.HasOwnProp("RepeatInterval") ? norm.RepeatInterval : 50)
            this.UpdateSingleModeExplain()
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
            if (this.RecIsRecordingSingle) {
                this.StartSingleKeyListening()
            }
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

    static ToggleSingleRecording() {
        if (this.RecIsRecordingSingle) {
            this.StopSingleRecording()
        } else {
            this.StartSingleRecording()
        }
    }

    static StartSingleRecording() {
        this.RecIsRecordingSingle := true
        if (this.RecBtnRecordSingle != "") {
            this.RecBtnRecordSingle.Text := "■ Stop Recording"
        }
        if (this.RecPreviewText != "") {
            this.RecPreviewText.SetFont("c" . "89B4FA")
            this.RecPreviewText.Value := "[ Press Any Key or Combination... ]"
        }
        this.StartSingleKeyListening()
        SoundBeep(900, 60)
    }

    static StopSingleRecording() {
        this.StopSingleKeyListening()
        this.RecIsRecordingSingle := false
        if (this.RecBtnRecordSingle != "") {
            this.RecBtnRecordSingle.Text := "● Record Key"
        }
        if (this.RecPreviewText != "") {
            if (this.RecCapturedLabel != "") {
                this.RecPreviewText.SetFont("c" . "A6E3A1")
                this.RecPreviewText.Value := "✔  " . this.RecCapturedLabel
            } else {
                this.RecPreviewText.SetFont("c" . "89B4FA")
                this.RecPreviewText.Value := "[ Click 'Record Key' to Begin ]"
            }
        }
    }

    static ClearSingleKey() {
        this.StopSingleKeyListening()
        this.RecIsRecordingSingle := false
        this.RecCapturedCmd := ""
        this.RecCapturedLabel := ""
        this.RecActiveCombo := []
        this.RecKeysDown.Clear()
        if (this.RecBtnRecordSingle != "") {
            this.RecBtnRecordSingle.Text := "● Record Key"
        }
        if (this.RecPreviewText != "") {
            this.RecPreviewText.SetFont("c" . "89B4FA")
            this.RecPreviewText.Value := "[ Click 'Record Key' to Begin ]"
        }
        SoundBeep(650, 70)
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

            ; Close the recording immediately after capturing the button/chord!
            this.StopSingleKeyListening()
            this.RecIsRecordingSingle := false
            if (this.RecBtnRecordSingle != "") {
                this.RecBtnRecordSingle.Text := "● Record Key"
            }
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
            ; Suppress keys that activate GUI buttons or alter dialog focus in the Button Studio window
            ih.KeyOpt("{Enter}{NumpadEnter}{Space}{Tab}{Escape}", "+S")
            ih.OnKeyDown := (hook, vk, sc) => this.OnMacroKeyDown(vk, sc)
            ih.OnKeyUp   := (hook, vk, sc) => this.OnMacroKeyUp(vk, sc)
            this.RecMacroHook := ih
            ih.Start()

            try this.RecLvMacro.Focus()

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
    }

    static OnMacroKeyUp(vk, sc) {
        if (!this.RecIsRecordingMacro || this.RecorderGui = "" || !WinExist(this.RecorderGui.Hwnd))
            return

        kName := GetKeyName(Format("vk{:02x}sc{:03x}", vk, sc))
        if (kName = "" || !this.RecMacroActiveKeys.Has(kName))
            return

        tNow := A_TickCount
        tDown := this.RecMacroActiveKeys[kName]
        del := this.RecChkRealDelays.Value ? Max(10, tNow - tDown) : Integer(this.RecEdtDefDelay.Value)
        this.RecMacroLastTime := tNow
        this.RecMacroActiveKeys.Delete(kName)

        this.AddMacroStep(this.RecActivePhase, "Up", kName, del)
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

        activeTab := this.RecTabs.Value

        if (activeTab = 1) {
            ; Save Single / Combination
            if (this.RecCapturedCmd = "") {
                OSD.Show("No Key Recorded", "Please press a key or combo first")
                return
            }
            playType := this.DisplayToPlayType(this.RecDdlSingleMode.Text)
            intVal := IsInteger(this.RecEdtSingleInt.Value) ? Integer(this.RecEdtSingleInt.Value) : 50
            actionObj := {
                Type: "Send",
                Cmd: this.RecCapturedCmd,
                Label: this.RecCapturedLabel,
                PlayType: playType,
                RepeatInterval: intVal
            }
            ProfileEngine.SaveButtonLayer(currentProf, btnId, this.CurrentViewLayer, actionObj)
            label := actionObj.Label
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
                actionObj := {
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
                actionObj := {
                    Type: "Macro",
                    Cmd: "Macro",
                    Label: label,
                    PlayType: playType,
                    RepeatInterval: defDelay,
                    Steps: this.RecStepsPress
                }
            }
            ProfileEngine.SaveButtonLayer(currentProf, btnId, this.CurrentViewLayer, actionObj)
        }

        ; Refresh layer switches and callout cards
        this.UpdateLayerSwitches()
        this.RefreshAllButtonCards()

        if (this.CurrentActionText != "") {
            this.CurrentActionText.Value := "Action: " . label
        }

        layerDisp := this.GetLayerDisplayName(this.CurrentViewLayer)
        OSD.Show("Mapping Saved (" . layerDisp . ")", this.RecTargetName . " -> " . label)
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
        this.RecBtnRecordSingle := ""
        this.RecIsRecordingSingle := false
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

    static AssignBShiftFromStudio() {
        btnId := this.RecTargetId
        currentProf := ProfileEngine.CurrentProfile
        existingShifts := ProfileEngine.GetShiftButtons(currentProf)
        otherShiftsCount := 0
        hasShift1 := false
        for s in existingShifts {
            if (s.Id != btnId) {
                otherShiftsCount++
                if (s.Type = "GShift1" || s.Type = "GShift")
                    hasShift1 := true
            }
        }
        if (otherShiftsCount >= 2) {
            OSD.Show("Shift Limit Reached", "Max 2 B-Shift buttons allowed! Reassign an existing shift button first.")
            SoundBeep(600, 120)
            return
        }
        shiftCmd := (hasShift1) ? "GShift2" : "GShift1"
        shiftLabel := (hasShift1) ? "B-Shift 2 Layer" : "B-Shift 1 Layer"
        actionObj := { Type: "Special", Cmd: shiftCmd, Label: shiftLabel }
        ProfileEngine.SaveButtonLayer(currentProf, btnId, "Normal", actionObj)

        this.StopKeystrokeRecording(false)
        if (this.RecorderGui != "") {
            this.RecorderGui.Destroy()
            this.RecorderGui := ""
        }
        this.UpdateLayerSwitches()
        this.RefreshAllButtonCards()
        if (this.CurrentActionText != "")
            this.CurrentActionText.Value := "Action: " . shiftLabel
        OSD.Show("Assigned B-Shift", this.RecTargetName . " -> " . shiftLabel)
        SoundBeep(1100, 80)
    }

    static OnProfileDropdownChanged(p) {
        ProfileEngine.SetProfile(p)
        this.UpdateLayerSwitches()
        this.RefreshAllButtonCards()
        this.SelectButton(this.SelectedButtonId, this.SelectedButtonName)
    }

    static OnProfileChangedHandler(p) {
        if (this.MainGui = "" || !WinExist(this.MainGui.Hwnd))
            return
        if (this.ProfileDropdown != "")
            this.ProfileDropdown.Choose(p)
        this.UpdateLayerSwitches()
        this.RefreshAllButtonCards()
        this.SelectButton(this.SelectedButtonId, this.SelectedButtonName)
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
        this.UpdateLayerSwitches()
        this.RefreshAllButtonCards()

        if (this.CurrentActionText != "") {
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

        this.UpdateLayerSwitches()
        this.RefreshAllButtonCards()

        newLabel := ProfileEngine.GetButtonLabel(currentProf, btnId, this.CurrentViewLayer)
        if (this.CurrentActionText != "") {
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

        this.UpdateLayerSwitches()
        this.RefreshAllButtonCards()

        if (this.CurrentActionText != "") {
            lbl := ProfileEngine.GetButtonLabel(profileName, this.SelectedButtonId, this.CurrentViewLayer)
            shiftBtns := ProfileEngine.GetShiftButtons()
            s1Id := (shiftBtns.Length >= 1) ? shiftBtns[1].Id : ""
            s2Id := (shiftBtns.Length >= 2) ? shiftBtns[2].Id : ""
            if ((this.CurrentViewLayer = "GShift" || this.CurrentViewLayer = "GShift1") && this.SelectedButtonId = s1Id) {
                lbl := "⚡ SHIFT 1 TRIGGER"
            } else if (this.CurrentViewLayer = "GShift2" && this.SelectedButtonId = s2Id) {
                lbl := "⚡ SHIFT 2 TRIGGER"
            }
            this.CurrentActionText.Value := "Action: " . lbl
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

    ; ========================================================
    ; DRAG & DROP COMMAND REMAPPING ENGINE
    ; ========================================================
    static IsMainGuiActive() {
        return (this.MainGui != "" && WinExist(this.MainGui.Hwnd) && WinActive(this.MainGui.Hwnd) && (this.MainTab = "" || this.MainTab.Value = 1))
    }

    static GetCalibratedPoints() {
        defaults := Map(
            "TiltLeft",     { name: "Tilt Left [F17]",      tx: 338, ty: 64 },
            "Middle",       { name: "Middle Click [F13]",   tx: 355, ty: 58 },
            "TiltRight",    { name: "Tilt Right [F18]",     tx: 374, ty: 64 },
            "G8",           { name: "G8 (DPI Up) [F20]",    tx: 228, ty: 106 },
            "G7",           { name: "G7 (DPI Down) [F21]",  tx: 242, ty: 126 },
            "DpiShift",     { name: "DPI Shift [F15]",      tx: 270, ty: 264 },
            "Forward",      { name: "G5 (Forward) [F16]",   tx: 308, ty: 248 },
            "Back",         { name: "G4 (Back) [F14]",      tx: 352, ty: 272 },
            "ProfileCycle", { name: "G9 (Profile) [F19]",   tx: 426, ty: 92 }
        )

        iniPath := A_ScriptDir . "\settings.ini"
        points := Map()

        for id, def in defaults {
            tx := def.tx
            ty := def.ty
            if FileExist(iniPath) {
                try {
                    iniX := IniRead(iniPath, "DiagramPoints", id . "_X", "")
                    iniY := IniRead(iniPath, "DiagramPoints", id . "_Y", "")
                    if (iniX != "" && IsInteger(iniX))
                        tx := Integer(iniX)
                    if (iniY != "" && IsInteger(iniY))
                        ty := Integer(iniY)
                }
            }
            points[id] := { name: def.name, tx: tx, ty: ty }
        }
        return points
    }

    static FindButtonUnderCursor() {
        pt := Buffer(8, 0)
        DllCall("GetCursorPos", "ptr", pt)
        hoverHwnd := DllCall("WindowFromPoint", "int64", NumGet(pt, 0, "int64"), "ptr")

        for btnId, cardCtrl in this.MonitorCards {
            if (hoverHwnd = cardCtrl.Hwnd)
                return btnId
        }

        for btnId, subCtrl in this.MonitorSubtitles {
            if (subCtrl != "" && hoverHwnd = subCtrl.Hwnd)
                return btnId
        }

        ; Check if cursor is over the diagram picture control (snaps to closest hardware button)
        if (this.DiagramPic != "" && hoverHwnd = this.DiagramPic.Hwnd) {
            diagPt := Buffer(8, 0)
            DllCall("GetCursorPos", "ptr", diagPt)
            DllCall("ScreenToClient", "ptr", this.DiagramPic.Hwnd, "ptr", diagPt)
            cx := NumGet(diagPt, 0, "int")
            cy := NumGet(diagPt, 4, "int")

            points := this.GetCalibratedPoints()
            closestId := ""
            minDist := 999999

            for id, p in points {
                dist := Sqrt((cx - p.tx)**2 + (cy - p.ty)**2)
                if (dist < minDist) {
                    minDist := dist
                    closestId := id
                }
            }

            if (minDist <= 55)
                return closestId
        }

        return ""
    }

    static HandleDragDrop() {
        if (!this.IsMainGuiActive() || this.CommandListView = "")
            return

        pt := Buffer(8, 0)
        DllCall("GetCursorPos", "ptr", pt)
        mHwnd := DllCall("WindowFromPoint", "int64", NumGet(pt, 0, "int64"), "ptr")
        if (mHwnd != this.CommandListView.Hwnd)
            return

        ; Convert to ListView client coordinates
        DllCall("ScreenToClient", "ptr", this.CommandListView.Hwnd, "ptr", pt)
        lvX := NumGet(pt, 0, "int")
        lvY := NumGet(pt, 4, "int")

        ; Hit test row in ListView
        hti := Buffer(24, 0)
        NumPut("int", lvX, hti, 0)
        NumPut("int", lvY, hti, 4)
        rowIdx := DllCall("SendMessage", "ptr", this.CommandListView.Hwnd, "uint", 0x1012, "ptr", 0, "ptr", hti, "int")
        clickedRow := (rowIdx >= 0) ? (rowIdx + 1) : 0
        if (clickedRow <= 0)
            return

        cat := this.CommandListView.GetText(clickedRow, 1)
        if (InStr(cat, "__SECTION__:"))
            return

        cmdName := Trim(this.CommandListView.GetText(clickedRow, 2))
        if (cmdName = "")
            return

        targetCmdObj := ""
        for item in this.CommandCatalog {
            if (item.Name = cmdName) {
                targetCmdObj := item
                break
            }
        }
        if (targetCmdObj = "")
            return

        startPt := Buffer(8, 0)
        DllCall("GetCursorPos", "ptr", startPt)
        startX := NumGet(startPt, 0, "int")
        startY := NumGet(startPt, 4, "int")
        isDragging := false

        while GetKeyState("LButton", "P") {
            curPt := Buffer(8, 0)
            DllCall("GetCursorPos", "ptr", curPt)
            if (Abs(NumGet(curPt, 0, "int") - startX) > 5 || Abs(NumGet(curPt, 4, "int") - startY) > 5) {
                isDragging := true
                break
            }
            Sleep 15
        }

        if (!isDragging)
            return

        lastHoveredId := ""
        while GetKeyState("LButton", "P") {
            curHoveredId := this.FindButtonUnderCursor()

            if (curHoveredId != lastHoveredId) {
                if (lastHoveredId != "" && this.MonitorCards.Has(lastHoveredId)) {
                    this.MonitorCards[lastHoveredId].Opt("Background1E1E2E cCDD6F4")
                    this.MonitorCards[lastHoveredId].Redraw()
                }
                if (curHoveredId != "" && this.MonitorCards.Has(curHoveredId)) {
                    this.MonitorCards[curHoveredId].Opt("BackgroundFAB387 c11111B")
                    this.MonitorCards[curHoveredId].Redraw()
                }
                lastHoveredId := curHoveredId
            }

            if (curHoveredId != "") {
                btnName := this.GetButtonDisplayName(curHoveredId)
                ToolTip("✨ Drop onto " . btnName . " to map '" . cmdName . "'!")
            } else {
                ToolTip("📌 Dragging: " . cmdName . "`nDrop onto any mouse button or card")
            }
            Sleep 20
        }

        ToolTip()
        if (lastHoveredId != "" && this.MonitorCards.Has(lastHoveredId)) {
            this.MonitorCards[lastHoveredId].Opt("Background1E1E2E cCDD6F4")
            this.MonitorCards[lastHoveredId].Redraw()
        }

        finalDropId := this.FindButtonUnderCursor()
        if (finalDropId != "") {
            this.AssignCommandToButton(targetCmdObj, finalDropId)
        } else {
            this.RefreshAllButtonCards()
        }
    }
}

#HotIf GuiManager.IsMainGuiActive()
~LButton::GuiManager.HandleDragDrop()
#HotIf
