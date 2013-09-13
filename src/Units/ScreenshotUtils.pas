unit ScreenshotUtils;

interface
uses Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, jpeg, StdCtrls, clipbrd, ActiveX, ShlObj, ShellApi,
  System.Generics.Collections, System.SyncObjs,Math,CommCtrl, mmsystem,
  Vcl.ImgList, Vcl.ComCtrls, Vcl.Grids,ImageUtils,{JclShell, }ShellUtils,
  TrayUtils,  Vcl.Imaging.PngImage,
  {$IFDEF WIN32}
  Vcl.OleAuto,
  {$ENDIF}
  Vcl.AppEvnts, Vcl.Menus, CommonUtils, Vcl.MPlayer,
  Vcl.Imaging.GIFImg, OptUtils, AutoRun, FileUtils;


  type

  TAppState = (asWaitingForScreen, asGrid);
  TStartHook=function(AppHandle: HWND): Integer; stdcall;
  TStopHook=function: Boolean;stdcall;
  TArrayOfThumbnail = Array of TThumbnail;
  TOnErrorEvent = procedure (Error:byte) of object;
  TOnStateChangedEvent = procedure (AppState:TAppState) of object;
  TOnLanguageChangedEvent = procedure of object;
  TGetSelectedItems = function:TArrayOfThumbnail of object;
  TScreenshoter = class
    private
      FHandle: THandle;
      FLanguagesCount: integer;
      FOnError: TOnErrorEvent;
      FOnLanguageChanged: TOnLanguageChangedEvent;
      FOnStateChanged: TOnStateChangedEvent;
      FState: TAppState;
      function GetAutoRun: Boolean;
      function GetDesktopFolder: string;
      function GetFileMask: string;
      function GetLanguage: Integer;
      function GetPlaySound: Boolean;
      procedure OnThumbCollectionUpdated(sender:TObject);
      procedure PlaySnd;
      procedure SetAutoRun(const Value: Boolean);
      procedure SetLanguage(const Value: Integer);
    protected

      hLib2: THandle;
      DllStr1: string;

      FPlaySound:boolean;

      FDesktopFolder:string;
      FGetSelectedItems:TGetSelectedItems;
      FOnCollectionUpdated:TOnCollectionUpdated;
      FFileWatchTread:TFileWatchTread;
      procedure GetLanguages;
      function GetWindowCaption(isDesktop: Boolean): string;
      procedure InvokeOnLanguageChanged;
      procedure InvokeOnStateChanged;

      procedure MakeFileName(const SaveData: TSaveData; var FileName, Hint: string);
      function SafePath(str: string): string;
      procedure SetPlaySound(Active: Boolean);
    public
       ThumbnailCollection:TThumbnailCollection;
      constructor Create;
      function Init(Handle: THandle; ThumbWidth, ThumbHeight: integer;
          AGetSelectedItems: TGetSelectedItems): Integer;
      destructor Destroy; override;
      procedure ChangeState(State: TAppState);
      procedure ClickSoundMessage(var Msg: TMessage);
      procedure Execute;
      procedure InvokeOnError(Error: Integer);
      procedure InvokeOnCollectionUpdated;
      procedure OpenDesktop;
      procedure ShowContextMenu(aPoint: Tpoint);
      procedure WMNewScreen(var Msg: TNewScreenMessage);
      property AutoRun: Boolean read GetAutoRun write SetAutoRun;
      property FileMask: string read GetFileMask;
      property Language: Integer read GetLanguage write SetLanguage;
      property LanguagesCount: integer read FLanguagesCount;
      property PlaySound: Boolean read GetPlaySound write SetPlaySound;
  published
      property OnError: TOnErrorEvent read FOnError write FOnError;
      property OnStateChanged: TOnStateChangedEvent read FOnStateChanged write
          FOnStateChanged;
       property OnCollectionUpdated: TOnCollectionUpdated read FOnCollectionUpdated
        write FOnCollectionUpdated;
      property OnLanguageChanged: TOnLanguageChangedEvent read FOnLanguageChanged
          write FOnLanguageChanged;
  end;

 const
  WM_MYTRAYNOTIFY = 1 + 123;
  RegistryName='Screenshoter';
