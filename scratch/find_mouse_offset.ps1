Add-Type -AssemblyName System.Drawing

$diag = [System.Drawing.Bitmap]::FromFile("D:\For Safe Keeping\OBM AHK\assets\g502x_diagram.png")
$clean = [System.Drawing.Bitmap]::FromFile("D:\For Safe Keeping\OBM AHK\assets\g502x.png")

# Find where clean is located inside diag by searching for the first non-transparent matching pixel
# Sample 5 pixels from clean
$p1 = $clean.GetPixel(268, 232) # center
Write-Output "Clean center pixel: $p1"

# Scan diag to find clean's top-left
$foundX = -1
$foundY = -1

for ($y = 0; $y -lt ($diag.Height - $clean.Height); $y++) {
    for ($x = 0; $x -lt ($diag.Width - $clean.Width); $x++) {
        $match = $true
        # Check 10 non-transparent pixels
        for ($cy = 100; $cy -le 400; $cy += 100) {
            for ($cx = 100; $cx -le 400; $cx += 100) {
                $cp = $clean.GetPixel($cx, $cy)
                if ($cp.A -gt 200) {
                    $dp = $diag.GetPixel($x + $cx, $y + $cy)
                    if ($dp.R -ne $cp.R -or $dp.G -ne $cp.G -or $dp.B -ne $cp.B) {
                        $match = $false
                        break
                    }
                }
            }
            if (-not $match) { break }
        }
        if ($match) {
            $foundX = $x
            $foundY = $y
            break
        }
    }
    if ($foundX -ge 0) { break }
}

Write-Output "Clean image placed in diagram at: X=$foundX, Y=$foundY"
$diag.Dispose()
$clean.Dispose()
