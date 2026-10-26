#Requires AutoHotkey v2.0

class GdipHelper {
    static pToken := 0
    static Init() {
        if (this.pToken != 0)
            return true
        DllCall("LoadLibrary", "Str", "gdiplus.dll", "Ptr")
        si := Buffer(24, 0)
        NumPut("UInt", 1, si, 0)
        token := 0
        if (DllCall("gdiplus\GdiplusStartup", "Ptr*", &token, "Ptr", si.Ptr, "Ptr", 0) == 0) {
            this.pToken := token
            return true
        }
        return false
    }
    static Shutdown() {
        if (this.pToken != 0) {
            DllCall("gdiplus\GdiplusShutdown", "Ptr", this.pToken)
            this.pToken := 0
        }
    }
}

/**
 * Sleek On-Screen Display (OSD) Notification for My Mouse My Choice
 * Displays non-intrusive floating HUD notifications with rounded corners and border.
 */
class OSD {
    static guiObj := ""
    static Enabled := true
    static hideFn := () => OSD.Hide()

    static Init() {
        if (this.guiObj != "")
            return

        ; Initialize GDI+ safely
        GdipHelper.Init()

        ; Create layered, click-through, non-activating, always-on-top window
        ; +E0x08000000 = WS_EX_NOACTIVATE (never takes focus from games/apps)
        ; +E0x00000020 = WS_EX_TRANSPARENT (click-through)
        ; +E0x00080000 = WS_EX_LAYERED (per-pixel 32-bit ARGB alpha blending)
        ; -DPIScale ensures 1:1 pixel rendering with our GDI+ buffer
        this.guiObj := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000000 +E0x00000020 +E0x00080000")
    }

