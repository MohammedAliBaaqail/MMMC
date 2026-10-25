#Requires AutoHotkey v2.0
#Include "..\lib\JSON.ahk"
try {
    m := Map("status", "ok", "profile", "Desktop", "val", 123)
    s := JSON.stringify(m)
    p := JSON.parse(s)
    out := A_ScriptDir . "\test_json.txt"
    try FileDelete(out)
    FileAppend("PARSE SUCCESS: status=" . p["status"] . ", val=" . p["val"], out)
} catch as err {
    out := A_ScriptDir . "\test_json.txt"
    try FileDelete(out)
    FileAppend("ERROR: " . err.Message . " in line " . err.Line, out)
}
ExitApp(0)
