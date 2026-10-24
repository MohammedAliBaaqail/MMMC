$ahk = "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
$script = "D:\For Safe Keeping\OBM AHK\G502X_Manager.ahk"
& $ahk /validate $script
Write-Output "Manager validation exit code: $LASTEXITCODE"
