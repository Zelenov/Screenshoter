unit Screenutils;

interface
uses
  Classes,Windows, Vcl.Graphics,System.SyncObjs,mmsystem,System.Generics.Collections,
    Vcl.clipbrd, ActiveX, SysUtils,ZThreads,Messages,StrUtils,ShlObj,CommCtrl,Math,
  CommonUtils,Vcl.Imaging.pngimage, SmartStringFormat;
type
 
TSaveThread = class (TQueueThread<TSaveData>)
protected
  Parent:HWND;
  procedure SendResult(const FilePath: string);

public
  DesktopPath: string;
  constructor Create(aParent:HWND);
  procedure Process(const Item: TSaveData); override;

end;
//var
//Parent:HWND;
//DesktopPath: string;
procedure Process(const Item: TSaveData; const DesktopPath: string; Mask:
    string; AppHandle: HWND; IsAltDown: Boolean);

procedure PlaySnd(Parent: HWND);

function GetWindowCaption(isDesktop: Boolean): string;

function SafePath(str: string): string;

procedure SendResult1(const FilePath: string; Parent: HWND);

implementation
type
TCharSet = set of char;
procedure MultiReplace(var str:string; const characters:array of char;
             const replacement:array of char); overload;
var c:PChar;
    character:char;
    i:integer;
begin
  if (Length(characters)=0) or (Length(replacement)<>Length(characters)) then
    exit;
  c:=@str[1];
  while c^<>#0 do begin
    for i:=Length(characters)-1 downto 0 do begin
      character:=characters[i];
      if (c^=character) then
        c^:=replacement[i];
    end;
    inc(c);
  end;
end;
procedure MultiReplace(var str:string; const characters:array of char;
             const replacement:char); overload;
var c:PChar;
    character:char;
    i:integer;
begin
  if (Length(characters)=0) then
    exit;
  c:=@str[1];
  while c^<>#0 do begin
    for i:=Length(characters)-1 downto 0 do begin
      character:=characters[i];
      if (c^=character) then
        c^:=replacement;
    end;
    inc(c);
  end;
end;

procedure MultiReplace(var str: string; const characters: TCharSet; const
    replacement: char); overload;
var c:PChar;
    character:char;
begin
  if (characters=[]) then
    exit;
  c:=@str[1];
  while c^<>#0 do begin
    if (c^ in characters) then
      c^:=replacement;
    inc(c);
  end;
end;


procedure Process(const Item: TSaveData; const DesktopPath: string; Mask:
    string; AppHandle: HWND; IsAltDown: Boolean);
var
NewFilePath,FilePath,FileName:string;
i:integer;
windowCaption:string;
begin
  //MessageBox(0,PChar(DesktopPath),PChar('324'),0);

  if DesktopPath<>'' then begin

    windowCaption:=GetWindowCaption(not IsAltDown);
    //MessageBox(0,PChar(windowCaption),PChar('324'),0);
    try
      //FileName:=CSharpFormat(Mask,[Item.Date,windowCaption]);
      FileName:='Screenshot';
      FileName:=SafePath(FileName);
    except
      FileName:='';
      beep;
    end;
    if FileName='' then
      exit;
    //FileName:='Screenshot - ' + FileName;
    NewFilePath:=DesktopPath+'\'+FileName + '.png';
    i:=1;
    while FileExists(NewFilePath) do
    begin
      NewFilePath:=DesktopPath+'\'+FileName+' ('+IntToStr(i)+')' + '.png';
      inc(i);
    end;
    try
      //Self.Synchronize(procedure begin
     //MessageBox(0,PChar(NewFilePath),PChar('jhkhj'),0);
      //end);
      Item.Bitmap.SaveToFile(NewFilePath);
      //PlaySound('SOUND', HINSTANCE, SND_RESOURCE OR SND_ASYNC);
      //SendResult(NewFilePath,Apphandle);
    except
      on E:Exception do begin
        MessageBox(0,PChar(E.Message),'Error',0);
      end;
    end;
  end;
    if Assigned(Item.Bitmap) then
      Item.Bitmap.Free;
end;
procedure PlaySnd(Parent: HWND);
var msg:Cardinal;
begin
 // msg:=RegisterWindowMessage('WM_PLAY_CLICKSOUND');
  //if msg=0 then  begin
  //beep;
  //end;

  //beep;
  //MessageBox(0,pChar(CSharpFormat('{0}',[Parent])),'a',0);
   // PostMessage(Parent, msg, 0, 0);
end;
function GetWindowCaption(isDesktop: Boolean): string;
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

function SafePath(str: string): string;
var st:TCharSet;
    substr:string;
    badName:boolean;
