#Requires AutoHotkey v2.0
#SingleInstance Force
#MaxThreadsPerHotkey 2
Persistent(true)
OnError(LogError)
LogError(thrown, mode) {
    FileAppend("Error: " . thrown.Message . "`nFile: " . thrown.File . "`nLine: " . thrown.Line . "`n", A_ScriptDir . "\error.log")
}

/**
 * LOGITECH G502 X — ADVANCED AHK v2 CONTROLLER
 * Integrates Logitech Onboard Memory Manager (OMM) with AHK v2.
 * 
 * Hardware buttons mapped via OMM:
 * Hardware buttons mapped via OMM (Buttons 3 to 11):
 *   - Button 3: Middle Click (Mouse 3)             -> F13
 *   - Button 4: Back Button Click (Mouse 4 / G4)   -> F14
 *   - Button 5: G-Shift / Sniper (DPI Shift)       -> F15 (G-Shift Layer & Tap macro)
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

; --- Application Initialization ---
A_IconTip := "Logitech G502 X Manager (AHK v2)"
ConfigFile := A_ScriptDir . "\settings.ini"

; Initialize profile mappings from settings
ProfileEngine.Init(ConfigFile)

; Load configuration if available
InitialProfile := IniRead(ConfigFile, "General", "DefaultProfile", "Desktop")
ProfileEngine.SetProfile(InitialProfile)

; Setup System Tray Menu
SetupTrayMenu()

; Display welcome OSD and Launch GUI
OSD.Show("G502 X Manager Active", "Profile: " . ProfileEngine.CurrentProfile . " (OMM Connected)")
GuiManager.Show()

; ========================================================
; TRAY MENU SETUP
; ========================================================
SetupTrayMenu() {
    tray := A_TrayMenu
    tray.Delete() ; Clear default items
    
    tray.Add("Open Control Center", (*) => GuiManager.Show())
    tray.Add() ; Separator

    ; Profile Submenu
    profileMenu := Menu()
    for p in ProfileEngine.Profiles {
        profileMenu.Add(p, (itemName, *) => SwitchProfileFromTray(itemName))
    }
    tray.Add("Profiles", profileMenu)
    
    tray.Add("Toggle Rapid-Fire", (*) => ProfileEngine.ToggleRapidFire())
    tray.Add() ; Separator
    
    tray.Add("Reload Script", (*) => Reload())
    tray.Add("Exit", (*) => SaveAndExit())
    tray.Default := "Open Control Center"
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
; ========================================================

; Button 3: Middle Click (Mouse 3) -> F13
*F13::ProfileEngine.HandleF13_Middle(true)

; Button 4: Back Button Click (Mouse 4 / G4) -> F14
*F14::ProfileEngine.HandleF14_Back(true)

; Button 5: G-Shift / Sniper Thumb Button (DPI Shift) -> F15
*F15::ProfileEngine.HandleF15_DpiShift(true)
*F15 Up::ProfileEngine.HandleF15_DpiShift(false)

; Button 6: Forward Button Click (Mouse 5 / G5) -> F16
*F16::ProfileEngine.HandleF16_Forward(true)

; Button 7: Tilt Left -> F17
*F17::ProfileEngine.HandleF17_TiltLeft(true)

; Button 8: Tilt Right -> F18
*F18::ProfileEngine.HandleF18_TiltRight(true)

; Button 9: Cycle Profiles (G9) -> F19
*F19::ProfileEngine.HandleF19_ProfileCycle(true)

; Button 10: Next DPI (G8 / DPI Up) -> F20
*F20::ProfileEngine.HandleF20_G8(true)

; Button 11: Previous DPI (G7 / DPI Down) -> F21
*F21::ProfileEngine.HandleF21_G7(true)

; ========================================================
; G-SHIFT CONDITIONAL CHORDS (#HotIf)
; Active only while DPI Shift (F17) is physically held down
; ========================================================
#HotIf ProfileEngine.IsGShiftActive

; Scroll Wheel transforms into Volume / Fine Control knob
*WheelUp::ProfileEngine.HandleWheel("Up")
*WheelDown::ProfileEngine.HandleWheel("Down")

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
