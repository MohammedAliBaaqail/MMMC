#Requires AutoHotkey v2.0

g := Gui()
g.BackColor := "181825"
g.SetFont("s9 bold cCDD6F4", "Segoe UI")

lv := g.Add("ListView", "x20 y20 w200 h400 Background1E1E2E +Report -Hdr", ["Cat", "Action", "Key"])
lv.ModifyCol(1, 0)
lv.ModifyCol(2, 130)
lv.ModifyCol(3, "Right 65")
lv.Add("", "Nav", "Copy (Ctrl+C)", "^c")
lv.Add("", "Nav", "Paste (Ctrl+V)", "^v")
lv.Add("", "Nav", "Middle Click", "{MButton}")
lv.Add("", "Nav", "Next Tab", "^{Tab}")

diagramPath := InStr(A_ScriptDir, "scratch") ? SubStr(A_ScriptDir, 1, InStr(A_ScriptDir, "\scratch",, -1)-1) . "\assets\g502x_diagram.png" : A_ScriptDir . "\assets\g502x_diagram.png"

pic := g.Add("Picture", "x240 y20 w860 h500 +BackgroundTrans", diagramPath)

cardG8 := g.Add("Text", "x250 y100 w145 h22 Center 0x200 Background1E1E2E +Border cCDD6F4", "G8: Copy")
cardG8.ButtonId := "G8"
cardG8.ButtonName := "G8 (DPI Up)"

cardMid := g.Add("Text", "x880 y100 w145 h22 Center 0x200 Background1E1E2E +Border cCDD6F4", "Mid: Middle")
cardMid.ButtonId := "Middle"
cardMid.ButtonName := "Middle Click"

cards := Map("G8", cardG8, "Middle", cardMid)

points := Map(
    "G8", { name: "G8 (DPI Up)", tx: 228, ty: 106 },
    "Middle", { name: "Middle Click", tx: 355, ty: 58 }
)

FindButtonUnderCursor() {
    pt := Buffer(8, 0)
    DllCall("GetCursorPos", "ptr", pt)
    hoverHwnd := DllCall("WindowFromPoint", "int64", NumGet(pt, 0, "int64"), "ptr")

    for id, c in cards {
        if (hoverHwnd = c.Hwnd)
            return id
    }

    if (hoverHwnd = pic.Hwnd) {
        diagPt := Buffer(8, 0)
        DllCall("GetCursorPos", "ptr", diagPt)
        DllCall("ScreenToClient", "ptr", pic.Hwnd, "ptr", diagPt)
        cx := NumGet(diagPt, 0, "int")
        cy := NumGet(diagPt, 4, "int")

        closestId := ""
        minDist := 999999
        for id, p in points {
            dist := Sqrt((cx - p.tx)**2 + (cy - p.ty)**2)
            if (dist < minDist) {
                minDist := dist
                closestId := id
            }
        }
        if (minDist <= 55)
            return closestId
    }
    return ""
}

#HotIf WinActive("ahk_id " . g.Hwnd)
~LButton:: {
    CoordMode("Mouse", "Screen")
    pt := Buffer(8, 0)
    DllCall("GetCursorPos", "ptr", pt)
    mHwnd := DllCall("WindowFromPoint", "int64", NumGet(pt, 0, "int64"), "ptr")
    if (mHwnd != lv.Hwnd)
        return

    DllCall("ScreenToClient", "ptr", lv.Hwnd, "ptr", pt)
    lvX := NumGet(pt, 0, "int")
    lvY := NumGet(pt, 4, "int")

    hti := Buffer(24, 0)
    NumPut("int", lvX, hti, 0)
    NumPut("int", lvY, hti, 4)
    rowIdx := DllCall("SendMessage", "ptr", lv.Hwnd, "uint", 0x1012, "ptr", 0, "ptr", hti, "int")
    clickedRow := (rowIdx >= 0) ? (rowIdx + 1) : 0
    if (clickedRow <= 0)
        return

    cmdName := Trim(lv.GetText(clickedRow, 2))
    if (cmdName = "")
        return

    startPt := Buffer(8, 0)
    DllCall("GetCursorPos", "ptr", startPt)
    startX := NumGet(startPt, 0, "int")
    startY := NumGet(startPt, 4, "int")
    isDrag := false

    while GetKeyState("LButton", "P") {
        curPt := Buffer(8, 0)
        DllCall("GetCursorPos", "ptr", curPt)
        if (Abs(NumGet(curPt, 0, "int") - startX) > 5 || Abs(NumGet(curPt, 4, "int") - startY) > 5) {
            isDrag := true
            break
        }
        Sleep 15
    }

    if (!isDrag)
        return

    lastHovered := ""
    while GetKeyState("LButton", "P") {
        curHovered := FindButtonUnderCursor()
        if (curHovered != lastHovered) {
            if (lastHovered != "" && cards.Has(lastHovered)) {
                cards[lastHovered].Opt("Background1E1E2E cCDD6F4")
                cards[lastHovered].Redraw()
            }
            if (curHovered != "" && cards.Has(curHovered)) {
                cards[curHovered].Opt("BackgroundFAB387 c11111B")
                cards[curHovered].Redraw()
            }
            lastHovered := curHovered
        }

        if (curHovered != "") {
            ToolTip("✨ Drop onto " . points[curHovered].name . " to map '" . cmdName . "'!")
        } else {
            ToolTip("📌 Dragging: " . cmdName . "`nDrop onto button or diagram")
        }
        Sleep 20
    }

    ToolTip()
    if (lastHovered != "" && cards.Has(lastHovered)) {
        cards[lastHovered].Opt("Background1E1E2E cCDD6F4")
        cards[lastHovered].Redraw()
    }

    finalDrop := FindButtonUnderCursor()
    if (finalDrop != "" && cards.Has(finalDrop)) {
        cards[finalDrop].Text := finalDrop . ": " . cmdName
        SoundBeep(1200, 80)
    }
}
#HotIf

g.Show("w1120 h540")
