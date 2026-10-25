#Requires AutoHotkey v2.0

/**
 * Modern Embedded WebView2 GUI Manager for Logitech G502 X
 * Hosts web/index.html in Microsoft Edge WebView2, connecting ProfileEngine,
 * OSD, and tray status via bidirectional IPC.
 */

#Include "WebView2.ahk"
#Include "JSON.ahk"
#Include "Profiles.ahk"
#Include "OSD.ahk"
#Include "OMMHelper.ahk"

class WebViewGuiManager {
    static MainGui := ""
    static GuiObj => this.MainGui
    static wvc := ""
    static wv := ""
    static IsAlwaysOnTop := false
    static IsInitialized := false
    static IsInitializing := false
    static IsNavigated := false
    static PendingMessages := []

    static Show() {
        if (this.MainGui != "" && WinExist(this.MainGui.Hwnd)) {
            this.MainGui.Show()
            this.ApplyThemeToTitleBar(this.MainGui.Hwnd)
            this.SetWindowIcon(this.MainGui.Hwnd)
            if (this.wvc != "") {
                this.wvc.Fill()
            }
            return
        }

        if (this.IsInitializing)
            return

        this.Init()
    }

    static Toggle() {
        if (this.MainGui != "" && WinExist(this.MainGui.Hwnd)) {
            if (DllCall("IsWindowVisible", "Ptr", this.MainGui.Hwnd)) {
                this.StopRecording()
                this.MainGui.Hide()
            } else {
                this.MainGui.Show()
                this.ApplyThemeToTitleBar(this.MainGui.Hwnd)
                this.SetWindowIcon(this.MainGui.Hwnd)
                if (this.wvc != "") {
                    this.wvc.Fill()
                }
            }
        } else {
            this.Show()
        }
    }

    static HasAttemptedFallback := false

    static Init() {
        this.IsInitializing := true
        this.HasAttemptedFallback := false

        ; Read AlwaysOnTop setting
        iniPath := A_ScriptDir . "\settings.ini"
        try {
            this.IsAlwaysOnTop := (IniRead(iniPath, "General", "AlwaysOnTop", "0") = "1")
        } catch {
            this.IsAlwaysOnTop := false
        }

        ; Hook ProfileEngine callbacks
        ProfileEngine.OnProfileChanged := (p) => WebViewGuiManager.OnProfileChangedHandler(p)
        ProfileEngine.OnButtonStateChanged := (btnId, isDown) => WebViewGuiManager.OnButtonStateChangedHandler(btnId, isDown)
        ProfileEngine.OnShiftStateChanged := (layerNum, isActive) => WebViewGuiManager.OnShiftStateChangedHandler(isActive, (layerNum = 2 ? "GShift2" : "GShift1"))

        ; Clean any orphaned WebView2 renderer processes from prior runs
        this.CleanOrphanedProcesses()

        ; Create GUI
        opt := "+Resize -MaximizeBox " . (this.IsAlwaysOnTop ? "+AlwaysOnTop" : "-AlwaysOnTop")
        g := Gui(opt, "Logitech G502 X — Advanced Studio")
        g.BackColor := "0b0d14"
        g.MarginX := 0
        g.MarginY := 0
        this.MainGui := g

        ; Set custom app icon (16x16 caption, 32x32 taskbar)
        this.SetWindowIcon(g.Hwnd)

        ; Apply immersive dark mode and theme matching colors to the title bar
        this.ApplyThemeToTitleBar(g.Hwnd)

        ; Sizing event
        g.OnEvent("Size", (guiObj, minMax, w, h) => WebViewGuiManager.OnSize(minMax, w, h))
        g.OnEvent("Close", (*) => (WebViewGuiManager.StopRecording(), g.Hide()))
        g.OnEvent("Escape", (*) => (WebViewGuiManager.StopRecording(), g.Hide()))

        ; Display window
        g.Show("w1360 h840 Center")
        this.ApplyThemeToTitleBar(g.Hwnd)

        ; Initialize WebView2 Controller
        dllPath := A_ScriptDir . "\lib\WebView2Loader.dll"
        if (!FileExist(dllPath))
            dllPath := A_ScriptDir . "\lib\64bit\WebView2Loader.dll"

        baseData := A_AppData . "\OBM_G502X_WebView2"
        if (!DirExist(baseData)) {
            try DirCreate(baseData)
        }
        currentPid := DllCall("GetCurrentProcessId")
        userData := baseData . "\WV_" . currentPid
        if (!DirExist(userData)) {
            try DirCreate(userData)
        }

        this.Log("Init: GUI created, HWND=" . g.Hwnd . ", calling CreateControllerAsync with PID=" . currentPid)

        WebView2.CreateControllerAsync(g.Hwnd, 0, userData, "", dllPath).then(
            this.OnControllerCreated.Bind(this),
            this.OnControllerError.Bind(this)
        )
    }

    static CleanOrphanedProcesses() {
        try {
            currentPid := DllCall("GetCurrentProcessId")
            baseData := A_AppData . "\OBM_G502X_WebView2"

            ; 1. Clean orphaned msedgewebview2 processes
            for proc in ComObjGet("winmgmts:").ExecQuery("Select ProcessId, CommandLine from Win32_Process where Name like 'msedgewebview2%'") {
                cmd := proc.CommandLine
                if (RegExMatch(cmd, "OBM_G502X_WV_(\d+)", &m)) {
                    ownerPid := Integer(m[1])
                    if (ownerPid != currentPid && !ProcessExist(ownerPid)) {
                        try ProcessClose(proc.ProcessId)
                    }
                }
            }

            ; 2. Clean dead session directories
            if (DirExist(baseData)) {
                Loop Files, baseData . "\WV_*", "D" {
                    if (RegExMatch(A_LoopFileName, "^WV_(\d+)$", &m)) {
                        ownerPid := Integer(m[1])
                        if (ownerPid != currentPid && !ProcessExist(ownerPid)) {
                            try DirDelete(A_LoopFileFullPath, true)
                        }
                    } else if (InStr(A_LoopFileName, "WV_FB_")) {
                        try DirDelete(A_LoopFileFullPath, true)
                    }
                }
            }
        }
    }

