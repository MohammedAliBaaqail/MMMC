$lines = Get-Content "D:\For Safe Keeping\OBM AHK\lib\GuiManager.ahk"
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "^\s*static\s+([A-Za-z0-9_]+)\s*\(") {
        Write-Output "$($i+1): $($lines[$i].Trim())"
    }
}
