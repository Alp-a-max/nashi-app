#define ProductName "Nashi"
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\Nashi-public-preview"
#endif
#ifdef TestBuild
  #define ProductId "{{99B80FD2-772C-49A6-AC2E-F6727CC401A8}"
  #define InstallerName "Nashi-Setup-test"
#else
  #define ProductId "{{89DA8C85-9C43-495E-AB05-BCF21E48D503}"
  #define InstallerName "Nashi-Setup-Windows-x64"
#endif

[Setup]
AppId={#ProductId}
AppName={#ProductName}
AppVersion=1.0 Preview
AppPublisher=Nashi contributors
AppPublisherURL=https://github.com/Alp-a-max/nashi-app
AppSupportURL=https://github.com/Alp-a-max/nashi-app
DefaultDirName={localappdata}\Programs\Nashi
DefaultGroupName=Nashi
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
OutputDir=..\..\build\windows
OutputBaseFilename={#InstallerName}
SetupIconFile=..\Nashi.Windows\Assets\NashiMascot.ico
UninstallDisplayIcon={app}\Nashi.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
CloseApplicationsFilter=Nashi.exe,Nashi.dll,Nashi.Core.dll
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"

[CustomMessages]
english.DesktopShortcut=Create a desktop shortcut
english.LaunchNashi=Launch Nashi
english.PreviewNotice=This is an unsigned preview. The existing updater checks the original upstream project; installing an offered update can replace this version. Disable automatic checks in Settings > Updates to retain this preview.
turkish.DesktopShortcut=Masaüstü kısayolu oluştur
turkish.LaunchNashi=Nashi uygulamasını aç
turkish.PreviewNotice=Bu sürüm imzasız bir önizlemedir. Mevcut güncelleme denetimi kaynak projeyi kontrol eder; önerilen güncellemeyi kurmak bu sürümü değiştirebilir. Bu sürümü korumak için Ayarlar > Güncellemeler bölümünde otomatik denetimi kapatın.

[Tasks]
Name: "desktopicon"; Description: "{cm:DesktopShortcut}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Nashi"; Filename: "{app}\Nashi.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\Nashi"; Filename: "{app}\Nashi.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\Nashi.exe"; Description: "{cm:LaunchNashi}"; Flags: nowait postinstall skipifsilent

[Code]
procedure InitializeWizard;
begin
  WizardForm.WelcomeLabel2.Caption := WizardForm.WelcomeLabel2.Caption + #13#10#13#10 + ExpandConstant('{cm:PreviewNotice}');
end;
