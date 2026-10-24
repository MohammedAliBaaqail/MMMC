Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Bitmap]::FromFile("D:\For Safe Keeping\OBM AHK\assets\g502x.png")
foreach ($y in @(40, 80, 110, 140, 170, 200, 240, 280, 320)) {
    $minX = -1; $maxX = -1
    for ($x = 0; $x -lt $img.Width; $x++) {
        if ($img.GetPixel($x, $y).A -gt 30) {
            if ($minX -eq -1) { $minX = $x }
            $maxX = $x
        }
    }
    Write-Output "Y=$y in clean image: Mouse spans X=$minX to X=$maxX (Width=$($maxX-$minX))"
}
$img.Dispose()
