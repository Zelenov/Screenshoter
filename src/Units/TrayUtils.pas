unit TrayUtils;

interface
uses Windows,Classes,ShlObj,ShellApi,SysUtils,Vcl.Dialogs,Forms,Vcl.ExtCtrls,
ComObj,
Winapi.Messages,Winapi.ActiveX,types,CommCtrl,Winapi.MultiMon,Vcl.Graphics
{$IFDEF WIN32}
   ,Vcl.OleAuto
  {$ENDIF}
  ;

type
  TGetIconRectParam=record
    Icon:TTrayIcon;
    ExeName:string;
    ParentForm:TForm;
  end;
  TGetIconRectWinFunc = function (aParam: TGetIconRectParam; out aRect: TRect): Boolean;
  TTrayIconHelper = class helper for TCustomTrayIcon
  public
    {$IF DEFINED(CLR)}
    function GetNotifyIconData:TNotifyIconData;
    {$ELSE}
    function GetNotifyIconData:PNotifyIconData;
    {$IFEND}

  end;
  TShell_NotifyIconGetRect = function (var identifier: NOTIFYICONIDENTIFIER;
  var iconLocation: TRect): HResult; stdcall;

function GetIconRectWin7(aParam: TGetIconRectParam; out aRect: TRect): Boolean;

function FindTrayToolbar: HWND;

function GetIconsCount: Integer;
type TPlacement=(ABE_TOP,ABE_LEFT,ABE_RIGHT,ABE_BOTTOM,ABE_UNDEFINED);

function GetTaskbarPlacement(out rcTaskbar: TRect; out TaskbarHandle: HWND):
    TPlacement;

function GetMonitorByWindow(aWindow: HWND): TMonitor;

function GetMonitoWithTaskbar(TaskbarRect: TRect; TaskbarPlacement:
    TPlacement): TMonitor;

function GetIconRectHack(aParam: TGetIconRectParam; out aRect: TRect): Boolean;

function Is64BitWindows: boolean;


var
  GetIconRect:TGetIconRectWinFunc;




implementation

//function Shell_NotifyIconGetRect; external shell32 name 'Shell_NotifyIconGetRect' delayed;
function GetIconRectFalse(aParam: TGetIconRectParam; out aRect: TRect): Boolean;
begin
  Result:=false;
end;

function GetIconRectFirst(aParam: TGetIconRectParam; out aRect: TRect): Boolean;
var isWin64:boolean;
begin
  GetIconRect:=GetIconRectFalse;
  Result:=GetIconRectWin7(aParam,aRect);
  if Result=true then begin
    GetIconRect:=GetIconRectWin7;
    exit;
  end;
  isWin64:=Is64BitWindows();
  {$IFDEF WIN64}
    if (not isWin64) then
      exit;
  {$ELSE WIN32}
    if (isWin64) then
      exit;
  {$ENDIF}
  Result:=GetIconRectHack(aParam,aRect);
  if Result=true then begin
    GetIconRect:=GetIconRectWin7;
    exit;
  end;
end;



function Is64BitWindows: boolean;
type
  TIsWow64Process = function(hProcess: THandle; var Wow64Process: BOOL): BOOL;
    stdcall;
var
  DLLHandle: THandle;
  pIsWow64Process: TIsWow64Process;
  IsWow64: BOOL;
begin
  Result := False;
  DllHandle := LoadLibrary('kernel32.dll');
  if DLLHandle <> 0 then begin
    pIsWow64Process := GetProcAddress(DLLHandle, 'IsWow64Process');
    Result := Assigned(pIsWow64Process)
      and pIsWow64Process(GetCurrentProcess, IsWow64) and IsWow64;
    FreeLibrary(DLLHandle);
  end;
end;

function GetIconRectHack(aParam: TGetIconRectParam; out aRect: TRect): Boolean;
type
  TTemp = record
    hWndOfIconOwner :HWND;
    iIconId:integer;
  end;
  TTBBUTTON = record
    iBitmap: Integer;
    idCommand: Integer;
    fsState: Byte;
    fsStyle: Byte;
    {$IFDEF WIN32}
    bReserved: array[1..2] of Byte; // padding for alignment
    {$ELSE WIN64}
    bReserved: array[1..6] of Byte; // padding for alignment
    {$ENDIF}
    dwData: DWORD_PTR;


    iString: INT_PTR;
  end;

