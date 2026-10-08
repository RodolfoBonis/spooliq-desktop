; Instalador Windows do SpoolIQ (Inno Setup 6).
; Compilar após `flutter build windows --release -t lib/main_production.dart`:
;   iscc /DAppVersion=0.1.0 windows\installer.iss
#ifndef AppVersion
  #define AppVersion "0.1.0"
#endif

[Setup]
AppId={{8C1E5A3B-4F2D-4C7E-9B1A-5D3F2E6A7C90}
AppName=SpoolIQ
AppVersion={#AppVersion}
AppPublisher=Loopcraft
AppPublisherURL=https://spooliq.com
DefaultDirName={autopf}\SpoolIQ
DefaultGroupName=SpoolIQ
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename=SpoolIQ-Setup-{#AppVersion}
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\spooliq_desktop.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\SpoolIQ"; Filename: "{app}\spooliq_desktop.exe"
Name: "{autodesktop}\SpoolIQ"; Filename: "{app}\spooliq_desktop.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\spooliq_desktop.exe"; Description: "{cm:LaunchProgram,SpoolIQ}"; Flags: nowait postinstall skipifsilent
