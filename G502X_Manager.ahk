#Requires AutoHotkey v2.0
#SingleInstance Force
#MaxThreadsPerHotkey 2
Persistent(true)

/**
 * LOGITECH G502 X — ADVANCED AHK v2 CONTROLLER
 * Integrates Logitech Onboard Memory Manager (OMM) with AHK v2.
 * 
 * Hardware buttons mapped via OMM:
 *   - Tilt Left    -> F13
 *   - Tilt Right   -> F14
 *   - G8 (DPI Up)  -> F15
 *   - G7 (DPI Dn)  -> F16
 *   - DPI Shift    -> F17 (G-Shift Layer & Tap macro)
 *   - G5 (Forward) -> F18
 *   - G4 (Back)    -> F19
 *   - G9 (Profile) -> F20
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
; HARDWARE INTERCEPT HOTKEYS (F13 - F20)
; ========================================================

; F13 - Wheel Tilt Left
*F13::ProfileEngine.HandleF13_TiltLeft(true)

; F14 - Wheel Tilt Right
*F14::ProfileEngine.HandleF14_TiltRight(true)

; F15 - G8 / DPI Up (Index Finger Front)
*F15::ProfileEngine.HandleF15_G8(true)

; F16 - G7 / DPI Down (Index Finger Rear)
*F16::ProfileEngine.HandleF16_G7(true)

; F17 - DPI Shift / Sniper Thumb Button (G-Shift modifier layer + Tap action)
*F17::ProfileEngine.HandleF17_DpiShift(true)
*F17 Up::ProfileEngine.HandleF17_DpiShift(false)

; F18 - G5 / Forward (Thumb Front)
*F18::ProfileEngine.HandleF18_Forward(true)

; F19 - G4 / Back (Thumb Rear)
*F19::ProfileEngine.HandleF19_Back(true)

; F20 - G9 / Profile Cycle Button
*F20::ProfileEngine.HandleF20_ProfileCycle(true)

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
