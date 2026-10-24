Add-Type -AssemblyName System.Drawing

$c = [System.Drawing.Bitmap]::FromFile("D:\For Safe Keeping\OBM AHK\assets\g502x.png")
$d = [System.Drawing.Bitmap]::FromFile("D:\For Safe Keeping\OBM AHK\assets\g502x_diagram.png")

# Compare row y=200 in clean with row y=200+30 in diagram across various x offsets
for ($xOff = 180; $xOff -le 240; $xOff++) {
    $diff = 0
    for ($cx = 100; $cx -le 400; $cx += 10) {
        $cp = $c.GetPixel($cx, 200)
        if ($cp.A -gt 200) {
            $dp = $d.GetPixel($cx + $xOff, 200 + 30)
            $diff += [Math]::Abs($dp.R - $cp.R) + [Math]::Abs($dp.G - $cp.G) + [Math]::Abs($dp.B - $cp.B)
        }
    }
    if ($diff -eq 0) {
        Write-Output "EXACT MATCH AT X Offset: $xOff, Y Offset: 30"
        break
    }
}

$c.Dispose()
$d.Dispose()