    static Cleanup() {
        if (this.wvc != "") {
            try this.wvc.Close()
            this.wvc := ""
            this.wv := ""
        }
        currentPid := DllCall("GetCurrentProcessId")
        baseData := A_AppData . "\OBM_G502X_WebView2"
        sessionDir := baseData . "\WV_" . currentPid
        if (DirExist(sessionDir)) {
            try DirDelete(sessionDir, true)
        }
        this.CleanOrphanedProcesses()
    }

    static Log(msg) {
        try {
            FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") . " | " . msg . "`n", A_ScriptDir . "\webview_debug.log")
        }
    }

    static OnControllerCreated(wvc) {
        global g_G502X_wvc := wvc
        global g_G502X_wv := wvc.CoreWebView2
        this.wvc := wvc
        this.wv := wvc.CoreWebView2
        this.IsInitializing := false
        this.Log("OnControllerCreated: Success! CoreWebView2 ptr=" . this.wv.ptr)

        ; Edge settings
        try {
            settings := this.wv.Settings
            settings.AreDefaultContextMenusEnabled := true
            settings.IsStatusBarEnabled := false
            settings.AreDevToolsEnabled := true
        }

        ; Fit window
        wvc.Fill()

        ; Register IPC listener
        this.wv.add_WebMessageReceived(this.OnWebMessageReceived.Bind(this))

        ; Navigate to web/index.html
        htmlPath := A_ScriptDir . "\web\index.html"
        url := "file:///" . StrReplace(htmlPath, "\", "/")
        this.Log("Navigating to: " . url)
        this.wv.Navigate(url)

        this.IsInitialized := true
    }

    static OnControllerError(err) {
        this.IsInitializing := false
        msg := IsObject(err) && err.HasOwnProp("Message") ? err.Message : String(err)
        this.Log("OnControllerError: " . msg)

        ; If first attempt fails, retry with emergency timestamp dir
        if (!this.HasAttemptedFallback) {
            this.HasAttemptedFallback := true
            this.Log("Attempting emergency fallback with unique timestamp folder...")
            SetTimer(() => this.RetryWithIsolatedFolder(), -200)
            return
        }

        this.OnFallbackFailed(err)
    }

    static RetryWithIsolatedFolder() {
        if (!this.MainGui || !WinExist(this.MainGui.Hwnd))
            return

        dllPath := A_ScriptDir . "\lib\WebView2Loader.dll"
        if (!FileExist(dllPath))
            dllPath := A_ScriptDir . "\lib\64bit\WebView2Loader.dll"

        userData := A_AppData . "\OBM_G502X_WebView2\WV_FB_" . A_TickCount
        try DirCreate(userData)

        this.Log("Retrying CreateControllerAsync with fallback: " . userData)
        WebView2.CreateControllerAsync(this.MainGui.Hwnd, 0, userData, "", dllPath).then(
            this.OnControllerCreated.Bind(this),
            (err) => this.OnFallbackFailed(err)
        )
    }

    static OnFallbackFailed(err) {
        msg := IsObject(err) && err.HasOwnProp("Message") ? err.Message : String(err)
        this.Log("WebView2 controller initialization failed: " . msg . ". Falling back to Classic Win32 GUI.")
        try {
            if (this.MainGui && WinExist(this.MainGui.Hwnd))
                this.MainGui.Hide()
            GuiManager.Show()
        }
    }

    static OnSize(minMax, w, h) {
        if (minMax = -1) ; Minimized
            return
        if (this.wvc != "") {
            this.wvc.Fill()
        }
    }

    ; =========================================================================
    ; IPC MESSAGING (Edge WebView2 <-> AutoHotkey)
    ; =========================================================================
    static OnWebMessageReceived(sender, args) {
        try {
            jsonStr := args.TryGetWebMessageAsString()
            if (!jsonStr)
                return

            this.Log("Received IPC: " . jsonStr)
            req := JSON.parse(jsonStr)
            this.DispatchClientAction(req)
        } catch as err {
            this.Log("Error in OnWebMessageReceived: " . err.Message)
        }
    }

    static DispatchClientAction(req) {
        if (!IsObject(req) || !req.Has("action"))
            return

        action := req["action"]

        switch action {
            case "getInitialState":
                this.SendInitialState()

            case "selectProfile":
                if (req.Has("profile")) {
                    ProfileEngine.SelectProfile(req["profile"])
                }

            case "addProfile":
                if (req.Has("name")) {
                    pName := req["name"]
                    pExe := req.Has("targetExe") ? req["targetExe"] : ""
                    pIcon := req.Has("icon") ? req["icon"] : "auto"
                    pHover := req.Has("switchOnHover") ? (req["switchOnHover"] ? true : false) : false
                    if (ProfileEngine.AddProfile(pName, pExe, pIcon, pHover)) {
                        this.SendProfilesUpdated()
                        ProfileEngine.SetProfile(pName)
                        OSD.Show("Profile Created: " . pName, pExe != "" ? "Bound to: " . pExe : "Default Bindings")
                    }
                }

            case "deleteProfile":
                if (req.Has("name")) {
                    pName := req["name"]
                    if (ProfileEngine.DeleteProfile(pName)) {
                        this.SendProfilesUpdated()
                        OSD.Show("Profile Deleted", pName)
                    }
                }

            case "updateProfile":
                if (req.Has("name")) {
                    pName := req["name"]
                    pExe := req.Has("targetExe") ? req["targetExe"] : ""
                    pIcon := req.Has("icon") ? req["icon"] : ""
                    pHover := req.Has("switchOnHover") ? (req["switchOnHover"] ? true : false) : -1
                    if (ProfileEngine.UpdateProfile(pName, pExe, pIcon, pHover)) {
                        this.SendProfilesUpdated()
                        OSD.Show("Profile Updated: " . pName, pExe != "" ? "App: " . pExe : "No Exe")
                    }
                }

            case "toggleAutoSwitch":
                enabled := req.Has("enabled") ? req["enabled"] : !ProfileEngine.AutoSwitchEnabled
                ProfileEngine.AutoSwitchEnabled := enabled ? true : false
                ProfileEngine.SaveProfileConfig()
                this.PostMessage(Map("type", "autoSwitchChanged", "enabled", ProfileEngine.AutoSwitchEnabled ? true : false))
                OSD.Show("Auto-Switch: " . (ProfileEngine.AutoSwitchEnabled ? "Enabled" : "Disabled"), "Window focus tracking")

            case "toggleLockProfile":
                targetProf := req.Has("profile") ? req["profile"] : ProfileEngine.CurrentProfile
                ProfileEngine.LockedProfile := (ProfileEngine.LockedProfile == targetProf) ? "" : targetProf
                ProfileEngine.SaveProfileConfig()
                this.PostMessage(Map("type", "lockProfileChanged", "lockedProfile", ProfileEngine.LockedProfile))
                OSD.Show(ProfileEngine.LockedProfile != "" ? "Profile Locked: " . ProfileEngine.LockedProfile : "Profile Unlocked", "Auto-switch will " . (ProfileEngine.LockedProfile != "" ? "stay on this profile" : "follow active window"))

            case "toggleOSD":
                enabled := req.Has("enabled") ? req["enabled"] : !OSD.Enabled
                OSD.Enabled := enabled ? true : false
                IniWrite(OSD.Enabled ? "1" : "0", ProfileEngine.ConfigPath, "Settings", "ShowOSD")
                this.PostMessage(Map("type", "osdStateChanged", "enabled", OSD.Enabled ? true : false))
                if (OSD.Enabled)
                    OSD.Show("Notifications: Enabled")

            case "getRunningApps":
                procs := ProfileEngine.GetRunningProcesses()
                this.PostMessage(Map("type", "runningAppsList", "apps", procs))

            case "saveMapping":
                this.HandleSaveMapping(req)

            case "copyProfileMappings":
                fromP := req.Has("fromProfile") ? req["fromProfile"] : ""
                toP := req.Has("toProfile") ? req["toProfile"] : ""
                if (fromP != "" && toP != "") {
                    ProfileEngine.CopyProfileMappings(fromP, toP)
                    this.PostMessage(Map(
                        "type", "mappingsCopied",
                        "fromProfile", fromP,
                        "toProfile", toP,
                        "mappings", this.ExportAllMappings()
                    ))
                    OSD.Show("Mappings Copied", "Pasted from " . fromP . " into " . toP)
                }

            case "browseAppExe":
                selectedFile := FileSelect(3, , "Select Application Executable for Profile", "Programs (*.exe)")
                if (selectedFile != "") {
                    SplitPath(selectedFile, &outFileName, &outDir, &outExt, &outNameNoExt)
                    iconName := ProfileEngine.EnsureExeIconDirect(selectedFile, outNameNoExt)
                    this.PostMessage(Map(
                        "type", "appExeBrowsed",
                        "fullPath", selectedFile,
                        "exeName", outFileName,
                        "nameNoExt", outNameNoExt,
                        "icon", iconName
                    ))
                }

            case "browseCustomIcon":
                selectedFile := FileSelect(1, , "Select Custom Profile Icon", "Image Files (*.png; *.ico; *.jpg; *.jpeg; *.bmp; *.exe)")
                if (selectedFile != "") {
                    SplitPath(selectedFile, &outFileName, &outDir, &outExt, &outNameNoExt)
                    cleanKey := "custom_" . StrLower(RegExReplace(outNameNoExt, "[^a-zA-Z0-9_]", "")) . "_" . A_TickCount
                    outPng := A_ScriptDir . "\web\icons\" . cleanKey . ".png"
                    if (ProfileEngine.SaveImageAsPng(selectedFile, outPng)) {
                        this.PostMessage(Map(
                            "type", "customIconSelected",
                            "iconKey", cleanKey,
                            "fileName", outFileName
                        ))
                    }
                }

            case "injectFKey":
                targetK := req.Has("key") ? req["key"] : "F20"
                OMMHelper.StartCountdown(targetK)

            case "swapHardwareFKeys":
                b1 := req.Has("btnId1") ? req["btnId1"] : ""
                b2 := req.Has("btnId2") ? req["btnId2"] : ""
                if (b1 != "" && b2 != "" && ProfileEngine.SwapHardwareFKeys(b1, b2)) {
                    this.PostMessage(Map("type", "hardwareFKeysUpdated", "hardwareFKeys", ProfileEngine.GetHardwareFKeysExport()))
                    OSD.Show("F-Keys Swapped", b1 . " ↔ " . b2)
                }

            case "copySingleButtonMapping":
                p := req.Has("profile") ? req["profile"] : ProfileEngine.CurrentProfile
                fId := req.Has("fromBtnId") ? req["fromBtnId"] : ""
                tId := req.Has("toBtnId") ? req["toBtnId"] : ""
                if (p != "" && fId != "" && tId != "" && ProfileEngine.CopySingleButtonMapping(p, fId, tId)) {
                    this.PostMessage(Map("type", "buttonMappingPasted", "profile", p, "toBtnId", tId, "mappings", this.ExportAllMappings()))
                    OSD.Show("Mapping Pasted", fId . " ➔ " . tId)
                }

            case "resetButtonDefault":
                this.HandleResetButtonDefault(req)

            case "toggleRapidFire":
                ProfileEngine.ToggleRapidFire()
                this.PostMessage(Map(
                    "type", "rapidFireChanged",
                    "enabled", ProfileEngine.RapidFireEnabled ? true : false
                ))

            case "setAlwaysOnTop":
                enable := req.Has("enabled") ? req["enabled"] : false
                this.SetAlwaysOnTop(enable)

            case "startRecording":
                mode := req.Has("mode") ? req["mode"] : "single"
                opts := Map()
                if (req.Has("defDelay"))
                    opts["defDelay"] := req["defDelay"]
                if (req.Has("realDelays"))
                    opts["realDelays"] := req["realDelays"]
                this.StartRecording(mode, opts)

            case "stopRecording":
                this.StopRecording()

            case "testMacro":
                if (req.Has("macro")) {
                    this.HandleTestMacro(req["macro"])
                }

            case "saveDiagramPoints":
                if (req.Has("points")) {
                    this.SaveDiagramPoints(req["points"])
                    this.PostMessage(Map(
                        "type", "diagramPointsSaved",
                        "success", true
                    ))
                    OSD.Show("Pointer Calibration", "Saved pointer coordinates to settings.ini")
                }

            case "resetDiagramPoints":
                this.ResetDiagramPoints()
                this.PostMessage(Map(
                    "type", "diagramPointsReset",
                    "diagramPoints", this.LoadDiagramPoints()
                ))
                OSD.Show("Pointer Calibration", "Restored default pointer coordinates")
        }
    }

    static SendInitialState() {
        try {
            this.Log("SendInitialState: gathering mappings and profiles...")
            mappings := this.ExportAllMappings()
            diagPoints := this.LoadDiagramPoints()

            profilesList := []
            for p in ProfileEngine.Profiles {
                meta := ProfileEngine.ProfileMetadata.Has(p) ? ProfileEngine.ProfileMetadata[p] : { TargetExe: "", Icon: "generic", IsDefault: (p = "Desktop"), SwitchOnHover: false, Desc: p . " Profile" }
                profilesList.Push(Map(
                    "name", p,
                    "targetExe", meta.TargetExe,
                    "icon", meta.Icon,
                    "isDefault", meta.IsDefault ? true : false,
                    "switchOnHover", (meta.HasOwnProp("SwitchOnHover") && meta.SwitchOnHover) ? true : false,
                    "desc", meta.HasOwnProp("Desc") ? meta.Desc : p . " Profile"
                ))
            }

            this.Log("SendInitialState: mappings gathered, building stateObj...")
            stateObj := Map(
                "type", "initialState",
                "profile", ProfileEngine.CurrentProfile,
                "profiles", profilesList,
                "autoSwitch", ProfileEngine.AutoSwitchEnabled ? true : false,
                "lockedProfile", ProfileEngine.LockedProfile,
                "rapidFire", ProfileEngine.RapidFireEnabled ? true : false,
                "alwaysOnTop", this.IsAlwaysOnTop ? true : false,
                "showOSD", OSD.Enabled ? true : false,
                "mappings", mappings,
                "hardwareFKeys", ProfileEngine.GetHardwareFKeysExport(),
                "diagramPoints", diagPoints
            )
            this.Log("SendInitialState: calling PostMessage...")
            this.PostMessage(stateObj)
            this.Log("SendInitialState: done!")
        } catch as err {
            this.Log("Error in SendInitialState: " . err.Message . " in line " . err.Line)
        }
    }

    static SendProfilesUpdated() {
        profilesList := []
        for p in ProfileEngine.Profiles {
            meta := ProfileEngine.ProfileMetadata.Has(p) ? ProfileEngine.ProfileMetadata[p] : { TargetExe: "", Icon: "generic", IsDefault: (p = "Desktop"), SwitchOnHover: false, Desc: p . " Profile" }
            profilesList.Push(Map(
                "name", p,
                "targetExe", meta.TargetExe,
                "icon", meta.Icon,
                "isDefault", meta.IsDefault ? true : false,
                "switchOnHover", (meta.HasOwnProp("SwitchOnHover") && meta.SwitchOnHover) ? true : false,
                "desc", meta.HasOwnProp("Desc") ? meta.Desc : p . " Profile"
            ))
        }
        this.PostMessage(Map(
            "type", "profilesUpdated",
            "profiles", profilesList,
            "currentProfile", ProfileEngine.CurrentProfile,
            "mappings", this.ExportAllMappings()
        ))
    }

    static HandleSaveMapping(req) {
        if (!req.Has("profile") || !req.Has("btnId") || !req.Has("layer") || !req.Has("actionObj"))
            return

        profile := req["profile"]
        btnId := req["btnId"]
        layer := req["layer"]
        rawObj := req["actionObj"]

        ; Normalize action object
        action := {
            Type: rawObj.Has("Type") ? rawObj["Type"] : "Send",
            Cmd: rawObj.Has("Cmd") ? rawObj["Cmd"] : "",
            Label: rawObj.Has("Label") ? rawObj["Label"] : "",
            PlayType: rawObj.Has("PlayType") ? rawObj["PlayType"] : "NoRepeat",
            RepeatInterval: rawObj.Has("RepeatInterval") ? Integer(rawObj["RepeatInterval"]) : 50,
            Steps: this.NormalizeSteps(rawObj.Get("Steps", [])),
            SeqPress: this.NormalizeSteps(rawObj.Get("SeqPress", [])),
            SeqHold: this.NormalizeSteps(rawObj.Get("SeqHold", [])),
            SeqRelease: this.NormalizeSteps(rawObj.Get("SeqRelease", []))
        }

        ProfileEngine.SaveButtonLayer(profile, btnId, layer, action)

        ; Send confirmation
        currMap := ProfileEngine.GetButtonMapping(profile, btnId)
        this.PostMessage(Map(
            "type", "mappingSaved",
            "profile", profile,
            "btnId", btnId,
            "mapping", this.ExportButtonMapping(currMap)
        ))
    }

    static HandleResetButtonDefault(req) {
        if (!req.Has("profile") || !req.Has("btnId"))
            return

        profile := req["profile"]
        btnId := req["btnId"]
        layer := req.Has("layer") ? req["layer"] : "Normal"

        defProfile := ProfileEngine.DefaultMappings.Has(profile) ? profile : "Desktop"
        if (ProfileEngine.DefaultMappings.Has(defProfile) && ProfileEngine.DefaultMappings[defProfile].Has(btnId)) {
            def := ProfileEngine.DefaultMappings[defProfile][btnId]

            if (layer = "GShift" || layer = "GShift1") {
                ProfileEngine.SaveButtonLayer(profile, btnId, "GShift", def.GShift.Clone())
            } else if (layer = "GShift2") {
                ProfileEngine.SaveButtonLayer(profile, btnId, "GShift2", def.Normal.Clone())
            } else {
                ; Default / Normal layer or full reset: restore baseline defaults across layers
                ProfileEngine.SaveButtonMapping(profile, btnId, def.Normal.Clone(), def.GShift.Clone(), def.Normal.Clone())
            }

            currMap := ProfileEngine.GetButtonMapping(profile, btnId)
            this.PostMessage(Map(
                "type", "mappingSaved",
                "profile", profile,
                "btnId", btnId,
                "mapping", this.ExportButtonMapping(currMap)
            ))
            OSD.Show("Reset to Default", btnId . " on " . profile)
        }
    }

    static HandleTestMacro(macroObj) {
        try {
            action := {
                Type: "Macro",
                Cmd: "Macro",
                Label: "Test Playback",
                PlayType: macroObj.Has("PlayType") ? macroObj["PlayType"] : "NoRepeat",
                RepeatInterval: macroObj.Has("RepeatInterval") ? Integer(macroObj["RepeatInterval"]) : 50,
                Steps: this.NormalizeSteps(macroObj.Get("Steps", [])),
                SeqPress: this.NormalizeSteps(macroObj.Get("SeqPress", [])),
                SeqHold: this.NormalizeSteps(macroObj.Get("SeqHold", [])),
                SeqRelease: this.NormalizeSteps(macroObj.Get("SeqRelease", []))
            }
            ProfileEngine.ExecuteAction(action)
        }
    }

    static ToggleAlwaysOnTop() {
        this.SetAlwaysOnTop(!this.IsAlwaysOnTop)
        OSD.Show("Always on Top", this.IsAlwaysOnTop ? "Enabled (Pinned)" : "Disabled (Unpinned)")
    }

    ; =========================================================================
    ; HARDWARE-LEVEL KEY & COMBINATION RECORDER (Suppresses all OS/Shell hotkeys)
    ; =========================================================================
    static IsRecordingActive := false
    static RecordingMode := ""
    static RecorderHook := ""
    static RecKeysDown := Map()
    static RecModifiers := Map()
    static RecCapturedResult := ""
    static RecMacroActiveKeys := Map()
    static RecMacroLastTime := 0
    static RecMacroDefDelay := 50
    static RecMacroRealDelays := false
    static FocusWatchdogFn := ObjBindMethod(WebViewGuiManager, "CheckRecordingFocus")
    static ReleaseSafetyFn := ObjBindMethod(WebViewGuiManager, "ForceReleaseRecordedHook")

    static IsRecording() {
        return this.IsRecordingActive
    }

    static StartRecording(mode := "single", options := "") {
        this.StopRecording()

        ; Ensure the Studio window is focused
        if (!this.MainGui || !WinExist(this.MainGui.Hwnd) || !WinActive("ahk_id " . this.MainGui.Hwnd))
            return

        this.IsRecordingActive := true
        this.RecordingMode := mode
        this.RecKeysDown.Clear()
        this.RecModifiers.Clear()
        this.RecCapturedResult := ""
        this.RecMacroActiveKeys.Clear()
        this.RecMacroLastTime := A_TickCount

        if (IsObject(options)) {
            if (options.Has("defDelay"))
                this.RecMacroDefDelay := Integer(options["defDelay"])
            if (options.Has("realDelays"))
                this.RecMacroRealDelays := !!options["realDelays"]
        }

        ; Low-level keyboard hook with +S (Suppress) and +N (Notify)
        ; Prevents Windows shell (Win+D, Win+E, Win+Tab, Start Menu, etc.) from executing!
        ih := InputHook("I0")
        ih.KeyOpt("{All}", "+S +N")
        ih.VisibleNonText := false

        if (mode = "macro") {
            ih.OnKeyDown := (hook, vk, sc) => this.OnMacroKeyDown(vk, sc)
            ih.OnKeyUp   := (hook, vk, sc) => this.OnMacroKeyUp(vk, sc)
        } else {
            ih.OnKeyDown := (hook, vk, sc) => this.OnSingleKeyDown(vk, sc)
            ih.OnKeyUp   := (hook, vk, sc) => this.OnSingleKeyUp(vk, sc)
        }

        this.RecorderHook := ih
        ih.Start()

        ; Focus watchdog: automatically deactivates hook if user clicks away or switches apps
        fnWatchdog := this.FocusWatchdogFn
        SetTimer(fnWatchdog, 100)
    }

    static StopRecording() {
        fnWatchdog := this.FocusWatchdogFn
        SetTimer(fnWatchdog, 0)
        fnSafety := this.ReleaseSafetyFn
        SetTimer(fnSafety, 0)

        if (this.RecorderHook != "") {
            try this.RecorderHook.Stop()
            this.RecorderHook := ""
        }

        this.IsRecordingActive := false
        this.RecordingMode := ""
        this.RecKeysDown.Clear()
        this.RecModifiers.Clear()
        this.RecCapturedResult := ""
        this.RecMacroActiveKeys.Clear()
    }

    static CheckRecordingFocus() {
        if (!this.IsRecordingActive) {
            fnWatchdog := this.FocusWatchdogFn
            SetTimer(fnWatchdog, 0)
            return
        }

        if (!this.MainGui || !WinExist(this.MainGui.Hwnd) || !WinActive("ahk_id " . this.MainGui.Hwnd)) {
            this.StopRecording()
            this.PostMessage(Map("type", "cancelRecording", "reason", "lostFocus"))
        }
    }

    static NormalizeKey(vk, sc) {
        kName := GetKeyName(Format("vk{:02x}sc{:03x}", vk, sc))
        if (kName = "")
            return ""

        switch kName {
            case "Control", "Ctrl", "LCtrl", "RCtrl": return "Ctrl"
            case "Shift", "LShift", "RShift":         return "Shift"
            case "Alt", "LAlt", "RAlt":               return "Alt"
            case "LWin", "RWin":                     return "Win"
        }

        switch kName {
            case "Escape":     return "Escape"
            case "Space":      return "Space"
            case "Tab":        return "Tab"
            case "Enter":      return "Enter"
            case "Backspace":  return "Backspace"
            case "Delete":     return "Delete"
            case "Insert":     return "Insert"
            case "Home":       return "Home"
            case "End":        return "End"
            case "PgUp":       return "PgUp"
            case "PgDn":       return "PgDn"
            case "Up":         return "Up"
            case "Down":       return "Down"
            case "Left":       return "Left"
            case "Right":      return "Right"
        }

        return kName
    }

    static OnSingleKeyDown(vk, sc) {
        if (!this.IsRecordingActive || !this.MainGui || !WinExist(this.MainGui.Hwnd) || !WinActive("ahk_id " . this.MainGui.Hwnd)) {
            this.StopRecording()
            return
        }

        kName := this.NormalizeKey(vk, sc)
        if (kName = "")
            return

        ; If a combo was already captured and we're waiting for key release, ignore further downs
        if (this.RecCapturedResult != "")
            return

        this.RecKeysDown[kName] := true

        ; If modifier pressed
        if (kName = "Ctrl" || kName = "Alt" || kName = "Shift" || kName = "Win") {
            this.RecModifiers[kName] := true
            this.PostMessage(Map(
                "type", "modifierStateChanged",
                "ctrl", this.RecModifiers.Has("Ctrl") ? true : false,
                "alt", this.RecModifiers.Has("Alt") ? true : false,
                "shift", this.RecModifiers.Has("Shift") ? true : false,
                "win", this.RecModifiers.Has("Win") ? true : false
            ))
            this.PostMessage(Map(
                "type", "liveKeyPreview",
                "preview", this.BuildModifierPreview()
            ))
            return
        }

        ; If Escape pressed alone with no modifiers, cancel recording
        if (kName = "Escape" && this.RecModifiers.Count = 0) {
            this.StopRecording()
            this.PostMessage(Map("type", "cancelRecording", "reason", "escape"))
            return
        }

        ; Non-modifier key pressed! Build combination
        mods := this.RecModifiers.Clone()
        if (GetKeyState("Ctrl", "P") && !mods.Has("Ctrl"))
            mods["Ctrl"] := true
        if (GetKeyState("Alt", "P") && !mods.Has("Alt"))
            mods["Alt"] := true
        if (GetKeyState("Shift", "P") && !mods.Has("Shift"))
            mods["Shift"] := true
        if ((GetKeyState("LWin", "P") || GetKeyState("RWin", "P")) && !mods.Has("Win"))
            mods["Win"] := true

        res := this.BuildSingleCombo(mods, kName)
        this.RecCapturedResult := res

        this.PostMessage(Map(
            "type", "singleKeyRecorded",
            "ahkCmd", res.Cmd,
            "niceLabel", res.Label
        ))

        ; Fallback safety timer: stop hook after 500ms even if keyup is somehow not triggered
        fnSafety := this.ReleaseSafetyFn
        SetTimer(fnSafety, -500)
    }

    static OnSingleKeyUp(vk, sc) {
        kName := this.NormalizeKey(vk, sc)
        if (kName != "") {
            if (this.RecKeysDown.Has(kName))
                this.RecKeysDown.Delete(kName)
            if (this.RecModifiers.Has(kName)) {
                this.RecModifiers.Delete(kName)
                this.PostMessage(Map(
                    "type", "modifierStateChanged",
                    "ctrl", this.RecModifiers.Has("Ctrl") ? true : false,
                    "alt", this.RecModifiers.Has("Alt") ? true : false,
                    "shift", this.RecModifiers.Has("Shift") ? true : false,
                    "win", this.RecModifiers.Has("Win") ? true : false
                ))
                if (this.RecCapturedResult = "") {
                    this.PostMessage(Map(
                        "type", "liveKeyPreview",
                        "preview", this.BuildModifierPreview()
                    ))
                }
            }
        }

        ; When all keys are physically released, safely stop the hook
        if (this.RecCapturedResult != "" && this.RecKeysDown.Count = 0) {
            this.StopRecording()
        }
    }

    static ForceReleaseRecordedHook() {
        if (this.RecCapturedResult != "") {
            this.StopRecording()
        }
    }

    static BuildSingleCombo(mods, keyName) {
        prefix := ""
        lbl := ""
        if (mods.Has("Ctrl")) {
            prefix .= "^"
            lbl .= "Ctrl + "
        }
        if (mods.Has("Alt")) {
            prefix .= "!"
            lbl .= "Alt + "
        }
        if (mods.Has("Shift")) {
            prefix .= "+"
            lbl .= "Shift + "
        }
        if (mods.Has("Win")) {
            prefix .= "#"
            lbl .= "Win + "
        }

        niceKey := (StrLen(keyName) = 1) ? StrUpper(keyName) : keyName
        ahkKey := (StrLen(keyName) = 1) ? StrLower(keyName) : keyName

        cmd := prefix . "{" . ahkKey . "}"
        lbl := lbl . niceKey
        return { Cmd: cmd, Label: lbl }
    }

    static BuildModifierPreview() {
        lbl := ""
        if (this.RecModifiers.Has("Ctrl"))
            lbl .= "Ctrl + "
        if (this.RecModifiers.Has("Alt"))
            lbl .= "Alt + "
        if (this.RecModifiers.Has("Shift"))
            lbl .= "Shift + "
        if (this.RecModifiers.Has("Win"))
            lbl .= "Win + "
        return (lbl != "") ? (lbl . "...") : ""
    }

    static OnMacroKeyDown(vk, sc) {
        if (!this.IsRecordingActive || !this.MainGui || !WinExist(this.MainGui.Hwnd) || !WinActive("ahk_id " . this.MainGui.Hwnd)) {
            this.StopRecording()
            return
        }

        kName := this.NormalizeKey(vk, sc)
        if (kName = "")
            return

        ; In macro mode, Escape alone stops recording
        if (kName = "Escape" && this.RecMacroActiveKeys.Count = 0) {
            this.StopRecording()
            this.PostMessage(Map("type", "macroRecordingStopped"))
            return
        }

        if (this.RecMacroActiveKeys.Has(kName))
            return ; Ignore auto-repeat keydown

        tNow := A_TickCount
        del := (this.RecMacroRealDelays && this.RecMacroLastTime > 0) ? Max(10, tNow - this.RecMacroLastTime) : this.RecMacroDefDelay
        this.RecMacroLastTime := tNow
        this.RecMacroActiveKeys[kName] := tNow

        ahkKey := (StrLen(kName) = 1) ? StrLower(kName) : ((kName = "Win") ? "LWin" : kName)

        this.PostMessage(Map(
            "type", "macroStepRecorded",
            "action", "Down",
            "key", ahkKey,
            "delay", del
        ))
    }

    static OnMacroKeyUp(vk, sc) {
        if (!this.IsRecordingActive || !this.MainGui || !WinExist(this.MainGui.Hwnd))
            return

        kName := this.NormalizeKey(vk, sc)
        if (kName = "")
            return

        tNow := A_TickCount
        del := this.RecMacroDefDelay
        if (this.RecMacroActiveKeys.Has(kName)) {
            tDown := this.RecMacroActiveKeys[kName]
            del := this.RecMacroRealDelays ? Max(10, tNow - tDown) : this.RecMacroDefDelay
            this.RecMacroActiveKeys.Delete(kName)
        }
        this.RecMacroLastTime := tNow

        ahkKey := (StrLen(kName) = 1) ? StrLower(kName) : ((kName = "Win") ? "LWin" : kName)

        this.PostMessage(Map(
            "type", "macroStepRecorded",
            "action", "Up",
            "key", ahkKey,
            "delay", del
        ))
    }

    static SetAlwaysOnTop(enable) {
        this.IsAlwaysOnTop := !!enable
        if (this.MainGui != "" && WinExist(this.MainGui.Hwnd)) {
            WinSetAlwaysOnTop(this.IsAlwaysOnTop ? 1 : 0, this.MainGui.Hwnd)
        }
        try {
            IniWrite(this.IsAlwaysOnTop ? "1" : "0", A_ScriptDir . "\settings.ini", "General", "AlwaysOnTop")
            if (this.IsAlwaysOnTop)
                A_TrayMenu.Check("Always on Top")
            else
                A_TrayMenu.Uncheck("Always on Top")
        }
    }

    ; =========================================================================
    ; DIAGRAM POINTER CALIBRATION
    ; =========================================================================
    static DefaultDiagramPoints := Map(
        "LeftClick",    Map("x", 268, "y", 88),
        "G8",           Map("x", 201, "y", 87),
        "G7",           Map("x", 242, "y", 126),
        "DpiShift",     Map("x", 270, "y", 264),
        "Forward",      Map("x", 287, "y", 229),
        "Back",         Map("x", 361, "y", 281),
        "RightClick",   Map("x", 388, "y", 88),
        "TiltLeft",     Map("x", 322, "y", 73),
        "WheelUp",      Map("x", 304, "y", 33),
        "Middle",       Map("x", 355, "y", 58),
        "WheelDown",    Map("x", 383, "y", 67),
        "TiltRight",    Map("x", 382, "y", 27),
        "ProfileCycle", Map("x", 444, "y", 105)
    )

    static LoadDiagramPoints() {
        iniPath := A_ScriptDir . "\settings.ini"
        out := Map()
        for btnId, defPt in this.DefaultDiagramPoints {
            xVal := defPt["x"]
            yVal := defPt["y"]
            try {
                xVal := Integer(IniRead(iniPath, "DiagramPoints", btnId . "_X", String(xVal)))
                yVal := Integer(IniRead(iniPath, "DiagramPoints", btnId . "_Y", String(yVal)))
            }
            out[btnId] := Map("x", xVal, "y", yVal)
        }
        return out
    }

    static SaveDiagramPoints(pointsMap) {
        iniPath := A_ScriptDir . "\settings.ini"
        try {
            for btnId, pt in pointsMap {
                if (IsObject(pt) && pt.Has("x") && pt.Has("y")) {
                    IniWrite(String(pt["x"]), iniPath, "DiagramPoints", btnId . "_X")
                    IniWrite(String(pt["y"]), iniPath, "DiagramPoints", btnId . "_Y")
                }
            }
        }
    }

    static ResetDiagramPoints() {
        iniPath := A_ScriptDir . "\settings.ini"
        try {
            for btnId, defPt in this.DefaultDiagramPoints {
                IniWrite(String(defPt["x"]), iniPath, "DiagramPoints", btnId . "_X")
                IniWrite(String(defPt["y"]), iniPath, "DiagramPoints", btnId . "_Y")
            }
        }
    }

    ; =========================================================================
    ; DATA NORMALIZATION & SERIALIZATION
    ; =========================================================================
    static ExportAllMappings() {
        out := Map()
        for profile, btnMap in ProfileEngine.ActiveMappings {
            profOut := Map()
            for btnId, mapping in btnMap {
                profOut[btnId] := this.ExportButtonMapping(mapping)
            }
            out[profile] := profOut
        }
        return out
    }

    static ExportButtonMapping(mapping) {
        return Map(
            "Normal", this.ExportAction(mapping.Normal),
            "GShift", this.ExportAction(mapping.GShift),
            "GShift2", mapping.HasOwnProp("GShift2") ? this.ExportAction(mapping.GShift2) : this.ExportAction(mapping.Normal)
        )
    }

    static ExportAction(act) {
        if (!IsObject(act))
            return Map("Type", "Default", "Cmd", "", "Label", "Default")

        out := Map(
            "Type", act.HasOwnProp("Type") ? act.Type : "Send",
            "Cmd", act.HasOwnProp("Cmd") ? act.Cmd : "",
            "Label", act.HasOwnProp("Label") ? act.Label : "",
            "PlayType", act.HasOwnProp("PlayType") ? act.PlayType : "NoRepeat",
            "RepeatInterval", act.HasOwnProp("RepeatInterval") ? act.RepeatInterval : 50
        )
        if (act.HasOwnProp("Steps") && IsObject(act.Steps) && act.Steps.Length > 0)
            out["Steps"] := this.ExportSteps(act.Steps)
        if (act.HasOwnProp("SeqPress") && IsObject(act.SeqPress) && act.SeqPress.Length > 0)
            out["SeqPress"] := this.ExportSteps(act.SeqPress)
        if (act.HasOwnProp("SeqHold") && IsObject(act.SeqHold) && act.SeqHold.Length > 0)
            out["SeqHold"] := this.ExportSteps(act.SeqHold)
        if (act.HasOwnProp("SeqRelease") && IsObject(act.SeqRelease) && act.SeqRelease.Length > 0)
            out["SeqRelease"] := this.ExportSteps(act.SeqRelease)

        return out
    }

    static ExportSteps(steps) {
        out := []
        if (!IsObject(steps))
            return out
        for s in steps {
            out.Push(Map(
                "Action", s.HasOwnProp("Action") ? s.Action : "Down",
                "Key", s.HasOwnProp("Key") ? s.Key : "",
                "Delay", s.HasOwnProp("Delay") ? s.Delay : 50
            ))
        }
        return out
    }

    static NormalizeSteps(rawList) {
        out := []
        if (!IsObject(rawList))
            return out
        for s in rawList {
            act := s.Has("Action") ? s["Action"] : "Down"
            key := s.Has("Key") ? s["Key"] : ""
            del := s.Has("Delay") ? Integer(s["Delay"]) : 50
            out.Push({ Action: act, Key: key, Delay: del })
        }
        return out
    }

    ; =========================================================================
    ; OUTBOUND IPC TO WEBVIEW2
    ; =========================================================================
    static PostMessage(obj) {
        try {
            jsonStr := JSON.stringify(obj)
            this.Log("PostMessage: " . SubStr(jsonStr, 1, 80) . "... (len=" . StrLen(jsonStr) . ")")
            if (this.wv != "") {
                this.wv.PostWebMessageAsString(jsonStr)
                return
            }
            this.PendingMessages.Push(jsonStr)
        } catch as err {
            this.Log("Error in PostMessage: " . err.Message)
        }
    }

    static FlushPendingMessages() {
        if (this.wv == "")
            return
        while (this.PendingMessages.Length > 0) {
            msg := this.PendingMessages.RemoveAt(1)
            try {
                this.wv.PostWebMessageAsString(msg)
            }
        }
    }

    ; =========================================================================
    ; HARDWARE & ENGINE EVENT HANDLERS
    ; =========================================================================
    static OnProfileChangedHandler(profileName) {
        this.PostMessage(Map(
            "type", "profileChanged",
            "profile", profileName,
            "mappings", this.ExportAllMappings().Get(profileName, Map())
        ))
    }

    static OnButtonStateChangedHandler(btnId, isDown) {
        if (btnId = "WheelUp" || btnId = "WheelDown")
            return
        this.PostMessage(Map(
            "type", "buttonStateChanged",
            "btnId", btnId,
            "isDown", isDown ? true : false
        ))
    }

    static OnShiftStateChangedHandler(isActive, shiftName) {
        this.PostMessage(Map(
            "type", "shiftStateChanged",
            "isShift", isActive ? true : false,
            "shiftName", shiftName
        ))
    }

    static SetWindowIcon(hwnd) {
        if (!hwnd || !WinExist(hwnd))
            return
        iconPath := A_ScriptDir . "\assets\app.ico"
        if FileExist(iconPath) {
            try TraySetIcon(iconPath)
            try {
                hIconSmall := LoadPicture(iconPath, "w16 h16 Icon1", &imgType1)
                hIconBig := LoadPicture(iconPath, "w32 h32 Icon1", &imgType2)
                if (hIconSmall)
                    SendMessage(0x0080, 0, hIconSmall, hwnd) ; WM_SETICON, ICON_SMALL
                if (hIconBig)
                    SendMessage(0x0080, 1, hIconBig, hwnd)   ; WM_SETICON, ICON_BIG
            }
        }
    }

    static ApplyThemeToTitleBar(hwnd) {
        if (!hwnd || !WinExist(hwnd))
            return
        try {
            ; DWMWA_USE_IMMERSIVE_DARK_MODE: 20 (Windows 11 / Windows 10 20H1+), 19 (older Win10)
            darkMode := Buffer(4, 0)
            NumPut("Int", 1, darkMode)
            if (DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 20, "Ptr", darkMode, "UInt", 4) != 0) {
                DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 19, "Ptr", darkMode, "UInt", 4)
            }

            ; DWMWA_CAPTION_COLOR: 35 (Windows 11) - Set background to match app header #10121c (BGR 0x1c1210)
            captionColor := Buffer(4, 0)
            NumPut("UInt", 0x1c1210, captionColor)
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 35, "Ptr", captionColor, "UInt", 4)

            ; DWMWA_TEXT_COLOR: 36 (Windows 11) - Set caption text to match #e6eaf8 (BGR 0xf8eae6)
            textColor := Buffer(4, 0)
            NumPut("UInt", 0xf8eae6, textColor)
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 36, "Ptr", textColor, "UInt", 4)

            ; DWMWA_BORDER_COLOR: 34 (Windows 11) - Set subtle border #222638 (BGR 0x382622)
            borderColor := Buffer(4, 0)
            NumPut("UInt", 0x382622, borderColor)
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 34, "Ptr", borderColor, "UInt", 4)
        }
    }
}
