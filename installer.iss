; =========================================================================
; INNO SETUP SCRIPT FOR MY MOUSE MY CHOICE
; Produces a modern, professional Windows setup wizard with:
; - Desktop & Start Menu shortcuts
; - Optional Windows Startup boot option
; - Clean Windows App Registration (Settings > Installed apps / Uninstall)
; - Preserves existing user profiles and settings.ini across updates
; =========================================================================

#define MyAppName "My Mouse My Choice"
#define MyAppVersion "2.0"
#define MyAppPublisher "OBM"
#define MyAppExeName "MyMouseMyChoice.exe"

[Setup]
AppId={{8F7D2B11-9A33-4E84-8E1A-7690C65A429E}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=dist
OutputBaseFilename=MyMouseMyChoice_Setup_v2.0
SetupIconFile=assets\app.ico
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
Source: "MyMouseMyChoice.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "G502X_Studio.exe"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
; Web UI layer (HTML, CSS, modern JS modules, app icons)
Source: "web\*"; DestDir: "{app}\web"; Flags: ignoreversion recursesubdirs createallsubdirs
; Assets (mouse hardware diagrams, presets, icon)
Source: "assets\*"; DestDir: "{app}\assets"; Flags: ignoreversion recursesubdirs createallsubdirs
; AHK backend libraries and loaders
Source: "lib\*"; DestDir: "{app}\lib"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "WebView2Loader.dll"; DestDir: "{app}"; Flags: ignoreversion
; User configurations: only write default settings.ini on a clean install so existing user bindings/profiles are never lost on updates
Source: "settings.ini"; DestDir: "{app}"; Flags: onlyifdoesntexist uninsneveruninstall

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: startupicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