    static ShowIcon(iconPath := "", durationMs := 1200) {
        if (!this.Enabled)
            return

        this.Init()

        dpiScale := A_ScreenDPI / 96.0

        ; Compact 56x56 square pill HUD
        guiW := Round(56 * dpiScale)
        guiH := Round(56 * dpiScale)
        cornerRadius := 14.0 * dpiScale

        ; Setup 32-bit ARGB DIB section for per-pixel alpha rendering
        hDC := DllCall("GetDC", "ptr", 0, "ptr")
        hMemDC := DllCall("CreateCompatibleDC", "ptr", hDC, "ptr")

        bi := Buffer(40, 0)
        NumPut("uint", 40, bi, 0)
        NumPut("int", guiW, bi, 4)
        NumPut("int", -guiH, bi, 8) ; Top-down DIB
        NumPut("ushort", 1, bi, 12)
        NumPut("ushort", 32, bi, 14) ; 32 bpp
        NumPut("uint", 0, bi, 16)   ; BI_RGB

        pBits := 0
        hBmp := DllCall("CreateDIBSection", "ptr", hMemDC, "ptr", bi, "uint", 0, "ptr*", &pBits, "ptr", 0, "uint", 0, "ptr")
        hOldBmp := DllCall("SelectObject", "ptr", hMemDC, "ptr", hBmp, "ptr")

        pGraphics := 0
        DllCall("gdiplus\GdipCreateFromHDC", "ptr", hMemDC, "ptr*", &pGraphics)
        DllCall("gdiplus\GdipSetSmoothingMode", "ptr", pGraphics, "int", 4) ; AntiAlias

        ; Create rounded rectangle path with subtle subpixel inset for clean border rendering
        inset := 1.2 * dpiScale
        r := cornerRadius
        d := r * 2.0
        rw := Float(guiW) - (inset * 2.0)
        rh := Float(guiH) - (inset * 2.0)

        pPath := 0
        DllCall("gdiplus\GdipCreatePath", "int", 0, "ptr*", &pPath)
        DllCall("gdiplus\GdipAddPathArc", "ptr", pPath, "float", inset, "float", inset, "float", d, "float", d, "float", 180, "float", 90)
        DllCall("gdiplus\GdipAddPathArc", "ptr", pPath, "float", inset + rw - d, "float", inset, "float", d, "float", d, "float", 270, "float", 90)
        DllCall("gdiplus\GdipAddPathArc", "ptr", pPath, "float", inset + rw - d, "float", inset + rh - d, "float", d, "float", d, "float", 0, "float", 90)
        DllCall("gdiplus\GdipAddPathArc", "ptr", pPath, "float", inset, "float", inset + rh - d, "float", d, "float", d, "float", 90, "float", 90)
        DllCall("gdiplus\GdipClosePathFigure", "ptr", pPath)

        ; Subtle obsidian gradient background (95% opacity)
        ptStart := Buffer(8, 0), ptEnd := Buffer(8, 0)
        NumPut("float", 0.0, ptStart, 0), NumPut("float", 0.0, ptStart, 4)
        NumPut("float", 0.0, ptEnd, 0), NumPut("float", Float(guiH), ptEnd, 4)
        pBgBrush := 0
        DllCall("gdiplus\GdipCreateLineBrush", "ptr", ptStart, "ptr", ptEnd, "uint", 0xF5111724, "uint", 0xF8090c12, "int", 0, "ptr*", &pBgBrush)
        DllCall("gdiplus\GdipFillPath", "ptr", pGraphics, "ptr", pBgBrush, "ptr", pPath)

        ; Crisp glowing cyan border on ALL 4 sides with anti-aliasing (1.5px 0xFF00D2FF)
        penW := 1.5 * dpiScale
        pPen := 0
        DllCall("gdiplus\GdipCreatePen1", "uint", 0xFF00D2FF, "float", penW, "int", 2, "ptr*", &pPen)
        DllCall("gdiplus\GdipDrawPath", "ptr", pGraphics, "ptr", pPen, "ptr", pPath)

        ; Render Icon centered without any text
        pBitmap := 0
        if (iconPath != "" && FileExist(iconPath)) {
            SplitPath(iconPath, , , &ext)
            if (StrLower(ext) != "exe") {
                DllCall("gdiplus\GdipCreateBitmapFromFile", "wstr", iconPath, "ptr*", &pBitmap)
            }
            if (!pBitmap) {
                pathBuf := Buffer(520, 0)
                StrPut(iconPath, pathBuf, "UTF-16")
                idx := 0
                hIcon := DllCall("shell32\ExtractAssociatedIcon", "Ptr", 0, "Ptr", pathBuf.Ptr, "Short*", &idx, "Ptr")
                if (hIcon) {
                    DllCall("gdiplus\GdipCreateBitmapFromHICON", "Ptr", hIcon, "Ptr*", &pBitmap)
                    DllCall("user32\DestroyIcon", "Ptr", hIcon)
                }
            }
        }

        if (pBitmap) {
            imgW := 0, imgH := 0
            DllCall("gdiplus\GdipGetImageWidth", "ptr", pBitmap, "uint*", &imgW)
            DllCall("gdiplus\GdipGetImageHeight", "ptr", pBitmap, "uint*", &imgH)

            if (imgW > 0 && imgH > 0) {
                maxBox := 34.0 * dpiScale
                scale := Min(maxBox / imgW, maxBox / imgH)
                drawW := imgW * scale
                drawH := imgH * scale
                dstX := (Float(guiW) - drawW) / 2.0
                dstY := (Float(guiH) - drawH) / 2.0

                DllCall("gdiplus\GdipSetInterpolationMode", "ptr", pGraphics, "int", 7) ; HighQualityBicubic
                DllCall("gdiplus\GdipDrawImageRectRect", "ptr", pGraphics, "ptr", pBitmap
                    , "float", dstX, "float", dstY, "float", drawW, "float", drawH
                    , "float", 0.0, "float", 0.0, "float", Float(imgW), "float", Float(imgH)
                    , "int", 2, "ptr", 0, "ptr", 0, "ptr", 0)
            }
            DllCall("gdiplus\GdipDisposeImage", "ptr", pBitmap)
        }

        ; Calculate position: bottom right of active monitor where mouse cursor is
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mX, &mY)
        monCount := MonitorGetCount()
        monIndex := 1
        Loop monCount {
            MonitorGet(A_Index, &mL, &mT, &mR, &mB)
            if (mX >= mL && mX < mR && mY >= mT && mY < mB) {
                monIndex := A_Index
                break
            }
        }
        MonitorGetWorkArea(monIndex, &WL, &WT, &WR, &WB)

        posX := WR - guiW - Round(24 * dpiScale)
        posY := WB - guiH - Round(24 * dpiScale)

