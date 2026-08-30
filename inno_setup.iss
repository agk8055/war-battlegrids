; Script generated for Inno Setup compiler
; Packaging Flutter Windows Application: War

#define MyAppName "War"
#ifndef MyAppVersion
#define MyAppVersion "1.0.0"
#endif
#define MyAppPublisher "War Games"
#define MyAppExeName "war.exe"

[Setup]
; NOTE: The value of AppId uniquely identifies this application.
AppId={{D8A13B44-59E4-48E0-BA10-7B1A99066611}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
DisableProgramGroupPage=yes
; Output folder & filename
OutputDir=build\windows\installer
OutputBaseFilename=War_Setup_v{#MyAppVersion}
SetupIconFile=windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Main Executable
Source: "build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
; All other binaries, DLLs, and data directories
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "{#MyAppExeName}"

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Filename: "{app}\{#MyAppExeName}"; Flags: nowait postinstall skipifsilent
