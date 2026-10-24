#Requires AutoHotkey v2.0

/**
 * Sleek On-Screen Display (OSD) Notification for G502 X Manager
 * Displays non-intrusive floating HUD notifications that do not steal focus.
 */
class OSD {
    static guiObj := ""
    static textTitle := ""
    static textSub := ""
    static timerCallback := ""

    static Init() {
        if (this.guiObj != "")
            return

        ; Create a layered, transparent, click-through, always-on-top window
        ; +E0x08000000 = WS_EX_NOACTIVATE (prevents taking focus)
        ; +E0x00000020 = WS_EX_TRANSPARENT (click-through)
        this.guiObj := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000 +E0x00000020")
        this.guiObj.BackColor := "181825"
        
        ; Rounded look and border simulation
        this.guiObj.MarginX := 20
        this.guiObj.MarginY := 14

        this.guiObj.SetFont("s11 bold c89B4FA", "Segoe UI")
        this.textTitle := this.guiObj.Add("Text", "w260 Center", "G502 X")

        this.guiObj.SetFont("s9 norm cCDD6F4", "Segoe UI")
        this.textSub := this.guiObj.Add("Text", "w260 Center y+4", "")
    }

    static hideFn := () => OSD.Hide()

    static Show(title, subtitle := "", durationMs := 1400) {
        this.Init()

        this.textTitle.Value := title
        this.textSub.Value := subtitle

        ; Calculate position: bottom right, above taskbar
        MonIndex := 1
        MonitorGetWorkArea(MonIndex, &WL, &WT, &WR, &WB)
        
        guiW := 300
        guiH := (subtitle != "") ? 74 : 52
        posX := WR - guiW - 30
        posY := WB - guiH - 30

        ; Show window with animation
        this.guiObj.Show("x" . posX . " y" . posY . " w" . guiW . " h" . guiH . " NoActivate")
        WinSetTransparent(235, this.guiObj.Hwnd)

        ; Reset hide timer
        SetTimer(this.hideFn, 0)
        SetTimer(this.hideFn, -durationMs)
    }

    static Hide() {
        if (OSD.guiObj != "") {
            OSD.guiObj.Hide()
        }
    }
}
