#Requires AutoHotkey v2.0
#SingleInstance Force
#MaxThreadsPerHotkey 2
Persistent(true)
OnError(LogError)
LogError(thrown, mode) {
    FileAppend("Error: " . thrown.Message . "`nFile: " . thrown.File . "`nLine: " . thrown.Line . "`n", A_ScriptDir . "\error.log")
}
OnExit(OnScriptExit)
OnScriptExit(ExitReason, ExitCode) {
    try WebViewGuiManager.Cleanup()
    FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") . " | SCRIPT EXIT: Reason=" . ExitReason . ", Code=" . ExitCode . "`n", A_ScriptDir . "\webview_debug.log")
}

/**
 * LOGITECH G502 X — ADVANCED AHK v2 CONTROLLER
 * Integrates Logitech Onboard Memory Manager (OMM) with AHK v2.
 * 
 * Hardware buttons mapped via OMM:
 * Hardware buttons mapped via OMM (Buttons 3 to 11):
 *   - Button 3: Middle Click (Mouse 3)             -> F13
 *   - Button 4: Back Button Click (Mouse 4 / G4)   -> F14
 *   - Button 5: G-Shift / Sniper (DPI Shift)       -> F15 (B-Shift / G-Shift Layer Modifier)
 *   - Button 6: Forward Button Click (Mouse 5 / G5)-> F16
 *   - Button 7: Tilt Left                          -> F17
 *   - Button 8: Tilt Right                         -> F18
 *   - Button 9: Cycle Profiles (G9)                -> F19
 *   - Button 10: Next DPI (G8 / DPI Up)            -> F20
 *   - Button 11: Previous DPI (G7 / DPI Down)      -> F21
 */

; Include modular libraries
#Include "lib/OSD.ahk"
#Include "lib/OMMHelper.ahk"
#Include "lib/Profiles.ahk"
#Include "lib/GuiManager.ahk"
#Include "lib/WebViewGuiManager.ahk"

; --- Application Initialization ---
A_IconTip := "Logitech G502 X Studio"
iconFile := A_ScriptDir . "\assets\app.ico"
if FileExist(iconFile) {
    try TraySetIcon(iconFile)
}
ConfigFile := A_ScriptDir . "\settings.ini"

; Initialize profile mappings from settings
ProfileEngine.Init(ConfigFile)

; Load configuration if available
InitialProfile := IniRead(ConfigFile, "General", "DefaultProfile", "Desktop")
ProfileEngine.SetProfile(InitialProfile)

AlwaysOnTopPref := IniRead(ConfigFile, "General", "AlwaysOnTop", "1")
WebViewGuiManager.IsAlwaysOnTop := (AlwaysOnTopPref = "1")
GuiManager.IsAlwaysOnTop := (AlwaysOnTopPref = "1")

; Setup System Tray Menu
SetupTrayMenu()

; Display welcome OSD and Launch Modern Studio GUI
OSD.Show("G502 X Studio Active", "Profile: " . ProfileEngine.CurrentProfile . " (OMM Connected)")
WebViewGuiManager.Show()

; ========================================================
; TRAY MENU SETUP
; ========================================================
SetupTrayMenu() {
    tray := A_TrayMenu
    tray.Delete() ; Clear default items
    
    tray.Add("Open G502 X Studio", (*) => WebViewGuiManager.Show())
    tray.Add("Open Classic GUI", (*) => GuiManager.Show())
    tray.Add("Always on Top", (*) => WebViewGuiManager.ToggleAlwaysOnTop())
    if (WebViewGuiManager.IsAlwaysOnTop)
        tray.Check("Always on Top")
    tray.Add() ; Separator

    ; Profile Submenu
    profileMenu := Menu()
    for p in ProfileEngine.Profiles {
        profileMenu.Add(p, (itemName, *) => SwitchProfileFromTray(itemName))
    }
    tray.Add("Profiles", profileMenu)
    
    tray.Add("Toggle Rapid-Fire", (*) => ProfileEngine.ToggleRapidFire())
    tray.Add() ; Separator
    
    tray.Add("Reload", (*) => Reload())
    tray.Add("Exit", (*) => SaveAndExit())
    tray.Default := "Open G502 X Studio"
}

SwitchProfileFromTray(p) {
    ProfileEngine.SetProfile(p)
    IniWrite(p, ConfigFile, "General", "DefaultProfile")
}

SaveAndExit() {
    IniWrite(ProfileEngine.CurrentProfile, ConfigFile, "General", "DefaultProfile")
    ExitApp()
}

; ========================================================
; HARDWARE INTERCEPT HOTKEYS (F13 - F21)
; Synchronized 1:1 with Logitech Onboard Memory Manager
; Active whenever keystroke recording modal is NOT open
; ========================================================
#HotIf !GuiManager.IsRecording() && !WebViewGuiManager.IsRecording()

; Button 3: Middle Click (Mouse 3) -> F13
*F13::ProfileEngine.HandleF13_Middle(true)
*F13 Up::ProfileEngine.HandleF13_Middle(false)

; Button 4: Back Button Click (Mouse 4 / G4) -> F14
*F14::ProfileEngine.HandleF14_Back(true)
*F14 Up::ProfileEngine.HandleF14_Back(false)

; Button 5: G-Shift / Sniper Thumb Button (DPI Shift) -> F15
*F15::ProfileEngine.HandleF15_DpiShift(true)
*F15 Up::ProfileEngine.HandleF15_DpiShift(false)

; Button 6: Forward Button Click (Mouse 5 / G5) -> F16
*F16::ProfileEngine.HandleF16_Forward(true)
*F16 Up::ProfileEngine.HandleF16_Forward(false)

; Button 7: Tilt Left -> F17
*F17::ProfileEngine.HandleF17_TiltLeft(true)
*F17 Up::ProfileEngine.HandleF17_TiltLeft(false)

; Button 8: Tilt Right -> F18
*F18::ProfileEngine.HandleF18_TiltRight(true)
*F18 Up::ProfileEngine.HandleF18_TiltRight(false)

; Button 9: Cycle Profiles (G9) -> F19
*F19::ProfileEngine.HandleF19_ProfileCycle(true)
*F19 Up::ProfileEngine.HandleF19_ProfileCycle(false)

; Button 10: Next DPI (G8 / DPI Up) -> F20
*F20::ProfileEngine.HandleF20_G8(true)
*F20 Up::ProfileEngine.HandleF20_G8(false)

; Button 11: Previous DPI (G7 / DPI Down) -> F21
*F21::ProfileEngine.HandleF21_G7(true)
*F21 Up::ProfileEngine.HandleF21_G7(false)

#HotIf

; ========================================================
; SCROLL WHEEL INTERCEPT (No F-Key Required)
; Dispatches based on active profile & B-Shift layer
; ========================================================
#HotIf !GuiManager.IsRecording() && !WebViewGuiManager.IsRecording() && ProfileEngine.NeedsWheelIntercept()

*WheelUp::ProfileEngine.DispatchWheel("Up")
*WheelDown::ProfileEngine.DispatchWheel("Down")

#HotIf

; ========================================================
; B-SHIFT LEFT & RIGHT CLICK INTERCEPT (#HotIf)
; Active ONLY when B-Shift is ON and a custom mapping exists
; Normal layer is NEVER intercepted, guaranteeing normal clicking
; ========================================================
#HotIf !GuiManager.IsRecording() && !WebViewGuiManager.IsRecording() && ProfileEngine.NeedsLeftClickIntercept()

*LButton::ProfileEngine.HandleLeftClick(true)
*LButton Up::ProfileEngine.HandleLeftClick(false)

#HotIf

#HotIf !GuiManager.IsRecording() && !WebViewGuiManager.IsRecording() && ProfileEngine.NeedsRightClickIntercept()

*RButton::ProfileEngine.HandleRightClick(true)
*RButton Up::ProfileEngine.HandleRightClick(false)

#HotIf

; ========================================================
; RAPID-FIRE AUTO-CLICKER (#HotIf)
; Active only when Rapid-Fire mode is toggled ON (G8 in Gaming)
; ========================================================
#HotIf ProfileEngine.RapidFireEnabled

*LButton::
{
    ProfileEngine.RapidFireActive := true
    SetTimer(ProfileEngine.rapidFireFn, ProfileEngine.RapidFireInterval)
    KeyWait("LButton")
    ProfileEngine.RapidFireActive := false
}

#HotIf
