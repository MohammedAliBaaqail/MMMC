#Requires AutoHotkey v2.0
DetectHiddenWindows(true)
list := WinGetList("ahk_pid 24880")
out := "Windows for 24880: " . list.Length . "`n"
for h in list {
    out .= "HWND=" . h . " | Title='" . WinGetTitle(h) . "' | Vis=" . DllCall("IsWindowVisible", "ptr", h) . "`n"
}
try FileDelete(A_ScriptDir . "\pid_hwnds.txt")
FileAppend(out, A_ScriptDir . "\pid_hwnds.txt")
ExitApp(0)
