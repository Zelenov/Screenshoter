unit CommonUtils;


interface
uses Messages,Windows,Vcl.Imaging.pngimage,SysUtils;


type
{CreateFileMapping or OpenFileMapping}
TFileMapOperation = (fmoRead,fmoWrite);

{Just a shell for mapping operaions}
TFileMap=record

  hMemFile:THandle; //File mapping handle
  fView:Pointer;//Pointer to shared memory
  /// <summary>Creates file map for writing
  /// </summary>
  /// <param name="aName"> name of shared memory file</param>
  /// <param name="aSize"> size of shared memory file</param>
  constructor Create(aName:string;aSize:integer); overload;
  /// <summary>Creates file map for reading
  /// </summary>
  /// <param name="aName"> name of shared memory file</param>
  constructor Create(aName: string); overload;
private
  FLastError: Integer; //Last error E_OK, if no errors
  /// <summary>Creates shared memory file for reading or writing
  /// </summary>
  /// <param name="aName"> name of shared memory file</param>
  /// <param name="aSize"> size of shared memory file </param>
  /// <param name="aOperation">read or write operation</param>
  constructor Create(aName: string; aSize: integer; aOperation:
      TFileMapOperation); overload;
  function GetCreated: Boolean;
public
  /// <summary>Closes shared memory
  /// </summary>
  procedure Destroy;
  /// <summary>Closes memory pointer
  /// </summary>
  procedure StopIO;
  property pView:Pointer read fView;
  /// <summary>Returns true if shared memory is not closed.
  /// </summary>
  /// type:Boolean
  property Created: Boolean read GetCreated;
  property LastError: Integer read FLastError;

end;
 TCharSet = set of char;
 {Message for interprocess communication}
 TNewScreenMessage = record
    Msg: Cardinal;
    Parent: HWND;  //Handle of parent window (reciever)
    IsAltDown: Integer; // 0 if alt is not down;
    Result: LRESULT;
 end;


/// <summary>Finding string in resources by key=(aLanguage+1)*1000+Index
/// </summary>
/// <returns> True, if string have been found in resources
/// </returns>
/// <param name="Index"> Index of string in resources </param>
/// <param name="sTranslation"> value found </param>
/// <param name="aLanguage"> language number </param>
function TryGetString(const Index: integer; out sTranslation: string;
    aLanguage: Integer): Boolean;

/// <summary>Returns string in resources by index in current language
/// </summary>
/// <returns>found string or empty string, if key doesn't exist
/// </returns>
/// <param name="Index">Index of string in current language </param>
function GetString(const Index: integer): string;

/// <summary>Replaces char in string, if it is in characters set.</summary>
/// <param name="str"> string to modify </param>
/// <param name="characters"> set  of characters to replace</param>
/// <param name="replacement"> replacement character</param>
procedure MultiReplace(var str: string; const characters: TCharSet; const
    replacement: char); overload;

/// <summary>Replaces char in string, if it is in characters array
/// </summary>
/// <param name="str"> string to modify </param>
/// <param name="characters"> array of characters to replace</param>
/// <param name="replacement"> replacement </param>
procedure MultiReplace(var str:string; const characters:array of char; const
    replacement:char); overload;

/// <summary>Replaces char in string, if it is in characters array.
/// n-th character in characters array is replacing by n-th character in
/// replacement array
/// </summary>
/// <param name="str"> string to modify </param>
/// <param name="characters"> array of characters to replace</param>
/// <param name="replacement"> array of replacement characters</param>
procedure MultiReplace(var str:string; const characters:array of char; const
    replacement:array of char); overload;

const
  COPYDATA_MAP = 'Global\Screenshoterx68';
  APP_NEWSCREEN=WM_APP+3;

  E_OK = 0;
  E_ALREADY_HOOKED = 1;
  E_MAPCREATE_FAILED = 7;
  E_MAP_EXISTS = 8;
  E_MAPVIEW_FAILED = 3;
  E_VIEW_ACCES_VIOLATION = 4;
  E_DESKTOPPATH_NOT_FOUND = 5;
  E_HOOK_FAILED = 6;
  E_BAD_FILE_NAME = 9;
  E_UNKNOWN_ERROR=128;


  WM_PLAY_CLICKSOUND = WM_APP+1;

