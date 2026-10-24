Add-Type -AssemblyName System.Drawing

$clean = [System.Drawing.Bitmap]::FromFile("D:\For Safe Keeping\OBM AHK\assets\g502x.png")
$bmp = New-Object System.Drawing.Bitmap($clean)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

# Candidate coordinates on clean image (536 x 465)
$coords = @{
    "TiltLeft"     = @{ x = 160; y = 42 }
    "Middle"       = @{ x = 175; y = 35 }
    "TiltRight"    = @{ x = 192; y = 42 }
    "G8"           = @{ x = 44;  y = 80 }
    "G7"           = @{ x = 58;  y = 96 }
    "DpiShift"     = @{ x = 75;  y = 220 }
    "Forward_G5"   = @{ x = 125; y = 218 }
    "Back_G4"      = @{ x = 180; y = 238 }
    "ProfileCycle" = @{ x = 250; y = 78 }
}

$redBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 255, 0, 0))
$whitePen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 2)
$font = New-Object System.Drawing.Font("Arial", 9, [System.Drawing.FontStyle]::Bold)
$textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Yellow)

foreach ($k in $coords.Keys) {
    $pt = $coords[$k]
    # Draw a 8px circle with white border
    $g.FillEllipse($redBrush, $pt.x - 4, $pt.y - 4, 8, 8)
    $g.DrawEllipse($whitePen, $pt.x - 4, $pt.y - 4, 8, 8)
    $g.DrawString($k, $font, $textBrush, $pt.x + 6, $pt.y - 6)
}

$bmp.Save("D:\For Safe Keeping\OBM AHK\scratch\test_mouse_points.png", [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$bmp.Dispose()
$clean.Dispose()
Write-Output "Saved test_mouse_points.png"
