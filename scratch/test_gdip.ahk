#Requires AutoHotkey v2.0

class DiagramRenderer {
    static Render(points, outputPath) {
        cleanPath := InStr(A_ScriptDir, "scratch") ? SubStr(A_ScriptDir, 1, InStr(A_ScriptDir, "\scratch",, -1)) . "assets\g502x.png" : A_ScriptDir . "\assets\g502x.png"
        if !FileExist(cleanPath)
            return false

        ; Gdiplus startup
        si := Buffer(24, 0)
        NumPut("uint", 1, si, 0)
        pToken := 0
        DllCall("gdiplus\GdiplusStartup", "ptr*", &pToken, "ptr", si, "ptr", 0)

        ; Load clean mouse image
        pClean := 0
        DllCall("gdiplus\GdipCreateBitmapFromFile", "wstr", cleanPath, "ptr*", &pClean)

        cleanW := 0, cleanH := 0
        DllCall("gdiplus\GdipGetImageWidth", "ptr", pClean, "uint*", &cleanW)
        DllCall("gdiplus\GdipGetImageHeight", "ptr", pClean, "uint*", &cleanH)

        ; Create 860x500 32bpp ARGB bitmap
        pCanvas := 0
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", 860, "int", 500, "int", 0, "int", 0x26200A, "ptr", 0, "ptr*", &pCanvas)

        pGraphics := 0
        DllCall("gdiplus\GdipGetImageGraphicsContext", "ptr", pCanvas, "ptr*", &pGraphics)
        ; Set SmoothingModeAntiAlias = 4
        DllCall("gdiplus\GdipSetSmoothingMode", "ptr", pGraphics, "int", 4)

        ; Draw clean mouse at X = 180, Y = 20
        DllCall("gdiplus\GdipDrawImageRectRectI", "ptr", pGraphics, "ptr", pClean
            , "int", 180, "int", 20, "int", cleanW, "int", cleanH
            , "int", 0, "int", 0, "int", cleanW, "int", cleanH
            , "int", 2, "ptr", 0, "ptr", 0, "ptr", 0)

        ; Create Pen for leader line (#89B4FA, ARGB: 0xEB89B4FA, width 1.8)
        pPen := 0
        DllCall("gdiplus\GdipCreatePen1", "uint", 0xEB89B4FA, "float", 1.8, "int", 2, "ptr*", &pPen)

        ; Create Brushes: Halo (0xBE89B4FA), White (0xFFFFFFFF)
        pHaloBrush := 0
        DllCall("gdiplus\GdipCreateSolidFill", "uint", 0xBE89B4FA, "ptr*", &pHaloBrush)

        pWhiteBrush := 0
        DllCall("gdiplus\GdipCreateSolidFill", "uint", 0xFFFFFFFF, "ptr*", &pWhiteBrush)

        pDotPen := 0
        DllCall("gdiplus\GdipCreatePen1", "uint", 0xFF181926, "float", 1.0, "int", 2, "ptr*", &pDotPen)

        for item in points {
            ax := item.ax, ay := item.ay
            tx := item.tx, ty := item.ty

            ; Draw line from anchor to target
            DllCall("gdiplus\GdipDrawLine", "ptr", pGraphics, "ptr", pPen, "float", ax, "float", ay, "float", tx, "float", ty)

            ; Draw anchor dot (at callout card edge)
            DllCall("gdiplus\GdipFillEllipse", "ptr", pGraphics, "ptr", pHaloBrush, "float", ax - 3, "float", ay - 3, "float", 6, "float", 6)

            ; Draw target halo + white dot
            DllCall("gdiplus\GdipFillEllipse", "ptr", pGraphics, "ptr", pHaloBrush, "float", tx - 5.5, "float", ty - 5.5, "float", 11, "float", 11)
            DllCall("gdiplus\GdipFillEllipse", "ptr", pGraphics, "ptr", pWhiteBrush, "float", tx - 2.5, "float", ty - 2.5, "float", 5, "float", 5)
            DllCall("gdiplus\GdipDrawEllipse", "ptr", pGraphics, "ptr", pDotPen, "float", tx - 2.5, "float", ty - 2.5, "float", 5, "float", 5)
        }

        ; PNG Encoder CLSID: {557CF406-1A04-11D3-9A73-0000F81EF32E}
        clsidPng := Buffer(16, 0)
        DllCall("ole32\CLSIDFromString", "wstr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "ptr", clsidPng)

        DllCall("gdiplus\GdipSaveImageToFile", "ptr", pCanvas, "wstr", outputPath, "ptr", clsidPng, "ptr", 0)

        ; Cleanup
        DllCall("gdiplus\GdipDeletePen", "ptr", pPen)
        DllCall("gdiplus\GdipDeletePen", "ptr", pDotPen)
        DllCall("gdiplus\GdipDeleteBrush", "ptr", pHaloBrush)
        DllCall("gdiplus\GdipDeleteBrush", "ptr", pWhiteBrush)
        DllCall("gdiplus\GdipDeleteGraphics", "ptr", pGraphics)
        DllCall("gdiplus\GdipDisposeImage", "ptr", pClean)
        DllCall("gdiplus\GdipDisposeImage", "ptr", pCanvas)
        DllCall("gdiplus\GdiplusShutdown", "ptr", pToken)
        return true
    }
}

testPoints := [
    { ax: 170, ay: 50,  tx: 338, ty: 64 },
    { ax: 170, ay: 115, tx: 228, ty: 106 },
    { ax: 170, ay: 175, tx: 242, ty: 126 },
    { ax: 170, ay: 245, tx: 270, ty: 264 },
    { ax: 170, ay: 315, tx: 308, ty: 248 },
    { ax: 170, ay: 385, tx: 352, ty: 272 },
    { ax: 650, ay: 50,  tx: 374, ty: 64 },
    { ax: 650, ay: 115, tx: 355, ty: 58 },
    { ax: 650, ay: 180, tx: 426, ty: 92 }
]

outTest := A_ScriptDir . "\scratch\test_gdip_out.png"
start := A_TickCount
res := DiagramRenderer.Render(testPoints, outTest)
elapsed := A_TickCount - start
FileAppend("Rendered in " . elapsed . " ms, Result: " . res . ", FileExist: " . FileExist(outTest) . "`n", "*")
