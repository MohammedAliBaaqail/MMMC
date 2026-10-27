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

        ; Clean any orphaned WebView2 renderer processes from prior runs asynchronously
        SetTimer(() => this.CleanOrphanedProcesses(), -1500)

        ; Create GUI with minimum dimensions (1060px width, 680px height) and enable MaximizeBox
        opt := "+Resize +MaximizeBox +MinSize1060x680 " . (this.IsAlwaysOnTop ? "+AlwaysOnTop" : "-AlwaysOnTop")
        g := Gui(opt, "My Mouse My Choice")
        g.BackColor := "0b0d14"
        g.MarginX := 0
        g.MarginY := 0
        this.MainGui := g

        ; Register OS-level minimum window tracking limit (WM_GETMINMAXINFO)
        OnMessage(0x0024, (wParam, lParam, msg, hwnd) => WebViewGuiManager.OnGetMinMaxInfo(lParam, hwnd))

        ; Set custom app icon (16x16 caption, 32x32 taskbar)
        this.SetWindowIcon(g.Hwnd)

        ; Apply immersive dark mode and theme matching colors to the title bar
        this.ApplyThemeToTitleBar(g.Hwnd)

        ; Sizing & window events
        g.OnEvent("Size", (guiObj, minMax, w, h) => WebViewGuiManager.OnSize(minMax, w, h))
        g.OnEvent("Close", (*) => (WebViewGuiManager.SaveWindowGeometry(), WebViewGuiManager.StopRecording(), g.Hide()))
        g.OnEvent("Escape", (*) => (WebViewGuiManager.IsRecordingActive ? "" : (WebViewGuiManager.SaveWindowGeometry(), WebViewGuiManager.StopRecording(), g.Hide())))

        ; Load saved window geometry from settings.ini
        savedW := 1360
        savedH := 840
        savedX := ""
        savedY := ""
        savedMax := 0
        try {
            savedW := Integer(IniRead(iniPath, "General", "WindowWidth", "1360"))
            savedH := Integer(IniRead(iniPath, "General", "WindowHeight", "840"))
            savedX := IniRead(iniPath, "General", "WindowX", "")
            savedY := IniRead(iniPath, "General", "WindowY", "")
            savedMax := Integer(IniRead(iniPath, "General", "WindowMaximized", "0"))
        } catch {
        }
        if (savedW < 1060)
            savedW := 1060
        if (savedH < 680)
            savedH := 680

        showOpt := "w" . savedW . " h" . savedH
        isValidPos := false
        if (savedX != "" && savedY != "" && IsNumber(savedX) && IsNumber(savedY)) {
            xVal := Integer(savedX)
            yVal := Integer(savedY)
            try {
                monCount := MonitorGetCount()
                Loop monCount {
                    MonitorGet(A_Index, &mLeft, &mTop, &mRight, &mBottom)
                    if (xVal + 100 >= mLeft && xVal <= mRight - 100 && yVal + 100 >= mTop && yVal <= mBottom - 100) {
                        isValidPos := true
                        break
                    }
                }
            } catch {
            }
            if (isValidPos)
                showOpt .= " x" . xVal . " y" . yVal
            else
                showOpt .= " Center"
        } else {
            showOpt .= " Center"
        }

        if (savedMax = 1) {
            showOpt .= " Maximize"
        }

        ; Display window
        g.Show(showOpt)
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
            settings.AreDefaultContextMenusEnabled := false
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

    static _saveGeometryTimer := () => WebViewGuiManager.SaveWindowGeometry()

    static OnSize(minMax, w, h) {
        if (minMax = -1) ; Minimized
            return
        if (this.wvc != "") {
            this.wvc.Fill()
        }
        if (minMax = 1) {
            ; Maximized
            try IniWrite(1, A_ScriptDir . "\settings.ini", "General", "WindowMaximized")
        } else if (minMax = 0) {
            ; Normal / Restored
            SetTimer(this._saveGeometryTimer, -500)
        }
    }

    static SaveWindowGeometry() {
        if (!this.MainGui || !WinExist(this.MainGui.Hwnd))
            return

        iniPath := A_ScriptDir . "\settings.ini"
        try {
            minMax := WinGetMinMax(this.MainGui.Hwnd)
            if (minMax = 1) {
                IniWrite(1, iniPath, "General", "WindowMaximized")
                return
            }
            if (minMax = -1) {
                return
            }

            this.MainGui.GetPos(&x, &y, &w, &h)
            if (w >= 1060 && h >= 680) {
                IniWrite(0, iniPath, "General", "WindowMaximized")
                IniWrite(w, iniPath, "General", "WindowWidth")
                IniWrite(h, iniPath, "General", "WindowHeight")
                IniWrite(x, iniPath, "General", "WindowX")
                IniWrite(y, iniPath, "General", "WindowY")
            }
        } catch {
        }
    }

    static LoadSidebarWidth() {
        iniPath := A_ScriptDir . "\settings.ini"
        try {
            val := Integer(IniRead(iniPath, "General", "SidebarWidth", "0"))
            if (val >= 260 && val <= 700)
                return val
        }
        return 0
    }

    static OnGetMinMaxInfo(lParam, hwnd) {
        if (this.MainGui && hwnd == this.MainGui.Hwnd) {
            ; Enforce physical window min track size (with DPI scaling)
            dpiScale := A_ScreenDPI / 96
            minW := Integer(1060 * dpiScale)
            minH := Integer(680 * dpiScale)
            NumPut("int", minW, lParam, 24) ; ptMinTrackSize.x
            NumPut("int", minH, lParam, 28) ; ptMinTrackSize.y
            return 0
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
            case "saveSidebarWidth":
                if (req.Has("width")) {
                    w := Integer(req["width"])
                    if (w >= 260 && w <= 700) {
                        try IniWrite(w, A_ScriptDir . "\settings.ini", "General", "SidebarWidth")
                    }
                }

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
                    pOsdIconOnly := req.Has("osdIconOnly") ? (req["osdIconOnly"] ? true : false) : false
                    if (ProfileEngine.AddProfile(pName, pExe, pIcon, pHover, pOsdIconOnly)) {
                        this.SendProfilesUpdated()
                        ProfileEngine.SetProfile(pName)
                        if (!pOsdIconOnly)
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
                    oldName := req.Has("oldName") ? req["oldName"] : pName
                    pExe := req.Has("targetExe") ? req["targetExe"] : ""
                    pIcon := req.Has("icon") ? req["icon"] : ""
                    pHover := req.Has("switchOnHover") ? (req["switchOnHover"] ? true : false) : -1
                    pOsdIconOnly := req.Has("osdIconOnly") ? (req["osdIconOnly"] ? true : false) : -1
                    if (ProfileEngine.UpdateProfile(pName, pExe, pIcon, pHover, pOsdIconOnly, oldName)) {
                        this.SendProfilesUpdated()
                        if (ProfileEngine.CurrentProfile == pName && pOsdIconOnly == 1) {
                            OSD.ShowIcon(ProfileEngine.GetProfileIconPath(pName))
                        } else {
                            OSD.Show("Profile Updated: " . pName, pExe != "" ? "App: " . pExe : "No Exe")
                        }
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

            case "toggleMuteWhenFocused":
                enabled := req.Has("enabled") ? req["enabled"] : !ProfileEngine.MuteWhenStudioFocused
                ProfileEngine.MuteWhenStudioFocused := enabled ? true : false
                IniWrite(ProfileEngine.MuteWhenStudioFocused ? "1" : "0", ProfileEngine.ConfigPath, "Settings", "MuteWhenFocused")
                this.PostMessage(Map("type", "muteWhenFocusedChanged", "enabled", ProfileEngine.MuteWhenStudioFocused ? true : false))
                if (OSD.Enabled) {
                    OSD.Show("Test in Focus: " . (ProfileEngine.MuteWhenStudioFocused ? "ACTIVE" : "OFF"), ProfileEngine.MuteWhenStudioFocused ? "Buttons highlight without executing actions" : "Normal button actions active")
                }

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

            case "setHardwareFKey":
                btnId := req.Has("btnId") ? req["btnId"] : ""
                fKey := req.Has("fkey") ? req["fkey"] : ""
                if (btnId != "" && ProfileEngine.SetHardwareFKey(btnId, fKey)) {
                    this.PostMessage(Map("type", "hardwareFKeysUpdated", "hardwareFKeys", ProfileEngine.GetHardwareFKeysExport()))
                    OSD.Show("F-Key Updated", btnId . " ➔ " . (fKey != "" ? fKey : "None"))
                }

            case "copySingleButtonMapping":
                fromProf := req.Has("fromProfile") ? req["fromProfile"] : (req.Has("profile") ? req["profile"] : ProfileEngine.CurrentProfile)
                toProf := req.Has("toProfile") ? req["toProfile"] : (req.Has("profile") ? req["profile"] : ProfileEngine.CurrentProfile)
                fId := req.Has("fromBtnId") ? req["fromBtnId"] : ""
                tId := req.Has("toBtnId") ? req["toBtnId"] : ""
                mappingObj := req.Has("mapping") ? req["mapping"] : ""
                if (fromProf != "" && toProf != "" && fId != "" && tId != "" && ProfileEngine.CopySingleButtonMapping(fromProf, toProf, fId, tId, mappingObj)) {
                    this.PostMessage(Map("type", "buttonMappingPasted", "profile", toProf, "toBtnId", tId, "mappings", this.ExportAllMappings()))
                    OSD.Show("Mapping Pasted", fId . " ➔ " . tId)
                }

            case "resetButtonDefault":
                this.HandleResetButtonDefault(req)

            case "resetProfileDefaults":
                this.HandleResetProfileDefaults(req)

            case "setButtonName":
                btnId := req.Has("btnId") ? req["btnId"] : ""
                customName := req.Has("name") ? Trim(req["name"]) : ""
                if (btnId != "") {
                    this.SaveButtonName(btnId, customName)
                    this.PostMessage(Map(
                        "type", "buttonNameUpdated",
                        "btnId", btnId,
                        "name", customName,
                        "buttonNames", this.LoadButtonNames()
                    ))
                    OSD.Show("Button Renamed", (customName != "" ? customName : btnId))
                }

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
                }
                if (req.Has("cardOffsets")) {
                    this.SaveCardOffsets(req["cardOffsets"])
                }
                if (req.Has("mouseOffset")) {
                    this.SaveMouseOffset(req["mouseOffset"])
                }
                this.PostMessage(Map(
                    "type", "diagramPointsSaved",
                    "success", true
                ))
                OSD.Show("Pointer & Card Calibration", "Saved coordinates & layout to settings.ini")

            case "resetDiagramPoints":
                this.ResetDiagramPoints()
                this.ResetCardOffsets()
                this.ResetMouseOffset()
                this.PostMessage(Map(
                    "type", "diagramPointsReset",
                    "diagramPoints", this.LoadDiagramPoints(),
                    "cardOffsets", Map(),
                    "mouseOffset", Map("x", 0, "y", 0)
                ))
                OSD.Show("Pointer & Card Calibration", "Restored default layout & coordinates")

            case "resetCardOffsets":
                this.ResetCardOffsets()
                this.PostMessage(Map(
                    "type", "cardOffsetsReset",
                    "cardOffsets", Map()
                ))

            case "saveMouseImage":
                if (req.Has("image")) {
                    savedPath := this.SaveMouseImage(req["image"])
                    this.PostMessage(Map(
                        "type", "mouseImageSaved",
                        "mouseImage", savedPath
                    ))
                    OSD.Show("Custom Mouse Image", "Saved custom mouse diagram image")
                }

            case "resetMouseImage":
                this.ResetMouseImage()
                this.PostMessage(Map(
                    "type", "mouseImageReset",
                    "mouseImage", ""
                ))
                OSD.Show("Mouse Image", "Restored default Logitech G502 X image")

            case "saveCustomButtons":
                if (req.Has("buttons")) {
                    ProfileEngine.SaveCustomButtons(req["buttons"])
                    this.PostMessage(Map(
                        "type", "customButtonsSaved",
                        "buttons", ProfileEngine.LoadCustomButtons()
                    ))
                    OSD.Show("Custom Buttons", "Saved mouse button layout")
                }

            case "deleteCustomButton":
                if (req.Has("btnId")) {
                    ProfileEngine.DeleteCustomButton(req["btnId"])
                    this.PostMessage(Map(
                        "type", "customButtonDeleted",
                        "btnId", req["btnId"]
                    ))
                    OSD.Show("Custom Button Deleted", req["btnId"] . " removed from layout")
                }

            case "resetCustomButtons":
                ProfileEngine.ResetCustomButtons()
                this.PostMessage(Map(
                    "type", "customButtonsReset"
                ))
                OSD.Show("Custom Buttons", "Restored factory default button layout")

            case "saveCustomMousePreset":
                if (req.Has("preset")) {
                    presets := this.SaveCustomMousePreset(req["preset"])
                    this.PostMessage(Map(
                        "type", "customMousePresetsUpdated",
                        "presets", presets
                    ))
                    OSD.Show("Mouse Preset Saved", "Saved new custom mouse option")
                }

            case "deleteCustomMousePreset":
                if (req.Has("presetId")) {
                    presets := this.DeleteCustomMousePreset(req["presetId"])
                    this.PostMessage(Map(
                        "type", "customMousePresetsUpdated",
                        "presets", presets
                    ))
                    OSD.Show("Mouse Preset Deleted", "Removed custom mouse option")
                }

            case "saveCustomActionPreset":
                if (req.Has("preset")) {
                    presets := this.SaveCustomActionPreset(req["preset"])
                    this.PostMessage(Map(
                        "type", "customActionPresetsUpdated",
                        "presets", presets
                    ))
                    OSD.Show("Preset Saved", "Added to Custom Presets in catalog")
                }

            case "deleteCustomActionPreset":
                if (req.Has("id")) {
                    presets := this.DeleteCustomActionPreset(req["id"])
                    this.PostMessage(Map(
                        "type", "customActionPresetsUpdated",
                        "presets", presets
                    ))
                    OSD.Show("Preset Deleted", "Removed from Custom Presets")
                }

            case "saveTextBlockPreset":
                if (req.Has("preset")) {
                    presets := this.SaveTextBlockPreset(req["preset"])
                    this.PostMessage(Map(
                        "type", "textBlockPresetsUpdated",
                        "presets", presets
                    ))
                    OSD.Show("Text Block Saved", "Added to Text Blocks in catalog")
                }

            case "deleteTextBlockPreset":
                if (req.Has("id")) {
                    presets := this.DeleteTextBlockPreset(req["id"])
                    this.PostMessage(Map(
                        "type", "textBlockPresetsUpdated",
                        "presets", presets
                    ))
                    OSD.Show("Text Block Deleted", "Removed from Text Blocks")
                }

            case "startQuickRemap":
                QuickRemap.Start()

            case "importFullBackup":
                backupData := req.Has("backup") ? req["backup"] : ""
                mode := req.Has("mode") ? req["mode"] : "replace"
                rawIni := req.Has("rawIni") ? req["rawIni"] : ""
                if (this.ImportFullBackup(backupData, mode, rawIni)) {
                    this.SendInitialState()
                    OSD.Show("Backup Restored", "All profiles, layouts & settings restored!")
                    this.PostMessage(Map("type", "backupImportSuccess", "message", "Configuration successfully imported"))
                } else {
                    this.PostMessage(Map("type", "backupImportFailed", "error", "Failed to restore backup file"))
                }

            case "exportBackupToFile":
                jsonContent := req.Has("jsonContent") ? req["jsonContent"] : ""
                defaultName := "MyMouseMyChoice_Backup_" . FormatTime(, "yyyy-MM-dd") . ".json"
                selectedFile := FileSelect("S16", defaultName, "Export Studio Backup", "JSON Files (*.json);;All Files (*.*)")
                if (selectedFile != "") {
                    if (!InStr(selectedFile, ".json"))
                        selectedFile .= ".json"
                    try FileDelete(selectedFile)
                    FileAppend(jsonContent, selectedFile, "UTF-8")
                    OSD.Show("Backup Exported", "Saved to " . selectedFile)
                    this.PostMessage(Map("type", "backupExported", "path", selectedFile))
                }

            case "browseBackupFile":
                selectedFile := FileSelect("3", "", "Select Backup File to Import", "Backup Files (*.json; *.ini);;JSON Files (*.json);;INI Files (*.ini);;All Files (*.*)")
                if (selectedFile != "" && FileExist(selectedFile)) {
                    content := FileRead(selectedFile, "UTF-8")
                    fileName := RegExReplace(selectedFile, "^.*[\\/]", "")
                    this.PostMessage(Map(
                        "type", "backupFileSelected",
                        "fileName", fileName,
                        "filePath", selectedFile,
                        "content", content
                    ))
                }
        }
    }

    static SendInitialState() {
        try {
            this.Log("SendInitialState: gathering mappings and profiles...")
            mappings := this.ExportAllMappings()
            diagPoints := this.LoadDiagramPoints()

            profilesList := []
            for p in ProfileEngine.Profiles {
                meta := ProfileEngine.ProfileMetadata.Has(p) ? ProfileEngine.ProfileMetadata[p] : { TargetExe: "", Icon: "generic", IsDefault: (p = "Desktop"), SwitchOnHover: false, OsdIconOnly: false, Desc: p . " Profile" }
                resolvedPath := ""
                if (meta.TargetExe != "") {
                    resolvedPath := ProfileEngine.ResolveExePath(meta.TargetExe)
                } else if (p = "Desktop" || meta.IsDefault) {
                    resolvedPath := A_WinDir . "\explorer.exe"
                }
                profilesList.Push(Map(
                    "name", p,
                    "targetExe", meta.TargetExe,
                    "exePath", resolvedPath,
                    "icon", meta.Icon,
                    "isDefault", meta.IsDefault ? true : false,
                    "switchOnHover", (meta.HasOwnProp("SwitchOnHover") && meta.SwitchOnHover) ? true : false,
                    "osdIconOnly", (meta.HasOwnProp("OsdIconOnly") && meta.OsdIconOnly) ? true : false,
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
                "muteWhenFocused", ProfileEngine.MuteWhenStudioFocused ? true : false,
                "mappings", mappings,
                "hardwareFKeys", ProfileEngine.GetHardwareFKeysExport(),
                "diagramPoints", diagPoints,
                "cardOffsets", this.LoadCardOffsets(),
                "mouseOffset", this.LoadMouseOffset(),
                "sidebarWidth", this.LoadSidebarWidth(),
                "buttonNames", this.LoadButtonNames(),
                "mouseImage", this.LoadMouseImage(),
                "customButtons", ProfileEngine.LoadCustomButtons(),
                "customMousePresets", this.LoadCustomMousePresets(),
                "customActionPresets", this.LoadCustomActionPresets(),
                "textBlockPresets", this.LoadTextBlockPresets(),
                "rawIni", FileExist(A_ScriptDir . "\settings.ini") ? FileRead(A_ScriptDir . "\settings.ini", "UTF-8") : ""
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
            meta := ProfileEngine.ProfileMetadata.Has(p) ? ProfileEngine.ProfileMetadata[p] : { TargetExe: "", Icon: "generic", IsDefault: (p = "Desktop"), SwitchOnHover: false, OsdIconOnly: false, Desc: p . " Profile" }
            resolvedPath := ""
            if (meta.TargetExe != "") {
                resolvedPath := ProfileEngine.ResolveExePath(meta.TargetExe)
            } else if (p = "Desktop" || meta.IsDefault) {
                resolvedPath := A_WinDir . "\explorer.exe"
            }
            profilesList.Push(Map(
                "name", p,
                "targetExe", meta.TargetExe,
                "exePath", resolvedPath,
                "icon", meta.Icon,
                "isDefault", meta.IsDefault ? true : false,
                "switchOnHover", (meta.HasOwnProp("SwitchOnHover") && meta.SwitchOnHover) ? true : false,
                "osdIconOnly", (meta.HasOwnProp("OsdIconOnly") && meta.OsdIconOnly) ? true : false,
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
        if (!ProfileEngine.DefaultMappings.Has(defProfile))
            defProfile := "Desktop"

        if (ProfileEngine.DefaultMappings.Has(defProfile) && ProfileEngine.DefaultMappings[defProfile].Has(btnId)) {
            def := ProfileEngine.DefaultMappings[defProfile][btnId]
            gs2 := def.HasOwnProp("GShift2") ? def.GShift2.Clone() : def.Normal.Clone()

            if (layer = "GShift" || layer = "GShift1") {
                ProfileEngine.SaveButtonLayer(profile, btnId, "GShift", def.GShift.Clone())
            } else if (layer = "GShift2") {
                ProfileEngine.SaveButtonLayer(profile, btnId, "GShift2", gs2)
            } else {
                ; Default / Normal layer or full reset: restore baseline defaults across layers
                ProfileEngine.SaveMapping(profile, btnId, def.Normal.Clone(), def.GShift.Clone(), gs2)
            }

            currMap := ProfileEngine.GetButtonMapping(profile, btnId)
            this.PostMessage(Map(
                "type", "buttonReset",
                "profile", profile,
                "btnId", btnId,
                "mapping", this.ExportButtonMapping(currMap)
            ))
            OSD.Show("Reset to Default", btnId . " on " . profile)
        }
    }

    static HandleResetProfileDefaults(req) {
        if (!req.Has("profile"))
            return

        profile := req["profile"]
        ProfileEngine.ResetProfileDefaults(profile)

        allMappings := this.ExportAllMappings()
        this.PostMessage(Map(
            "type", "profileReset",
            "profile", profile,
            "mappings", allMappings
        ))
        OSD.Show("Profile Reset", "All buttons reset on " . profile)
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
    static RecComboKeys := []
    static RecCapturedResult := ""
    static RecMacroActiveKeys := Map()
    static RecMacroLastTime := 0
    static RecMacroDefDelay := 50
    static RecMacroRealDelays := false
    static FocusWatchdogFn := ObjBindMethod(WebViewGuiManager, "CheckRecordingFocus")
    static ReleaseSafetyFn := ObjBindMethod(WebViewGuiManager, "ForceReleaseRecordedHook")
    static FinalizeComboFn := ObjBindMethod(WebViewGuiManager, "FinalizeSingleCombo")

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
        this.RecComboKeys := []
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
        fnFinalize := this.FinalizeComboFn
        SetTimer(fnFinalize, 0)

        if (this.RecorderHook != "") {
            try this.RecorderHook.Stop()
            this.RecorderHook := ""
        }

        this.IsRecordingActive := false
        this.RecordingMode := ""
        this.RecKeysDown.Clear()
        this.RecModifiers.Clear()
        this.RecComboKeys := []
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

    static IsStudioFocused() {
        if (!this.MainGui || !WinExist(this.MainGui.Hwnd)) {
            return false
        }
        if (WinActive("ahk_id " . this.MainGui.Hwnd)) {
            return true
        }
        try {
            activeHwnd := WinActive("A")
            if (activeHwnd) {
                rootHwnd := DllCall("GetAncestor", "Ptr", activeHwnd, "UInt", 2, "Ptr") ; GA_ROOT = 2
                if (rootHwnd = this.MainGui.Hwnd) {
                    return true
                }
            }
        }
        return false
    }

    static NormalizeKey(vk, sc) {
        ; 1. Hardware Virtual Key codes for letters A-Z (completely immune to Arabic/international layouts!)
        if (vk >= 0x41 && vk <= 0x5A)
            return Chr(vk)

        ; 2. Digits 0-9
        if (vk >= 0x30 && vk <= 0x39)
            return Chr(vk)

        ; 3. Numpad digits 0-9
        if (vk >= 0x60 && vk <= 0x69)
            return "Numpad" . (vk - 0x60)

        ; 4. Function keys F1 - F24
        if (vk >= 0x70 && vk <= 0x87)
            return "F" . (vk - 0x6F)

        ; 5. Specific virtual keys with standard English names
        switch vk {
            case 0x11, 0xA2, 0xA3: return "Ctrl"
            case 0x10, 0xA0, 0xA1: return "Shift"
            case 0x12, 0xA4, 0xA5: return "Alt"
            case 0x5B, 0x5C:       return "Win"
            case 0x1B:             return "Escape"
            case 0x20:             return "Space"
            case 0x09:             return "Tab"
            case 0x0D:             return "Enter"
            case 0x08:             return "Backspace"
            case 0x2E:             return "Delete"
            case 0x2D:             return "Insert"
            case 0x24:             return "Home"
            case 0x23:             return "End"
            case 0x21:             return "PgUp"
            case 0x22:             return "PgDn"
            case 0x26:             return "Up"
            case 0x28:             return "Down"
            case 0x25:             return "Left"
            case 0x27:             return "Right"
            case 0x14:             return "CapsLock"
            case 0x90:             return "NumLock"
            case 0x91:             return "ScrollLock"
            case 0x2C:             return "PrintScreen"
            case 0x13:             return "Pause"
            case 0x6A:             return "NumpadMult"
            case 0x6B:             return "NumpadAdd"
            case 0x6D:             return "NumpadSub"
            case 0x6E:             return "NumpadDot"
            case 0x6F:             return "NumpadDiv"
            case 0xBA:             return ";"
            case 0xBB:             return "="
            case 0xBC:             return ","
            case 0xBD:             return "-"
            case 0xBE:             return "."
            case 0xBF:             return "/"
            case 0xC0:             return "``"
            case 0xDB:             return "["
            case 0xDC:             return "\"
            case 0xDD:             return "]"
            case 0xDE:             return "'"
        }

        ; Fallback to GetKeyName
        kName := GetKeyName(Format("vk{:02x}sc{:03x}", vk, sc))
        if (kName = "")
            return ""

        switch kName {
            case "Control", "Ctrl", "LControl", "RControl", "LCtrl", "RCtrl": return "Ctrl"
            case "Shift", "LShift", "RShift":                                 return "Shift"
            case "Alt", "LAlt", "RAlt":                                       return "Alt"
            case "Win", "LWin", "RWin":                                       return "Win"
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

        ; Cancel any pending finalize debounce timer as user is actively typing keys
        fnFinalize := this.FinalizeComboFn
        SetTimer(fnFinalize, 0)

        this.RecKeysDown[kName] := true

        ; Check modifier keys vs regular keys
        if (kName = "Ctrl" || kName = "Alt" || kName = "Shift" || kName = "Win") {
            this.RecModifiers[kName] := true
        } else {
            ; Check if already in RecComboKeys
            hasKey := false
            for existing in this.RecComboKeys {
                if (existing = kName) {
                    hasKey := true
                    break
                }
            }
            if (!hasKey) {
                this.RecComboKeys.Push(kName)
            }
        }

        ; Sync physical modifier state
        if (GetKeyState("Ctrl", "P") && !this.RecModifiers.Has("Ctrl"))
            this.RecModifiers["Ctrl"] := true
        if (GetKeyState("Alt", "P") && !this.RecModifiers.Has("Alt"))
            this.RecModifiers["Alt"] := true
        if (GetKeyState("Shift", "P") && !this.RecModifiers.Has("Shift"))
            this.RecModifiers["Shift"] := true
        if ((GetKeyState("LWin", "P") || GetKeyState("RWin", "P")) && !this.RecModifiers.Has("Win"))
            this.RecModifiers["Win"] := true

        this.PostMessage(Map(
            "type", "modifierStateChanged",
            "ctrl", this.RecModifiers.Has("Ctrl") ? true : false,
            "alt", this.RecModifiers.Has("Alt") ? true : false,
            "shift", this.RecModifiers.Has("Shift") ? true : false,
            "win", this.RecModifiers.Has("Win") ? true : false
        ))

        res := this.BuildSingleCombo(this.RecModifiers, this.RecComboKeys)
        this.RecCapturedResult := res

        ; Real-time live preview update of all keys currently in combination
        this.PostMessage(Map(
            "type", "liveKeyPreview",
            "preview", res.Label,
            "ahkCmd", res.Cmd,
            "niceLabel", res.Label
        ))
    }

    static OnSingleKeyUp(vk, sc) {
        kName := this.NormalizeKey(vk, sc)
        if (kName = "")
            return

        if (this.RecKeysDown.Has(kName))
            this.RecKeysDown.Delete(kName)

        ; When all pressed keys are physically released, wait 200ms debounce
        ; If no further key is pressed within 200ms, finalize the recorded combination!
        if (this.RecKeysDown.Count = 0 && this.RecCapturedResult != "") {
            fnFinalize := this.FinalizeComboFn
            SetTimer(fnFinalize, -200)
        }
    }

    static FinalizeSingleCombo() {
        if (!this.IsRecordingActive || this.RecCapturedResult = "")
            return

        res := this.RecCapturedResult
        this.PostMessage(Map(
            "type", "singleKeyRecorded",
            "ahkCmd", res.Cmd,
            "niceLabel", res.Label
        ))

        this.StopRecording()
    }

    static ForceReleaseRecordedHook() {
        if (this.RecCapturedResult != "") {
            this.FinalizeSingleCombo()
        }
    }

    static BuildSingleCombo(mods, keys) {
        if (!IsObject(keys)) {
            keys := (keys != "") ? [keys] : []
        }

        prefix := ""
        lblParts := []

        if (mods.Has("Ctrl")) {
            prefix .= "^"
            lblParts.Push("Ctrl")
        }
        if (mods.Has("Alt")) {
            prefix .= "!"
            lblParts.Push("Alt")
        }
        if (mods.Has("Shift")) {
            prefix .= "+"
            lblParts.Push("Shift")
        }
        if (mods.Has("Win")) {
            prefix .= "#"
            lblParts.Push("Win")
        }

        cleanKeys := []
        for k in keys {
            if (k = "Ctrl" || k = "Alt" || k = "Shift" || k = "Win")
                continue

            niceKey := (StrLen(k) = 1) ? StrUpper(k) : k
            lblParts.Push(niceKey)

            ahkKey := (StrLen(k) = 1) ? StrLower(k) : k
            cleanKeys.Push(ahkKey)
        }

        if (cleanKeys.Length = 0) {
            if (lblParts.Length > 0) {
                lastMod := lblParts[lblParts.Length]
                return { Cmd: "{" . lastMod . "}", Label: this.JoinComboParts(lblParts) }
            }
            return { Cmd: "", Label: "" }
        }

        if (cleanKeys.Length = 1) {
            k := cleanKeys[1]
            cmd := prefix . "{" . k . "}"
            lbl := this.JoinComboParts(lblParts)
            return { Cmd: cmd, Label: lbl }
        }

        ; Multiple non-modifier keys in combination (e.g. W + D, or Shift + G + Enter)
        downSeq := ""
        upSeq := ""
        for k in cleanKeys {
            downSeq .= "{" . k . " down}"
            upSeq := "{" . k . " up}" . upSeq
        }

        cmd := "{Blind}" . prefix . downSeq . upSeq
        lbl := this.JoinComboParts(lblParts)
        return { Cmd: cmd, Label: lbl }
    }

    static JoinComboParts(parts) {
        res := ""
        for idx, p in parts {
            res .= (idx = 1 ? "" : " + ") . p
        }
        return res
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

        if (lbl != "") {
            if (this.RecModifiers.Count = 1) {
                firstMod := ""
                for k in this.RecModifiers {
                    firstMod := k
                    break
                }
                return "[ " . firstMod . " ] (Release to map alone, or press combo key)"
            }
            return lbl . "..."
        }
        return ""
    }

    static OnMacroKeyDown(vk, sc) {
        if (!this.IsRecordingActive || !this.MainGui || !WinExist(this.MainGui.Hwnd) || !WinActive("ahk_id " . this.MainGui.Hwnd)) {
            this.StopRecording()
            return
        }

        kName := this.NormalizeKey(vk, sc)
        if (kName = "")
            return

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
        "LeftClick",    Map("x", 213, "y", 25),
        "G8",           Map("x", 96, "y", 41),
        "G7",           Map("x", 178, "y", 128),
        "DpiShift",     Map("x", 166, "y", 251),
        "Forward",      Map("x", 213, "y", 218),
        "Back",         Map("x", 310, "y", 293),
        "RightClick",   Map("x", 414, "y", -33),
        "TiltLeft",     Map("x", 266, "y", -5),
        "WheelUp",      Map("x", 241, "y", -66),
        "Middle",       Map("x", 306, "y", -37),
        "WheelDown",    Map("x", 346, "y", -9),
        "TiltRight",    Map("x", 349, "y", -59),
        "ProfileCycle", Map("x", 406, "y", 34)
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

    static LoadCardOffsets() {
        iniPath := A_ScriptDir . "\settings.ini"
        out := Map()
        for btnId, defPt in this.DefaultDiagramPoints {
            try {
                xStr := IniRead(iniPath, "CardOffsets", btnId . "_X", "")
                yStr := IniRead(iniPath, "CardOffsets", btnId . "_Y", "")
                if (xStr != "" || yStr != "") {
                    out[btnId] := Map("x", (xStr != "" ? Integer(xStr) : 0), "y", (yStr != "" ? Integer(yStr) : 0))
                }
            }
        }
        return out
    }

    static SaveCardOffsets(offsetsMap) {
        iniPath := A_ScriptDir . "\settings.ini"
        try {
            for btnId, pt in offsetsMap {
                if (IsObject(pt) && pt.Has("x") && pt.Has("y")) {
                    IniWrite(String(pt["x"]), iniPath, "CardOffsets", btnId . "_X")
                    IniWrite(String(pt["y"]), iniPath, "CardOffsets", btnId . "_Y")
                }
            }
        } catch as err {
            this.Log("Error saving card offsets: " . err.Message)
        }
    }

    static ResetCardOffsets() {
        iniPath := A_ScriptDir . "\settings.ini"
        try {
            IniDelete(iniPath, "CardOffsets")
        }
    }

    static LoadMouseOffset() {
        iniPath := A_ScriptDir . "\settings.ini"
        try {
            xStr := IniRead(iniPath, "General", "MouseOffsetX", "0")
            yStr := IniRead(iniPath, "General", "MouseOffsetY", "0")
            return Map("x", (xStr != "" ? Integer(xStr) : 0), "y", (yStr != "" ? Integer(yStr) : 0))
        } catch {
            return Map("x", 0, "y", 0)
        }
    }

    static SaveMouseOffset(offsetMap) {
        iniPath := A_ScriptDir . "\settings.ini"
        try {
            if (IsObject(offsetMap) && offsetMap.Has("x") && offsetMap.Has("y")) {
                IniWrite(String(offsetMap["x"]), iniPath, "General", "MouseOffsetX")
                IniWrite(String(offsetMap["y"]), iniPath, "General", "MouseOffsetY")
            }
        } catch as err {
            this.Log("Error saving mouse offset: " . err.Message)
        }
    }

    static ResetMouseOffset() {
        iniPath := A_ScriptDir . "\settings.ini"
        try {
            IniDelete(iniPath, "General", "MouseOffsetX")
            IniDelete(iniPath, "General", "MouseOffsetY")
        }
    }

    static LoadButtonNames() {
        iniPath := A_ScriptDir . "\settings.ini"
        out := Map()
        for btnId, defPt in this.DefaultDiagramPoints {
            try {
                val := IniRead(iniPath, "ButtonNames", btnId, "")
                if (val != "")
                    out[btnId] := val
            }
        }
        return out
    }

    static SaveButtonName(btnId, customName) {
        iniPath := A_ScriptDir . "\settings.ini"
        try {
            if (customName = "") {
                try IniDelete(iniPath, "ButtonNames", btnId)
            } else {
                IniWrite(customName, iniPath, "ButtonNames", btnId)
            }
        } catch as err {
            this.Log("Error saving button name: " . err.Message)
        }
    }

    ; =========================================================================
    ; CUSTOM MOUSE IMAGE PERSISTENCE
    ; =========================================================================
    static LoadMouseImage() {
        iniPath := A_ScriptDir . "\settings.ini"
        try {
            img := IniRead(iniPath, "General", "MouseImage", "")
            return img
        }
        return ""
    }

    static SaveMouseImage(imgDataOrPath) {
        iniPath := A_ScriptDir . "\settings.ini"
        if (imgDataOrPath = "") {
            try IniDelete(iniPath, "General", "MouseImage")
            return ""
        }
        finalPath := imgDataOrPath
        ; If it's a base64 data URI, decode and save to assets/custom_mouse.png
        if (InStr(imgDataOrPath, "data:image/")) {
            assetsDir := A_ScriptDir . "\assets"
            if (!DirExist(assetsDir))
                try DirCreate(assetsDir)
            saveFile := assetsDir . "\custom_mouse.png"
            commaPos := InStr(imgDataOrPath, ",")
            if (commaPos) {
                b64 := SubStr(imgDataOrPath, commaPos + 1)
                this.WriteBase64ToFile(saveFile, b64)
                finalPath := "../assets/custom_mouse.png?t=" . A_TickCount
            }
        }
        try IniWrite(finalPath, iniPath, "General", "MouseImage")
        return finalPath
    }

    static ResetMouseImage() {
        iniPath := A_ScriptDir . "\settings.ini"
        try IniDelete(iniPath, "General", "MouseImage")
        customImgFile := A_ScriptDir . "\assets\custom_mouse.png"
        if (FileExist(customImgFile))
            try FileDelete(customImgFile)
    }

    static WriteBase64ToFile(filePath, b64String) {
        try {
            size := 0
            DllCall("crypt32\CryptStringToBinaryW", "Str", b64String, "UInt", StrLen(b64String), "UInt", 1, "Ptr", 0, "UInt*", &size, "Ptr", 0, "Ptr", 0)
            if (size > 0) {
                buf := Buffer(size)
                DllCall("crypt32\CryptStringToBinaryW", "Str", b64String, "UInt", StrLen(b64String), "UInt", 1, "Ptr", buf.Ptr, "UInt*", &size, "Ptr", 0, "Ptr", 0)
                fileObj := FileOpen(filePath, "w")
                fileObj.RawWrite(buf, size)
                fileObj.Close()
            }
        }
    }

    ; =========================================================================
    ; USER-DEFINED PERMANENT MOUSE PRESETS
    ; =========================================================================
    static LoadCustomMousePresets() {
        iniPath := A_ScriptDir . "\settings.ini"
        out := []
        try {
            listStr := IniRead(iniPath, "MousePresets", "List", "")
            if (listStr = "") {
                return out
            }
            pIds := StrSplit(listStr, ",")
            for _, pId in pIds {
                pId := Trim(pId)
                if (pId = "") {
                    continue
                }
                secName := "MousePreset_" . pId
                name := IniRead(iniPath, secName, "Name", pId)
                desc := IniRead(iniPath, secName, "Desc", "Custom mouse preset")
                badge := IniRead(iniPath, secName, "Badge", "Custom")
                image := IniRead(iniPath, secName, "Image", "")
                buttonsJson := IniRead(iniPath, secName, "Buttons", "")

                presetMap := Map(
                    "id", pId,
                    "name", name,
                    "desc", desc,
                    "badge", badge,
                    "image", image,
                    "isCustom", true
                )
                if (buttonsJson != "") {
                    try {
                        parsedBtns := JSON.parse(buttonsJson)
                        presetMap["buttons"] := parsedBtns
                    }
                }
                out.Push(presetMap)
            }
        } catch as err {
            this.Log("Error loading custom mouse presets: " . err.Message)
        }
        return out
    }

    static SaveCustomMousePreset(presetObj) {
        iniPath := A_ScriptDir . "\settings.ini"
        pId := presetObj.Has("id") && presetObj["id"] != "" ? presetObj["id"] : ("custom_" . A_TickCount)
        name := presetObj.Has("name") && presetObj["name"] != "" ? presetObj["name"] : "Custom Mouse"
        desc := presetObj.Has("desc") ? presetObj["desc"] : "Custom mouse model"
        badge := presetObj.Has("badge") ? presetObj["badge"] : "Custom"
        rawImg := presetObj.Has("image") ? presetObj["image"] : ""

        imgPath := rawImg
        if (InStr(rawImg, "data:image/")) {
            assetsDir := A_ScriptDir . "\assets"
            if (!DirExist(assetsDir)) {
                try DirCreate(assetsDir)
            }
            saveFile := assetsDir . "\" . pId . ".png"
            commaPos := InStr(rawImg, ",")
            if (commaPos) {
                b64 := SubStr(rawImg, commaPos + 1)
                this.WriteBase64ToFile(saveFile, b64)
                imgPath := "../assets/" . pId . ".png?t=" . A_TickCount
            }
        }

        secName := "MousePreset_" . pId
        try IniWrite(name, iniPath, secName, "Name")
        try IniWrite(desc, iniPath, secName, "Desc")
        try IniWrite(badge, iniPath, secName, "Badge")
        try IniWrite(imgPath, iniPath, secName, "Image")

        if (presetObj.Has("buttons") && IsObject(presetObj["buttons"])) {
            try {
                jsonBtns := JSON.stringify(presetObj["buttons"])
                IniWrite(jsonBtns, iniPath, secName, "Buttons")
            }
        }

        ; Update MousePresets List
        listStr := ""
        try listStr := IniRead(iniPath, "MousePresets", "List", "")
        pIds := StrSplit(listStr, ",")
        found := false
        for _, id in pIds {
            if (Trim(id) = pId) {
                found := true
                break
            }
        }
        if (!found) {
            newList := (listStr != "" ? listStr . "," : "") . pId
            try IniWrite(newList, iniPath, "MousePresets", "List")
        }

        ; Set as active mouse image
        try IniWrite(imgPath, iniPath, "General", "MouseImage")

        return this.LoadCustomMousePresets()
    }

    static DeleteCustomMousePreset(presetId) {
        iniPath := A_ScriptDir . "\settings.ini"
        try IniDelete(iniPath, "MousePreset_" . presetId)

        listStr := ""
        try listStr := IniRead(iniPath, "MousePresets", "List", "")
        pIds := StrSplit(listStr, ",")
        newList := ""
        for _, id in pIds {
            id := Trim(id)
            if (id != "" && id != presetId) {
                newList := (newList != "" ? (newList . ",") : "") . id
            }
        }
        try IniWrite(newList, iniPath, "MousePresets", "List")

        imgFile := A_ScriptDir . "\assets\" . presetId . ".png"
        if (FileExist(imgFile)) {
            try FileDelete(imgFile)
        }

        return this.LoadCustomMousePresets()
    }

    static LoadCustomActionPresets() {
        iniPath := A_ScriptDir . "\settings.ini"
        out := []
        try {
            listStr := IniRead(iniPath, "ActionPresets", "List", "")
            if (listStr = "") {
                return out
            }
            pIds := StrSplit(listStr, ",")
            for _, pId in pIds {
                pId := Trim(pId)
                if (pId = "") {
                    continue
                }
                secName := "ActionPreset_" . pId
                name := IniRead(iniPath, secName, "Name", pId)
                label := IniRead(iniPath, secName, "Label", name)
                type := IniRead(iniPath, secName, "Type", "Send")
                cmd := IniRead(iniPath, secName, "Cmd", "")
                playType := IniRead(iniPath, secName, "PlayType", "NoRepeat")
                repeatInterval := Integer(IniRead(iniPath, secName, "RepeatInterval", "50"))
                color := IniRead(iniPath, secName, "Color", "none")

                presetMap := Map(
                    "id", pId,
                    "name", name,
                    "label", label,
                    "type", type,
                    "cmd", cmd,
                    "playType", playType,
                    "repeatInterval", repeatInterval,
                    "color", color
                )

                for _, jsonKey in ["Steps", "SeqPress", "SeqHold", "SeqRelease"] {
                    lowerKey := StrLower(SubStr(jsonKey, 1, 1)) . SubStr(jsonKey, 2)
                    rawVal := IniRead(iniPath, secName, jsonKey, "")
                    val := []
                    if (rawVal != "") {
                        if (SubStr(rawVal, 1, 1) = "[") {
                            try val := JSON.parse(rawVal)
                        } else {
                            try val := ProfileEngine.DeserializeSteps(rawVal)
                        }
                    }
                    if (!IsObject(val))
                        val := []
                    exportVal := this.ExportSteps(val)
                    presetMap[jsonKey] := exportVal
                    presetMap[lowerKey] := exportVal
                }
                out.Push(presetMap)
            }
        } catch as err {
            this.Log("Error loading custom action presets: " . err.Message)
        }
        return out
    }

    static SaveCustomActionPreset(presetObj) {
        iniPath := A_ScriptDir . "\settings.ini"
        pId := presetObj.Has("id") && presetObj["id"] != "" ? presetObj["id"] : ("act_" . A_TickCount)
        name := presetObj.Has("name") && presetObj["name"] != "" ? presetObj["name"] : (presetObj.Has("label") ? presetObj["label"] : "Custom Preset")
        label := presetObj.Has("label") && presetObj["label"] != "" ? presetObj["label"] : name
        type := presetObj.Has("type") ? presetObj["type"] : (presetObj.Has("Type") ? presetObj["Type"] : "Send")
        cmd := presetObj.Has("cmd") ? presetObj["cmd"] : (presetObj.Has("Cmd") ? presetObj["Cmd"] : "")
        playType := presetObj.Has("playType") ? presetObj["playType"] : (presetObj.Has("PlayType") ? presetObj["PlayType"] : "NoRepeat")
        repeatInterval := presetObj.Has("repeatInterval") ? presetObj["repeatInterval"] : (presetObj.Has("RepeatInterval") ? presetObj["RepeatInterval"] : 50)
        color := presetObj.Has("color") ? presetObj["color"] : (presetObj.Has("Color") ? presetObj["Color"] : "none")

        secName := "ActionPreset_" . pId
        try IniWrite(name, iniPath, secName, "Name")
        try IniWrite(label, iniPath, secName, "Label")
        try IniWrite(type, iniPath, secName, "Type")
        try IniWrite(cmd, iniPath, secName, "Cmd")
        try IniWrite(playType, iniPath, secName, "PlayType")
        try IniWrite(String(repeatInterval), iniPath, secName, "RepeatInterval")
        try IniWrite(color, iniPath, secName, "Color")

        for _, jsonKey in ["Steps", "SeqPress", "SeqHold", "SeqRelease"] {
            lowerKey := StrLower(SubStr(jsonKey, 1, 1)) . SubStr(jsonKey, 2)
            stepsVal := ""
            if (presetObj.Has(jsonKey))
                stepsVal := presetObj[jsonKey]
            else if (presetObj.Has(lowerKey))
                stepsVal := presetObj[lowerKey]

            stepsStr := ""
            if (IsObject(stepsVal) && stepsVal.Length > 0) {
                stepsStr := ProfileEngine.SerializeSteps(stepsVal)
            } else if (Type(stepsVal) = "String" && stepsVal != "") {
                if (SubStr(Trim(stepsVal), 1, 1) = "[") {
                    try {
                        parsedObj := JSON.parse(stepsVal)
                        stepsStr := ProfileEngine.SerializeSteps(parsedObj)
                    } catch {
                        stepsStr := ""
                    }
                } else {
                    stepsStr := stepsVal
                }
            }
            try IniWrite(stepsStr, iniPath, secName, jsonKey)
        }

        ; Update ActionPresets List
        listStr := ""
        try listStr := IniRead(iniPath, "ActionPresets", "List", "")
        pIds := StrSplit(listStr, ",")
        found := false
        for _, id in pIds {
            if (Trim(id) = pId) {
                found := true
                break
            }
        }
        if (!found) {
            newList := (listStr != "" ? listStr . "," : "") . pId
            try IniWrite(newList, iniPath, "ActionPresets", "List")
        }

        return this.LoadCustomActionPresets()
    }

    static DeleteCustomActionPreset(presetId) {
        iniPath := A_ScriptDir . "\settings.ini"
        try IniDelete(iniPath, "ActionPreset_" . presetId)

        listStr := ""
        try listStr := IniRead(iniPath, "ActionPresets", "List", "")
        pIds := StrSplit(listStr, ",")
        newList := ""
        for _, id in pIds {
            id := Trim(id)
            if (id != "" && id != presetId) {
                newList := (newList != "" ? (newList . ",") : "") . id
            }
        }
        try IniWrite(newList, iniPath, "ActionPresets", "List")

        return this.LoadCustomActionPresets()
    }

    static LoadTextBlockPresets() {
        iniPath := A_ScriptDir . "\settings.ini"
        out := []
        try {
            listStr := IniRead(iniPath, "TextBlockPresets", "List", "")
            if (listStr = "") {
                return out
            }
            pIds := StrSplit(listStr, ",")
            for _, pId in pIds {
                pId := Trim(pId)
                if (pId = "") {
                    continue
                }
                secName := "TextBlockPreset_" . pId
                name := IniRead(iniPath, secName, "Name", pId)
                label := IniRead(iniPath, secName, "Label", name)
                text := IniRead(iniPath, secName, "Text", "")
                text := StrReplace(text, "\n", "`n")
                text := StrReplace(text, "\\", "\")

                presetMap := Map(
                    "id", pId,
                    "name", name,
                    "label", label,
                    "text", text,
                    "cmd", text,
                    "type", "Text"
                )
                out.Push(presetMap)
            }
        } catch as err {
            this.Log("Error loading text block presets: " . err.Message)
        }
        return out
    }

    static SaveTextBlockPreset(presetObj) {
        iniPath := A_ScriptDir . "\settings.ini"
        pId := presetObj.Has("id") && presetObj["id"] != "" ? presetObj["id"] : ("txt_" . A_TickCount)
        name := presetObj.Has("name") && presetObj["name"] != "" ? presetObj["name"] : (presetObj.Has("label") ? presetObj["label"] : "Text Block")
        label := presetObj.Has("label") && presetObj["label"] != "" ? presetObj["label"] : name
        text := presetObj.Has("text") ? presetObj["text"] : (presetObj.Has("cmd") ? presetObj["cmd"] : (presetObj.Has("Cmd") ? presetObj["Cmd"] : ""))

        savedText := StrReplace(text, "\", "\\")
        savedText := StrReplace(savedText, "`r`n", "\n")
        savedText := StrReplace(savedText, "`n", "\n")
        savedText := StrReplace(savedText, "`r", "\n")

        secName := "TextBlockPreset_" . pId
        try IniWrite(name, iniPath, secName, "Name")
        try IniWrite(label, iniPath, secName, "Label")
        try IniWrite(savedText, iniPath, secName, "Text")
        try IniWrite("Text", iniPath, secName, "Type")

        listStr := ""
        try listStr := IniRead(iniPath, "TextBlockPresets", "List", "")
        pIds := StrSplit(listStr, ",")
        found := false
        for _, id in pIds {
            if (Trim(id) = pId) {
                found := true
                break
            }
        }
        if (!found) {
            newList := (listStr != "" ? (listStr . ",") : "") . pId
            try IniWrite(newList, iniPath, "TextBlockPresets", "List")
        }

        return this.LoadTextBlockPresets()
    }

    static DeleteTextBlockPreset(presetId) {
        iniPath := A_ScriptDir . "\settings.ini"
        try IniDelete(iniPath, "TextBlockPreset_" . presetId)

        listStr := ""
        try listStr := IniRead(iniPath, "TextBlockPresets", "List", "")
        pIds := StrSplit(listStr, ",")
        newList := ""
        for _, id in pIds {
            id := Trim(id)
            if (id != "" && id != presetId) {
                newList := (newList != "" ? (newList . ",") : "") . id
            }
        }
        try IniWrite(newList, iniPath, "TextBlockPresets", "List")

        return this.LoadTextBlockPresets()
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
            if (key != "") {
                out.Push(Map(
                    "Action", act,
                    "Key", key,
                    "Delay", del
                ))
            }
        }
        return out
    }

    static NormalizeSteps(rawList) {
        out := []
        if (!IsObject(rawList))
            return out
        for s in rawList {
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
            if (key != "") {
                out.Push({ Action: act, Key: key, Delay: del })
            }
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

    ; =========================================================================
    ; COMPLETE STUDIO BACKUP & RESTORE (IMPORT / EXPORT)
    ; =========================================================================
    static ImportFullBackup(backupObj, mode := "replace", rawIni := "") {
        iniPath := A_ScriptDir . "\settings.ini"

        ; Create safety backup of existing settings.ini before restoring
        try {
            if FileExist(iniPath) {
                FileCopy(iniPath, iniPath . ".bak", 1)
            }
        }

        ; If raw INI string is supplied, write directly
        if (rawIni != "" && (mode == "raw_ini" || (!IsObject(backupObj) || backupObj.Count == 0))) {
            try {
                if FileExist(iniPath) {
                    FileDelete(iniPath)
                }
                FileAppend(rawIni, iniPath, "UTF-8")
                ProfileEngine.Init(iniPath)
                return true
            } catch as err {
                this.Log("Error importing raw INI: " . err.Message)
                return false
            }
        }

        if (!IsObject(backupObj)) {
            return false
        }

        try {
            ; 1. General Settings
            if (backupObj.Has("general") && IsObject(backupObj["general"])) {
                gen := backupObj["general"]
                if (gen.Has("defaultProfile") && gen["defaultProfile"] != "") {
                    IniWrite(gen["defaultProfile"], iniPath, "General", "DefaultProfile")
                }
                if (gen.Has("alwaysOnTop")) {
                    IniWrite(gen["alwaysOnTop"] ? "1" : "0", iniPath, "General", "AlwaysOnTop")
                }
                if (gen.Has("mouseImage") && gen["mouseImage"] != "") {
                    IniWrite(gen["mouseImage"], iniPath, "General", "MouseImage")
                }
                if (gen.Has("showOSD")) {
                    IniWrite(gen["showOSD"] ? "1" : "0", iniPath, "Settings", "ShowOSD")
                }
                if (gen.Has("muteWhenFocused")) {
                    IniWrite(gen["muteWhenFocused"] ? "1" : "0", iniPath, "Settings", "MuteWhenFocused")
                }
                if (gen.Has("autoSwitch")) {
                    IniWrite(gen["autoSwitch"] ? "1" : "0", iniPath, "Profiles", "AutoSwitchEnabled")
                }
                if (gen.Has("lockedProfile")) {
                    IniWrite(gen["lockedProfile"], iniPath, "Profiles", "LockedProfile")
                }
            }

            ; 2. Profiles List & Metadata
            if (backupObj.Has("profiles") && IsObject(backupObj["profiles"])) {
                profs := backupObj["profiles"]
                existingProfsStr := IniRead(iniPath, "Profiles", "List", "")
                existingArr := StrSplit(existingProfsStr, ",")
                existingMap := Map()
                for _, p in existingArr {
                    pTrim := Trim(p)
                    if (pTrim != "") {
                        existingMap[pTrim] := true
                    }
                }

                importedList := []
                for _, p in profs {
                    pName := p.Has("name") ? Trim(p["name"]) : ""
                    if (pName = "") {
                        continue
                    }
                    importedList.Push(pName)
                    sec := "Profile_" . pName
                    if (p.Has("targetExe")) {
                        IniWrite(p["targetExe"], iniPath, sec, "TargetExe")
                    }
                    if (p.Has("icon")) {
                        IniWrite(p["icon"], iniPath, sec, "Icon")
                    }
                    if (p.Has("isDefault")) {
                        IniWrite(p["isDefault"] ? "1" : "0", iniPath, sec, "IsDefault")
                    }
                    if (p.Has("switchOnHover")) {
                        IniWrite(p["switchOnHover"] ? "1" : "0", iniPath, sec, "SwitchOnHover")
                    }
                    if (p.Has("osdIconOnly")) {
                        IniWrite(p["osdIconOnly"] ? "1" : "0", iniPath, sec, "OsdIconOnly")
                    }
                    if (p.Has("desc")) {
                        IniWrite(p["desc"], iniPath, sec, "Desc")
                    }
                }

                if (mode == "replace") {
                    listStr := ""
                    for idx, name in importedList {
                        listStr .= (idx = 1 ? "" : ",") . name
                    }
                    IniWrite(listStr, iniPath, "Profiles", "List")
                } else {
                    ; Merge mode: add any new profiles to existing list
                    for _, name in importedList {
                        if (!existingMap.Has(name)) {
                            existingArr.Push(name)
                            existingMap[name] := true
                        }
                    }
                    mergedStr := ""
                    for idx, name in existingArr {
                        if (name != "") {
                            mergedStr .= (mergedStr = "" ? "" : ",") . name
                        }
                    }
                    IniWrite(mergedStr, iniPath, "Profiles", "List")
                }
            }

            ; 3. Button Mappings across all profiles and layers
            if (backupObj.Has("mappings") && IsObject(backupObj["mappings"])) {
                mappings := backupObj["mappings"]
                for profName, profBtns in mappings {
                    if (!IsObject(profBtns)) {
                        continue
                    }
                    for btnId, btnLayers in profBtns {
                        if (!IsObject(btnLayers)) {
                            continue
                        }
                        for layerName, actObj in btnLayers {
                            if (IsObject(actObj)) {
                                ProfileEngine.SaveButtonLayer(profName, btnId, layerName, actObj)
                            }
                        }
                    }
                }
            }

            ; 4. Mouse Layout & Buttons (coordinates, offsets, f-keys)
            if (backupObj.Has("mouseLayout") && IsObject(backupObj["mouseLayout"])) {
                mLayout := backupObj["mouseLayout"]

                if (mLayout.Has("image") && mLayout["image"] != "") {
                    IniWrite(mLayout["image"], iniPath, "General", "MouseImage")
                }

                if (mLayout.Has("buttons") && IsObject(mLayout["buttons"])) {
                    ProfileEngine.SaveCustomButtons(mLayout["buttons"])
                }

                if (mLayout.Has("diagramPoints") && IsObject(mLayout["diagramPoints"])) {
                    for bId, pt in mLayout["diagramPoints"] {
                        if (IsObject(pt)) {
                            if (pt.Has("x")) {
                                IniWrite(String(pt["x"]), iniPath, "DiagramPoints", bId . "_X")
                            }
                            if (pt.Has("y")) {
                                IniWrite(String(pt["y"]), iniPath, "DiagramPoints", bId . "_Y")
                            }
                        }
                    }
                }

                if (mLayout.Has("cardOffsets") && IsObject(mLayout["cardOffsets"])) {
                    this.SaveCardOffsets(mLayout["cardOffsets"])
                }

                if (mLayout.Has("mouseOffset") && IsObject(mLayout["mouseOffset"])) {
                    this.SaveMouseOffset(mLayout["mouseOffset"])
                }

                if (mLayout.Has("customButtonNames") && IsObject(mLayout["customButtonNames"])) {
                    for bId, cName in mLayout["customButtonNames"] {
                        this.SaveButtonName(bId, cName)
                    }
                }

                if (mLayout.Has("hardwareFKeys") && IsObject(mLayout["hardwareFKeys"])) {
                    assignedFKeys := Map()
                    try IniDelete(iniPath, "HardwareFKeys")
                    for bId, fKey in mLayout["hardwareFKeys"] {
                        if (fKey != "" && !assignedFKeys.Has(fKey)) {
                            assignedFKeys[fKey] := bId
                            IniWrite(fKey, iniPath, "HardwareFKeys", bId)
                        }
                    }
                }
            }

            ; 5. Custom Mouse Presets Gallery
            if (backupObj.Has("customMousePresets") && IsObject(backupObj["customMousePresets"])) {
                for _, preset in backupObj["customMousePresets"] {
                    if (IsObject(preset)) {
                        this.SaveCustomMousePreset(preset)
                    }
                }
            }

            ; 6. Custom Action Presets (Macros & Combos)
            if (backupObj.Has("customActionPresets") && IsObject(backupObj["customActionPresets"])) {
                for _, preset in backupObj["customActionPresets"] {
                    if (IsObject(preset)) {
                        this.SaveCustomActionPreset(preset)
                    }
                }
            }

            ; 7. Text Block Presets
            if (backupObj.Has("textBlockPresets") && IsObject(backupObj["textBlockPresets"])) {
                for _, preset in backupObj["textBlockPresets"] {
                    if (IsObject(preset)) {
                        this.SaveTextBlockPreset(preset)
                    }
                }
            }

            ; 8. Reload engine
            ProfileEngine.Init(iniPath)
            return true
        } catch as err {
            this.Log("Error in ImportFullBackup: " . err.Message . " in line " . err.Line)
            return false
        }
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
