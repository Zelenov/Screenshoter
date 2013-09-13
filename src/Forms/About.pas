unit About;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.StdCtrls,Winapi.ShellAPI,
  Vcl.Imaging.GIFImg, CommonUtils;

type
  TiAboutForm = class(TForm)
    Panel1: TPanel;
    ilabelScreenshooter: TLabel;
    iLogo: TImage;
    ilabelVersion: TLabel;
    ilabelAbout: TLabel;
    Panel2: TPanel;
    ilabelMe: TLinkLabel;
    ilabelGithub: TLinkLabel;
    Image2: TImage;
    procedure FormDestroy(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure ilabelMeLinkClick(Sender: TObject; const Link: string;
      LinkType: TSysLinkType);
  private
      Font1,Font2: THandle;
    function LoadFont(const FontResIndex: integer): THandle;
  public
    function GetExeVersion: string;
    procedure Translate;
    { Public declarations }
  end;
procedure VerticalCenter(Control: TControl);

procedure Center(Control: TControl);

procedure HorizontalCenter(Control: TControl);

var
  iAboutForm: TiAboutForm;


implementation

{$R *.dfm}
procedure CenterControl(Control: TControl; const isVertical:boolean; const isHorisontal:boolean);
var parent:TWinControl;
    childRect,parentRect,newRect:TRect;
    dx,dy:integer;
begin
  if (not Assigned(Control)) or (not Assigned(Control.Parent)) then
    exit;
  childRect:=Control.BoundsRect;
  parentRect:=Rect(0,0,Control.Parent.Width,Control.Parent.Height);
  if isHorisontal then
    dx:=(parentRect.Width-childRect.Width) div 2
  else
    dx:=childRect.Left;
  if isVertical then
    dy:=(parentRect.Height-childRect.Height) div 2
  else
    dy:=childRect.Top;
  newRect:=Rect(dx,dy,dx+childRect.Width,dy+childRect.Height);
  Control.BoundsRect:=newRect;
end;
procedure HorizontalCenter(Control: TControl);
begin
 CenterControl(Control,false,true);
end;
procedure Center(Control: TControl);
begin
 CenterControl(Control,true,true);
end;
procedure VerticalCenter(Control: TControl);
begin
  CenterControl(Control,true,false);
end;

procedure TiAboutForm.FormDestroy(Sender: TObject);
begin
  if Font1<>0 then
    RemoveFontMemResourceEx(Font1);
  if Font2<>0 then
    RemoveFontMemResourceEx(Font2);
end;

procedure TiAboutForm.FormCreate(Sender: TObject);
var
  FontName: string;
  FontNameMono: string;
begin
  FontName := 'PT SANS';
  FontNameMono:='PT MONO';
  Font1:=LoadFont(1);
  if Font1<>0 then begin
    try
      ilabelMe.Font.Name:=FontName;
      ilabelGithub.Font.Name:=FontName;
      ilabelVersion.Font.Name:=FontName;
      ilabelAbout.Font.Name:=FontName;
    except
    end;
  end;
  Font2:=LoadFont(1);
  if Font2<>0 then begin
    try
      ilabelScreenshooter.Font.Name:=FontNameMono;
    except
    end;
  end;
  ilabelVersion.Caption:=GetExeVersion;
end;

procedure TiAboutForm.FormResize(Sender: TObject);
begin
  HorizontalCenter(iLogo);
  HorizontalCenter(ilabelScreenshooter);
  ilabelVersion.Left:=ilabelScreenshooter.BoundsRect.Right+5;
end;

function TiAboutForm.GetExeVersion: string;
var
  verblock:PVSFIXEDFILEINFO;
  versionMS,versionLS:cardinal;
  verlen:cardinal;
  rs:TResourceStream;
  m:TMemoryStream;
  p:pointer;
  s:cardinal;
begin
  m:=TMemoryStream.Create;
  Result:='';
  try
    rs:=TResourceStream.CreateFromID(HInstance,1,RT_VERSION);
    try
      m.CopyFrom(rs,rs.Size);
    finally
      rs.Free;
    end;
    m.Position:=0;
    if VerQueryValue(m.Memory,'\',pointer(verblock),verlen) then
      begin
        VersionMS:=verblock.dwFileVersionMS;
        VersionLS:=verblock.dwFileVersionLS;
        Result:=
          IntToStr(versionMS shr 16)+'.'+
          IntToStr(versionMS and $FFFF)+'.'+
          IntToStr(VersionLS shr 16);
      end;
    if VerQueryValue(m.Memory,PChar('\\StringFileInfo\\'+
      IntToHex(GetThreadLocale,4)+IntToHex(GetACP,4)+'\\FileDescription'),p,s) or
        VerQueryValue(m.Memory,'\\StringFileInfo\\040904E4\\FileDescription',p,s) then //en-us
          Result:=PChar(p)+' '+Result;
  finally
    m.Free;
  end;
end;

procedure TiAboutForm.ilabelMeLinkClick(Sender: TObject; const Link: string;
  LinkType: TSysLinkType);
begin
  ShellExecute(0, 'OPEN', PChar(Link), '', '', SW_SHOWNORMAL);
end;

function TiAboutForm.LoadFont(const FontResIndex: integer): THandle;
var
  DllHandle: HMODULE;
  ResHandle: HRSRC;
  ResSize, NbFontAdded: Cardinal;
  ResAddr:HGLOBAL;
begin
  Result:=0;
{  DllHandle := LoadLibrary(DllName);
  if DllHandle = 0 then
    RaiseLastOSError; }
  ResHandle := FindResource(HInstance, makeintresource(FontResIndex), RT_FONT);
  if ResHandle = 0 then
    exit;
  ResAddr := LoadResource(HInstance, ResHandle);
  if ResAddr = 0 then
    exit;
  ResSize := SizeOfResource(HInstance, ResHandle);
  if ResSize = 0 then
    exit;
  Result := AddFontMemResourceEx(Pointer(ResAddr), ResSize, nil, @NbFontAdded);

end;

procedure TiAboutForm.Translate;
begin
  Caption:=GetString(S_ABOUT_CAPTION);
  ilabelScreenshooter.Caption:=GetString(S_ABOUT_TITLE);
  ilabelAbout.Caption:=GetString(S_ABOUT_INFO);
  ilabelMe.Caption:=GetString(S_ABOUT_ME);
  ilabelGithub.Caption:=GetString(S_ABOUT_GITHUB);

  Resize;
end;

end.
