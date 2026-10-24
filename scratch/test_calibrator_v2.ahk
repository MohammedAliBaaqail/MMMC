#Requires AutoHotkey v2.0

class CalibrateWindowTest {
    static DefaultPoints := Map(
        "TiltLeft",     { name: "Tilt Left [F17]",      ax: 170, ay: 50,  tx: 338, ty: 64,  tag: "TL" },
        "Middle",       { name: "Middle Click [F13]",   ax: 650, ay: 115, tx: 355, ty: 58,  tag: "MID" },
        "TiltRight",    { name: "Tilt Right [F18]",     ax: 650, ay: 50,  tx: 374, ty: 64,  tag: "TR" },
        "G8",           { name: "G8 (DPI Up) [F20]",    ax: 170, ay: 115, tx: 228, ty: 106, tag: "G8" },
        "G7",           { name: "G7 (DPI Down) [F21]",  ax: 170, ay: 175, tx: 242, ty: 126, tag: "G7" },
        "DpiShift",     { name: "DPI Shift [F15]",      ax: 170, ay: 245, tx: 270, ty: 264, tag: "DPI" },
        "Forward",      { name: "G5 (Forward) [F16]",   ax: 170, ay: 315, tx: 308, ty: 248, tag: "G5" },
        "Back",         { name: "G4 (Back) [F14]",      ax: 170, ay: 385, tx: 352, ty: 272, tag: "G4" },
        "ProfileCycle", { name: "G9 (Profile) [F19]",   ax: 650, ay: 180, tx: 426, ty: 92,  tag: "G9" }
    )

    static ButtonOrder := ["TiltLeft", "Middle", "TiltRight", "G8", "G7", "DpiShift", "Forward", "Back", "ProfileCycle"]
    static CurrentPoints := Map()
    static SelectedId := "G8"
    static StepSize := 2
    static Markers := Map()
    static SelectorBtns := Map()
    static Dlg := ""
    static InfoText := ""
    static CanvasPic := ""
    static CanvasX := 80
    static CanvasY := 140
    static CanvasW := 860
    static CanvasH := 500

