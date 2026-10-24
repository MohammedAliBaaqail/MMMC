Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Bitmap]::FromFile("D:\For Safe Keeping\OBM AHK\assets\g502x.png")
for ($y = 0; $y -lt $img.Height; $y += 5) {
    for ($x = 0; $x -lt $img.Width; $x += 5) {
        $p = $img.GetPixel($x, $y)
        if ($p.R -gt 100 -and $p.R -lt 160 -and $p.G -gt 150 -and $p.G -lt 200 -and $p.B -gt 230) {
            Write-Output "Blue pixel at X=$($x), Y=$($y)"
        }
    }
}
$img.Dispose()
