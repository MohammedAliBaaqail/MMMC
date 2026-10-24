Add-Type -AssemblyName System.Drawing

function Get-BBox($bmp) {
    $minX = $bmp.Width; $maxX = 0; $minY = $bmp.Height; $maxY = 0
    for ($y = 0; $y -lt $bmp.Height; $y++) {
        for ($x = 0; $x -lt $bmp.Width; $x++) {
            $p = $bmp.GetPixel($x, $y)
            if ($p.A -gt 30) {
                if ($x -lt $minX) { $minX = $x }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }
    return [PSCustomObject]@{ MinX = $minX; MaxX = $maxX; MinY = $minY; MaxY = $maxY; Width = ($maxX - $minX + 1); Height = ($maxY - $minY + 1) }
}

$c = [System.Drawing.Bitmap]::FromFile("D:\For Safe Keeping\OBM AHK\assets\g502x.png")
$d = [System.Drawing.Bitmap]::FromFile("D:\For Safe Keeping\OBM AHK\assets\g502x_diagram.png")
Write-Output "Clean BBox: $(Get-BBox $c | ConvertTo-Json)"
Write-Output "Diagram BBox: $(Get-BBox $d | ConvertTo-Json)"
$c.Dispose()
$d.Dispose()
