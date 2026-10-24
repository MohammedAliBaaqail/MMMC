Get-CimInstance Win32_Process | Where-Object { $_.Name -like "*AutoHotkey*" } | Select-Object ProcessId, CommandLine | Format-List
