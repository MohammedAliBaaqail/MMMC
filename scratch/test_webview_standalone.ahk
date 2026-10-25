#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent(true)

FileAppend("Step 1: starting`n", A_ScriptDir . "\test_trace.log")

#Include "..\lib\WebViewGuiManager.ahk"

FileAppend("Step 2: included WebViewGuiManager`n", A_ScriptDir . "\test_trace.log")

WebViewGuiManager.Show()

FileAppend("Step 3: after Show()`n", A_ScriptDir . "\test_trace.log")

