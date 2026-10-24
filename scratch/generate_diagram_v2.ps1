Add-Type -AssemblyName System.Drawing

$clean = [System.Drawing.Bitmap]::FromFile("D:\For Safe Keeping\OBM AHK\assets\g502x.png")
$canvasW = 860
$canvasH = 500
$bmp = New-Object System.Drawing.Bitmap($canvasW, $canvasH)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::Transparent)

# Mouse placement: X = 180, Y = 20
$mouseX = 180
$mouseY = 20
$g.DrawImage($clean, $mouseX, $mouseY, $clean.Width, $clean.Height)

# Button center targets (cx, cy relative to clean image):
# TiltLeft: (158, 44)
# Middle: (175, 38)
# TiltRight: (194, 44)
# G8: (48, 86)
# G7: (62, 106)
# DpiShift: (90, 244)
# Forward (G5): (128, 228)
# Back (G4): (172, 252)
# ProfileCycle (G9): (246, 72)

# Left Anchor: X = 170
# Right Anchor: X = 650
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

# Line styling: G-HUB soft blue #89B4FA
$lineColor = [System.Drawing.Color]::FromArgb(230, 137, 180, 250)
$linePen   = New-Object System.Drawing.Pen($lineColor, 1.8)

# Glowing halo & center dot
$haloBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(180, 137, 180, 250))
$dotBrush  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$dotPen    = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 24, 25, 38), 1.0)

foreach ($l in $lines) {
    $ax = $l.Anchor.X
    $ay = $l.Anchor.Y
    $tx = $l.Target.X
    $ty = $l.Target.Y

    # Draw leader line from anchor to target
    $g.DrawLine($linePen, $ax, $ay, $tx, $ty)

    # Draw small anchor dot at callout box edge
    $g.FillEllipse($haloBrush, $ax - 3, $ay - 3, 6, 6)

    # Draw glowing indicator point dead-center on the button
    # Outer halo (d=11)
    $g.FillEllipse($haloBrush, $tx - 5.5, $ty - 5.5, 11, 11)
    # Solid white center core (d=5)
    $g.FillEllipse($dotBrush,  $tx - 2.5, $ty - 2.5, 5, 5)
    # Crisp outline
    $g.DrawEllipse($dotPen,    $tx - 2.5, $ty - 2.5, 5, 5)
}

$bmp.Save("D:\For Safe Keeping\OBM AHK\scratch\test_diagram_v2.png", [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$bmp.Dispose()
$clean.Dispose()
Write-Output "Saved test_diagram_v2.png"