implementation

uses SmartStringFormat;

constructor TScreenshoter.Create;
begin
  inherited;
  //RegisterWindowMessage(
end;

{ TScreenshoter }

function TScreenshoter.Init(Handle: THandle; ThumbWidth, ThumbHeight: integer;
    AGetSelectedItems: TGetSelectedItems): Integer;
  var
 StartHook1: TStartHook;
 StopHook:TStopHook;
 SHresult: Byte;
 Mask,Desktop:string;
begin
  FHandle:=Handle;
  FGetSelectedItems:=AGetSelectedItems;
  GetLanguages;
  CommonUtils.Language:=Language;
  ThumbnailCollection:=TThumbnailCollection.Create;
  ThumbnailCollection.Width:=ThumbWidth;
  ThumbnailCollection.Height:=ThumbHeight;
  ThumbnailCollection.OnMakeFileName:=MakeFileName;
  ThumbnailCollection.OnCollectionUpdated:=OnThumbCollectionUpdated;
  TOptions.ReadOption('Sound',FPlaySound);
  FDesktopFolder:=GetDesktopFolder;
  Mask:=GetString(S_FILE_MASK);
  if Mask='' then
    exit(E_BAD_FILE_NAME);
  Desktop:=FDesktopFolder;
  Mask:='';

  Desktop:='';
  if FDesktopFolder='' then begin
    ///!!!EROROR
  end;
  //Application.OnIdle:=AppIdle;                            // подключаем обработчик, реагирующий на принтскрин
  hLib2:=0;
  hLib2:=LoadLibrary('Screenshoter_hook.dll');
  @StartHook1:=GetProcAddress(hLib2, 'StartHook');
  if @StartHook1<>nil then begin
    SHresult:=StartHook1(Handle);
    if SHresult<>E_OK then begin
      InvokeOnError(SHresult);
    end;
  end;

  ChangeState(asWaitingForScreen);
  FFileWatchTread:=TFileWatchTread.Create(ThumbnailCollection);
  FFileWatchTread.Start;

  InvokeOnLanguageChanged;
  Result:=E_OK;
end;

destructor TScreenshoter.Destroy;
var
 StopHook1: TStopHook;
begin
  if Assigned(FFileWatchTread) then
    FreeAndNil(FFileWatchTread);
  if assigned(ThumbnailCollection) then
    FreeAndNil(ThumbnailCollection);
  if hLib2<>0 then begin
    @StopHook1:=GetProcAddress(hLib2, 'Hook is Stoped');
    if @StopHook1<>nil then
    FreeLibrary(hLib2);
  end;
  inherited;
end;

procedure TScreenshoter.ChangeState(State: TAppState);
begin
    FState:=State;
    InvokeOnStateChanged;

end;

procedure TScreenshoter.ClickSoundMessage(var Msg: TMessage);
begin
  PlaySnd;
end;

procedure TScreenshoter.Execute;
var selected:TArrayOfThumbnail;
    len,i:integer;
begin
  if not Assigned(FGetSelectedItems) then
    exit;
  selected:=FGetSelectedItems;
  len:=Length(selected)-1;
  for i:=0 to len do begin
    if not Assigned(selected[i]) then
      continue;
    ShellExecute(FHandle,'open',PChar(selected[i].FileName),nil,nil,SW_SHOWNORMAL);
  end;
end;

function TScreenshoter.GetAutoRun: Boolean;
begin
  Result:=TAutoRun.isAutorun(RegistryName);
end;

function TScreenshoter.GetDesktopFolder: string;

var
 buf: array[0..MAX_PATH] of char;
 pidList: PItemIDList;
begin
  if (FDesktopFolder<>'') and DirectoryExists(FDesktopFolder) then
    exit(FDesktopFolder);
  FDesktopFolder := '';
  SHGetSpecialFolderLocation(Application.Handle, CSIDL_DESKTOP, pidList);
  if (pidList <> nil) then
    if (SHGetPathFromIDList(pidList, buf)) then
      FDesktopFolder := buf;
  Result:=FDesktopFolder;
end;

