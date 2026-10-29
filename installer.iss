; =========================================================================
; INNO SETUP SCRIPT FOR MY MOUSE MY CHOICE
; Produces a modern, professional Windows setup wizard with:
; - Desktop & Start Menu shortcuts
; - Optional Windows Startup boot option
; - Clean Windows App Registration (Settings > Installed apps / Uninstall)
; - Preserves existing user profiles and settings.ini across updates
; - Strictly excludes all git-ignored files and development junk
; =========================================================================

#define MyAppName "My Mouse My Choice"
#define MyAppVersion "2.0"
#define MyAppPublisher "OBM"
#define MyAppExeName "MyMouseMyChoice.exe"

#ifndef AppSourceDir
  #define AppSourceDir "."
#endif

[Setup]
AppId={{8F7D2B11-9A33-4E84-8E1A-7690C65A429E}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=dist
OutputBaseFilename=setup
SetupIconFile={#AppSourceDir}\assets\app.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog commandline
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}:"
Name: "startupicon"; Description: "Start automatically when Windows boots"; GroupDescription: "Startup Options:"; Flags: unchecked

[Files]
; Main standalone binary
Source: "{#AppSourceDir}\MyMouseMyChoice.exe"; DestDir: "{app}"; Flags: ignoreversion

; Embedded Edge Chromium WebView2 runtime bridge
Source: "{#AppSourceDir}\WebView2Loader.dll"; DestDir: "{app}"; Flags: ignoreversion

; Interception kernel driver command line installer (elevated driver manager)
Source: "{#AppSourceDir}\tools\install-interception.exe"; DestDir: "{app}\tools"; Flags: ignoreversion

; Clean default user configuration (never overwrites existing user settings.ini on update)
Source: "{#AppSourceDir}\settings.default.ini"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#AppSourceDir}\settings.default.ini"; DestDir: "{app}"; DestName: "settings.ini"; Flags: onlyifdoesntexist uninsneveruninstall

; Modern UI typography
Source: "{#AppSourceDir}\JetBrainsMono-VariableFont_wght.ttf"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#AppSourceDir}\ShareTech-Regular.ttf"; DestDir: "{app}"; Flags: ignoreversion

; Web UI application (HTML, CSS, modern JS modules, SVG vector library, application icons, embedded fonts)
; Strictly excludes git-ignored logs, temporary files, caches, backups, and settings
Source: "{#AppSourceDir}\web\*"; DestDir: "{app}\web"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.log,*.tmp,*.temp,*.bak,*.backup,*.old,*.orig,*.dmp,*.ini,settings.ini,Thumbs.db,Desktop.ini,.DS_Store,*.git*"

; Visual assets & mouse hardware diagrams
Source: "{#AppSourceDir}\assets\*"; DestDir: "{app}\assets"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.log,*.tmp,*.temp,*.bak,*.backup,*.old,*.orig,*.dmp,*.ini,settings.ini,Thumbs.db,Desktop.ini,.DS_Store,*.git*"

; AHK backend modular libraries & native architecture binaries (x64, x86, 64bit loaders, CLR bridge)
; Strictly excludes git-ignored logs, scratch files, test harnesses, verifiers, and temp backups
Source: "{#AppSourceDir}\lib\*"; DestDir: "{app}\lib"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.log,*.tmp,*.temp,*.bak,*.backup,*.old,*.orig,*.dmp,*.ini,settings.ini,test_*,*Verifier*,probe_*,scratch\*,Thumbs.db,Desktop.ini,.DS_Store,*.git*"

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: startupicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "taskkill.exe"; Parameters: "/f /im {#MyAppExeName}"; Flags: runhidden; RunOnceId: "CloseRunningBeforeUninstall"

[Code]
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
begin
  // Terminate any running instance so files are not locked during install/update
  Exec('taskkill.exe', '/f /im {#MyAppExeName}', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Result := '';
end;
