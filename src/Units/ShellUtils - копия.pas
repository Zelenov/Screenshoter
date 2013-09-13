unit ShellUtils;
{$DEFINE SUPPORTS_UNICODE}
interface
uses Windows,Classes,ShlObj,ShellApi,SysUtils,Vcl.Dialogs,Forms,
Winapi.Messages,Winapi.ActiveX
 {$IFDEF WIN32}
   ,Vcl.OleAuto
  {$ENDIF}
 ;
type
TStringArray = array of string;
TPidlArray = array of PItemIDList;
{$IFDEF MSWINDOWS}
  TModuleHandle = HINST;
{$ENDIF MSWINDOWS}
{$IFDEF LINUX}
  TModuleHandle = Pointer;
{$ENDIF LINUX}
TShell = class
  private
    class function CreateMenuCallbackWnd(const ContextMenu: IContextMenu2): THandle;
  public
    class function DisplayContextMenuPidl(const Handle: THandle; const Folder:
        IShellFolder; Item: TPidlArray; Pos: TPoint): Boolean;

    class function DisplayContextMenu(const Handle: THandle; const FileName: string; Pos:
        TPoint): Boolean; overload;

    // memory initialization
    // first parameter is "out" to make FPC happy with uninitialized values
    class procedure ResetMemory(out P; Size: Longint);

    class function PathToPidlBind(const FileName: string; out Folder: IShellFolder): PItemIdList;

    class function PidlFree(var IdList: PItemIdList): Boolean;

    // Paths and PIDLs
    class function DriveToPidlBind(const DriveName: string; out Folder: IShellFolder): PItemIdList;

    class procedure UnloadModule(var Module: TModuleHandle);

    class function FileNamesToPidlArray(FileNames: TStringArray; out Folder:
        IShellFolder): TPidlArray;

    class function DisplayContextMenu(const Handle: THandle; FileNames: TStringArray;
        Pos: TPoint): Boolean; overload;

    class function GetFileListDataObject(const Directory: string; Files: TStrings):
        IDataObject;
end;
const
  INVALID_MODULEHANDLE_VALUE = TModuleHandle(0);
var
  // MSI.DLL functions can''t be converted to Unicode due to an internal compiler bug (F2084 Internal Error: URW1021)
  RtdlMsiLibHandle: TModuleHandle = INVALID_MODULEHANDLE_VALUE;
implementation
type
  TWidePath = array [0..MAX_PATH-1] of WideChar;
  {$IFDEF SUPPORTS_UNICODE}
  TWidePathPtr = PWideChar;
  {$ELSE ~SUPPORTS_UNICODE}
  TWidePathPtr = TWidePath;
  {$ENDIF ~SUPPORTS_UNICODE}
// Window procedure for the callback window created by DisplayContextMenu.
// It simply forwards messages to the folder. If you don't do this then the
// system created submenu's will be empty (except for 1 stub item!)
// note: storing the IContextMenu2 pointer in the window's user data was
// 'inspired' by (read: copied from) code by Brad Stowers.

function MenuCallback(Wnd: THandle; Msg: UINT; wParam: WPARAM;
    lParam: LPARAM): LRESULT;
var
  ContextMenu2: IContextMenu2;
begin
  case Msg of
    WM_CREATE:
      begin
        ContextMenu2 := IContextMenu2(PCreateStruct(lParam).lpCreateParams);
        SetWindowLongPtr(Wnd, GWLP_USERDATA, LONG_PTR(ContextMenu2));
        Result := DefWindowProc(Wnd, Msg, wParam, lParam);
      end;
    WM_INITMENUPOPUP:
      begin
        ContextMenu2 := IContextMenu2(GetWindowLongPtr(Wnd, GWLP_USERDATA));
        ContextMenu2.HandleMenuMsg(Msg, wParam, lParam);
        Result := 0;
      end;
    WM_DRAWITEM, WM_MEASUREITEM:
      begin
        ContextMenu2 := IContextMenu2(GetWindowLongPtr(Wnd, GWLP_USERDATA));
        ContextMenu2.HandleMenuMsg(Msg, wParam, lParam);
        Result := 1;
      end;
  else
    Result := DefWindowProc(Wnd, Msg, wParam, lParam);
  end;
end;

// Helper class function TShell.for DisplayContextMenu, creates the callback window.

class function TShell.CreateMenuCallbackWnd(const ContextMenu: IContextMenu2):
    THandle;
const
  IcmCallbackWnd = 'ICMCALLBACKWND';
var
  WndClass: TWndClass;
begin
 ResetMemory(WndClass, SizeOf(WndClass));
  WndClass.lpszClassName := PChar(IcmCallbackWnd);
  WndClass.lpfnWndProc := @MenuCallback;
  WndClass.hInstance := HInstance;
  Windows.RegisterClass(WndClass);
  try
  Result := CreateWindow(IcmCallbackWnd, IcmCallbackWnd, WS_POPUPWINDOW, 0,
    0, 0, 0, 0, 0, HInstance, Pointer(ContextMenu));
  except
    On e:Exception do begin
      beep;
    end;
  end;
