; Inno Setup script. Run from the repo root: iscc windows\installer.iss
[Setup]
AppId={{6D0C6C5E-7B1F-4E7C-9B43-2A0E5F3B7A11}
AppName=zrNotes
AppVersion=1.0.0
AppPublisher=zr
DefaultDirName={autopf}\zrNotes
DefaultGroupName=zrNotes
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\Output
OutputBaseFilename=zrnotes-setup
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\zrnotes.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{group}\zrNotes"; Filename: "{app}\zrnotes.exe"
Name: "{autodesktop}\zrNotes"; Filename: "{app}\zrnotes.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\zrnotes.exe"; Description: "Open zrNotes"; Flags: nowait postinstall skipifsilent
