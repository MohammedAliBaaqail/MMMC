#Requires AutoHotkey v2.0

/**
 * FocusFollowsMouse — Automatic Window Focus on Mouse Hover
 * High-performance, zero-flicker window hover activation with safety exclusions.
 * Supports:
 *   - "off": Completely disabled
 *   - "profile": Active only when the current profile has FocusOnHover enabled
 *   - "all": Globally active across all windows and profiles
 */
class FocusFollowsMouse {
    static Mode := "profile"   ; "off", "profile", "all"
    static Delay := 120        ; ms hover dwell duration before activating
    static LastHoverHwnd := 0
    static HoverStartTick := 0
    static TimerFn := ""
    static ConfigPath := ""

    static Init(iniPath) {
        this.ConfigPath := iniPath
        this.Mode := IniRead(this.ConfigPath, "General", "FocusOnHoverMode", "profile")
        this.Delay := Integer(IniRead(this.ConfigPath, "General", "FocusOnHoverDelay", "120"))
        if (this.Delay < 0)
            this.Delay := 0
        if (this.Delay > 1000)
            this.Delay := 1000

        this.TimerFn := ObjBindMethod(FocusFollowsMouse, "Tick")
        this.UpdateTimerState()
    }

    static UpdateTimerState() {
        if (!this.TimerFn)
            return

        if (this.Mode == "off") {
            SetTimer(this.TimerFn, 0)
            this.Reset()
        } else {
            ; 50ms tick ensures responsive hover detection without high CPU usage
            SetTimer(this.TimerFn, 50)
        }
    }

    static SetMode(newMode) {
        if (newMode != "off" && newMode != "profile" && newMode != "all")
            newMode := "profile"
        this.Mode := newMode
        if (this.ConfigPath != "") {
            try IniWrite(this.Mode, this.ConfigPath, "General", "FocusOnHoverMode")
        }
        this.UpdateTimerState()
        this.Reset()
    }

    static SetDelay(newDelay) {
        val := Integer(newDelay)
        if (val < 0)
            val := 0
        if (val > 1000)
            val := 1000
        this.Delay := val
        if (this.ConfigPath != "") {
            try IniWrite(this.Delay, this.ConfigPath, "General", "FocusOnHoverDelay")
        }
        this.Reset()
    }

    static Reset() {
        this.LastHoverHwnd := 0
        this.HoverStartTick := 0
    }

    static Tick() {
        ; Do not steal focus if user is currently holding a mouse button (e.g. dragging, selecting text, painting)
        if (GetKeyState("LButton", "P") || GetKeyState("RButton", "P") || GetKeyState("MButton", "P")
            || GetKeyState("XButton1", "P") || GetKeyState("XButton2", "P")) {
            this.Reset()
            return
        }

        MouseGetPos(, , &hoverHwnd)
        if (!hoverHwnd) {
            this.Reset()
            return
        }

        ; Resolve to top-level window (GA_ROOT = 2)
        rootHwnd := DllCall("GetAncestor", "ptr", hoverHwnd, "uint", 2, "ptr")
        if (!rootHwnd)
            rootHwnd := hoverHwnd

        ; Check if this window is already in the foreground
        activeHwnd := WinExist("A")
        if (rootHwnd == activeHwnd) {
            this.LastHoverHwnd := rootHwnd
            this.HoverStartTick := 0
            return
        }

        ; Exclude Studio GUI windows (WebView2 or Classic) and child controls
        guiHwnd := (HasProp(WebViewGuiManager, "MainGui") && WebViewGuiManager.MainGui != "") ? WebViewGuiManager.MainGui.Hwnd : 0
        classicHwnd := (HasProp(GuiManager, "MainGui") && GuiManager.MainGui != "") ? GuiManager.MainGui.Hwnd : 0
        if ((guiHwnd && (rootHwnd == guiHwnd || DllCall("IsChild", "ptr", guiHwnd, "ptr", rootHwnd)))
            || (classicHwnd && (rootHwnd == classicHwnd || DllCall("IsChild", "ptr", classicHwnd, "ptr", rootHwnd)))) {
            this.Reset()
            return
        }

        ; Safety Exclusions: Taskbar, Desktop wallpaper, Start menu, Context menus, Windows Shell
        procName := ""
        try {
            winClass := WinGetClass("ahk_id " rootHwnd)
            if (winClass = "WorkerW" || winClass = "Progman" || winClass = "Shell_TrayWnd" 
                || winClass = "Shell_SecondaryTrayWnd" || winClass = "Windows.UI.Core.CoreWindow" 
                || winClass = "#32768" || winClass = "XamlExplorerHostIslandWindow" 
                || winClass = "DV2ControlHost") {
                this.Reset()
                return
            }

            procName := WinGetProcessName("ahk_id " rootHwnd)
            if (procName = "SearchHost.exe" || procName = "StartMenuExperienceHost.exe" 
                || procName = "ShellExperienceHost.exe" || procName = "MultitaskingView.exe" 
                || procName = "dwm.exe") {
                this.Reset()
                return
            }
        } catch {
            this.Reset()
            return
        }

        ; In "profile" mode, check if hover focus should apply:
        ; 1) Target window matches a profile with FocusOnHover enabled
        ; 2) Or currently active profile has FocusOnHover enabled
        if (this.Mode == "profile") {
            allowed := false

            ; 1. Check if the target window under cursor belongs to a profile with FocusOnHover
            if (procName != "") {
                targetProf := ProfileEngine.FindProfileForProcess(procName, false)
                if (targetProf != "" && ProfileEngine.ProfileMetadata.Has(targetProf)) {
                    targetMeta := ProfileEngine.ProfileMetadata[targetProf]
                    if (targetMeta.HasOwnProp("FocusOnHover") && targetMeta.FocusOnHover) {
                        allowed := true
                    }
                }
            }

            ; 2. Check if currently active profile has FocusOnHover
            if (!allowed) {
                currProf := ProfileEngine.CurrentProfile
                if (ProfileEngine.ProfileMetadata.Has(currProf)) {
                    currMeta := ProfileEngine.ProfileMetadata[currProf]
                    if (currMeta.HasOwnProp("FocusOnHover") && currMeta.FocusOnHover) {
                        allowed := true
                    }
                }
            }

            if (!allowed) {
                this.Reset()
                return
            }
        }

        ; Require mouse to dwell over the target window steadily for Delay duration before activating
        if (rootHwnd != this.LastHoverHwnd) {
            this.LastHoverHwnd := rootHwnd
            this.HoverStartTick := A_TickCount
            return
        }

        if (this.HoverStartTick > 0 && (A_TickCount - this.HoverStartTick >= this.Delay)) {
            this.HoverStartTick := 0
            try {
                if (WinExist("ahk_id " rootHwnd) && !WinActive("ahk_id " rootHwnd)) {
                    WinActivate("ahk_id " rootHwnd)
                }
            }
        }
    }
}
