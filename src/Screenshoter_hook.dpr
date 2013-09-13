library Screenshoter_hook;

uses
  Windows,
  VCL.Graphics,
  Messages,
  WinApi.ShlObj,
  SysUtils,
  Vcl.clipbrd,
  mmsystem,
  Vcl.Imaging.pngimage,

  CommonUtils in 'Units\CommonUtils.pas';

type
  PHWND= ^ HWND;
var
 Hooked: Boolean;
 hKeyHook : HHOOK;
 GlobalMap:TFileMap;
function Destroy: Boolean;
begin
  result:=true;
  if GlobalMap.Created then
    GlobalMap.Destroy;


   if (Hooked) then begin
    if hKeyHook<>0 then begin
      result:=UnhookWindowsHookEx(hKeyHook);
      hKeyHook:=0;
    end;
  end;
end;
procedure MakeScreen(Parent: HWND; const IsAltDown: Boolean);
begin

    PostMessage(Parent,APP_NEWSCREEN, Parent, LParam(Integer(IsAltDown)));
end;

procedure Work(IsAltDown: Boolean);
const
  MAX_ATTEMPTS = 10;         // Максимальное кол-во попыток
var
  AspectRatio: double;       // Отношение сторон скриншота
  Attempts: byte;            // Счётчик попыток
  Success: boolean;          // Флаг успеха



  Parent:HWND;

  Map:TFileMap;
begin
  try
    Map:=TFileMap.Create(COPYDATA_MAP);
    if Map.LastError=E_OK then
    begin
      Parent:=PHWND(Map.pView)^;
    end;
  finally
    Map.Destroy;
  end;

  MakeScreen(Parent,IsAltDown);
end;

function KeyHookFunc(Code: Integer; VirtualKey: Word; KeyStroke: LongInt):
    LRESULT; stdcall;
var
 KeyState1: TKeyBoardState;
 AryChar: array[0..1] of Char;
 Count: Integer;
 isAltDown:boolean;
begin
  //MessageBox(0,PChar(Format('%d',[hParent])),PChar('!'),0);
 Result:=CallNextHookEx(hKeyHook, Code, VirtualKey, KeyStroke);
 if (Code=HC_NOREMOVE)or(Code<0)  then
  Exit;
 if (Code=HC_ACTION) and (VirtualKey = VK_SNAPSHOT) then
 begin
    //MessageBox(0,PChar('!'),PChar('2'),0);
    //MessageBox(0,PChar(Format('%d',[hParent])),PChar('2'),0);
    isAltDown:=(GetKeyState(VK_MENU) AND $8000) <>0;
    //isAltDown:=(KeyStroke shr 29) and 1 = 1;
    Work(isAltDown);
  end
end;

function StartHook(AppHandle: HWND): Integer;stdcall; export;
begin
  //MessageBox(0,PChar('1'),PChar('!'),0);
  try
  Result:=E_OK;
  if Hooked then
  begin
   Result:=E_ALREADY_HOOKED;
   Exit;
  end;
    GlobalMap:=TFileMap.Create(COPYDATA_MAP,sizeof(Integer));
    result:=GlobalMap.LastError;
    if Result<>E_OK then
      exit;
    try
      PHWND(GlobalMap.pView)^:=AppHandle;
    finally
      GlobalMap.StopIO;
    end;

    try
      //MessageBox(0,PChar(Format('%d',[hParent])),PChar('!'),0);
      hKeyHook:=SetWindowsHookEx(WH_KEYBOARD, @KeyHookFunc, hInstance, 0);
      if hKeyHook<=0 then begin
        Result:=E_HOOK_FAILED;
      end else
      begin
        Hooked:=true;
      end
    except
      Result:=E_UNKNOWN_ERROR;
    end;
  finally
    if Result<>E_OK then begin
      Destroy;

    end;
  end;
end;

function StopHook: Boolean;stdcall; export;
begin
  if Hooked then
    Result:=Destroy()
  else
    Result:=true;
    Hooked:=false;
end;

procedure EntryProc(dwReason: DWORD);
begin
 if (dwReason=Dll_Process_Detach)
 then
  begin
    Destroy;
  end;
end;


exports StartHook,StopHook;

begin
    //PHookRec1 := nil;
    FillChar(GlobalMap,sizeof(GlobalMap),0);
    Hooked := false;
    hKeyHook := 0;
    DLLProc := @EntryProc;
    EntryProc(Dll_Process_Attach);

end.
