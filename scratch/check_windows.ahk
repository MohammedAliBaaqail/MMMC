#Requires AutoHotkey v2.0
DetectHiddenWindows(true)
list := WinGetList("ahk_pid 41392")
out := "Windows count: " . list.Length . "`n"
for hwnd in list {
    out .= "HWND: " . hwnd . " | Title: '" . WinGetTitle(hwnd) . "' | Visible: " . DllCall("IsWindowVisible", "ptr", hwnd) . " | Class: " . WinGetClass(hwnd) . "`n"
}
try FileDelete(A_ScriptDir . "\win_info.txt")
FileAppend(out, A_ScriptDir . "\win_info.txt")
ExitApp(0)
