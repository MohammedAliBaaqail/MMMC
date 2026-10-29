#Requires AutoHotkey v2.0

/**
 * Snap Tap / SOCD Directional Counter-Strafe Cleaner — My Mouse My Choice
 * Pure Logical SOCD Engine with Zero App Blacklisting.
 * 
 * Core Logic:
 * 1. Active-Key State Machine:
 *    - Tracks which key is currently logical master ('ActiveKey').
 *    - When 'A' and 'D' overlap, whichever key was pressed last takes priority.
 *    - The previously active key is released with Send("{Blind}{... up}").
 *    - CRITICAL FIX: When the user lifts their finger off the suppressed key, the active key is
 *      ALREADY physically and virtually down. We do NOT send an artificial key-down event.
 *      This completely eliminates the duplicate character bug ("add", "daa").
 * 2. Overlap Dwell Guard:
 *    - When the active key is released, the opposing key only resumes if it was held longer
 *      than a typing rollover tap (>= 100ms).
 *    - Fast typing overlaps (30-60ms) are cleanly released without injecting ghost letters.
 *    - Gaming counter-strafes (> 150ms holds) resume instantaneously.
 */
class SnapTap {
    static Enabled := false
    static Mode := "games"   ; "games" (only active in game profiles) or "all" (always active)
    static MinDwellMs := 100 ; Distinguishes fast typing rollover taps (< 100ms) from sustained strafe holds

    ; Internal state tracking
    static ActiveKey := ""     ; Currently logically down ("a", "d", or "")
    static PhysA := false      ; Physical state of 'A'
    static PhysD := false      ; Physical state of 'D'
    static ALastDownTime := 0  ; TickCount when 'A' was physically pressed
    static DLastDownTime := 0  ; TickCount when 'D' was physically pressed

    static Init() {
        iniPath := A_ScriptDir . "\settings.ini"
        val := IniRead(iniPath, "Settings", "SnapTap", "0")
        this.Enabled := (val = "1" || val = "true")
        try {
            this.Mode := IniRead(iniPath, "Settings", "SnapTapMode", "games")
        } catch {
            this.Mode := "games"
        }
        try {
            dwellVal := IniRead(iniPath, "Settings", "SnapTapDwellMs", "100")
            this.MinDwellMs := Integer(dwellVal)
        } catch {
            this.MinDwellMs := 100
        }
    }

    static SetMode(newMode) {
        if (newMode != "games" && newMode != "all")
            newMode := "games"
        this.Mode := newMode
        iniPath := A_ScriptDir . "\settings.ini"
        try IniWrite(this.Mode, iniPath, "Settings", "SnapTapMode")
    }

    static SetEnabled(enable) {
        this.Enabled := enable ? true : false
        this.Reset()
        iniPath := A_ScriptDir . "\settings.ini"
        try IniWrite(this.Enabled ? "1" : "0", iniPath, "Settings", "SnapTap")
    }

    static Toggle() {
        this.SetEnabled(!this.Enabled)
        statusText := this.Enabled ? "Snap Tap: ON" : "Snap Tap: OFF"
        if (IsSet(OSD) && HasProp(OSD, "Show")) {
            OSD.Show("Snap Tap", statusText)
        }
        return this.Enabled
    }

    static IsActive() {
        if (!this.Enabled)
            return false
        if (this.Mode == "all")
            return true
        ; "games" mode: active if current profile is not Desktop or has a target exe
        if (HasProp(ProfileEngine, "CurrentProfile")) {
            prof := ProfileEngine.CurrentProfile
            if (prof != "Desktop" && prof != "")
                return true
            if (HasProp(ProfileEngine, "ProfileMetadata") && ProfileEngine.ProfileMetadata.Has(prof)) {
                meta := ProfileEngine.ProfileMetadata[prof]
                if (meta.HasOwnProp("TargetExe") && meta.TargetExe != "")
                    return true
            }
        }
        return false
    }

    static Reset() {
        this.ActiveKey := ""
        this.PhysA := false
        this.PhysD := false
        this.ALastDownTime := 0
        this.DLastDownTime := 0
    }

    static OnADown() {
        if (this.PhysA)
        return  ; Ignore Windows key auto-repeat
        this.PhysA := true
        this.ALastDownTime := A_TickCount
        if (this.ActiveKey == "d") {
            Send("{Blind}{d up}")
        }
        this.ActiveKey := "a"
    }

    static OnAUp() {
        this.PhysA := false
        this.ALastDownTime := 0
        if (this.ActiveKey == "a") {
            this.ActiveKey := ""
            ; Re-engage D only if D is still physically held AND was held for at least MinDwellMs
            if (GetKeyState("d", "P") && this.DLastDownTime > 0) {
                dDwell := A_TickCount - this.DLastDownTime
                if (dDwell >= this.MinDwellMs) {
                    Send("{Blind}{d down}")
                    this.ActiveKey := "d"
                }
            }
        }
        ; If ActiveKey was "d", D is ALREADY active. Do NOT send "d down"!
    }

    static OnDDown() {
        if (this.PhysD)
        return  ; Ignore Windows key auto-repeat
        this.PhysD := true
        this.DLastDownTime := A_TickCount
        if (this.ActiveKey == "a") {
            Send("{Blind}{a up}")
        }
        this.ActiveKey := "d"
    }

    static OnDUp() {
        this.PhysD := false
        this.DLastDownTime := 0
        if (this.ActiveKey == "d") {
            this.ActiveKey := ""
            ; Re-engage A only if A is still physically held AND was held for at least MinDwellMs
            if (GetKeyState("a", "P") && this.ALastDownTime > 0) {
                aDwell := A_TickCount - this.ALastDownTime
                if (aDwell >= this.MinDwellMs) {
                    Send("{Blind}{a down}")
                    this.ActiveKey := "a"
                }
            }
        }
        ; If ActiveKey was "a", A is ALREADY active. Do NOT send "a down"!
    }
}
