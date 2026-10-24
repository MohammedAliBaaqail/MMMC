param(
    [string]$RootPath = "",
    [string]$OutputFile = ""
)

Add-Type -AssemblyName System.Drawing

if ([string]::IsNullOrWhiteSpace($RootPath)) {
    $RootPath = Split-Path -Parent $PSScriptRoot
    if (!(Test-Path (Join-Path $RootPath "assets\g502x.png"))) {
        $RootPath = "D:\For Safe Keeping\OBM AHK"
    }
}

if ([string]::IsNullOrWhiteSpace($OutputFile)) {
    $OutputFile = Join-Path $RootPath "assets\g502x_diagram.png"
}

$cleanPath = Join-Path $RootPath "assets\g502x.png"
if (!(Test-Path $cleanPath)) {
    Write-Error "Clean mouse image not found at $cleanPath"
    exit 1
}

# Read settings.ini for custom [DiagramPoints]
$iniPath = Join-Path $RootPath "settings.ini"
$customPoints = @{}

if (Test-Path $iniPath) {
    $inSection = $false
    # Read with default detection
    $lines = Get-Content $iniPath -ErrorAction SilentlyContinue
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -eq "[DiagramPoints]") {
            $inSection = $true
            continue
        } elseif ($trimmed -match "^\[.*\]$") {
            $inSection = $false
            continue
        }

        if ($inSection -and $trimmed -match "^([^=]+)=(.*)$") {
            $key = $matches[1].Trim()
            $val = [int]$matches[2].Trim()
            $customPoints[$key] = $val
        }
    }
}

function Get-PointCoord($name, $axis, $defaultVal) {
    $key = "${name}_${axis}"
    if ($customPoints.ContainsKey($key)) {
        return [int]$customPoints[$key]
    }
    return [int]$defaultVal
}

# Canvas: 860 x 500
$canvasW = 860
$canvasH = 500
$bmp = New-Object System.Drawing.Bitmap($canvasW, $canvasH)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::Transparent)

# Draw clean mouse at X = 180, Y = 20
$clean = [System.Drawing.Bitmap]::FromFile($cleanPath)
$mouseX = 180
$mouseY = 20
$g.DrawImage($clean, $mouseX, $mouseY, $clean.Width, $clean.Height)
$clean.Dispose()

# Define all 9 buttons with anchors and targets
$buttons = @(
    # Left side (Top to Bottom)
    @{ Id = "TiltLeft";     Anchor = @{ X = 170; Y = 50 };  DefTarget = @{ X = 338; Y = 64 } },
    @{ Id = "G8";           Anchor = @{ X = 170; Y = 115 }; DefTarget = @{ X = 228; Y = 106 } },
    @{ Id = "G7";           Anchor = @{ X = 170; Y = 175 }; DefTarget = @{ X = 242; Y = 126 } },
    @{ Id = "DpiShift";     Anchor = @{ X = 170; Y = 245 }; DefTarget = @{ X = 270; Y = 264 } },
    @{ Id = "Forward";      Anchor = @{ X = 170; Y = 315 }; DefTarget = @{ X = 308; Y = 248 } },
    @{ Id = "Back";         Anchor = @{ X = 170; Y = 385 }; DefTarget = @{ X = 352; Y = 272 } },

    # Right side (Top to Bottom)
    @{ Id = "TiltRight";    Anchor = @{ X = 650; Y = 50 };  DefTarget = @{ X = 374; Y = 64 } },
    @{ Id = "Middle";       Anchor = @{ X = 650; Y = 115 }; DefTarget = @{ X = 355; Y = 58 } },
    @{ Id = "ProfileCycle"; Anchor = @{ X = 650; Y = 180 }; DefTarget = @{ X = 426; Y = 92 } }
)

# Leader line styling: Catppuccin / G-HUB Soft Blue #89B4FA
$lineColor = [System.Drawing.Color]::FromArgb(235, 137, 180, 250)
$linePen   = New-Object System.Drawing.Pen($lineColor, 1.8)

# Glowing target indicator: outer halo + solid white center core
$haloBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(190, 137, 180, 250))
$dotBrush  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$dotPen    = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 24, 25, 38), 1.0)

foreach ($b in $buttons) {
    $ax = $b.Anchor.X
    $ay = $b.Anchor.Y
    $tx = Get-PointCoord $b.Id "X" $b.DefTarget.X
    $ty = Get-PointCoord $b.Id "Y" $b.DefTarget.Y

    # Draw leader line
    $g.DrawLine($linePen, $ax, $ay, $tx, $ty)

    # Draw anchor dot at card edge
    $g.FillEllipse($haloBrush, $ax - 3, $ay - 3, 6, 6)

    # Draw glowing indicator point at the target center
    $g.FillEllipse($haloBrush, $tx - 5.5, $ty - 5.5, 11, 11)
    $g.FillEllipse($dotBrush,  $tx - 2.5, $ty - 2.5, 5, 5)
    $g.DrawEllipse($dotPen,    $tx - 2.5, $ty - 2.5, 5, 5)
}

$bmp.Save($OutputFile, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$bmp.Dispose()
Write-Output "Rendered diagram to $OutputFile"
