#Requires AutoHotkey v2.0
#SingleInstance Force
#MaxThreadsPerHotkey 2
#UseHook true
Persistent(true)
A_MaxHotkeysPerInterval := 2000
A_HotkeyInterval := 2000
OnError(LogError)
LogError(thrown, mode) {
    FileAppend("Error: " . thrown.Message . "`nFile: " . thrown.File . "`nLine: " . thrown.Line . "`n", A_ScriptDir . "\error.log")
}
OnExit(OnScriptExit)
OnScriptExit(ExitReason, ExitCode) {
    try WebViewGuiManager.Cleanup()
    try GdipHelper.Shutdown()
    FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") . " | SCRIPT EXIT: Reason=" . ExitReason . ", Code=" . ExitCode . "`n", A_ScriptDir . "\webview_debug.log")
}

/**
 * MY MOUSE MY CHOICE — ADVANCED AHK v2 CONTROLLER
 * Universal multi-mouse customization, profiles, and macro execution engine.
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
#Include "lib/QuickRemap.ahk"

; --- Application Initialization ---
A_IconTip := "My Mouse My Choice"
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
ProfileEngine.OnProfilesListChanged := (*) => SetupTrayMenu()
SetupTrayMenu()

; Display welcome OSD and Launch Modern Studio GUI
OSD.Show("My Mouse My Choice Active", "Profile: " . ProfileEngine.CurrentProfile . " (OMM Connected)")
WebViewGuiManager.Show()

; ========================================================
; TRAY MENU SETUP
; ========================================================
SetupTrayMenu() {
    tray := A_TrayMenu
    tray.Delete() ; Clear default items
    
    tray.Add("Open My Mouse My Choice", (*) => WebViewGuiManager.Show())
    tray.Add("Open Classic GUI", (*) => GuiManager.Show())
    tray.Add("Always on Top", (*) => WebViewGuiManager.ToggleAlwaysOnTop())
    if (WebViewGuiManager.IsAlwaysOnTop)
        tray.Check("Always on Top")
    tray.Add("Quick Remap Button (Ctrl+Shift+F1)", (*) => QuickRemap.Start())
    tray.Add("New Profile for Active App (Ctrl+Shift+F2)", (*) => ProfileEngine.CreateProfileFromFocusedWindow())
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
    tray.Default := "Open My Mouse My Choice"
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
; QUICK REMAP TRIGGER HOTKEY (System-Wide)
; Exclusively: Ctrl + Shift + F1
; ========================================================
^+F1::
*^+F1::
^+vk70::
*^+vk70::
^+sc03B::
*^+sc03B::QuickRemap.Start()

; ========================================================
; QUICK CREATE PROFILE FOR FOCUSED APP (System-Wide)
; Exclusively: Ctrl + Shift + F2
; ========================================================
^+F2::
*^+F2::
^+vk71::
*^+vk71::
^+sc03C::
*^+sc03C::ProfileEngine.CreateProfileFromFocusedWindow()

; ========================================================
; QUICK REMAP — STEP 2 MOUSE BUTTON INTERCEPT
; Captures whichever mouse button is pressed for remapping
; ========================================================
#HotIf QuickRemap.IsWaitingForButton()

*F13::QuickRemap.OnMouseButtonEvent("Middle", true)
*F13 Up::QuickRemap.OnMouseButtonEvent("Middle", false)

*F14::QuickRemap.OnMouseButtonEvent("Back", true)
*F14 Up::QuickRemap.OnMouseButtonEvent("Back", false)

*F15::QuickRemap.OnMouseButtonEvent("DpiShift", true)
*F15 Up::QuickRemap.OnMouseButtonEvent("DpiShift", false)

*F16::QuickRemap.OnMouseButtonEvent("Forward", true)
*F16 Up::QuickRemap.OnMouseButtonEvent("Forward", false)

*F17::QuickRemap.OnMouseButtonEvent("TiltLeft", true)
*F17 Up::QuickRemap.OnMouseButtonEvent("TiltLeft", false)

*F18::QuickRemap.OnMouseButtonEvent("TiltRight", true)
*F18 Up::QuickRemap.OnMouseButtonEvent("TiltRight", false)

*F19::QuickRemap.OnMouseButtonEvent("ProfileCycle", true)
*F19 Up::QuickRemap.OnMouseButtonEvent("ProfileCycle", false)

*F20::QuickRemap.OnMouseButtonEvent("G8", true)
*F20 Up::QuickRemap.OnMouseButtonEvent("G8", false)

*F21::QuickRemap.OnMouseButtonEvent("G7", true)
*F21 Up::QuickRemap.OnMouseButtonEvent("G7", false)

*F22::QuickRemap.OnMouseButtonEvent("F22", true)
*F22 Up::QuickRemap.OnMouseButtonEvent("F22", false)

*F23::QuickRemap.OnMouseButtonEvent("F23", true)
*F23 Up::QuickRemap.OnMouseButtonEvent("F23", false)

*F24::QuickRemap.OnMouseButtonEvent("F24", true)
*F24 Up::QuickRemap.OnMouseButtonEvent("F24", false)

*WheelUp::QuickRemap.OnMouseButtonEvent("WheelUp", true)
*WheelDown::QuickRemap.OnMouseButtonEvent("WheelDown", true)

*MButton::QuickRemap.OnMouseButtonEvent("Middle", true)
*MButton Up::QuickRemap.OnMouseButtonEvent("Middle", false)

*XButton1::QuickRemap.OnMouseButtonEvent("Back", true)
*XButton1 Up::QuickRemap.OnMouseButtonEvent("Back", false)

*XButton2::QuickRemap.OnMouseButtonEvent("Forward", true)
*XButton2 Up::QuickRemap.OnMouseButtonEvent("Forward", false)

*LButton::QuickRemap.OnMouseButtonEvent("LeftClick", true)
*LButton Up::QuickRemap.OnMouseButtonEvent("LeftClick", false)

*RButton::QuickRemap.OnMouseButtonEvent("RightClick", true)
*RButton Up::QuickRemap.OnMouseButtonEvent("RightClick", false)

#HotIf

; ========================================================
; QUICK REMAP — STEP 3 MOUSE CLICKS IN COMBINATION
; Supports injecting mouse clicks into combination (e.g. Ctrl + Left Click)
; ========================================================
#HotIf QuickRemap.IsWaitingForKey()

*LButton::QuickRemap.OnMouseButtonInCombo("LButton")
*RButton::QuickRemap.OnMouseButtonInCombo("RButton")
*MButton::QuickRemap.OnMouseButtonInCombo("MButton")
*XButton1::QuickRemap.OnMouseButtonInCombo("XButton1")
*XButton2::QuickRemap.OnMouseButtonInCombo("XButton2")

#HotIf

; ========================================================
; QUICK REMAP — CANCEL (ESCAPE)
; ========================================================
#HotIf QuickRemap.IsActive

*Escape::QuickRemap.Cancel()

#HotIf

; ========================================================
; HARDWARE INTERCEPT HOTKEYS (F13 - F21)
; Synchronized 1:1 with Logitech Onboard Memory Manager
; Active whenever keystroke recording modal is NOT open
; ========================================================
#HotIf !GuiManager.IsRecording() && !WebViewGuiManager.IsRecording() && !QuickRemap.IsActive

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

; Additional Virtual Keys for Custom Buttons (F22 - F24)
*F22::ProfileEngine.HandleFKey("F22", true)
*F22 Up::ProfileEngine.HandleFKey("F22", false)

*F23::ProfileEngine.HandleFKey("F23", true)
*F23 Up::ProfileEngine.HandleFKey("F23", false)

*F24::ProfileEngine.HandleFKey("F24", true)
*F24 Up::ProfileEngine.HandleFKey("F24", false)

#HotIf

; ========================================================
; SCROLL WHEEL INTERCEPT (No F-Key Required)
; Dispatches based on active profile & B-Shift layer
; ========================================================
#HotIf !GuiManager.IsRecording() && !WebViewGuiManager.IsRecording() && !QuickRemap.IsActive && ProfileEngine.NeedsWheelIntercept()

*WheelUp::ProfileEngine.DispatchWheel("Up")
*WheelDown::ProfileEngine.DispatchWheel("Down")

#HotIf

; ========================================================
; B-SHIFT LEFT & RIGHT CLICK INTERCEPT (#HotIf)
; Active ONLY when B-Shift is ON and a custom mapping exists
; Normal layer is NEVER intercepted, guaranteeing normal clicking
; ========================================================
#HotIf !GuiManager.IsRecording() && !WebViewGuiManager.IsRecording() && !QuickRemap.IsActive && ProfileEngine.NeedsLeftClickIntercept()

*LButton::ProfileEngine.HandleLeftClick(true)
*LButton Up::ProfileEngine.HandleLeftClick(false)

#HotIf

#HotIf !GuiManager.IsRecording() && !WebViewGuiManager.IsRecording() && !QuickRemap.IsActive && ProfileEngine.NeedsRightClickIntercept()

*RButton::ProfileEngine.HandleRightClick(true)
*RButton Up::ProfileEngine.HandleRightClick(false)

#HotIf

; ========================================================
; NATIVE PASS-THROUGH MONITORING (Left, Right, Wheel)
; Passes native clicks/scrolls directly to Windows while
; highlighting the buttons in the Studio hardware diagram
; ========================================================
#HotIf !GuiManager.IsRecording() && !WebViewGuiManager.IsRecording() && !QuickRemap.IsActive && !ProfileEngine.NeedsLeftClickIntercept() && !ProfileEngine.RapidFireEnabled

~*LButton::ProfileEngine.NotifyButton("LeftClick", true)
~*LButton Up::ProfileEngine.NotifyButton("LeftClick", false)

#HotIf !GuiManager.IsRecording() && !WebViewGuiManager.IsRecording() && !QuickRemap.IsActive && !ProfileEngine.NeedsRightClickIntercept()

~*RButton::ProfileEngine.NotifyButton("RightClick", true)
~*RButton Up::ProfileEngine.NotifyButton("RightClick", false)

#HotIf !GuiManager.IsRecording() && !WebViewGuiManager.IsRecording() && !QuickRemap.IsActive && !ProfileEngine.NeedsWheelIntercept()

~*WheelUp::ProfileEngine.NotifyWheel("WheelUp")
~*WheelDown::ProfileEngine.NotifyWheel("WheelDown")

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
