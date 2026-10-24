#Requires AutoHotkey v2.0
#SingleInstance Force

#Include "lib/OSD.ahk"
#Include "lib/OMMHelper.ahk"
#Include "lib/Profiles.ahk"
#Include "lib/GuiManager.ahk"

ProfileEngine.Init("d:\For Safe Keeping\OBM AHK\settings.ini")
GuiManager.Show()

; Open editor for G8
GuiManager.OpenMappingEditor("G8", "G8 (DPI Up)  [F15]")
Sleep(200)

; Trigger OnPresetChanged
GuiManager.EditPresetDrop.Choose("Copy (Ctrl + C)")
GuiManager.OnPresetChanged()

; Verify EditCustomCmd is ^c
cmdVal := GuiManager.EditCustomCmd.Value

; Test Saving
GuiManager.SaveEditorMapping()

FileAppend("SUCCESS_CMD_" . cmdVal, "d:\For Safe Keeping\OBM AHK\scratch\editor_test_ok.txt")
ExitApp()
