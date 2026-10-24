Add-Type -AssemblyName System.Drawing

function Make-Toggle($path, $isOn, $bgHex, $trackHex, $knobHex, $activeTrackHex) {
    $w = 46
    $h = 24
    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.ColorTranslator]::FromHtml($bgHex))
    
    $tColor = if ($isOn) { [System.Drawing.ColorTranslator]::FromHtml($activeTrackHex) } else { [System.Drawing.ColorTranslator]::FromHtml($trackHex) }
    $tBrush = New-Object System.Drawing.SolidBrush($tColor)
    
    # Draw pill track (h=20, y=2, w=44, x=1)
    $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
    $gp.AddArc(1, 2, 20, 20, 90, 180)
    $gp.AddArc(23, 2, 20, 20, 270, 180)
    $gp.CloseFigure()
    $g.FillPath($tBrush, $gp)
    
    # Draw knob (d=16, y=4)
    $kx = if ($isOn) { 25 } else { 3 }
    $kBrush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml($knobHex))
    $g.FillEllipse($kBrush, $kx, 4, 16, 16)
    
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
}

$assets = 'D:\For Safe Keeping\OBM AHK\assets'
if (-not (Test-Path $assets)) { New-Item -ItemType Directory -Path $assets }
# Transparent/dark background matching Gui background #181825
Make-Toggle "$assets\toggle_off.png" $false '#181825' '#585B70' '#FFFFFF' '#89B4FA'
Make-Toggle "$assets\toggle_on.png"  $true  '#181825' '#585B70' '#FFFFFF' '#89B4FA'
Write-Host 'Toggles generated successfully.'