S_LANGUAGE = 1;
  S_PRESS_PRINTSCREEN = 2;
  S_OPEN_DESKTOP = 3;
  S_LAST_SCREENS = 4;
  S_MAINWIN_CAPTION = 5;
  S_AUTORUN = 6;
  S_SOUND = 7;
  S_MENU_LANGUAGE = 8;
  S_ABOUT = 9;
  S_ABOUT_CAPTION = 10;
  S_QUIT = 11;
  S_ABOUT_TITLE = 12;
  S_ABOUT_INFO = 13;
  S_ABOUT_ME = 14;
  S_ABOUT_GITHUB = 15;
S_FILE_MASK = 16;
  S_ALREADY_HOOKED = 101;
  S_MAPCREATE_FAILED = 102;
  S_MAP_EXISTS = 103;
  S_MAPVIEW_FAILED = 104;
  S_VIEW_ACCES_VIOLATION = 105;
  S_DESKTOPPATH_NOT_FOUND = 106;
  S_HOOK_FAILED = 107;
  S_UNKNOWN_ERROR = 108;
S_BAD_FILE_NAME = 109;




var Language:integer = 0;
implementation



function TryGetString(const Index: integer; out sTranslation: string;
    aLanguage: Integer): Boolean;
var
  buffer : array[0..255] of char;
  ls : integer;
begin
  sTranslation := '';
  ls := LoadString(hInstance,
                   (aLanguage+1)*1000+Index,
                   buffer,
                   sizeof(buffer));
  Result:=ls <> 0;
  if Result then
    sTranslation := buffer
end;

function GetString(const Index: integer): string;
var found:boolean;

    lang:integer;
begin
  found:=TryGetString(Index,Result,Language);
  if not found then begin
    if Language=0 then
      Result :=''
    else begin
      found:=TryGetString(Index,Result,1);
      if not found then
        Result:='';
    end;
  end;

end;

procedure MultiReplace(var str:string; const characters:array of char; const
    replacement:array of char);
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

procedure MultiReplace(var str:string; const characters:array of char; const
    replacement:char);
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
    replacement: char);
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

constructor TFileMap.Create(aName:string;aSize:integer);
begin
  Create(aName,aSize,fmoWrite);
end;

constructor TFileMap.Create(aName: string);
begin
  Create(aName,0,fmoRead);
end;

constructor TFileMap.Create(aName: string; aSize: integer; aOperation:
    TFileMapOperation);
var CreateFileMappingProtection,MapViewOfFileAccess:Cardinal;
begin
  fView:=0;
  hMemFile:=0;
  case aOperation of
    fmoRead:begin
              CreateFileMappingProtection:=FILE_MAP_READ;
              MapViewOfFileAccess:=FILE_MAP_READ;
              hMemFile := OpenFileMapping(CreateFileMappingProtection, False, PChar(aName));
              if hMemFile=0 then
                FLastError:=E_MAPCREATE_FAILED;
            end;
    fmoWrite:begin
              CreateFileMappingProtection:=PAGE_READWRITE;
              MapViewOfFileAccess:=FILE_MAP_WRITE;
              hMemFile := CreateFileMapping(INVALID_HANDLE_VALUE, nil,
                CreateFileMappingProtection, 0, aSize, PChar(aName));
              if hMemFile=0 then
                FLastError:=E_MAPCREATE_FAILED;
            end;
  end;


  if hMemFile = 0 then
   Exit;
  fView := MapViewOfFile(hMemFile, MapViewOfFileAccess, 0, 0, 0);
  if (pView=nil) then begin
    FLastError:=E_MAPVIEW_FAILED;
    Destroy;
    exit;
  end;
  FLastError:=E_OK;
end;

procedure TFileMap.Destroy;
begin
  if pView<>nil then
    StopIO;
  if (hMemFile<>0) then begin
    CloseHandle(hMemFile);
    hMemFile:=0;
  end;
end;

function TFileMap.GetCreated: Boolean;
begin
  Result := (hMemFile<>0)or(pView<>nil);
end;

procedure TFileMap.StopIO;
begin
  if pView<>nil then begin
    UnmapViewOfFile(pView);
    fView:=nil;
  end;
end;

end.
