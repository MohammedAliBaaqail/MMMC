#Requires AutoHotkey v2.0

g := Gui("+AlwaysOnTop", "Test B-Shift Toggle Switch")
g.BackColor := "181825"

diagramPath := A_ScriptDir . "\assets\g502x_diagram.png"
if FileExist(diagramPath)
    g.Add("Picture", "x20 y20 w500 h300", diagramPath)

; Switch 1
g.SetFont("s10 bold cFFFFFF", "Segoe UI")
lblDef1 := g.Add("Text", "x150 y340 w75 h24 0x202", "DEFAULT")
picTog1 := g.Add("Picture", "x232 y340 w46 h24 +BackgroundTrans", A_ScriptDir . "\assets\toggle_off.png")
g.SetFont("s10 bold c6C7086", "Segoe UI")
lblBShift1 := g.Add("Text", "x286 y340 w180 h24 0x200", "B-SHIFT (DPI Shift)")

currentLayer := "Normal"

UpdateVisual() {
    isNorm := (currentLayer = "Normal")
    picTog1.Value := isNorm ? (A_ScriptDir . "\assets\toggle_off.png") : (A_ScriptDir . "\assets\toggle_on.png")
    lblDef1.SetFont(isNorm ? "s10 bold cFFFFFF" : "s10 bold c6C7086")
    lblBShift1.SetFont(isNorm ? "s10 bold c6C7086" : "s10 bold c89B4FA")
}

Toggle() {
    global currentLayer := (currentLayer = "Normal") ? "GShift" : "Normal"
    UpdateVisual()
}

lblDef1.OnEvent("Click", (*) => (global currentLayer := "Normal", UpdateVisual()))
picTog1.OnEvent("Click", (*) => Toggle())
lblBShift1.OnEvent("Click", (*) => (global currentLayer := "GShift", UpdateVisual()))

g.Show("w600 h400")
Sleep(500)
ExitApp(0)