function TScreenshoter.GetFileMask: string;
begin
  Result :=  GetString(S_FILE_MASK);;
end;

function TScreenshoter.GetLanguage: Integer;
begin
  TOptions.ReadOption('Language',Result);
end;

procedure TScreenshoter.GetLanguages;
var i:integer;
    found:boolean;
    LangName:string;
begin
  i:=0;
  repeat
    found:=TryGetString(1,LangName,i);
    inc(i);
  until not found;
  dec(i);
  fLanguagesCount:=i;
end;

function TScreenshoter.GetPlaySound: Boolean;
begin
  TOptions.ReadOption('Sound',Result);
end;

function TScreenshoter.GetWindowCaption(isDesktop: Boolean): string;
var
  Handle: HWND;
  captionSize:integer;
const MaxCaptionSize=50;
begin
  SetLength(Result, MaxCaptionSize);
  if isDesktop then
    exit('')
    //Handle:=GetDesktopWindow
  else
    Handle := GetForegroundWindow();
  captionSize:=GetWindowText(Handle, PChar(Result), MaxCaptionSize);
  if (captionSize=0) then begin
    if isDesktop then
      result:=''
    else
      result:=GetWindowCaption(true);
  end else begin
    SetLength(Result, captionSize);
  end;
  //MessageBox(0,PChar(Result),PChar('jhkhj'),0);
end;

procedure TScreenshoter.InvokeOnError(Error: Integer);
begin
  if Assigned(OnError) then
    OnError(Error)
end;

procedure TScreenshoter.InvokeOnCollectionUpdated;
begin
  if Assigned(OnCollectionUpdated) then
    OnCollectionUpdated(ThumbnailCollection);
end;

procedure TScreenshoter.InvokeOnLanguageChanged;
begin
  if Assigned(OnLanguageChanged) then
    OnLanguageChanged;
end;

procedure TScreenshoter.InvokeOnStateChanged;
begin
  if Assigned(OnStateChanged) then
    OnStateChanged(FState);
end;

procedure TScreenshoter.MakeFileName(const SaveData: TSaveData; var FileName,
    Hint: string);
var Mask,NewFileName:string;
  i:integer;
begin
  try
    Mask:=FileMask;
    if Mask='' then
      exit;
      FileName:=CSharpFormat(Mask,[SaveData.Date,SaveData.ForegroundWindowCaption]);
      FileName:=SafePath(FileName);
    except
      FileName:='';
    end;
    if FileName='' then
      exit;
    Hint:=FileName + '.png';
    NewFileName:=IncludeTrailingPathDelimiter(FDesktopFolder)+Hint;
    i:=1;
    while FileExists(NewFileName) do
    begin
      Hint:=FileName+' ('+IntToStr(i)+')' + '.png';
      NewFileName:=IncludeTrailingPathDelimiter(FDesktopFolder)+Hint;
      inc(i);
    end;
    FileName:=NewFileName;
end;

procedure TScreenshoter.OnThumbCollectionUpdated(sender:TObject);
var ListItem:TListItem;
    this:TThumbnailCollection absolute Sender;
begin
  if ThumbnailCollection.Count=0 then
    ChangeState(asWaitingForScreen)
  else
    ChangeState(asGrid);
  InvokeOnCollectionUpdated;
end;

procedure TScreenshoter.OpenDesktop;
begin
  if GetDesktopFolder<>'' then
  try
    ShellExecute(Application.Handle,
      PChar('explore'),
      PChar(GetDesktopFolder),
      nil,
      nil,
      SW_SHOWNORMAL);
  except

  end;
end;

     //MediaPlayer1
procedure TScreenshoter.PlaySnd;
begin
  if FPlaySound then begin
  sndPlaySoundW(PChar('CLICK'),SND_RESOURCE or
    SND_NODEFAULT OR SND_ASYNC);
  end;
end;

function TScreenshoter.SafePath(str: string): string;
var st:TCharSet;
    substr:string;
    badName:boolean;