    static Show() {
        this.LoadPoints()

        g := Gui("+AlwaysOnTop -MinimizeBox", "🎯 G502 X Button Pointer Calibration")
        this.Dlg := g
        g.BackColor := "181825"

        ; Header
        g.SetFont("s13 bold cCDD6F4", "Segoe UI")
        g.Add("Text", "x20 y12 w800", "🎯 Logitech G502 X Button Pointer Calibration")
        g.SetFont("s9 norm cA6ADC8", "Segoe UI")
        g.Add("Text", "x20 y38 w980", 
            "1. Select a button below.`n"
            . "2. CLICK DIRECTLY ON THE MOUSE to place its target point at that exact position.`n"
            . "3. Fine-tune with Arrow keys (◄ ▲ ▼ ►) or Nudge buttons.`n"
            . "4. Click 'Preview Lines' to see leader lines live, then 'Save & Apply' when satisfied.")

        ; Selector buttons
        bx := 20, by := 88, bw := 105, bh := 32
        this.SelectorBtns := Map()
        for id in this.ButtonOrder {
            info := this.CurrentPoints[id]
            g.SetFont("s9 bold cCDD6F4", "Segoe UI")
            btn := g.Add("Button", "x" . bx . " y" . by . " w" . bw . " h" . bh, info.tag . ": " . id)
            btn.ButtonId := id
            btn.OnEvent("Click", (ctrl, *) => this.SelectButton(ctrl.ButtonId))
            this.SelectorBtns[id] := btn
            bx += bw + 5
        }

        ; Coordinate readout & Nudge controls
        g.SetFont("s10 bold c89B4FA", "Segoe UI")
        this.InfoText := g.Add("Text", "x20 y" . (this.CanvasY + this.CanvasH + 15) . " w450 h28 0x200", "")

        ; Nudge controls
        nx := 480, ny := this.CanvasY + this.CanvasH + 12
        g.SetFont("s9 bold cA6ADC8", "Segoe UI")
        g.Add("Text", "x" . nx . " y" . (ny + 4) . " w55 h24", "Nudge:")
        btnLeft := g.Add("Button", "x" . (nx + 55) . " y" . ny . " w40 h26", "◄")
        btnLeft.OnEvent("Click", (*) => this.Nudge(-this.StepSize, 0))
        btnUp := g.Add("Button", "x+4 y" . ny . " w40 h26", "▲")
        btnUp.OnEvent("Click", (*) => this.Nudge(0, -this.StepSize))
        btnDown := g.Add("Button", "x+4 y" . ny . " w40 h26", "▼")
        btnDown.OnEvent("Click", (*) => this.Nudge(0, this.StepSize))
        btnRight := g.Add("Button", "x+4 y" . ny . " w40 h26", "►")
        btnRight.OnEvent("Click", (*) => this.Nudge(this.StepSize, 0))

        ; Step toggle
        btnStep := g.Add("Button", "x+10 y" . ny . " w85 h26", "Step: " . this.StepSize . "px")
        btnStep.OnEvent("Click", (ctrl, *) => this.ToggleStep(ctrl))

        ; Bottom action row
        ay := ny + 45
        g.SetFont("s10 bold c89B4FA", "Segoe UI")
        btnPreview := g.Add("Button", "x340 y" . ay . " w160 h36", "👁️ Preview Lines")
        btnPreview.OnEvent("Click", (*) => this.PreviewLines())

        g.SetFont("s10 bold cA6E3A1", "Segoe UI")
        btnSave := g.Add("Button", "x510 y" . ay . " w160 h36", "💾 Save & Apply")
        btnSave.OnEvent("Click", (*) => this.SaveAndApply())

        g.SetFont("s10 bold cFAB387", "Segoe UI")
        btnReset := g.Add("Button", "x680 y" . ay . " w150 h36", "🔄 Reset Defaults")
        btnReset.OnEvent("Click", (*) => this.ResetDefaults())

        g.SetFont("s10 bold cF38BA8", "Segoe UI")
        btnCancel := g.Add("Button", "x840 y" . ay . " w100 h36", "Cancel")
        btnCancel.OnEvent("Click", (*) => g.Destroy())

        ; Canvas background and diagram
        rootDir := InStr(A_ScriptDir, "scratch") ? SubStr(A_ScriptDir, 1, InStr(A_ScriptDir, "\scratch",, -1)-1) : A_ScriptDir
        diagramPath := rootDir . "\assets\g502x_diagram.png"
        cleanPath   := rootDir . "\assets\g502x.png"
        bgPath      := FileExist(diagramPath) ? diagramPath : cleanPath

        g.Add("Text", "x" . (this.CanvasX - 2) . " y" . (this.CanvasY - 2) . " w" . (this.CanvasW + 4) . " h" . (this.CanvasH + 4) . " Background11111B +Border")
        this.CanvasPic := g.Add("Picture", "x" . this.CanvasX . " y" . this.CanvasY . " w" . this.CanvasW . " h" . this.CanvasH . " +BackgroundTrans", bgPath)
        this.CanvasPic.OnEvent("Click", (ctrl, *) => this.OnCanvasClick())

        ; Marker badges
        this.Markers := Map()
        for id in this.ButtonOrder {
            pt := this.CurrentPoints[id]
            mx := this.CanvasX + pt.tx - 13
            my := this.CanvasY + pt.ty - 13
            m := g.Add("Text", "x" . mx . " y" . my . " w26 h26 Center 0x200 Background1E1E2E c89B4FA +Border", pt.tag)
            m.ButtonId := id
            m.OnEvent("Click", (ctrl, *) => this.SelectButton(ctrl.ButtonId))
            this.Markers[id] := m
        }

        ; Register keyboard handler
        g.OnEvent("Close", (*) => this.Cleanup())
        g.OnEvent("Escape", (*) => g.Destroy())
        OnMessage(0x0100, this.OnKeyDownHandler.Bind(this))

        this.SelectButton("G8")
        g.Show("w1020 h750")
    }

    static SelectButton(id) {
        this.SelectedId := id
        for bid, btn in this.SelectorBtns {
            if (bid = id) {
                btn.SetFont("s9 bold cFAB387")
            } else {
                btn.SetFont("s9 bold cCDD6F4")
            }
        }
        for bid, m in this.Markers {
            pt := this.CurrentPoints[bid]
            if (bid = id) {
                m.Opt("BackgroundFAB387 c11111B")
                m.Redraw()
            } else {
                m.Opt("Background1E1E2E c89B4FA")
                m.Redraw()
            }
        }
        this.UpdateStatus()
    }

    static UpdateStatus() {
        if (!this.CurrentPoints.Has(this.SelectedId))
            return
        pt := this.CurrentPoints[this.SelectedId]
        this.InfoText.Value := "Selected: " . pt.name . " | Target: X = " . pt.tx . ", Y = " . pt.ty
    }

    static OnCanvasClick() {
        CoordMode("Mouse", "Client")
        MouseGetPos(&mX, &mY)

        targetX := mX - this.CanvasX
        targetY := mY - this.CanvasY

        targetX := Max(10, Min(this.CanvasW - 10, targetX))
        targetY := Max(10, Min(this.CanvasH - 10, targetY))

        pt := this.CurrentPoints[this.SelectedId]
        pt.tx := targetX
        pt.ty := targetY

        m := this.Markers[this.SelectedId]
        m.Move(this.CanvasX + targetX - 13, this.CanvasY + targetY - 13)
        this.UpdateStatus()
    }

