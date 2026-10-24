#Requires AutoHotkey v2.0

g := Gui()
g.BackColor := "181825"
g.SetFont("s9 bold cCDD6F4", "Segoe UI")

lv := g.Add("ListView", "x20 y20 w200 h300 Background1E1E2E", ["Action", "Key"])
lv.Add("", "Copy", "^c")
lv.Add("", "Paste", "^v")
lv.Add("", "Cut", "^x")
lv.Add("", "Undo", "^z")

card1 := g.Add("Text", "x260 y50 w140 h30 Center 0x200 Background1E1E2E +Border cCDD6F4", "Button G8")
card1.ButtonId := "G8"

card2 := g.Add("Text", "x260 y120 w140 h30 Center 0x200 Background1E1E2E +Border cCDD6F4", "Button G7")
card2.ButtonId := "G7"

statusText := g.Add("Text", "x20 y340 w380 h30 c89B4FA", "Ready. Click & drag an item to a button.")

; Track drag state
global isDragging := false
global dragData := ""

; When LButton is pressed over ListView, check if dragging starts
~LButton:: {
    global isDragging, dragData
    CoordMode("Mouse", "Window")
    MouseGetPos(&mX, &mY, &mWin, &mCtrl, 2)
    if (mCtrl != lv.Hwnd)
        return

    row := lv.GetNext(0)
    if (row <= 0)
        return

    cmdName := lv.GetText(row, 1)
    if (cmdName = "")
        return

    ; Wait to see if mouse moves more than 4px while holding LButton
    startX := mX, startY := mY
    while GetKeyState("LButton", "P") {
        MouseGetPos(&curX, &curY)
        if (Abs(curX - startX) > 5 || Abs(curY - startY) > 5) {
            ; Drag threshold reached!
            isDragging := true
            dragData := cmdName
            break
        }
        Sleep 15
    }

    if (!isDragging)
        return

    ; Drag loop
    ToolTip("📌 Dragging: " . dragData . "`nDrop onto a button")
    while GetKeyState("LButton", "P") {
        MouseGetPos(&curX, &curY, &hoverWin, &hoverCtrl, 2)
        if (hoverCtrl = card1.Hwnd) {
            ToolTip("✨ Drop onto " . card1.ButtonId . "!")
        } else if (hoverCtrl = card2.Hwnd) {
            ToolTip("✨ Drop onto " . card2.ButtonId . "!")
        } else {
            ToolTip("📌 Dragging: " . dragData . "`nDrop onto a button")
        }
        Sleep 20
    }

    ; Released LButton!
    ToolTip()
    MouseGetPos(&endX, &endY, &endWin, &endCtrl, 2)
    if (endCtrl = card1.Hwnd) {
        card1.Text := "G8: " . dragData
        statusText.Value := "Success! Mapped " . dragData . " to G8"
    } else if (endCtrl = card2.Hwnd) {
        card2.Text := "G7: " . dragData
        statusText.Value := "Success! Mapped " . dragData . " to G7"
    } else {
        statusText.Value := "Drag cancelled (not dropped on a button)"
    }
    isDragging := false
    dragData := ""
}

g.Show("w440 h400")
