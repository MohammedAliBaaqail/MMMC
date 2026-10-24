#Requires AutoHotkey v2.0

g := Gui()
g.BackColor := "181825"
g.SetFont("s9 bold cCDD6F4", "Segoe UI")

lv := g.Add("ListView", "x20 y20 w220 h350 Background1E1E2E +Report -Hdr", ["Cat", "Action", "Key"])
lv.ModifyCol(1, 0)
lv.ModifyCol(2, 140)
lv.ModifyCol(3, "Right 70")

lv.Add("", "Nav", "Copy", "^c")
lv.Add("", "Nav", "Paste", "^v")
lv.Add("", "Nav", "Browser Back", "!{Left}")
lv.Add("", "Nav", "Browser Forward", "!{Right}")
lv.Add("", "Nav", "Volume Up", "{Volume_Up}")

card1 := g.Add("Text", "x280 y40 w150 h24 Center 0x200 Background1E1E2E +Border cCDD6F4", "G8: Default")
card1.ButtonId := "G8"
card1.ButtonName := "G8 (DPI Up)"

card2 := g.Add("Text", "x280 y100 w150 h24 Center 0x200 Background1E1E2E +Border cCDD6F4", "G7: Default")
card2.ButtonId := "G7"
card2.ButtonName := "G7 (DPI Down)"

card3 := g.Add("Text", "x280 y160 w150 h24 Center 0x200 Background1E1E2E +Border cCDD6F4", "Forward: Default")
card3.ButtonId := "Forward"
card3.ButtonName := "G5 (Forward)"

statusText := g.Add("Text", "x20 y390 w400 h30 c89B4FA", "Ready. Click & drag any command from the list to a button card.")

cards := [card1, card2, card3]

LV_GetRowAt(lvHwnd, clientX, clientY) {
    hti := Buffer(24, 0)
    NumPut("int", clientX, hti, 0)
    NumPut("int", clientY, hti, 4)
    rowIdx := DllCall("SendMessage", "ptr", lvHwnd, "uint", 0x1012, "ptr", 0, "ptr", hti, "int")
    return (rowIdx >= 0) ? (rowIdx + 1) : 0
}

#HotIf WinActive("ahk_id " . g.Hwnd)
~LButton:: {
    CoordMode("Mouse", "Client")
    MouseGetPos(&mX, &mY, &mWin, &mCtrl, 2)
    if (mCtrl != lv.Hwnd)
        return

    ; Convert client coords to ListView control relative coords
    winRect := Buffer(16, 0)
    DllCall("GetWindowRect", "ptr", lv.Hwnd, "ptr", winRect)
    pt := Buffer(8, 0)
    DllCall("GetCursorPos", "ptr", pt)
    DllCall("ScreenToClient", "ptr", lv.Hwnd, "ptr", pt)
    lvX := NumGet(pt, 0, "int")
    lvY := NumGet(pt, 4, "int")

    clickedRow := LV_GetRowAt(lv.Hwnd, lvX, lvY)
    if (clickedRow <= 0)
        return

    cmdName := Trim(lv.GetText(clickedRow, 2))
    if (cmdName = "" || InStr(lv.GetText(clickedRow, 1), "__SECTION__:"))
        return

    ; Check if user drags beyond threshold
    startX := mX, startY := mY
    isDrag := false
    while GetKeyState("LButton", "P") {
        MouseGetPos(&curX, &curY)
        if (Abs(curX - startX) > 6 || Abs(curY - startY) > 6) {
            isDrag := true
            break
        }
        Sleep 15
    }

    if (!isDrag)
        return

    ; Actively dragging!
    lastHovered := ""
    while GetKeyState("LButton", "P") {
        MouseGetPos(&curX, &curY, &hoverWin, &hoverCtrl, 2)
        
        currentHovered := ""
        for c in cards {
            if (hoverCtrl = c.Hwnd) {
                currentHovered := c
                break
            }
        }

        if (currentHovered != lastHovered) {
            ; Reset previous
            if (lastHovered != "") {
                lastHovered.Opt("Background1E1E2E cCDD6F4")
                lastHovered.Redraw()
            }
            ; Highlight new
            if (currentHovered != "") {
                currentHovered.Opt("BackgroundFAB387 c11111B")
                currentHovered.Redraw()
            }
            lastHovered := currentHovered
        }

        if (currentHovered != "") {
            ToolTip("✨ Drop onto " . currentHovered.ButtonName . " to map!")
        } else {
            ToolTip("📌 Dragging: " . cmdName . "`nDrop onto any button")
        }
        Sleep 20
    }

    ; Released!
    ToolTip()
    if (lastHovered != "") {
        lastHovered.Opt("Background1E1E2E cCDD6F4")
        lastHovered.Redraw()
    }

    MouseGetPos(&endX, &endY, &endWin, &endCtrl, 2)
    droppedCard := ""
    for c in cards {
        if (endCtrl = c.Hwnd) {
            droppedCard := c
            break
        }
    }

    if (droppedCard != "") {
        droppedCard.Text := droppedCard.ButtonId . ": " . cmdName
        statusText.Value := "🎉 Success! Mapped '" . cmdName . "' to " . droppedCard.ButtonName
        SoundBeep(1200, 80)
    } else {
        statusText.Value := "Drag cancelled (not dropped on a button)"
    }
}
#HotIf

g.Show("w460 h440")
