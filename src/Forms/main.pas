unit main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, jpeg, StdCtrls, clipbrd, ActiveX, ShlObj, ShellApi,
  System.Generics.Collections, System.SyncObjs,Math,CommCtrl, mmsystem,About,
  Vcl.ImgList, Vcl.ComCtrls, Vcl.Grids,ImageUtils,{JclShell, }ShellUtils,
  TrayUtils,
  {$IFDEF WIN32}
   Vcl.OleAuto,
  {$ENDIF}
  Vcl.AppEvnts, Vcl.Menus, CommonUtils, Vcl.MPlayer,
  Vcl.Imaging.GIFImg, ScreenshotUtils
  ;

type

  TiScreenshoterForm = class(TForm,IDropSource)
    iTrayIcon: TTrayIcon;
    iDummyImageList: TImageList;
    iBottomPanel: TPanel;
    iApplicationEvents: TApplicationEvents;
    PopupMenu1: TPopupMenu;
    NQuit: TMenuItem;
    iGridPanel: TPanel;
    ListView1: TListView;
    Panel3: TPanel;
    iTopShape: TShape;
    iLastScreens: TStaticText;
    iGradient: TPaintBox;
    iWaitingForScreenPanel: TPanel;
    iPrintScreenPanel: TPanel;
    iGifAnim: TImage;
    iPressPrintscreen: TLabel;
    NAutorunItem: TMenuItem;
    NLanguageItem: TMenuItem;
    N4: TMenuItem;
    N5: TMenuItem;
    NSoundItem: TMenuItem;
    NAboutItem: TMenuItem;
    NSeperator: TMenuItem;
    iOpenFolder: TLabel;
    procedure iApplicationEventsDeactivate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure ListView1CustomDrawItem(Sender: TCustomListView; Item: TListItem;
      State: TCustomDrawState; var DefaultDraw: Boolean);
    procedure DrawGrid1DrawCell(Sender: TObject; ACol, ARow: Integer;
      Rect: TRect; State: TGridDrawState);
    procedure Button1Click(Sender: TObject);
    procedure FlyoutForm(aPoint: TPoint; Placement: TPlacement; TaskbarMonitor:
        TMonitor);
    procedure FormDeactivate(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormShow(Sender: TObject);
    function GetSelectedItems: TArrayOfThumbnail;
    procedure iOpenFolderClick(Sender: TObject);
    procedure iOpenFolderMouseEnter(Sender: TObject);
    procedure iOpenFolderMouseLeave(Sender: TObject);
    procedure iWaitingForScreenPanelResize(Sender: TObject);
    procedure iTrayIconClick(Sender: TObject);
    procedure ListView1DblClick(Sender: TObject);
    procedure ListView1KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ListView1MouseDown(Sender: TObject; Button: TMouseButton; Shift:
        TShiftState; X, Y: Integer);
    procedure ListView1MouseMove(Sender: TObject; Shift: TShiftState; X, Y:
        Integer);
    procedure NQuitClick(Sender: TObject);
    procedure NAboutItemClick(Sender: TObject);
    procedure NAutorunItemClick(Sender: TObject);
    procedure NSoundItemClick(Sender: TObject);
    procedure iGradientPaint(Sender: TObject);
    procedure iBottomPanelResize(Sender: TObject);
    procedure ShowDllError(Result: Byte);
    procedure TrayClick;
  private
    FAboutForm:TiAboutForm;
    GlowBitmap:TBitmap;
    GlowCanvas:TCanvas;
    Screenshoter:TScreenshoter;
    FDragStartPos: TPoint;
    fOldItem: TListItem;

    procedure AboutFormClose(Sender: TObject; var Action: TCloseAction);
    procedure DrawGlow(Canvas:TCanvas;aRect:TRect;StartIndex:Integer);
    procedure DrawBitmapStretched(Canvas:TCanvas;SrcRect,DestRect:TRect);
    procedure DrawBitmap(Canvas:TCanvas;SrcRect:TRect;X,Y:Integer);
    procedure ClickSoundMessage(var Msg: TMessage); message WM_PLAY_CLICKSOUND;
    procedure GetLanguages;
    procedure WMNewScreen(var Msg: TNewScreenMessage); message APP_NEWSCREEN;
    procedure WMNCHitTest(var Msg: TWMNcHitTest); message WM_NCHitTest;
    function GiveFeedback(dwEffect: Longint): HResult; stdcall;
    procedure LanguageItemClick(Sender: TObject);
    function QueryContinueDrag(fEscapePressed: BOOL; grfKeyState: Longint):
        HResult; stdcall;
    procedure Translate;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure OnLanguageChanged;
    procedure OnCollectionUpdated(sender:TObject);
    procedure ShowAboutForm;
  public
    procedure OnError(Error: Byte);
    procedure ChangeState(State: TAppState);
  end;

var
  iScreenshoterForm: TiScreenshoterForm;


IsAlreadyRunning:Boolean;
implementation
uses AutoRun, OptUtils;
var mHandle:THandle;
{$R *.dfm}


procedure TiScreenshoterForm.iApplicationEventsDeactivate(Sender: TObject);
begin

  if GetForegroundWindow() <> Handle then Hide;
end;

function TiScreenshoterForm.QueryContinueDrag(fEscapePressed: BOOL; grfKeyState: Longint):
    HResult;
begin
  if fEscapePressed or (grfKeyState and MK_RBUTTON = MK_RBUTTON) then
  begin
    Result := DRAGDROP_S_CANCEL
  end else if grfKeyState and MK_LBUTTON = 0 then
  begin
    Result := DRAGDROP_S_DROP
  end else
  begin
    Result := S_OK;
  end;
end;

function TiScreenshoterForm.GiveFeedback(dwEffect: Longint): HResult;
begin
  Result := DRAGDROP_S_USEDEFAULTCURSORS;
end;

procedure TiScreenshoterForm.FormDestroy(Sender: TObject);
begin
  if assigned(Screenshoter) then
    FreeAndNil(Screenshoter);
  if assigned(GlowBitmap) then
    FreeAndNil(GlowBitmap);

end;

{ TForm1 }


procedure TiScreenshoterForm.Button1Click(Sender: TObject);
begin
 // ThumbnailCollection.Add('c:\Windows\Web\Wallpaper\Landscapes\img8.jpg');
//  SendMessage(ListView1.Handle,LB_SETITEMHEIGHT,0,50)
end;

procedure TiScreenshoterForm.ChangeState(State: TAppState);
var
  isGrid:boolean;
begin
  isGrid:=State = asGrid;
  iWaitingForScreenPanel.Visible:=not isGrid;
  iGridPanel.Visible:=isGrid;
  iGridPanel.Align:=alClient;
  iWaitingForScreenPanel.Align:=alClient;
  (iGifAnim.Picture.Graphic as TGIFImage).Animate := not isGrid;

end;

procedure TiScreenshoterForm.CreateParams(var Params: TCreateParams);
begin
  inherited;
  Params.Style := WS_POPUP or WS_THICKFRAME;
  Params.ExStyle := Params.ExStyle or WS_EX_TOPMOST
   or WS_EX_TOOLWINDOW and not WS_EX_APPWINDOW;
end;

procedure TiScreenshoterForm.ClickSoundMessage(var Msg: TMessage);
begin
  Screenshoter.ClickSoundMessage(Msg);
end;

procedure TiScreenshoterForm.DrawBitmap(Canvas: TCanvas; SrcRect: TRect; X, Y: Integer);
begin
  if not Assigned(GlowBitmap) then
    exit;
  Canvas.CopyRect(Rect(X,Y,X+(SrcRect.Right-SrcRect.Left),
    y+(SrcRect.Bottom-SrcRect.Top)),GlowCanvas,SrcRect);
end;

procedure TiScreenshoterForm.DrawBitmapStretched(Canvas: TCanvas; SrcRect, DestRect: TRect);
begin
  if not Assigned(GlowBitmap) then
    exit;
  Canvas.CopyRect(DestRect,GlowCanvas,SrcRect);
end;

procedure TiScreenshoterForm.DrawGlow(Canvas: TCanvas; aRect: TRect; StartIndex: Integer);
var H,W:integer;
  function GetRectByIndex(const Index:Integer):TRect;
  begin
    Result.Left:=(StartIndex+Index)*W;
    Result.Right:=Result.Left+W;
    if (Result.Right>GlowBitmap.Width) then begin
      Result:=Rect(0,0,0,0);
    end else begin
      Result.Top:=0;
      Result.Bottom:=H;
    end;

  end;

begin
  if not Assigned(GlowBitmap) then
    exit;
  H:=GlowBitmap.Height;
  W:=H;
  with aRect do begin
    DrawBitmapStretched(Canvas,GetRectByIndex(0),Rect(Left-W,Top-H,Left,Top));
    DrawBitmapStretched(Canvas,GetRectByIndex(1),Rect(Left,Top-H,Right,Top));
    DrawBitmapStretched(Canvas,GetRectByIndex(2),Rect(Right,Top-H,Right+W,Top));
    DrawBitmapStretched(Canvas,GetRectByIndex(3),Rect(Left-W,Top,Left,Bottom));
    DrawBitmapStretched(Canvas,GetRectByIndex(4),Rect(Right,Top,Right+W,Bottom));
    DrawBitmapStretched(Canvas,GetRectByIndex(5),Rect(Left-W,Bottom,Left,Bottom+H));
    DrawBitmapStretched(Canvas,GetRectByIndex(6),Rect(Left,Bottom,Right,Bottom+H));
    DrawBitmapStretched(Canvas,GetRectByIndex(7),Rect(Right,Bottom,Right+W,Bottom+H));
  end
end;

procedure TiScreenshoterForm.DrawGrid1DrawCell(Sender: TObject; ACol, ARow: Integer;
  Rect: TRect; State: TGridDrawState);
var Index:integer;
this:TDrawGrid absolute Sender;
aRect:TRect;
Canvas:tCanvas;
StartIndex:integer;
begin


  StartIndex:=-1;
  if  (gdSelected in State) then
    StartIndex:=1
  else
  if (gdHotTrack in State) then
    StartIndex:=0
  else
    StartIndex:=-1;
  canvas:=this.Canvas;
  aRect:= Rect;
  //if StartIndex=1 then begin
  //  Canvas.DrawFocusRect(Rect);
  //end;
  Index:=ARow*this.ColCount+ACol;
  if (Index>=ListView1.Items.Count) then
    Exit;
 { case State of
    cdsSelected:StartIndex:=1;
    cdsHot:StartIndex:=0;
    cdsMarked, cdsIndeterminate,
    cdsShowKeyboardCues, cdsNearHot, cdsOtherSideHot, cdsDropHilited,
    cdsGrayed, cdsDisabled, cdsChecked,
    cdsFocused, cdsDefault:StartIndex:=-1;
  end;     }

  with aRect do begin
    aRect:=Classes.Rect(Left+6,Top+6,Right-6,Bottom-6);
  end;

  ListView1.LargeImages.Draw(Canvas,aRect.Left,aRect.Top,ListView1.Items[Index].Index,True);
  if (StartIndex>=0) then
    DrawGlow(Canvas,aRect,StartIndex*8);
  this.Canvas.Font.Color:=clBlue;
  //Canvas.Brush.Style:=bsSolid;
end;

procedure TiScreenshoterForm.FormCreate(Sender: TObject);
begin

  Application.MainFormOnTaskbar := True;
  FAboutForm:=nil;
  GlowBitmap:=TBitmap.Create;
  try
    GlowBitmap.LoadFromResourceName(HInstance,'GLOW');
    GlowCanvas:=GlowBitmap.Canvas;
  except
    FreeAndNil(GlowBitmap);
  end;
  Screenshoter:=TScreenshoter.Create;
  Screenshoter.OnCollectionUpdated:=OnCollectionUpdated;
  Screenshoter.OnStateChanged:=ChangeState;
  Screenshoter.OnLanguageChanged:=OnLanguageChanged;
  Screenshoter.OnError:=OnError;
  Screenshoter.Init(Handle,iDummyImageList.Width+43-12,iDummyImageList.Height+18-12,GetSelectedItems);
  NAutorunItem.Checked:=Screenshoter.AutoRun;
  NSoundItem.Checked:=Screenshoter.PlaySound;

end;

procedure TiScreenshoterForm.FormPaint(Sender: TObject);
begin
  ShowWindow(Application.Handle, SW_HIDE);                             // отключить отображение в панели задач
end;

procedure TiScreenshoterForm.FlyoutForm(aPoint: TPoint; Placement: TPlacement;
    TaskbarMonitor: TMonitor);
var screenRect:TRect;
    formRect:TRect;
    dx,dy,w,h:integer;
    offsetPoint:TPoint;
const margin=9;
begin
  if (TaskbarMonitor=nil) then
    screenRect:=Rect(0,0,Screen.Width,Screen.Height)
  else
    screenRect:=TaskbarMonitor.BoundsRect;


  w:=Width;
  h:=Height;
  formRect:=Rect(0,0,W,H);
  //Screen.Monitors[I].
  case placement of
    ABE_LEFT:offsetPoint:=Point(aPoint.X+margin,aPoint.Y-H div 2);
    ABE_TOP:offsetPoint:=Point(aPoint.X-W div 2,aPoint.Y+margin);
    ABE_RIGHT:offsetPoint:=Point(aPoint.X-w-margin,aPoint.Y-H div 2);
    ABE_BOTTOM: offsetPoint:=Point(aPoint.X-W div 2,aPoint.Y-H-margin);
  end;
  OffsetRect(formRect,offsetPoint.X,offsetPoint.Y);

  dx:=0;
  dy:=0;
  if formRect.Left<screenRect.Left then
    dx:=formRect.Left-screenRect.Left-margin
  else if formRect.Right>screenRect.Right then
    dx:=formRect.Right-screenRect.Right+margin;

    if formRect.Top<screenRect.Top then
    dy:=formRect.Top-screenRect.Top-margin
  else if formRect.Bottom>screenRect.Bottom then
    dy:=formRect.Bottom-screenRect.Bottom+margin;

  OffsetRect(formRect,-dx,-dy);
  BoundsRect:=formRect;
  Show;
end;

procedure TiScreenshoterForm.FormDeactivate(Sender: TObject);
begin
  Hide;
end;

procedure TiScreenshoterForm.FormShow(Sender: TObject);
var item:TListItem;
    i:integer;
begin
SetForegroundWindow(Application.MainForm.Handle);
if ListView1.Items.Count>0 then
  ListView1.Items[0].DisplayRect(drSelectBounds);
iBottomPanelResize(iBottomPanel);
end;

procedure TiScreenshoterForm.GetLanguages;
var i:integer;
    found:boolean;
    LangName:string;

    MenuItem:TMenuItem;

begin
  NLanguageItem.Clear;// .Items.Clear;
  for i:=0 to Screenshoter.LanguagesCount-1 do
  begin
    found:=TryGetString(1,LangName,i);
    if found then begin
      MenuItem:=TMenuItem.Create(Self);
      MenuItem.Caption:=LangName;
      MenuItem.OnClick:=LanguageItemClick;
      MenuItem.RadioItem:=true;
      MenuItem.Tag:=i;
      NLanguageItem.Add(MenuItem);
    end;
  end;


end;

function TiScreenshoterForm.GetSelectedItems: TArrayOfThumbnail;
var len,i,j,count:integer;
    res:TArrayOfThumbnail;
begin

  count:=ListView1.Items.Count-1;
  len:=0;
  for i:=0 to count do
    if (ListView1.Items[i].Selected) then
      inc(len);
  SetLength(res,len);
  j:=0;
  Screenshoter.ThumbnailCollection.Traverse(
  procedure (Index:integer; Thumbnail:TThumbnail; var doDelete:boolean)
  begin
    if (ListView1.Items[Index].Selected) then begin
      res[j]:=Thumbnail;
      inc(j);
    end;
  end);
  Result:=res;
  // TODO -cMM: TForm1.GetSelectedItems default body inserted
end;

procedure TiScreenshoterForm.iOpenFolderClick(Sender: TObject);
begin
  Screenshoter.OpenDesktop;
end;

procedure TiScreenshoterForm.iOpenFolderMouseEnter(Sender: TObject);
var this:TLabel absolute Sender;
begin
  this.Font.Style:=this.Font.Style+[fsUnderline];
end;

procedure TiScreenshoterForm.iOpenFolderMouseLeave(Sender: TObject);
var this:TLabel absolute Sender;
begin
  this.Font.Style:=this.Font.Style-[fsUnderline];
end;

procedure TiScreenshoterForm.iWaitingForScreenPanelResize(Sender: TObject);
begin
 VerticalCenter(iPrintScreenPanel);
end;

procedure TiScreenshoterForm.iTrayIconClick(Sender: TObject);
begin
  TrayClick;
end;

procedure TiScreenshoterForm.ListView1CustomDrawItem(Sender: TCustomListView;
  Item: TListItem; State: TCustomDrawState; var DefaultDraw: Boolean);

var
aRect:TRect;
Canvas:tCanvas;
StartIndex:integer;
x,y:integer;
Thumbnail:TThumbnail;
begin
//exit;
  try
    DefaultDraw:=False;
    Thumbnail:=Screenshoter.ThumbnailCollection[Item.Index];
    if Assigned(Thumbnail) then begin

      aRect:= Item.DisplayRect(drSelectBounds);

      x:=aRect.Left+(aRect.Width-Thumbnail.Bitmap.Width)div 2;
      y:=aRect.Top+(aRect.Height-Thumbnail.Bitmap.Height)div 2;
      aRect:=Rect(0,0,Thumbnail.Bitmap.Width,Thumbnail.Bitmap.Height);
      OffsetRect(aRect,x,y);
      with aRect do begin
       // aRect:=Rect(Left+6,Top+6,Right-6,Bottom-6);
      end;
      StartIndex:=-1;
      if  (cdsSelected in State) then
        StartIndex:=1
      else
      if (cdsHot in State) then
        StartIndex:=0
      else
        StartIndex:=-1;
     { case State of
        cdsSelected:StartIndex:=1;
        cdsHot:StartIndex:=0;
        cdsMarked, cdsIndeterminate,
        cdsShowKeyboardCues, cdsNearHot, cdsOtherSideHot, cdsDropHilited,
        cdsGrayed, cdsDisabled, cdsChecked,
        cdsFocused, cdsDefault:StartIndex:=-1;
      end;     }
      canvas:=Sender.Canvas;

      Thumbnail.Draw(Canvas,aRect);
      //ListView1.LargeImages.Draw(Canvas,aRect.Left,aRect.Top,Item.ImageIndex,True);
      if (StartIndex>=0) then
        DrawGlow(Canvas,aRect,StartIndex*8);

      {aRect:= Item.DisplayRect(drSelectBounds);
      with aRect do begin
        aRect:=Rect(Left+6,Top+6,Right-6,Bottom-6);
      end;
      DrawGlow(Canvas,aRect,0);   }
    end;
  except
    on e:Exception do begin

    end;
  end;
end;

procedure TiScreenshoterForm.ListView1DblClick(Sender: TObject);
begin
  Screenshoter.Execute;
end;

procedure TiScreenshoterForm.ListView1KeyDown(Sender: TObject; var Key: Word; Shift:
    TShiftState);
begin
  if Key = VK_RETURN then
    Screenshoter.Execute;
end;

procedure TiScreenshoterForm.ListView1MouseDown(Sender: TObject; Button: TMouseButton;
    Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
  begin
    FDragStartPos.x := X;
    FDragStartPos.y := Y;
  end else
    if Button=mbRight then
      Screenshoter.ShowContextMenu(Point(x,y));
end;

procedure TiScreenshoterForm.ListView1MouseMove(Sender: TObject; Shift: TShiftState; X, Y:
    Integer);
const
  Threshold = 5;
var
  SelFileList: TStrings;
  i: Integer;
  DataObject: IDataObject;
  Effect: Integer;
  aSelected:TArrayOfThumbnail;
  dir:string;
  res:HRESULT;
  currentItem:TListItem;
  this:TListView absolute sender;
begin
  with this do
  begin

    currentItem:=this.GetItemAt(x,y);


     // this should do the trick..
     if fOldItem <> currentItem then
       Application.CancelHint;
     fOldItem := currentItem;

     if (currentItem <>nil) and (currentItem.Index <= Items.Count) then
       Hint := Screenshoter.ThumbnailCollection[currentItem.Index].Hint
     else
       Hint := '';
    if (SelCount > 0) and (csLButtonDown in ControlState)
      and ((Abs(X - FDragStartPos.x) >= Threshold)
      or (Abs(Y - FDragStartPos.y) >= Threshold)) then
      begin
      aSelected:=GetSelectedItems;

      Perform(WM_LBUTTONUP, 0, MakeLong(X, Y));
      SelFileList := TStringList.Create;
      try
        SelFileList.Capacity := SelCount;
        for i := 0 to Length(aSelected) - 1 do
          if Assigned(aSelected[i]) then
          SelFileList.Add(aSelected[i].FileName);
          //SelFileList.Add('d:\Dropbox\Megasplash\Dropbox\Delphi\snaptool\glow.bmp');
          //d:\Dropbox\Megasplash\Dropbox\Delphi\snaptool\glow.bmp
        dir:=ExtractFileDir(aSelected[0].FileName);
        //dir:='d:\Dropbox\Megasplash\Dropbox\Delphi\snaptool';
        if  SelFileList.Count>0 then

          DataObject := TShell.GetFileListDataObject(
          dir , SelFileList);
      finally
        SelFileList.Free;
      end;
      Effect := DROPEFFECT_NONE;
      if  Length(aSelected)>0 then begin
        res:=DoDragDrop(DataObject, Self, DROPEFFECT_COPY, Effect);
      end;
    end;
  end;
end;

procedure TiScreenshoterForm.LanguageItemClick(Sender: TObject);
var this:TMenuItem absolute Sender;
begin
  Screenshoter.Language:=this.Tag;
end;
procedure TiScreenshoterForm.NQuitClick(Sender: TObject);
begin
  Close;
end;

procedure TiScreenshoterForm.NAboutItemClick(Sender: TObject);
begin
  ShowAboutForm;
end;

procedure TiScreenshoterForm.NAutorunItemClick(Sender: TObject);
var this:TmenuItem absolute Sender;
begin
  Screenshoter.Autorun:=this.Checked;
  this.Checked:=Screenshoter.Autorun;
end;

procedure TiScreenshoterForm.NSoundItemClick(Sender: TObject);
var this:TmenuItem absolute Sender;
    opt:boolean;
begin
  Screenshoter.PlaySound:=this.Checked;
  this.Checked:=Screenshoter.PlaySound;
end;

procedure TiScreenshoterForm.OnLanguageChanged;
begin
  GetLanguages;
  if (NLanguageItem.Count>0)and(Screenshoter.Language<NLanguageItem.Count) then begin
    NLanguageItem[Language].Checked:=true;
    Translate;
    if Assigned(FAboutForm) then
      FAboutForm.Translate;
  end;
end;

procedure TiScreenshoterForm.OnCollectionUpdated(sender:TObject);
var ListItem:TListItem;
    this:TThumbnailCollection absolute Sender;
    cnt:integer;
begin
  cnt:=this.Count;
  while (cnt>ListView1.Items.Count) do begin
    ListItem:=ListView1.Items.Add;
    //ListItem.Index:=ListView1.Items.Count-1;
  end;
  while (cnt<ListView1.Items.Count) do begin
    ListView1.Items.Delete(ListView1.Items.Count-1);
  end;
  ListView1.Refresh;
end;

procedure TiScreenshoterForm.OnError(Error: Byte);
begin
  ShowDllError(Error);
end;

procedure TiScreenshoterForm.iGradientPaint(Sender: TObject);
var r:TRect;
    paintBox:TPaintBox absolute sender;
    i,j:integer;
    updateRect:TRect;
    fillRect:TRect;
    paintCanvas:tCanvas;
const
   colors:array [0..4] of integer = ($ebdbcf,$f0e2d9,$f3eae2,$f8f2ec,$fbf5f1);
begin
//Exit;
  updateRect:=Rect(0,0,iGradient.Width,iGradient.Height);
  paintCanvas:=paintBox.Canvas;
  fillRect:=updateRect;
  for j := updateRect.Top to updateRect.Bottom-1 do begin

    if j<Length(colors)-2 then begin
      fillRect.Top:=j;
      fillRect.Bottom:=j+1;
      paintCanvas.Brush.Color:=colors[j];
      paintCanvas.FillRect(fillRect);
    end else begin
      fillRect.Top:=j;
      fillRect.Bottom:=updateRect.Bottom;
      paintCanvas.Brush.Color:=colors[length(colors)-1];
      paintCanvas.FillRect(fillRect);
    end;
  end;
end;

procedure TiScreenshoterForm.iBottomPanelResize(Sender: TObject);
begin
  Center(iOpenFolder);
end;

procedure TiScreenshoterForm.ShowAboutForm;
begin
  if not Assigned(FAboutForm) then begin
    FAboutForm:=TiAboutForm.Create(self);
    FAboutForm.OnClose:=AboutFormClose;
    FAboutForm.Translate;
  end;
  FAboutForm.Show;
end;
procedure TiScreenshoterForm.AboutFormClose(Sender: TObject; var Action:
    TCloseAction);
begin
  Action:=caFree;
  FAboutForm:=nil;
end;

procedure TiScreenshoterForm.FormResize(Sender: TObject);
begin
  //iLastScreens.Caption:=Format('%d x %d',[Width, Height]);
end;

procedure TiScreenshoterForm.ShowDllError(Result: Byte);
var s:string;
    isError:boolean;
begin
  isError:=true;
  s:='';
  {$IFDEF DEBUG}
  case Result of
    E_OK: isError:=false;
    E_ALREADY_HOOKED: s:=GetString(S_ALREADY_HOOKED);
    E_MAPCREATE_FAILED: s:=GetString(S_MAPCREATE_FAILED);
    E_MAP_EXISTS: s:=GetString(S_MAP_EXISTS);
    E_MAPVIEW_FAILED: s:=GetString(S_MAPVIEW_FAILED);
    E_VIEW_ACCES_VIOLATION: s:=GetString(S_VIEW_ACCES_VIOLATION);
    E_DESKTOPPATH_NOT_FOUND: s:=GetString(S_DESKTOPPATH_NOT_FOUND);
    E_HOOK_FAILED: s:=GetString(S_HOOK_FAILED);
    E_UNKNOWN_ERROR: s:=GetString(S_UNKNOWN_ERROR);
    E_BAD_FILE_NAME: s:=GetString(S_BAD_FILE_NAME);
  end;
  {$ELSE}

  {$ENDIF}
  if isError then begin
    Application.MessageBox(PChar(s),'Screenshoter error', MB_ICONERROR OR MB_OK)
  end;
end;

procedure TiScreenshoterForm.Translate;
begin

  iScreenshoterForm.Caption:=GetString(S_MAINWIN_CAPTION);
  iLastScreens.Caption:=GetString(S_LAST_SCREENS);
  iPressPrintscreen.Caption:=GetString(S_PRESS_PRINTSCREEN);
  iOpenFolder.Caption:=GetString(S_OPEN_DESKTOP);

  NQuit.Caption:=GetString(S_QUIT);
  NAutorunItem.Caption:=GetString(S_AUTORUN);
  NLanguageItem.Caption:=GetString(S_MENU_LANGUAGE);
  NSoundItem.Caption:=GetString(S_SOUND);
  NAboutItem.Caption:=GetString(S_ABOUT);
  Self.Resize;
end;

procedure TiScreenshoterForm.TrayClick;
  var placement:TPlacement;
    iconRect,trayRect:TRect;
    iconFound,trayFound:boolean;
    trayPoint,iconPoint,pinPoint:TPoint;
    TaskbarHandle:HWND;
    TaskbarMonitor:TMonitor;
    GetIconRectParam:TGetIconRectParam;
begin

    placement:=GetTaskbarPlacement({out}trayRect, {out} TaskbarHandle);

    trayFound:=placement <> ABE_UNDEFINED;
    trayPoint:=Point(0,0);
    iconPoint:=Point(0,0);
    if not trayfound then begin
      TaskbarMonitor:=nil;
      placement:=ABE_BOTTOM;
      trayRect:=Rect(0,0,Screen.Width,Screen.Height);
    end else begin
      TaskbarMonitor:=GetMonitoWithTaskbar(trayRect,placement);
    end;
    GetIconRectParam.Icon:=iTrayIcon;
    GetIconRectParam.ExeName:='screenshoter';
    GetIconRectParam.ParentForm:=self;

    iconFound:=TrayUtils.GetIconRect(GetIconRectParam,iconRect);
    //iconFound:=TrayUtils.GetIconRect('snaptool',iconRect);
    if iconFound then begin
      with iconRect do begin
        iconPoint:=Point((Right+Left)div 2, (Bottom+Top)div 2);
      end;
    end else begin
      case placement of
        ABE_LEFT:iconPoint:=Point(trayRect.Right,trayRect.Bottom);
        ABE_TOP:iconPoint:=Point(trayRect.Right,trayRect.Bottom);
        ABE_RIGHT:iconPoint:=Point(trayRect.Left,trayRect.Bottom);
        ABE_BOTTOM:iconPoint:=Point(trayRect.Right,trayRect.Top);
      end;
    end;

    case placement of
      ABE_LEFT:pinPoint:=Point(trayRect.Right,iconPoint.y);
      ABE_TOP:pinPoint:=Point(iconPoint.X,trayRect.Bottom);
      ABE_RIGHT:pinPoint:=Point(trayRect.Left,iconPoint.Y);
      ABE_BOTTOM:pinPoint:=Point(iconPoint.X,trayRect.Top);
    end;

    FlyoutForm(pinPoint,placement,TaskbarMonitor);
   

end;

procedure TiScreenshoterForm.WMNewScreen(var Msg: TNewScreenMessage);
begin
  Screenshoter.WMNewScreen(Msg);
end;

procedure TiScreenshoterForm.WMNCHitTest(var Msg: TWMNcHitTest);
begin
  Inherited;
  case Msg.Result of
    HTLEFT,HTTOP,HTRIGHT,HTBOTTOM,HTBOTTOMLEFT,HTBOTTOMRIGHT,
      HTTOPLEFT,HTTOPRIGHT:Msg.Result:=HTCLIENT;
  end;

end;

initialization
  OleInitialize(nil);
  mHandle := CreateMutex(nil,True,'Screenshoter');
  IsAlreadyRunning:= GetLastError = ERROR_ALREADY_EXISTS;
finalization
  OleUninitialize;
  if  mHandle <> 0 then
    CloseHandle(mHandle);
end.


