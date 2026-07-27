#ifndef MyAppVersion
  #define MyAppVersion "0.10.0"
#endif

[Setup]
AppId={{A742D502-FAB0-465F-A688-51DC35B1A890}
AppName=泺栋传奇
AppVersion={#MyAppVersion}
AppPublisher=SunKeXu01
DefaultDirName={localappdata}\Programs\LuodongLegendary
DefaultGroupName=泺栋传奇
AllowNoIcons=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
OutputDir=..\release
OutputBaseFilename=LuodongLegendary-{#MyAppVersion}-win-x64-setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\LuodongLegendary.exe
SetupIconFile=..\godot\assets\app_icon.ico
SetupLogging=yes

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加快捷方式："

[Files]
Source: "..\build\windows\LuodongLegendary.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\LuodongLegendary.pck"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\godot\ENGINE_LICENSE.txt"; DestDir: "{app}\licenses"; DestName: "GodotEngine.txt"; Flags: ignoreversion

[Icons]
Name: "{group}\泺栋传奇"; Filename: "{app}\LuodongLegendary.exe"
Name: "{autodesktop}\泺栋传奇"; Filename: "{app}\LuodongLegendary.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\LuodongLegendary.exe"; Description: "启动泺栋传奇"; Flags: nowait postinstall skipifsilent