begin
  str:=Trim(str);
  st:=['<','>',':','"','/','\','|','?','*',#1..#31];
  MultiReplace(str,st,' ');
  badName:=false;
  if (Length(str)=3) then begin
      substr:=UpperCase(str);
      case str[1] of
       'C':begin badName:=str='CON' end;
       'P':begin badName:=str='PRN' end;
       'A':begin badName:=str='AUX' end;
       'N':begin badName:=str='NUL' end;
      end;
  end else
    if (Length(str)=4)and(str[4] in ['0'..'9']) then begin
      case str[1] of
       'C':begin badName:=(str[2]='O') and (str[3]='M') end;
       'L':begin badName:=(str[2]='P') and (str[3]='T') end;
      end;
    end;
  if badName then
    str:=Copy(str,1,2);

  result:=str;
  //MessageBox(0,PChar(Result),PChar('jhkhj1'),0);
end;

procedure TScreenshoter.SetAutoRun(const Value: Boolean);
begin
  TAutoRun.SetAutorun(RegistryName,Value);
end;

procedure TScreenshoter.SetLanguage(const Value: Integer);
begin
  if (Value<0) or (Value>=LanguagesCount) then
    exit;
  CommonUtils.Language:=TOptions.WriteOption('Language',Value);
  InvokeOnLanguageChanged;
end;

procedure TScreenshoter.SetPlaySound(Active: Boolean);
begin
  FPlaySound:=TOptions.WriteOption('Sound',Active);
end;



procedure TScreenshoter.ShowContextMenu(aPoint: Tpoint);
var selected:TArrayOfThumbnail;
    len,i:integer;
    fileNames:TStringArray;
begin
  if not Assigned(FGetSelectedItems) then
    exit;
  selected:=FGetSelectedItems;
  len:=Length(selected);
  if Len>0 then begin
    SetLength(fileNames,len);
    for i:=len-1 downto 0 do
      fileNames[i]:=selected[i].FileName;
    TShell.DisplayContextMenu(FHandle,fileNames,aPoint);
  end;
  // TODO -cMM: TScreenshoter.ShowContextMenu default body inserted
end;

procedure TScreenshoter.WMNewScreen(var Msg: TNewScreenMessage);
const
  MAX_ATTEMPTS = 10;
var
   SaveData:TSaveData;
   Attempts:integer;
   Success:Boolean;
   Map:TFileMap;
 begin
// exit;
//  PlaySnd;
  //len:=Msg.CopyDataStruct.cbData;
  //SetLength(sText,len div 2);
  //StrLCopy(PWideChar(sText), Msg.CopyDataStruct.lpData, len*sizeof(char));
  Msg.Result:=0;

  if Clipboard.HasFormat(CF_BITMAP) then begin
      Attempts := 0;
      SaveData:=TSaveData.Create;                          // сбрасываем счётчик попыток
      try
        SaveData.Bitmap:=TPngImage.Create;
        repeat
          Success := true;                          // Изначально предполагаем успех
          Attempts := Attempts + 1;                 // Попытки +1
          try
            SaveData.Bitmap.LoadFromClipboardFormat(CF_BITMAP, Clipboard.GetAsHandle(CF_BITMAP),0);      // Пробуем взять скрин из буфера
          except
          on E:Exception do begin
              Success := false;                                                                           // сбрасываем флаг успех
            end;
          end;
        until (Success)or (Attempts > MAX_ATTEMPTS);                                         // сохраняем
        if (Success) then begin
          SaveData.Date:=Now();
          SaveData.ForegroundWindowCaption:=GetWindowCaption(Msg.IsAltDown=0);
          //MessageBox(0,PChar(Format('%s - %d',[SaveData.ForegroundWindowCaption, Parent])),PChar('!'),0);
          //SendResult(Parent,SaveData);
          //PlaySound('SOUND', HINSTANCE, SND_RESOURCE OR SND_ASYNC);
        end;
      except
        FreeAndNil(SaveData);
      end;
    end;
  if SaveData=nil then
    exit;
    PlaySnd;
  try
    if Assigned(ThumbnailCollection) then
      ThumbnailCollection.Add(SaveData);
  except
    FreeAndNil(SaveData);
  end;

 // Panel1.Caption:=IntToStr(StrToInt(Panel1.Caption)+1);


end;

end.
