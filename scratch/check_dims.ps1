Add-Type -AssemblyName System.Drawing
$c = [System.Drawing.Image]::FromFile("D:\For Safe Keeping\OBM AHK\assets\g502x.png")
$d = [System.Drawing.Image]::FromFile("D:\For Safe Keeping\OBM AHK\assets\g502x_diagram.png")
Write-Output "Clean: $($c.Width) x $($c.Height)"
Write-Output "Diagram: $($d.Width) x $($d.Height)"
$c.Dispose()
$d.Dispose()
