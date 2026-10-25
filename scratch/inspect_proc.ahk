#Requires AutoHotkey v2.0
DetectHiddenWindows(true)
hwndList := WinGetList("ahk_pid 30228")
out := "Windows: " . hwndList.Length . "`n"
for h in hwndList {
    out .= "Title: '" . WinGetTitle(h) . "' | Text: '" . WinGetText(h) . "'`n"
}
FileAppend(out, A_ScriptDir . "\inspect_res.txt")
ExitApp(0)
