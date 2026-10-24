Add-Type -AssemblyName System.Drawing

$clean = [System.Drawing.Bitmap]::FromFile("D:\For Safe Keeping\OBM AHK\assets\g502x.png")
$canvasW = 830
$canvasH = 490
$bmp = New-Object System.Drawing.Bitmap($canvasW, $canvasH)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::Transparent)

# Draw clean mouse at X = 175, Y = 25
$mouseX = 175
$mouseY = 25
$g.DrawImage($clean, $mouseX, $mouseY, $clean.Width, $clean.Height)

# Callout lines definition:
# Anchor: point where line touches callout box
# Target: center of button on g502x (cx, cy)
$lines = @(
    # Left side
    @{ Name = "TiltLeft";     Anchor = @{ X = 170; Y = 36 };  Target = @{ X = $mouseX + 158; Y = $mouseY + 44 } },
    @{ Name = "G8";           Anchor = @{ X = 170; Y = 101 }; Target = @{ X = $mouseX + 48;  Y = $mouseY + 86 } },
    @{ Name = "G7";           Anchor = @{ X = 170; Y = 156 }; Target = @{ X = $mouseX + 62;  Y = $mouseY + 106 } },
    @{ Name = "DpiShift";     Anchor = @{ X = 170; Y = 221 }; Target = @{ X = $mouseX + 90;  Y = $mouseY + 244 } },
    @{ Name = "Forward_G5";   Anchor = @{ X = 170; Y = 286 }; Target = @{ X = $mouseX + 128; Y = $mouseY + 228 } },
    @{ Name = "Back_G4";      Anchor = @{ X = 170; Y = 351 }; Target = @{ X = $mouseX + 172; Y = $mouseY + 252 } },

    # Right side
    @{ Name = "TiltRight";    Anchor = @{ X = 565; Y = 36 };  Target = @{ X = $mouseX + 194; Y = $mouseY + 44 } },
    @{ Name = "Middle";       Anchor = @{ X = 565; Y = 101 }; Target = @{ X = $mouseX + 175; Y = $mouseY + 38 } },
    @{ Name = "ProfileCycle"; Anchor = @{ X = 565; Y = 166 }; Target = @{ X = $mouseX + 246; Y = $mouseY + 72 } }
)

# Colors matching G-HUB Catppuccin theme
$lineColor = [System.Drawing.Color]::FromArgb(210, 137, 180, 250) # Vibrant Soft Blue/Cyan #89B4FA
$linePen = New-Object System.Drawing.Pen($lineColor, 1.8)

$haloBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(180, 137, 180, 250))
$dotBrush  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$dotPen    = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 17, 17, 27), 1.0)

foreach ($l in $lines) {
    $ax = $l.Anchor.X
    $ay = $l.Anchor.Y
    $tx = $l.Target.X
    $ty = $l.Target.Y

    # Draw leader line from anchor to target
    $g.DrawLine($linePen, $ax, $ay, $tx, $ty)

    # Draw anchor dot (at callout box edge)
    $g.FillEllipse($haloBrush, $ax - 3, $ay - 3, 6, 6)

    # Draw target point in the center of the button (outer glowing halo + solid white center)
    $g.FillEllipse($haloBrush, $tx - 5, $ty - 5, 10, 10)
    $g.FillEllipse($dotBrush,  $tx - 2.5, $ty - 2.5, 5, 5)
    $g.DrawEllipse($dotPen,    $tx - 2.5, $ty - 2.5, 5, 5)
}

$bmp.Save("D:\For Safe Keeping\OBM AHK\scratch\test_diagram_generated.png", [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$bmp.Dispose()
$clean.Dispose()
Write-Output "Saved test_diagram_generated.png"
