Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Bitmap]::FromFile("D:\For Safe Keeping\OBM AHK\assets\g502x.png")
# Check pixel at (300, 20) or check if there are blue line pixels in g502x.png
$bluePixels = 0
for ($y = 0; $y -lt $img.Height; $y++) {
    for ($x = 0; $x -lt $img.Width; $x++) {
        $p = $img.GetPixel($x, $y)
        if ($p.R -gt 100 -and $p.R -lt 160 -and $p.G -gt 150 -and $p.G -lt 200 -and $p.B -gt 230) {
            $bluePixels++
        }
    }
}
Write-Output "Blue line pixels in g502x.png: $bluePixels"
$img.Dispose()
