Add-Type -AssemblyName System.Drawing

$clean = [System.Drawing.Bitmap]::FromFile("D:\For Safe Keeping\OBM AHK\assets\g502x.png")
$canvasW = 860
$canvasH = 500
$bmp = New-Object System.Drawing.Bitmap($canvasW, $canvasH)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::Transparent)

# Mouse placement: X = 180, Y = 20 (Clean image: 536 x 465)
$mouseX = 180
$mouseY = 20
$g.DrawImage($clean, $mouseX, $mouseY, $clean.Width, $clean.Height)

# Pinpoint button center targets (verified via crosshairs):
# Left Anchor: X = 170 (touches left callout cards at x=305..450 in GUI)
# Right Anchor: X = 650 (touches right callout cards at x=930..1075 in GUI)
$lines = @(
    # Left side (Top to Bottom)
    @{ Name = "TiltLeft";     Anchor = @{ X = 170; Y = 50 };  Target = @{ X = $mouseX + 158; Y = $mouseY + 44 } },
    @{ Name = "G8";           Anchor = @{ X = 170; Y = 115 }; Target = @{ X = $mouseX + 48;  Y = $mouseY + 86 } },
    @{ Name = "G7";           Anchor = @{ X = 170; Y = 175 }; Target = @{ X = $mouseX + 62;  Y = $mouseY + 106 } },
    @{ Name = "DpiShift";     Anchor = @{ X = 170; Y = 245 }; Target = @{ X = $mouseX + 90;  Y = $mouseY + 244 } },
    @{ Name = "Forward_G5";   Anchor = @{ X = 170; Y = 315 }; Target = @{ X = $mouseX + 128; Y = $mouseY + 228 } },
    @{ Name = "Back_G4";      Anchor = @{ X = 170; Y = 385 }; Target = @{ X = $mouseX + 172; Y = $mouseY + 252 } },

    # Right side (Top to Bottom)
    @{ Name = "TiltRight";    Anchor = @{ X = 650; Y = 50 };  Target = @{ X = $mouseX + 194; Y = $mouseY + 44 } },
    @{ Name = "Middle";       Anchor = @{ X = 650; Y = 115 }; Target = @{ X = $mouseX + 175; Y = $mouseY + 38 } },
    @{ Name = "ProfileCycle"; Anchor = @{ X = 650; Y = 180 }; Target = @{ X = $mouseX + 246; Y = $mouseY + 72 } }
)

# Leader line styling: Catppuccin / G-HUB Soft Blue #89B4FA
$lineColor = [System.Drawing.Color]::FromArgb(235, 137, 180, 250)
$linePen   = New-Object System.Drawing.Pen($lineColor, 1.8)

# Glowing target indicator: outer halo + solid white center core
$haloBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(190, 137, 180, 250))
$dotBrush  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$dotPen    = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 24, 25, 38), 1.0)

foreach ($l in $lines) {
    $ax = $l.Anchor.X
    $ay = $l.Anchor.Y
    $tx = $l.Target.X
    $ty = $l.Target.Y

    # Draw leader line
    $g.DrawLine($linePen, $ax, $ay, $tx, $ty)

    # Draw anchor dot at card edge
    $g.FillEllipse($haloBrush, $ax - 3, $ay - 3, 6, 6)

    # Draw glowing indicator point at the exact center of the button
    $g.FillEllipse($haloBrush, $tx - 5.5, $ty - 5.5, 11, 11)
    $g.FillEllipse($dotBrush,  $tx - 2.5, $ty - 2.5, 5, 5)
    $g.DrawEllipse($dotPen,    $tx - 2.5, $ty - 2.5, 5, 5)
}

# Overwrite assets/g502x_diagram.png
$diagPath = "D:\For Safe Keeping\OBM AHK\assets\g502x_diagram.png"
$bmp.Save($diagPath, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$bmp.Dispose()
$clean.Dispose()
Write-Output "Successfully updated $diagPath"