var
  isInt64:boolean;
  tdata: TTBBUTTON;

var
  dwTray: DWORD;
  wndTray: HWND;
  hTray: THandle;
  remoteTray: Pointer;

  tdataSize:integer;
  i: Integer;
  btsread:DWORD;

  btsreadUInt:NativeUInt absolute btsread;
  str:Pchar;

  hWndOfIconOwner:HWND;
  iIconId:integer;

  temp:TTemp;

  rcPosition :TRect;
  hWndTray:HWND;

begin
  Result := False;
  isInt64 := Is64BitWindows;
  tdataSize := sizeof(tdata) ;
  str:=nil;
  wndTray := FindTrayToolbar;
  GetWindowThreadProcessId(wndTray, @dwTray);
  hTray := OpenProcess(PROCESS_ALL_ACCESS, False, dwTray);
  if hTray <> 0 then
  begin
    remoteTray := VirtualAllocEx(hTray, nil, tdataSize, MEM_COMMIT,
      PAGE_READWRITE);
    try
      GetMem(str, 255);
      for i := 0 to GetIconsCount - 1 do
      begin
        hWndTray := FindTrayToolbar;
        SendMessage(hWndTray, TB_GETBUTTON, wparam(i), lparam(remoteTray));
        { ReadProcessMemory(NativeUInt(hTray),remotetray,@temp,
          NativeUInt(sizeof(temp)),NativeUInt(btsread)); }
        ReadProcessMemory(NativeUInt(hTray), remoteTray, @tdata,
          NativeUInt(tdataSize), btsreadUInt);
        if (tdata.dwData <> 0) then
        begin
          ReadProcessMemory(NativeUInt(hTray), Pointer(tdata.dwData), @temp,
            NativeUInt(sizeof(temp)), btsreadUInt);
        end;
        // ReadProcessMemory(naprocesshandle, tdata.dwData, out nihandlenew, Marshal.SizeOf(typeof(IntPtr)), out bytesread);
        if (tdata.iString <> 0) then
        begin
          ReadProcessMemory(NativeUInt(hTray), Ptr(tdata.iString), str, 255,
            btsreadUInt);
          if str = aParam.ExeName then
          begin
            SendMessage(hWndTray, TB_GETITEMRECT, wparam(i),
              lparam(remoteTray));
            ReadProcessMemory(NativeUInt(hTray), remoteTray, @rcPosition,
              sizeof(TRect), btsreadUInt);
            MapWindowPoints(hWndTray, 0, rcPosition, 2);
            aRect := rcPosition;
            Result := true;
            break;
          end;
          // ListBox1.Items.Add(str);
          { hWndOfIconOwner :=  temp.hWndOfIconOwner;
            iIconId         := temp.iIconId;
            if(hWndOfIconOwner <> Handle{|| iIconId <> a_iButtonID }{ )then
            continue; }
          beep;
        end;
        // remotetray
        // we found our icon - in WinXP it could be hidden - let's check it:
        // if( buttonData.fsState AND TBSTATE_HIDDEN ) then
        // break;
        // GetMem(str,255);
        // ReadProcessMemory(hTray,Ptr(tdata.iString),str,255,btsread);
        // ListBox1.Items.Add(str);
      end;
    finally
      if str<>nil then
        FreeMem(str);
      if (remoteTray<>nil) then
        VirtualFreeEx(hTray, remoteTray, tdataSize, MEM_RELEASE);
    end;
  end
  //else
  //  ShowMessage('Could not locate tray icons');
end;

function FindTrayToolbar: HWND;
begin
  Result := FindWindow('Shell_TrayWND', nil);
  Result := FindWindowEx(Result, 0, 'TrayNotifyWnd', nil);
  Result := FindWindowEx(Result, 0, 'SysPager', nil);
  Result := FindWindowEx(Result, 0, 'ToolbarWindow32', nil);
end;

function GetIconsCount: Integer;
begin
  Result := SendMessage(FindTrayToolbar, TB_BUTTONCOUNT, 0, 0);
end;

function GetTaskbarPlacement(out rcTaskbar: TRect; out TaskbarHandle: HWND):
    TPlacement;
  function NearlyEqual(A,B,Tolerance:integer):boolean;
  begin
    result:=Abs(A-B)<=Tolerance;
  end;
  const TASKBAR_X_TOLERANCE=100;
        TASKBAR_Y_TOLERANCE=100;
        MARGIN=10;

  var nScreenWidth,nScreenHeight  :integer;
      appBarData:_appBarData;
      edge:integer;
      h1,h2,h3:HWND;
  begin
    result:=ABE_UNDEFINED;
    nScreenWidth := GetSystemMetrics(SM_CXSCREEN);
    nScreenHeight := GetSystemMetrics(SM_CYSCREEN);
    appBarData.cbSize := sizeof(appBarData);
    appBarData.hWnd := 0;
    if (0 = SHAppBarMessage(ABM_GETTASKBARPOS, appBarData)) then begin
      beep;
    end else begin
      rcTaskbar:=appBarData.rc;
      edge:=appBarData.uEdge;
      TaskbarHandle:=appBarData.hWnd;
      case edge of
        0:Result:=ABE_LEFT;
        1:Result:=ABE_TOP;
        2:Result:=ABE_RIGHT;
        3:Result:=ABE_BOTTOM;
      end;
   
  end;
end;

function GetMonitoWithTaskbar(TaskbarRect: TRect; TaskbarPlacement:
    TPlacement): TMonitor;
var i:integer;
    r1,r2:trect;
    monitor:TMonitor;
    mRect:TRect;
begin
  Result := nil;
  for i:=Screen.MonitorCount-1 downto 0 do begin
    monitor:=Screen.Monitors[i];
    mRect:=monitor.BoundsRect;
    case TaskbarPlacement of
      ABE_LEFT:
        if (TaskbarRect.Left=mRect.Left)and((TaskbarRect.Top=mRect.Top)) then
            exit(monitor);
      ABE_TOP:
        if (TaskbarRect.Left=mRect.Left)and((TaskbarRect.Top=mRect.Top)) then
            exit(monitor);
      ABE_RIGHT:
        if (TaskbarRect.Right=mRect.Right)and((TaskbarRect.Top=mRect.Top)) then
            exit(monitor);
      ABE_BOTTOM:
        if (TaskbarRect.Bottom=mRect.Bottom)and((TaskbarRect.Left=mRect.Left)) then
            exit(monitor);
    end;
  end;

end;

function GetMonitorByWindow(aWindow: HWND): TMonitor;
var i:integer;
    monitor:HMONITOR;
    r1,r2:trect;
begin
  Result := nil;
  monitor:=MonitorFromWindow(aWindow,MONITOR_DEFAULTTONEAREST);

  for i:=Screen.MonitorCount-1 downto 0 do begin
    if (Screen.Monitors[i].Handle=monitor) then
      exit(Screen.Monitors[i]);
  end;

end;

function GetIconRectWin7(aParam: TGetIconRectParam; out aRect: TRect): Boolean;


var
    i:integer;
    id:NOTIFYICONIDENTIFIER ;

    res:HRESULT;
   {$IF DEFINED(CLR)}
      data: TNotifyIconData;
  {$ELSE}
      data: PNotifyIconData;
  {$IFEND}

  Shell_NotifyIconGetRect:TShell_NotifyIconGetRect;

  shellLib:THandle;

begin
  result:=false;
  id.cbSize:=SizeOf(id);
  data:=aParam.Icon.GetNotifyIconData;
  id.hWnd:=data.Wnd;
  id.uID:=data.uID;
  id.guidItem:=data.guidItem;

  shellLib:=LoadLibrary('shell32.dll');
  if shellLib<>0 then
    try
      @Shell_NotifyIconGetRect:=GetProcAddress(shellLib, 'Shell_NotifyIconGetRect');
      if @Shell_NotifyIconGetRect=nil then begin
        result:=false;
      end
      else begin
      res:=Shell_NotifyIconGetRect(id,aRect);
      result:=res=0;
      end;
    finally
      FreeLibrary(shellLib);
    end;
  //OleCheck(res);
  //beep;
end;

 (*
function inc2(var i: integer): integer;
begin
  result := i;
  inc(i);
end;

function FindOutPositionOfIconDirectly(const a_hWndOwner:  HWND;
const a_iButtonID:Integer; var a_rcIcon:TRect):Boolean;
type
  TBBUTTON = record
    iBitmap: Integer;
    idCommand: Integer;
    fsState: Byte;
    fsStyle: Byte;
   // {$IFDEF CPUX64}
    bReserved: array[1..6] of Byte; // padding for alignment
   // {$ELSE}
   // bReserved: array[1..2] of Byte; // padding for alignment
   // {$ENDIF}
    dwData: DWORD_PTR;
    iString: INT_PTR;
  end;

  var hWndTray: Integer;
  var reposition: TRect;
  var ilconld: Integer;
  var hWndOfIconOwner: HWND;
  var dwExtraData: array [0 .. 2] of DWORD;
  var buttonData: TBBUTTON;
  var dw3ytesRead: DWORD;
  var blconFound: BOOL;
  //var TBBUTTON: LPVOID; var sizeof: LPVOID; var NULL: LPVOID;
  var lpData: LPVOID;
  var T3_3UTTONCOUNT: integer;
   var i3uttonsCount: integer;
  var hTrayProc: THANDLE;
  var dwTrayProcessID: DWORD;
begin
hWndTray := GetTrayToolbarControl;
{ now we have to get an ID of the parent process for system tray }
dwTrayProcessID := -1;
GetWindowThreadProcessId(hWndTray, @dwTrayProcessID);
{ here we get a handle to tray application process }
hTrayProc := OpenProcess(PROCESS_ALL_ACCESS; 0, dwTrayProcessID);
{ now we check how many buttons is there - should be more than 0 }
i3uttonsCount := Sendl - lessage(hWndTray; 0, 0);
{ We want to get data from another process - it's not possible }
{ to just send messages like T3_GET3UTTON with a locally }
{ allocated buffer for return data. Pointer to locally allocated }
{ data has no usefull meaning in a context of another }
{ process (since Win95) - so we need }
{ to allocate some memory inside Tray process. }
{ We allocate sizeof(TBBUTTON) bytes of memory - }
{ because TBBUTTON is the biggest structure we will fetch. }
{ 3ut this buffer will be also used to get smaller }
{ pieces of	data like RECT	structures. }
lpData := VirtualAllocEx(hTrayProc; , MEM_COMMIT, PAGE_READWRITE);
blconFound := FALSE;
int i3utton := 0;
while (i3utton < i3uttonsCount) do
begin
  begin
    { first let’s read T3UTTON information }
    { about	each button in	a task bar of tray } dw3ytesRead := -1;
    Sendl - lessage(hWndTray, T3_GET3UTTON, i3utton, LPARAM(lpData));
    { we filled lpData with details of i3utton icon of toolbar }
    { - now let's copy this data from tray application }
    { back to our process }
    ReadProcessMemory(hTrayProc, lpData, @buttonData, sizeof(TBBUTTON),
      @dw3ytesRead);
    { let's read extra data of each button: }
    { there will be a HWND of the window that }
    { created an icon and icon ID } dwExtraData := (0, 0);
    ReadProcessMemory(hTrayProc, LPVOID(buttonData.dwData), dwExtraData,
      sizeof(dwExtraData), @dw3ytesRead);
    hWndOfIconOwner := HWND(dwExtraData)[0];
    ilconld := int(if ((hWndOfIconOwner <> a_hWndOwner) or
      (ilconld begin continue; end;
      { we found our icon - in WinXP it could be hidden -	let's check	it: }
      if (buttonData.fsState and T3STATE_HIDDEN) then begin break; end;
      { now just ask a tool bar of rectangle of our icon } reposition := (0,
      0); Sendl - lessage(hWndTray, T3_GETITE1 - 1 RECT, i3utton, LPARAM(lpData)
      ); ReadProcessMemory(hTrayProc, lpData, @reposition, sizeof(RECT),
      @dw3ytesRead); MapWindowPoints(hWndTray, NULL, (LPPOINT) and reposition,
      2); a_rcIcon := rcPosition; blconFound := TRUE; break; end; inc2(i3utton);
    end; VirtualFreeEx(hTrayProc, lpData, NULL, MEM_RELEASE);
      CloseHandle(hTrayProc); (begin result := blconFound; exit; end; end;

      *)
    { TTrayIconHelper }

{$IF DEFINED(CLR)}
function TTrayIconHelper.GetNotifyIconData:TNotifyIconData;
{$ELSE}
function TTrayIconHelper.GetNotifyIconData:PNotifyIconData;
{$IFEND}
begin
  result:=self.FData;
end;

initialization
  GetIconRect:=GetIconRectFirst;
end.
