$ahk = "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
$script = "D:\For Safe Keeping\OBM AHK\scratch\test_calibrator_v2.ahk"
& $ahk /validate $script
Write-Output "Validation exit code: $LASTEXITCODE"
