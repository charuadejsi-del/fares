; Installateur Windows — Atelier Broderie (compilé par la CI avec Inno Setup 6)
#ifndef AppVersion
  #define AppVersion "6.0.0"
#endif

[Setup]
AppId={{8C1F4E2A-5B7D-4A63-9E21-A7B3C0D4F516}
AppName=Atelier Broderie
AppVersion={#AppVersion}
AppPublisher=Atelier Broderie
DefaultDirName={autopf}\Atelier Broderie
DefaultGroupName=Atelier Broderie
DisableProgramGroupPage=yes
OutputDir=..\build\installer
OutputBaseFilename=AtelierBroderie-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
UninstallDisplayIcon={app}\atelier_broderie.exe
CloseApplications=yes

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "Créer une icône sur le bureau"; GroupDescription: "Raccourcis :"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Atelier Broderie"; Filename: "{app}\atelier_broderie.exe"
Name: "{autodesktop}\Atelier Broderie"; Filename: "{app}\atelier_broderie.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\atelier_broderie.exe"; Description: "Lancer Atelier Broderie"; Flags: nowait postinstall skipifsilent
