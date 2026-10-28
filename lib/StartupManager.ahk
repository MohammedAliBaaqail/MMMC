#Requires AutoHotkey v2.0

/**
 * StartupManager — Windows Startup & Boot Auto-Launch Controller
 * Handles launching MyMouseMyChoice when Windows starts up.
 * Supports:
 *  - Shell:Startup shortcut (%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup)
 *  - HKCU\Software\Microsoft\Windows\CurrentVersion\Run registry entry
 *  - Windows Task Scheduler (for silent elevated launch without UAC prompts when Kernel Driver is active)
 */
class StartupManager {
    static AppName := "MyMouseMyChoice"
    static RegKey := "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run"
    static ShortcutPath => A_Startup . "\MyMouseMyChoice.lnk"

    static IsEnabled() {
        iniPath := A_ScriptDir . "\settings.ini"
        if (FileExist(iniPath)) {
            val := IniRead(iniPath, "General", "RunAtStartup", "")
            if (val = "1")
                return true
            if (val = "0")
                return false
        }

        ; Check shortcut in Startup folder
        if (FileExist(this.ShortcutPath))
            return true

        ; Check HKCU Run registry key
        try {
            regVal := RegRead(this.RegKey, this.AppName)
            if (regVal != "")
                return true
        }
        return false
    }

    static SetEnabled(enable, iniPath := "") {
        target := A_IsCompiled ? A_ScriptFullPath : A_AhkPath
        args := A_IsCompiled ? "/minimized" : ('"' . A_ScriptFullPath . '" /minimized')

        if (enable) {
            if (A_IsAdmin) {
                ; 1. Elevated: use Scheduled Task for completely silent logon without UAC prompts
                try {
                    taskTr := A_IsCompiled ? ('\"' . target . '\" /minimized') : ('\"' . target . '\" \"' . A_ScriptFullPath . '\" /minimized')
                    Run('schtasks /create /tn "' . this.AppName . '" /tr "' . taskTr . '" /sc onlogon /rl highest /f',, "Hide")
                }
                ; Clean up HKCU Run & shortcut to avoid double-launches
                try RegDelete(this.RegKey, this.AppName)
                try FileDelete(this.ShortcutPath)
            } else {
                ; 2. Standard user: write to HKCU Run key
                try {
                    regCmd := '"' . target . '" ' . args
                    RegWrite(regCmd, "REG_SZ", this.RegKey, this.AppName)
                }
                ; Clean up scheduled task & shortcut to avoid double-launches
                try Run('schtasks /delete /tn "' . this.AppName . '" /f',, "Hide")
                try FileDelete(this.ShortcutPath)
            }

            ; 3. Update settings.ini
            if (iniPath != "") {
                try IniWrite("1", iniPath, "General", "RunAtStartup")
            }
            return true
        } else {
            ; 1. Delete shortcut in Startup folder
            try FileDelete(this.ShortcutPath)

            ; 2. Delete HKCU Run key
            try RegDelete(this.RegKey, this.AppName)

            ; 3. Delete Scheduled Task if present
            try {
                Run('schtasks /delete /tn "' . this.AppName . '" /f',, "Hide")
            }

            ; 4. Update settings.ini
            if (iniPath != "") {
                try IniWrite("0", iniPath, "General", "RunAtStartup")
            }
            return false
        }
    }
}