end;

class function TShell.DisplayContextMenuPidl(const Handle: THandle; const Folder:
    IShellFolder; Item: TPidlArray; Pos: TPoint): Boolean;
var
  Cmd: Cardinal;
  ContextMenu: IContextMenu;
  ContextMenu2: IContextMenu2;
  Menu: HMENU;
  CommandInfo: TCMInvokeCommandInfo;
  CallbackWindow: THandle;
begin
  Result := False;
  if (Length(Item)=0) or (Folder = nil) then
    Exit;
  Folder.GetUIObjectOf(Handle, Length(Item), Item[0], IID_IContextMenu, nil,
    Pointer(ContextMenu));
  if ContextMenu <> nil then
  begin
    Menu := CreatePopupMenu;
    if Menu <> 0 then
    begin
      if Succeeded(ContextMenu.QueryContextMenu(Menu, 0, 1, $7FFF, CMF_EXPLORE)) then
      begin
        CallbackWindow := 0;
        if Succeeded(ContextMenu.QueryInterface(IContextMenu2, ContextMenu2)) then
        begin
          CallbackWindow := CreateMenuCallbackWnd(ContextMenu2);
        end;
        ClientToScreen(Handle, Pos);
        Cmd := Cardinal(TrackPopupMenu(Menu, TPM_LEFTALIGN or TPM_LEFTBUTTON or
          TPM_RIGHTBUTTON or TPM_RETURNCMD, Pos.X, Pos.Y, 0, CallbackWindow, nil));
        if Cmd <> 0 then
        begin
          ResetMemory(CommandInfo, SizeOf(CommandInfo));
          CommandInfo.cbSize := SizeOf(TCMInvokeCommandInfo);
          CommandInfo.hwnd := Handle;
          CommandInfo.lpVerb := MakeIntResourceA(Cmd - 1);
          CommandInfo.nShow := SW_SHOWNORMAL;
          Result := Succeeded(ContextMenu.InvokeCommand(CommandInfo));
        end;
        if CallbackWindow <> 0 then
          DestroyWindow(CallbackWindow);
      end;
      DestroyMenu(Menu);
    end;
  end;
end;

class function TShell.DisplayContextMenu(const Handle: THandle; FileNames: TStringArray;
    Pos: TPoint): Boolean;
var
  ItemIdList: TPidlArray;
  Folder: IShellFolder;
  i:Integer;
begin
  Result := False;
  ItemIdList := FileNamesToPidlArray(FileNames, Folder);
  if Length(ItemIdList) >0 then
  begin
    Result := DisplayContextMenuPidl(Handle, Folder, ItemIdList, Pos);
    for i:=Length(ItemIdList)-1 downto 0 do
      PidlFree(ItemIdList[i]);
  end;
end;

class function TShell.PathToPidlBind(const FileName: string; out Folder: IShellFolder): PItemIdList;
var
  Attr, Eaten: ULONG;
  PathIdList: PItemIdList;
  DesktopFolder: IShellFolder;
  Path, ItemName: TWidePathPtr;
begin
  Result := nil;
  {$IFDEF SUPPORTS_UNICODE}
  Path := PChar(ExtractFilePath(FileName));
  ItemName := PChar(ExtractFileName(FileName));
  {$ELSE ~SUPPORTS_UNICODE}
  MultiByteToWideChar(CP_ACP, MB_PRECOMPOSED, PAnsiChar(ExtractFilePath(FileName)), -1, Path, MAX_PATH);
  MultiByteToWideChar(CP_ACP, MB_PRECOMPOSED, PAnsiChar(ExtractFileName(FileName)), -1, ItemName, MAX_PATH);
  {$ENDIF ~SUPPORTS_UNICODE}
  if Succeeded(SHGetDesktopFolder(DesktopFolder)) then
  begin
    Attr := 0;
    if Succeeded(DesktopFolder.ParseDisplayName(0, nil, Path, Eaten, PathIdList,
      Attr)) then
    begin
      if Succeeded(DesktopFolder.BindToObject(PathIdList, nil, IID_IShellFolder,
        Pointer(Folder))) then
      begin
        if Failed(Folder.ParseDisplayName(0, nil, ItemName, Eaten, Result, Attr)) then
        begin
          Folder := nil;
          Result := DriveToPidlBind(FileName, Folder);
        end;
      end;
      PidlFree(PathIdList);
    end
    else
      Result := DriveToPidlBind(FileName, Folder);
  end;
end;

class function TShell.PidlFree(var IdList: PItemIdList): Boolean;
var
  Malloc: IMalloc;
begin
  Result := False;
  if IdList = nil then
    Result := True
  else
  begin
    Malloc := nil;
    if Succeeded(SHGetMalloc(Malloc)) and (Malloc.DidAlloc(IdList) > 0) then
    begin
      Malloc.Free(IdList);
      IdList := nil;
      Result := True;
    end;
  end;
end;

//=== Paths and PIDLs ========================================================

