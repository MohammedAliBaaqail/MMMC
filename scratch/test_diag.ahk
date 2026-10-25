#Requires AutoHotkey v2.0
Persistent(true)
FileAppend("DIAG: starting...`n", A_ScriptDir . "\diag.log")

OnError(LogErr)
LogErr(e, mode) {
    FileAppend("ONERROR: " . e.Message . " in " . e.File . ":" . e.Line . "`nStack: " . e.Stack . "`n", A_ScriptDir . "\diag.log")
    return 1 ; Suppress standard dialog
}
OnExit((reason, code) => FileAppend("EXIT: reason=" . reason . " code=" . code . "`n", A_ScriptDir . "\diag.log"))

#Include "..\lib\OSD.ahk"
#Include "..\lib\Profiles.ahk"
#Include "..\lib\WebViewGuiManager.ahk"

FileAppend("DIAG: loaded includes, calling Show()...`n", A_ScriptDir . "\diag.log")
WebViewGuiManager.Show()
FileAppend("DIAG: Show() finished.`n", A_ScriptDir . "\diag.log")
