Add-Type -AssemblyName System.Drawing

$clean = [System.Drawing.Bitmap]::FromFile("D:\For Safe Keeping\OBM AHK\assets\g502x.png")
$bmp = New-Object System.Drawing.Bitmap($clean)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

# Refined coordinates on clean image (536 x 465)
$coords = @{
    "TiltLeft"     = @{ x = 158; y = 44 }
    "Middle"       = @{ x = 175; y = 38 }
    "TiltRight"    = @{ x = 194; y = 44 }
    "G8"           = @{ x = 48;  y = 86 }
    "G7"           = @{ x = 62;  y = 106 }
    "DpiShift"     = @{ x = 90;  y = 244 }
    "Forward_G5"   = @{ x = 128; y = 228 }
    "Back_G4"      = @{ x = 172; y = 252 }
    "ProfileCycle" = @{ x = 246; y = 72 }
}

$cyanBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 0, 229, 255))
$whitePen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 2)
$font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$bgBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200, 0, 0, 0))

foreach ($k in $coords.Keys) {
    $pt = $coords[$k]
    # Draw crosshair + dot
    $g.DrawLine($whitePen, $pt.x - 6, $pt.y, $pt.x + 6, $pt.y)
    $g.DrawLine($whitePen, $pt.x, $pt.y - 6, $pt.x, $pt.y + 6)
    $g.FillEllipse($cyanBrush, $pt.x - 3, $pt.y - 3, 6, 6)
    
    $sz = $g.MeasureString($k, $font)
    $g.FillRectangle($bgBrush, $pt.x + 8, $pt.y - 7, $sz.Width + 4, $sz.Height)
    $g.DrawString($k, $font, $textBrush, $pt.x + 10, $pt.y - 7)
}

$bmp.Save("D:\For Safe Keeping\OBM AHK\scratch\test_points_v2.png", [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$bmp.Dispose()
$clean.Dispose()
Write-Output "Saved test_points_v2.png"
