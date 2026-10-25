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
                this.MainGui.Hide()
            } else {
                this.MainGui.Show()
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
        ProfileEngine.OnShiftStateChanged := (isShift, shiftName) => WebViewGuiManager.OnShiftStateChangedHandler(isShift, shiftName)

        ; Clean any orphaned WebView2 renderer processes from prior runs
        this.CleanOrphanedProcesses()

        ; Create GUI
        opt := "+Resize -MaximizeBox " . (this.IsAlwaysOnTop ? "+AlwaysOnTop" : "-AlwaysOnTop")
        g := Gui(opt, "Logitech G502 X — Advanced Studio")
        g.BackColor := "0b0d14"
        g.MarginX := 0
        g.MarginY := 0
        this.MainGui := g

        ; Sizing event
        g.OnEvent("Size", (guiObj, minMax, w, h) => WebViewGuiManager.OnSize(minMax, w, h))
        g.OnEvent("Close", (*) => g.Hide())
        g.OnEvent("Escape", (*) => g.Hide())

        ; Display window
        g.Show("w1360 h840 Center")

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
                    pIcon := req.Has("icon") ? req["icon"] : "generic"
                    if (ProfileEngine.AddProfile(pName, pExe, pIcon)) {
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
                    if (ProfileEngine.UpdateProfile(pName, pExe, pIcon)) {
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

            case "getRunningApps":
                procs := ProfileEngine.GetRunningProcesses()
                this.PostMessage(Map("type", "runningAppsList", "apps", procs))

            case "saveMapping":
                this.HandleSaveMapping(req)

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
                meta := ProfileEngine.ProfileMetadata.Has(p) ? ProfileEngine.ProfileMetadata[p] : { TargetExe: "", Icon: "generic", IsDefault: (p = "Desktop"), Desc: p . " Profile" }
                profilesList.Push(Map(
                    "name", p,
                    "targetExe", meta.TargetExe,
                    "icon", meta.Icon,
                    "isDefault", meta.IsDefault ? true : false,
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
                "mappings", mappings,
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
            meta := ProfileEngine.ProfileMetadata.Has(p) ? ProfileEngine.ProfileMetadata[p] : { TargetExe: "", Icon: "generic", IsDefault: (p = "Desktop"), Desc: p . " Profile" }
            profilesList.Push(Map(
                "name", p,
                "targetExe", meta.TargetExe,
                "icon", meta.Icon,
                "isDefault", meta.IsDefault ? true : false,
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
        if (!req.Has("profile") || !req.Has("btnId") || !req.Has("layer"))
            return

        profile := req["profile"]
        btnId := req["btnId"]
        layer := req["layer"]

        if (ProfileEngine.DefaultMappings.Has(profile) && ProfileEngine.DefaultMappings[profile].Has(btnId)) {
            def := ProfileEngine.DefaultMappings[profile][btnId]
            defAction := (layer = "GShift2") ? def.Normal : ((layer = "GShift" || layer = "GShift1") ? def.GShift : def.Normal)
            ProfileEngine.SaveButtonLayer(profile, btnId, layer, defAction)

            currMap := ProfileEngine.GetButtonMapping(profile, btnId)
            this.PostMessage(Map(
                "type", "mappingSaved",
                "profile", profile,
                "btnId", btnId,
                "mapping", this.ExportButtonMapping(currMap)
            ))
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

    static IsRecording() {
        return false
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
        "G8",           Map("x", 201, "y", 87),
        "G7",           Map("x", 242, "y", 126),
        "DpiShift",     Map("x", 270, "y", 264),
        "Forward",      Map("x", 287, "y", 229),
        "Back",         Map("x", 361, "y", 281),
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

    static OnShiftStateChangedHandler(isShift, shiftName) {
        this.PostMessage(Map(
            "type", "shiftStateChanged",
            "isShift", isShift ? true : false,
            "shiftName", shiftName
        ))
    }
}