class function TShell.DriveToPidlBind(const DriveName: string; out Folder: IShellFolder): PItemIdList;
var
  Attr: ULONG;
  Eaten: ULONG;
  DesktopFolder: IShellFolder;
  Drives: PItemIdList;
  Path: TWidePathPtr;
begin
  Result := nil;
  if Succeeded(SHGetDesktopFolder(DesktopFolder)) then
  begin
    if Succeeded(SHGetSpecialFolderLocation(0, CSIDL_DRIVES, Drives)) then
    begin
      if Succeeded(DesktopFolder.BindToObject(Drives, nil, IID_IShellFolder,
        Pointer(Folder))) then
      begin
        {$IFDEF SUPPORTS_UNICODE}
        Path := PChar(IncludeTrailingPathDelimiter(DriveName));
        {$ELSE ~SUPPORTS_UNICODE}
        MultiByteToWideChar(CP_ACP, MB_PRECOMPOSED, PAnsiChar(IncludeTrailingPathDelimiter(DriveName)), -1, Path, MAX_PATH);
        {$ENDIF ~SUPPORTS_UNICODE}
        Attr := 0;
        if Failed(Folder.ParseDisplayName(0, nil, Path, Eaten, Result, Attr)) then
        begin
          Folder := nil;
          // Failure probably means that this is not a drive. However, do not
          // call PathToPidlBind() because it may cause infinite recursion.
        end;
      end;
    end;
    CoTaskMemFree(Drives);
  end;
end;

class function TShell.FileNamesToPidlArray(FileNames: TStringArray; out Folder:
    IShellFolder): TPidlArray;
var FileCount,i,j:integer;
begin
  FileCount:=Length(FileNames);
  SetLength(Result,FileCount);
    j:=0;
  try
    for i := FileCount-1 downto 0 do
    begin
      Result[j]:=PathToPidlBind(FileNames[i],Folder);
      if (Result[j]=nil) then
        Dec(FileCount)
      else
        Inc(j);
    end;
    if (FileCount<>Length(Result)) then begin
      SetLength(Result,FileCount);
    end;
  except
  end;
end;

class function TShell.DisplayContextMenu(const Handle: THandle; const FileName: string; Pos:
    TPoint): Boolean;
var
  ItemIdList: PItemIdList;
  Folder: IShellFolder;
begin
  Result := False;
  ItemIdList := PathToPidlBind(FileName, Folder);
  if ItemIdList <> nil then
  begin
    //Result := DisplayContextMenuPidl(Handle, Folder, ItemIdList, Pos);
    PidlFree(ItemIdList);
  end;
end;

class function TShell.GetFileListDataObject(const Directory: string; Files: TStrings):
    IDataObject;
type
  PArrayOfPItemIDList = ^TArrayOfPItemIDList;
  TArrayOfPItemIDList = array[0..0] of PItemIDList;
var

  Malloc: IMalloc;
  Root: IShellFolder;
  FolderPidl: PItemIDList;
  Folder: IShellFolder;
  p: TPidlArray;
  chEaten: ULONG;
  pchEaten:pointer;
  dwAttributes: ULONG;
  FileCount: Integer;
  i,j: Integer;
  temp:Integer;

begin

  Result := nil;
  chEaten:=0;
  pchEaten:=@chEaten;
  dwAttributes:=0;
  if Files.Count = 0 then
    Exit;
  SHGetMalloc(Malloc);
  SHGetDesktopFolder(Root);
  Root.ParseDisplayName(0, nil,
    PWideChar(WideString(Directory)),
    chEaten, FolderPidl, dwAttributes);
  try
    Root.BindToObject(FolderPidl, nil, IShellFolder,
      Pointer(Folder));
    FileCount := Files.Count;
    //p := AllocMem(SizeOf(PItemIDList) * FileCount);
    SetLength(p,FileCount);
    j:=0;
    try
      for i := FileCount-1 downto 0 do
      begin
        p[j]:=PathToPidlBind(Files[i],Folder);
        if (p[j]=nil) then
          Dec(FileCount)
        else
          Inc(j);
      end;
      if (FileCount<>Length(p)) then begin
        SetLength(p,FileCount);
      end;
      if (FileCount>0) then
      Folder.GetUIObjectOf(0, FileCount, p[0], IDataObject,
        nil,
        Pointer(Result));
    finally
      for i := 0 to FileCount - 1 do begin
        if p[i] <> nil then Malloc.Free(p[i]);
      end;
    end;
  finally
    Malloc.Free(FolderPidl);
  end;
end;

class procedure TShell.ResetMemory(out P; Size: Longint);
begin
  if Size > 0 then
  begin
    Byte(P) := 0;
    FillChar(P, Size, 0);
  end;
end;

class procedure TShell.UnloadModule(var Module: TModuleHandle);
begin
  if Module <> INVALID_MODULEHANDLE_VALUE then
    FreeLibrary(Module);
  Module := INVALID_MODULEHANDLE_VALUE;
end;



initialization
 OleInitialize(nil);
finalization
  OleUninitialize();
end.