        ptDst := Buffer(8, 0)
        NumPut("int", posX, ptDst, 0)
        NumPut("int", posY, ptDst, 4)

        sz := Buffer(8, 0)
        NumPut("int", guiW, sz, 0)
        NumPut("int", guiH, sz, 4)

        ptSrc := Buffer(8, 0)
        NumPut("int", 0, ptSrc, 0)
        NumPut("int", 0, ptSrc, 4)

        blend := Buffer(4, 0)
        NumPut("uchar", 0, blend, 0)   ; AC_SRC_OVER
        NumPut("uchar", 0, blend, 1)   ; Flags
        NumPut("uchar", 255, blend, 2) ; SourceConstantAlpha
        NumPut("uchar", 1, blend, 3)   ; AC_SRC_ALPHA

        this.guiObj.Show("x" . posX . " y" . posY . " w" . guiW . " h" . guiH . " NoActivate")
        DllCall("UpdateLayeredWindow", "ptr", this.guiObj.Hwnd, "ptr", hDC, "ptr", ptDst, "ptr", sz, "ptr", hMemDC, "ptr", ptSrc, "uint", 0, "ptr", blend, "uint", 2)

        ; Cleanup GDI+ drawing resources
        DllCall("gdiplus\GdipDeleteBrush", "ptr", pBgBrush)
        DllCall("gdiplus\GdipDeletePen", "ptr", pPen)
        DllCall("gdiplus\GdipDeletePath", "ptr", pPath)
        DllCall("gdiplus\GdipDeleteGraphics", "ptr", pGraphics)

        DllCall("SelectObject", "ptr", hMemDC, "ptr", hOldBmp)
        DllCall("DeleteObject", "ptr", hBmp)
        DllCall("DeleteDC", "ptr", hMemDC)
        DllCall("ReleaseDC", "ptr", 0, "ptr", hDC)