    static Nudge(dx, dy) {
        if (!this.CurrentPoints.Has(this.SelectedId))
            return
        pt := this.CurrentPoints[this.SelectedId]
        pt.tx := Max(10, Min(this.CanvasW - 10, pt.tx + dx))
        pt.ty := Max(10, Min(this.CanvasH - 10, pt.ty + dy))

        m := this.Markers[this.SelectedId]
        m.Move(this.CanvasX + pt.tx - 13, this.CanvasY + pt.ty - 13)
        this.UpdateStatus()
    }

    static OnKeyDownHandler(wParam, lParam, msg, hwnd) {
        if (!this.Dlg || !WinExist(this.Dlg.Hwnd) || !WinActive(this.Dlg.Hwnd))
            return

        ; 37: Left, 38: Up, 39: Right, 40: Down
        switch wParam {
            case 37: this.Nudge(-this.StepSize, 0), return 0
            case 38: this.Nudge(0, -this.StepSize), return 0
            case 39: this.Nudge(this.StepSize, 0), return 0
            case 40: this.Nudge(0, this.StepSize), return 0
        }
    }

    static ToggleStep(ctrl) {
        this.StepSize := (this.StepSize = 1) ? 2 : ((this.StepSize = 2) ? 5 : ((this.StepSize = 5) ? 10 : 1))
        ctrl.Text := "Step: " . this.StepSize . "px"
    }

    static LoadPoints() {
        this.CurrentPoints := Map()
        rootDir := InStr(A_ScriptDir, "scratch") ? SubStr(A_ScriptDir, 1, InStr(A_ScriptDir, "\scratch",, -1)-1) : A_ScriptDir
        iniPath := rootDir . "\settings.ini"

        for id, def in this.DefaultPoints {
            defTx := def.tx
            defTy := def.ty
            if FileExist(iniPath) {
                try {
                    iniX := IniRead(iniPath, "DiagramPoints", id . "_X", "")
                    iniY := IniRead(iniPath, "DiagramPoints", id . "_Y", "")
                    if (iniX != "" && IsInteger(iniX))
                        defTx := Integer(iniX)
                    if (iniY != "" && IsInteger(iniY))
                        defTy := Integer(iniY)
                }
            }
            this.CurrentPoints[id] := { name: def.name, ax: def.ax, ay: def.ay, tx: defTx, ty: defTy, tag: def.tag }
        }
    }

    static PreviewLines() {
        this.SaveToIniOnly()
        rootDir := InStr(A_ScriptDir, "scratch") ? SubStr(A_ScriptDir, 1, InStr(A_ScriptDir, "\scratch",, -1)-1) : A_ScriptDir
        psScript := rootDir . "\lib\render_diagram.ps1"
        diagramPath := rootDir . "\assets\g502x_diagram.png"
        if FileExist(psScript) {
            RunWait('powershell -ExecutionPolicy Bypass -File "' . psScript . '"', rootDir, "Hide")
            if (this.CanvasPic != "")
                this.CanvasPic.Value := diagramPath
        }
    }

    static SaveToIniOnly() {
        rootDir := InStr(A_ScriptDir, "scratch") ? SubStr(A_ScriptDir, 1, InStr(A_ScriptDir, "\scratch",, -1)-1) : A_ScriptDir
        iniPath := rootDir . "\settings.ini"
        for id, pt in this.CurrentPoints {
            IniWrite(pt.tx, iniPath, "DiagramPoints", id . "_X")
            IniWrite(pt.ty, iniPath, "DiagramPoints", id . "_Y")
        }
    }

    static SaveAndApply() {
        this.SaveToIniOnly()
        rootDir := InStr(A_ScriptDir, "scratch") ? SubStr(A_ScriptDir, 1, InStr(A_ScriptDir, "\scratch",, -1)-1) : A_ScriptDir
        psScript := rootDir . "\lib\render_diagram.ps1"
        if FileExist(psScript) {
            RunWait('powershell -ExecutionPolicy Bypass -File "' . psScript . '"', rootDir, "Hide")
        }
        MsgBox("Calibration saved and applied successfully!", "Pointer Calibration", "64")
        this.Cleanup()
        this.Dlg.Destroy()
    }

    static ResetDefaults() {
        for id, def in this.DefaultPoints {
            pt := this.CurrentPoints[id]
            pt.tx := def.tx
            pt.ty := def.ty
            m := this.Markers[id]
            m.Move(this.CanvasX + pt.tx - 13, this.CanvasY + pt.ty - 13)
        }
        this.UpdateStatus()
    }

    static Cleanup() {
        OnMessage(0x0100, this.OnKeyDownHandler.Bind(this), 0)
    }
}

CalibrateWindowTest.Show()
