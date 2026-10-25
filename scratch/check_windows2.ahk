#Requires AutoHotkey v2.0
DetectHiddenWindows(true)
list := WinGetList()
out := "Total windows: " . list.Length . "`n"
for hwnd in list {
    pid := WinGetPID(hwnd)
    pname := WinGetProcessName(hwnd)
    title := WinGetTitle(hwnd)
    if InStr(pname, "AutoHotkey") || InStr(title, "G502") || InStr(title, "Studio") {
        out .= "HWND: " . hwnd . " | PID: " . pid . " | Name: " . pname . " | Title: '" . title . "' | Vis: " . DllCall("IsWindowVisible", "ptr", hwnd) . "`n"
    }
}
try FileDelete(A_ScriptDir . "\win_info2.txt")
FileAppend(out, A_ScriptDir . "\win_info2.txt")
ExitApp(0)
