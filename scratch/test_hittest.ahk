#Requires AutoHotkey v2.0

g := Gui()
lv := g.Add("ListView", "w200 h200", ["Col1"])
lv.Add("", "Row 1")
lv.Add("", "Row 2")
lv.Add("", "Row 3")

LV_GetRowAt(lvHwnd, clientX, clientY) {
    hti := Buffer(24, 0)
    NumPut("int", clientX, hti, 0)
    NumPut("int", clientY, hti, 4)
    rowIdx := DllCall("SendMessage", "ptr", lvHwnd, "uint", 0x1012, "ptr", 0, "ptr", hti, "int")
    return (rowIdx >= 0) ? (rowIdx + 1) : 0
}

g.Show("w240 h240")
Sleep 500

; Test hit test at y = 10, y = 30
r1 := LV_GetRowAt(lv.Hwnd, 20, 10)
r2 := LV_GetRowAt(lv.Hwnd, 20, 30)
FileAppend("r1: " . r1 . ", r2: " . r2 . "`n", "*")
ExitApp()