        ; Reset hide timer
        SetTimer(this.hideFn, 0)
        SetTimer(this.hideFn, -durationMs)
    }

    static Show(title, subtitle := "", durationMs := 1200) {
        if (!this.Enabled)
            return

        this.Init()

        dpiScale := A_ScreenDPI / 96.0

        hasSubtitle := (subtitle != "")
        if (hasSubtitle) {
            maxLen := Max(StrLen(title) * 9.5, StrLen(subtitle) * 8.2)
            guiW := Round(Max(330, maxLen + 48) * dpiScale)
            guiH := Round(66 * dpiScale)
        } else {
            guiW := Round(Max(270, StrLen(title) * 9.5 + 44) * dpiScale)
            guiH := Round(44 * dpiScale)
        }
        cornerRadius := 12.0 * dpiScale

        ; Setup 32-bit ARGB DIB section for per-pixel alpha rendering
        hDC := DllCall("GetDC", "ptr", 0, "ptr")
        hMemDC := DllCall("CreateCompatibleDC", "ptr", hDC, "ptr")

        bi := Buffer(40, 0)
        NumPut("uint", 40, bi, 0)
        NumPut("int", guiW, bi, 4)
        NumPut("int", -guiH, bi, 8) ; Top-down DIB
        NumPut("ushort", 1, bi, 12)
        NumPut("ushort", 32, bi, 14) ; 32 bpp
        NumPut("uint", 0, bi, 16)   ; BI_RGB

        pBits := 0
        hBmp := DllCall("CreateDIBSection", "ptr", hMemDC, "ptr", bi, "uint", 0, "ptr*", &pBits, "ptr", 0, "uint", 0, "ptr")
        hOldBmp := DllCall("SelectObject", "ptr", hMemDC, "ptr", hBmp, "ptr")

        pGraphics := 0
        DllCall("gdiplus\GdipCreateFromHDC", "ptr", hMemDC, "ptr*", &pGraphics)
        DllCall("gdiplus\GdipSetSmoothingMode", "ptr", pGraphics, "int", 4) ; AntiAlias
        DllCall("gdiplus\GdipSetTextRenderingHint", "ptr", pGraphics, "int", 4) ; AntiAliasGridFit

        ; Create rounded rectangle path with subtle subpixel inset for clean border rendering
        inset := 1.2 * dpiScale
        r := cornerRadius
        d := r * 2.0
        rw := Float(guiW) - (inset * 2.0)
        rh := Float(guiH) - (inset * 2.0)

        pPath := 0
        DllCall("gdiplus\GdipCreatePath", "int", 0, "ptr*", &pPath)
        DllCall("gdiplus\GdipAddPathArc", "ptr", pPath, "float", inset, "float", inset, "float", d, "float", d, "float", 180, "float", 90)
        DllCall("gdiplus\GdipAddPathArc", "ptr", pPath, "float", inset + rw - d, "float", inset, "float", d, "float", d, "float", 270, "float", 90)
        DllCall("gdiplus\GdipAddPathArc", "ptr", pPath, "float", inset + rw - d, "float", inset + rh - d, "float", d, "float", d, "float", 0, "float", 90)
        DllCall("gdiplus\GdipAddPathArc", "ptr", pPath, "float", inset, "float", inset + rh - d, "float", d, "float", d, "float", 90, "float", 90)
        DllCall("gdiplus\GdipClosePathFigure", "ptr", pPath)

        ; Subtle obsidian gradient background (95% opacity)
        ptStart := Buffer(8, 0), ptEnd := Buffer(8, 0)
        NumPut("float", 0.0, ptStart, 0), NumPut("float", 0.0, ptStart, 4)
        NumPut("float", 0.0, ptEnd, 0), NumPut("float", Float(guiH), ptEnd, 4)
        pBgBrush := 0
        DllCall("gdiplus\GdipCreateLineBrush", "ptr", ptStart, "ptr", ptEnd, "uint", 0xF5111724, "uint", 0xF8090c12, "int", 0, "ptr*", &pBgBrush)
        DllCall("gdiplus\GdipFillPath", "ptr", pGraphics, "ptr", pBgBrush, "ptr", pPath)

        ; Crisp glowing cyan border on ALL 4 sides with anti-aliasing (1.5px 0xFF00D2FF)
        penW := 1.5 * dpiScale
        pPen := 0
        DllCall("gdiplus\GdipCreatePen1", "uint", 0xFF00D2FF, "float", penW, "int", 2, "ptr*", &pPen)
        DllCall("gdiplus\GdipDrawPath", "ptr", pGraphics, "ptr", pPen, "ptr", pPath)

        ; Font Family
        pFamily := 0
        DllCall("gdiplus\GdipCreateFontFamilyFromName", "wstr", "Segoe UI", "ptr", 0, "ptr*", &pFamily)

        pFormat := 0
        DllCall("gdiplus\GdipCreateStringFormat", "int", 0, "int", 0, "ptr*", &pFormat)
        DllCall("gdiplus\GdipSetStringFormatAlign", "ptr", pFormat, "int", 1) ; Center
        DllCall("gdiplus\GdipSetStringFormatLineAlign", "ptr", pFormat, "int", 1) ; Center

        pTextBrush := 0
        DllCall("gdiplus\GdipCreateSolidFill", "uint", 0xFF00D2FF, "ptr*", &pTextBrush)

        pFont := 0
        pFontSub := 0
        pSubBrush := 0

        if (hasSubtitle) {
            ; Title in upper portion (Segoe UI Bold, 10.5pt, Cyan)
            fontSize := 10.5 * dpiScale
            DllCall("gdiplus\GdipCreateFont", "ptr", pFamily, "float", fontSize, "int", 1, "int", 3, "ptr*", &pFont)

            rectTitle := Buffer(16, 0)
            NumPut("float", 0.0, rectTitle, 0)
            NumPut("float", Float(8 * dpiScale), rectTitle, 4)
            NumPut("float", Float(guiW), rectTitle, 8)
            NumPut("float", Float(24 * dpiScale), rectTitle, 12)
            DllCall("gdiplus\GdipDrawString", "ptr", pGraphics, "wstr", title, "int", -1, "ptr", pFont, "ptr", rectTitle, "ptr", pFormat, "ptr", pTextBrush)

            ; Subtitle in lower portion (Segoe UI Regular, 9pt, Light White)
            fontSizeSub := 9.0 * dpiScale
            DllCall("gdiplus\GdipCreateFont", "ptr", pFamily, "float", fontSizeSub, "int", 0, "int", 3, "ptr*", &pFontSub)
            DllCall("gdiplus\GdipCreateSolidFill", "uint", 0xFFF1F5F9, "ptr*", &pSubBrush)

            rectSub := Buffer(16, 0)
            NumPut("float", 0.0, rectSub, 0)
            NumPut("float", Float(34 * dpiScale), rectSub, 4)
            NumPut("float", Float(guiW), rectSub, 8)
            NumPut("float", Float(24 * dpiScale), rectSub, 12)
            DllCall("gdiplus\GdipDrawString", "ptr", pGraphics, "wstr", subtitle, "int", -1, "ptr", pFontSub, "ptr", rectSub, "ptr", pFormat, "ptr", pSubBrush)
        } else {
            ; Notification title in Segoe UI Bold centered
            fontSize := 10.5 * dpiScale
            DllCall("gdiplus\GdipCreateFont", "ptr", pFamily, "float", fontSize, "int", 1, "int", 3, "ptr*", &pFont)

            rectF := Buffer(16, 0)
            NumPut("float", 0.0, rectF, 0)
            NumPut("float", 0.0, rectF, 4)
            NumPut("float", Float(guiW), rectF, 8)
            NumPut("float", Float(guiH), rectF, 12)
            DllCall("gdiplus\GdipDrawString", "ptr", pGraphics, "wstr", title, "int", -1, "ptr", pFont, "ptr", rectF, "ptr", pFormat, "ptr", pTextBrush)
        }

        ; Calculate position: bottom right of active monitor where mouse cursor is
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mX, &mY)
        monCount := MonitorGetCount()
        monIndex := 1
        Loop monCount {
            MonitorGet(A_Index, &mL, &mT, &mR, &mB)
            if (mX >= mL && mX < mR && mY >= mT && mY < mB) {
                monIndex := A_Index
                break
            }
        }
        MonitorGetWorkArea(monIndex, &WL, &WT, &WR, &WB)

        posX := WR - guiW - Round(24 * dpiScale)
        posY := WB - guiH - Round(24 * dpiScale)

        ptDst := Buffer(8, 0)
        NumPut("int", posX, ptDst, 0)
        NumPut("int", posY, ptDst, 4)

        sz := Buffer(8, 0)
        NumPut("int", guiW, sz, 0)
        NumPut("int", guiH, sz, 4)

        ptSrc := Buffer(8, 0)
        NumPut("int", 0, ptSrc, 0)
        NumPut("int", 0, ptSrc, 4)

        blend := Buffer(4, 0)
        NumPut("uchar", 0, blend, 0)   ; AC_SRC_OVER
        NumPut("uchar", 0, blend, 1)   ; Flags
        NumPut("uchar", 255, blend, 2) ; SourceConstantAlpha
        NumPut("uchar", 1, blend, 3)   ; AC_SRC_ALPHA

        this.guiObj.Show("x" . posX . " y" . posY . " w" . guiW . " h" . guiH . " NoActivate")
        DllCall("UpdateLayeredWindow", "ptr", this.guiObj.Hwnd, "ptr", hDC, "ptr", ptDst, "ptr", sz, "ptr", hMemDC, "ptr", ptSrc, "uint", 0, "ptr", blend, "uint", 2)

        ; Cleanup GDI+ drawing resources
        DllCall("gdiplus\GdipDeleteBrush", "ptr", pBgBrush)
        DllCall("gdiplus\GdipDeleteBrush", "ptr", pTextBrush)
        if (pSubBrush != 0)
            DllCall("gdiplus\GdipDeleteBrush", "ptr", pSubBrush)
        DllCall("gdiplus\GdipDeletePen", "ptr", pPen)
        DllCall("gdiplus\GdipDeletePath", "ptr", pPath)
        DllCall("gdiplus\GdipDeleteFont", "ptr", pFont)
        if (pFontSub != 0)
            DllCall("gdiplus\GdipDeleteFont", "ptr", pFontSub)
        DllCall("gdiplus\GdipDeleteFontFamily", "ptr", pFamily)
        DllCall("gdiplus\GdipDeleteStringFormat", "ptr", pFormat)
        DllCall("gdiplus\GdipDeleteGraphics", "ptr", pGraphics)

        DllCall("SelectObject", "ptr", hMemDC, "ptr", hOldBmp)
        DllCall("DeleteObject", "ptr", hBmp)
        DllCall("DeleteDC", "ptr", hMemDC)
        DllCall("ReleaseDC", "ptr", 0, "ptr", hDC)

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