begin
  str:=Trim(str);
  st:=['<','>',':','"','/','\','|','?','*','.',#1..#31];
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

procedure SendResult1(const FilePath: string; Parent: HWND);
var
  hMap : THandle;
  pData: Pointer;
  DataStruct: TCopyDataStruct;
  name:string;
  Result:boolean;
  len:integer;
begin

  //exit;
  len:=Min(Length(FilePath),60);
  name:=Copy(FilePath,Length(FilePath)-len,len);
  name:=StringReplace(name,'\','_',[rfReplaceAll]);
  //name:='sadasd'
  hMap := CreateFileMapping($FFFFFFFF, nil,
   PAGE_READWRITE, 0, Length(FilePath)+1, PChar(name));

  if hMap = 0 then Exit;
  try
    len:=(Length(FilePath)+1)*sizeof(Char);

    pData := MapViewOfFile(hMap, FILE_MAP_WRITE, 0, 0, len);
    if pData<>nil then
    begin
    try
      CopyMemory(pData, PChar(FilePath), len);
      if Parent<>0 then
      begin
        DataStruct.dwData := 0;
        DataStruct.cbData := len;
        DataStruct.lpData := pData;
        //MessageBox(0,PChar(FilePath+' '+IntToStr(len)+' '+IntToStr(Parent)),PChar(name),0);
        Result := (SendMessage(Parent, WM_COPYDATA, 0, Longint(@DataStruct)) = 0);
        // MessageBox(0,PChar('ok'),PChar(name),0);
      end;
    finally
      UnmapViewOfFile(pData);
    end;
  end;
  finally
    if hMap<>0 then
      CloseHandle(hMap);
  end;
end;




constructor TSaveThread.Create(aParent:HWND);
begin
  inherited Create('ScreenFinishThreadEvent','ScreenFinishThreadSemaphore');
  Parent:=aParent;
end;

procedure TSaveThread.Process(const Item: TSaveData);
var
NewFilePath,FilePath,FileName:string;
i:integer;
begin

  //MessageBox(0,PChar('234'),PChar('324'),0);
  DateTimeToString(FileName,'DD.MM.YY',Item.Date);
  FileName:='Screenshot - ' + FileName;
  NewFilePath:=DesktopPath+'\'+FileName + '.bmp';
  i:=1;
  while FileExists(NewFilePath) do
  begin
    NewFilePath:=DesktopPath+'\'+FileName+' ('+IntToStr(i)+')' + '.bmp';
    inc(i);
  end;
  try
    //Self.Synchronize(procedure begin
    //MessageBox(0,PChar(NewFilePath),PChar('jhkhj'),0);
    //end);
    Item.Bitmap.SaveToFile(NewFilePath);
    //PlaySound('SOUND', HINSTANCE, SND_RESOURCE OR SND_ASYNC);
    SendResult(NewFilePath);
  except
    on E:Exception do begin
      MessageBox(0,PChar(E.Message),'Error',0);
    end;
  end;
  if Assigned(Item.Bitmap) then
    Item.Bitmap.Free;
end;

procedure TSaveThread.SendResult(const FilePath: string);
var
  hMap : THandle;
  pData: Pointer;
  DataStruct: TCopyDataStruct;
  name:string;
  Result:boolean;
  len:integer;

  fileMap:TFileMap;
begin
  //EXIT;
  len:=Min(Length(FilePath),60);
  name:=Copy(FilePath,Length(FilePath)-len,len);
  name:=StringReplace(name,'\','_',[rfReplaceAll]);

  len:=(Length(FilePath))*sizeof(char);
  fileMap:=TFileMap.Create(COPYDATA_MAP,len);
  if filemap.Created then
  try
    try
      CopyMemory(filemap.pView,@FilePath[1],len);
    finally
      filemap.StopIO;
    end;
    Result := (SendMessage(Parent, WM_COPYDATA, 0, 0) = 0);
  finally
    filemap.Destroy;
  end;
  {
  //name:='sadasd'
  hMap := CreateFileMapping($FFFFFFFF, nil,
   PAGE_READWRITE, 0, Length(FilePath)+1, PChar(name));

  if hMap = 0 then Exit;
  try
    len:=(Length(FilePath)+1)*sizeof(Char);
    // MessageBox(0,PChar(FilePath+' '+IntToStr(len)),PChar(name),0);
    pData := MapViewOfFile(hMap, FILE_MAP_WRITE, 0, 0, len);
    if pData<>nil then
    begin
    try
      CopyMemory(pData, PChar(FilePath), len);
      DataStruct.lpData := pData;
    finally
      UnmapViewOfFile(pData);
      pData:=nil;
    end;
   if Parent<>0 then
    begin

      DataStruct.dwData := 0;
      DataStruct.cbData := len;
      Result := (SendMessage(Parent, WM_COPYDATA, 0, Longint(@DataStruct)) = 0);
    end;
  end;
  finally
    if hMap<>0 then
      CloseHandle(hMap);
  end;  }
end;

{ TSaveData }


end.
