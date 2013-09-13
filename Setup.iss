; -- Languages.iss --
; Demonstrates a multilingual installation.

; SEE THE DOCUMENTATION FOR DETAILS ON CREATING .ISS SCRIPT FILES!


#pragma option -v+
#pragma verboselevel 9

#define Automated
#ifndef Automated
  #define Path AddBackslash(SourcePath)+"bin\FinalBuilder\Win32\Exe"
  #define OutputDir Path
#endif

#define AppName "Screenshoter"
#define AppId "Screenshoter"
#define AppVersion4Digits GetFileVersion(AddBackslash(Path) + "Screenshoter.exe")
#define AppVersion Copy(AppVersion4Digits,1,RPos('.',AppVersion4Digits)-1)

[Setup]
AppId={#AppId}
AppName={#AppName}
AppVersion={#AppVersion}
OutputDir = {#OutputDir}
AppVerName = {#AppVersion}
DefaultDirName={pf}\{#AppName}
DefaultGroupName={#AppName}
SourceDir={#Path}
WizardSmallImageFile = {#SourcePath}Images\SetupIcon.bmp
UninstallDisplayIcon={#Path}\Screenshoter.exe
VersionInfoDescription=Screenshoter Setup
VersionInfoProductName=Screenshoter
DisableProgramGroupPage = true
OutputBaseFilename=ScreenshoterSetup

; Uncomment the following line to disable the "Select Setup Language"
; dialog and have it rely solely on auto-detection.
;ShowLanguageDialog=no
; If you want all languages to be listed in the "Select Setup Language"
; dialog, even those that can't be displayed in the active code page,
; uncomment the following line. Note: Unicode Inno Setup always displays
; all languages.
;ShowUndisplayableLanguages=yes

[Languages]

Name: English; MessagesFile: "D:\DropBox\Megasplash\Dropbox\Delphi\snaptool\Languages\English\English.isl"; LicenseFile: "D:\DropBox\Megasplash\Dropbox\Delphi\snaptool\Languages\English\License.txt"
Name: Russian; MessagesFile: "D:\DropBox\Megasplash\Dropbox\Delphi\snaptool\Languages\Russian\Russian.isl"; LicenseFile: "D:\DropBox\Megasplash\Dropbox\Delphi\snaptool\Languages\Russian\License.txt"

[Files]
Source: "{#Path}\Screenshoter.exe"; DestDir: "{app}";
Source: "{#Path}\Screenshoter_hook.dll"; DestDir: "{app}"
Source: "{#Path}\Options.ini"; DestDir: "{app}";Flags:onlyifdoesntexist; 
;Source: "MyProg.chm"; DestDir: "{app}"; Languages: en
;Source: "Readme.txt"; DestDir: "{app}"; Languages: en; Flags: isreadme
;Source: "Readme-Dutch.txt"; DestName: "Leesmij.txt"; DestDir: "{app}"; Languages: nl; Flags: isreadme
;Source: "Readme-German.txt"; DestName: "Liesmich.txt"; DestDir: "{app}"; Languages: de; Flags: isreadme

[Icons]
Name: "{group}\{cm:MyAppName}"; Filename: "{app}\Screenshoter.exe"; WorkingDir: "{app}"
Name: "{group}\{cm:UninstallProgram,{cm:MyAppName}}"; Filename: "{uninstallexe}"
[Run]
Filename: {app}\Screenshoter.exe; Description: {cm:LaunchProgram,{cm:MyAppName}}; Flags: nowait postinstall skipifsilent
[INI]
Filename: "{app}\Options.ini"; Section: "Options"; Key: "Language"; String: "{cm:LanguageNumber}";
[Registry]
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "Screenshoter"; ValueData: ""; Flags:dontcreatekey uninsdeletevalue;

[Code]
/////////////////////////////////////////////////////////////////////
function GetUninstallString(): String;
var
  sUnInstPath: String;
  sUnInstallString: String;
begin
  sUnInstPath := ExpandConstant('Software\Microsoft\Windows\CurrentVersion\Uninstall\{#emit SetupSetting("AppId")}_is1');
  sUnInstallString := '';
  if not RegQueryStringValue(HKLM, sUnInstPath, 'UninstallString', sUnInstallString) then
    RegQueryStringValue(HKCU, sUnInstPath, 'UninstallString', sUnInstallString);
  Result := sUnInstallString;
end;


/////////////////////////////////////////////////////////////////////
function IsUpgrade(): Boolean;
begin
  Result := (GetUninstallString() <> '');
end;



/////////////////////////////////////////////////////////////////////
function UnInstallOldVersion(): Integer;
var
  sUnInstallString: String;
  iResultCode: Integer;
begin
// Return Values:
// 1 - uninstall string is empty
// 2 - error executing the UnInstallString
// 3 - successfully executed the UnInstallString

  // default return value
  Result := 0;

  // get the uninstall string of the old app
  sUnInstallString := GetUninstallString();
  if sUnInstallString <> '' then begin
    sUnInstallString := RemoveQuotes(sUnInstallString);
    if Exec(sUnInstallString, '/SILENT /NORESTART /SUPPRESSMSGBOXES','', SW_HIDE, ewWaitUntilTerminated, iResultCode) then
      Result := 3
    else
      Result := 2;
  end else
    Result := 1;
end;

  const
    WM_CLOSE = 16;

Function InitializeSetup : Boolean;
var winHwnd: longint;
    retVal : boolean;
    strProg: string;
begin
  Result := true;
  try
    //Either use FindWindowByClassName. ClassName can be found with Spy++ included with Visual C++. 
    strProg := 'TiScreenshoterForm';
    winHwnd := FindWindowByClassName(strProg);
    //Or FindWindowByWindowName.  If using by Name, the name must be exact and is case sensitive.
    //strProg := 'Screenshoter';
    //winHwnd := FindWindowByWindowName(strProg);
    Log('winHwnd: ' + inttostr(winHwnd));
    if winHwnd <> 0 then begin
      retVal:=postmessage(winHwnd,WM_CLOSE,0,0);
      if retVal then
        Result := True
      else
        Result := True;
     end else
      Result:= True;

  except
  end;

end;
/////////////////////////////////////////////////////////////////////
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if (CurStep=ssInstall) then
  begin
    if (IsUpgrade()) then
    begin
      //UnInstallOldVersion();
    end;
  end;
end;

//function ShouldSkipPage(PageID: Integer): Boolean;
//begin
  // this will NEVER happened - see documentation below
//  if (PageID = wpPassword) or (PageID =  wpInfoBefore) or (PageID =  wpUserInfo) or (PageID =  wpSelectDir)
//   or (PageID =  wpSelectComponents) or (PageID =  wpSelectTasks)
//   or (PageID =  wpPreparing) or (PageID =  wpInfoAfter) then
//  begin
    // skip install - simply for example
//    result := True;
//    exit;
//  end else
//    result := false;
//end;
