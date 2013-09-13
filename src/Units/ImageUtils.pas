unit ImageUtils;

interface
uses Windows,Vcl.Graphics,SysUtils,Generics.Collections,ZThreads, Vcl.Imaging.PngImage,Math,
 Vcl.Imaging.GIFImg,SyncObjs ,  System.Classes,
Types,Vcl.Imaging.Jpeg, CommonUtils;
type

  {All the information to save bitmap}
  TSaveData = class
  private
  public
    /// <summary>Image to save
    /// </summary>
    /// type:TPngImage
    Bitmap: TPngImage;
    /// <summary>Date of image creation
    /// </summary>
    /// type:TDateTime
    Date: TDateTime;
    /// <summary>Name of foreground window when picture was captured
    /// </summary>
    /// type:string
    ForegroundWindowCaption: string;
    constructor Create;
    destructor Destroy;
  end;


  TThumbnail = class
  private
  public
    Bitmap:TBitmap;
    FileName:string;
    Hint:string;
    Scale:double;
    Rect:TRect;
    constructor Create;
    destructor Destroy;override;
    /// <summary>Changes the size of bitmap with saving of proportions.
    /// Code by David E. Dirkse (http://www.davdata.nl/math/bmresize.html)
    ///  with some minor changes by Evgeny Zelenov
    /// </summary>
    /// <param name="aFromBtimap"> Bitmap to resize </param>
    /// <param name="aToBitmap"> Resized bitmap</param>
    procedure AntiAliasedShrink(const aFromBtimap: TBitmap; aToBitmap: TBitmap);
    /// <summary>Draw thumbnail on Canvas
    /// </summary>
    /// <param name="Canvas">Canvas to draw on</param>
    /// <param name="aRect"> a rect to fit bitmap in</param>
    procedure Draw(Canvas: TCanvas; aRect: TRect);
    /// <summary>Creates little copy of graphic to fit in Rect property
    /// </summary>
    /// <param name="Old"> Graphic to reduce </param>
    procedure Shrink(Old: TGraphic);
  end;
  TThumbTraverseProc = reference to procedure (Index:integer; Thumbnail:TThumbnail; var doDelete:boolean);
  TMakeFileNameProc = procedure (const SaveData:TSaveData; var FileName:string;var Hint: string) of object;
  TThumbnailCollection=class;


  TLoadQueue=class (TQueueThread<TSaveData>)
  private
    FOnMakeFileName: TMakeFileNameProc;
    procedure DetectImage(const InputFileName: string; BM: TBitmap);
  protected
    Parent:TThumbnailCollection;
    procedure InvokeOnMakeFileName(const SaveData: TSaveData; var FileName: string;
        var Hint: string);
    procedure Process(const Item: TSaveData); override;
  public
    constructor Create(aParent:TThumbnailCollection);
    function SafePath(str: string): string;
//var
//Parent:HWND;
//DesktopPath: string;
    function Save(const Item: TSaveData;out Hint:string): string;
  published
    property OnMakeFileName: TMakeFileNameProc read FOnMakeFileName write
        FOnMakeFileName;
  end;
  TOnCollectionUpdated = procedure (Sender:TObject) of object;
  TThumbnailCollection = class
  private
    FHeight: Integer;
    FOnCollectionUpdated: TOnCollectionUpdated;
    FWidth: Integer;
    fLocked:Integer;
    FLockedList: TList;
    FListCritical:TCriticalSection ;
    function GetCount: Integer;
    function GetOnMakeFileName: TMakeFileNameProc;
    procedure SetOnMakeFileName(const Value: TMakeFileNameProc);
  protected
    List: TThreadList;
    ThreadedQueue:TLoadQueue;
    function GetThumbnails(Index: Integer): TThumbnail;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(SaveData: TSaveData); overload;
    procedure Add(Thumbnail:TThumbnail); overload;
    procedure Delete(Index: Integer);
    procedure InvokeOnCollectionUpdated;
    procedure Lock;
    procedure Traverse(aTraverseProc: TThumbTraverseProc);
    procedure Unlock;
    property Count: Integer read GetCount;
    property Height: Integer read FHeight write FHeight;
    property Thumbnails[Index: Integer]: TThumbnail read GetThumbnails; default;
    property Width: Integer read FWidth write FWidth;

  published
    property OnCollectionUpdated: TOnCollectionUpdated read FOnCollectionUpdated
        write FOnCollectionUpdated;
    property OnMakeFileName: TMakeFileNameProc read GetOnMakeFileName write
        SetOnMakeFileName;
  end;


implementation

{ TThumbnail }

uses SmartStringFormat;

constructor TThumbnail.Create;
begin
  inherited;

end;

destructor TThumbnail.Destroy;
begin
  if Assigned(Bitmap) then
    FreeAndNil(Bitmap);
  inherited;
end;

procedure TThumbnail.AntiAliasedShrink(const aFromBtimap: TBitmap; aToBitmap:
    TBitmap);
//reduce or enlarge
type 
    
    TWa = ARRAY[0..0] OF TRGBTriple;
    PWa = ^TWa;
var 
    sw,sh:integer;
    sx1,sy1,sx2,sy2 : single;    //source field positions
    py,pj : PWa;
    x,y,i,j : word;              //source,dest field pixels
    destR,destG,destB : single;  //destination colors
    sR,sG,sB : byte;             //source colors
    destWidth, destheight : word;
    f,fi2 : single;              //factors
    dx,dy,AP : single;           //distance, area percentage
    color : TRGBTriple;//longInt;
begin

//
  sw:=aFromBtimap.Width;
  sh:=aFromBtimap.Height;
  
 destwidth := aToBitmap.Width;
 f := sw / destwidth;
 fi2 := 1/f;
 fi2 := fi2*fi2;
 destheight := trunc(sh/f);
 aToBitmap.Height:= destheight;
// destheight := aToBitmap.Height;
//---
 for y := 0 to destheight-1 do         //vertical destination pixels
  begin
   sy1 := f * y;
   sy2 := sy1 + f;
   py := aToBitmap.ScanLine[y];
   for x := 0 to destwidth-1 do        //horizontal destination pixels
    begin
     sx1 := f * x;
     sx2 := sx1 + f;
     destR := 0; destG := 0; destB := 0;       //clear colors
     for j := floor(sy1) to ceil(sy2)-1 do  //vertical source pixels
      begin
       pj := aFromBtimap.scanline[j];
       dy := 1;
       if sy1 > j then begin
                        dy := dy-(sy1-j);
                       end;
       if sy2 < j+1 then begin
                          dy := dy-(j+1-sy2);
                         end;
       for i := floor(sx1) to ceil(sx2)-1 do //horizontal source pixels
        begin
         dx := 1;
         if sx1 > i then begin
                         dx := dx-(sx1-i);
                        end;
         if sx2 < i+1 then begin
                           dx := dx-(i+1-sx2);
                          end;
         color := pj^[i];
         sB := color.rgbtBlue;// and $ff;
         sG := color.rgbtGreen;//(color shr 8) and $ff;
         sR := color.rgbtRed;//(color shr 16) and $ff;
         AP := dx*dy*fi2;
         destR := destR + sR*AP;
         destG := destG + sG*AP;
         destB := destB + sB*AP;
        end;//for i
      end;//for j
      color.rgbtBlue := trunc(destB);
      color.rgbtGreen := trunc(destG);
      color.rgbtRed := trunc(destR);
      py^[x] := color;
    end;//for x
  end;//for y
end;

procedure TThumbnail.Draw(Canvas: TCanvas; aRect: TRect);
begin
  Canvas.Draw(aRect.Left,aRect.Top,Bitmap);
end;

procedure TThumbnail.Shrink(Old: TGraphic);
var NewBitmap:TBitmap;
    w,h:integer;
    b:boolean;

    temp:TBitmap;
begin
  w:=Rect.Width;
  h:=rect.Height;

  if Assigned(Bitmap) then
    FreeAndNil(Bitmap);
  Bitmap:=TBitmap.Create();

  Bitmap.SetSize(w,h);
  Bitmap.PixelFormat:=pf24bit;
  temp:=TBitmap.Create;
  temp.Assign(Old);
  try
    AntiAliasedShrink(temp,Bitmap);
  finally
    FreeAndNil(Temp);
    
  end;

  {Uncomment this code for unsightly size changing}
 // Bitmap.Canvas.StretchDraw(
 //   Types.Rect(0, 0, w, h),
 //   Old);


end;

{ TThumbnailCollection }

constructor TThumbnailCollection.Create;
begin
  inherited;
  List:=TThreadList.Create;
  ThreadedQueue:=TLoadQueue.Create(self);
  ThreadedQueue.Start;
  FListCritical:=TCriticalSection.Create;
end;

destructor TThumbnailCollection.Destroy;
begin
  if Assigned(FListCritical) then
    FreeAndNil(FListCritical);
  if Assigned(List) then
    FreeAndNil(List);
  if Assigned(ThreadedQueue) then
    FreeAndNil(ThreadedQueue);
  inherited;
end;

procedure TThumbnailCollection.Add(Thumbnail:TThumbnail);
begin
  if not Assigned(Thumbnail) then
    exit;
  Thumbnail.Scale:=1.0;

  List.Add(Thumbnail);
  InvokeOnCollectionUpdated;
end;

procedure TThumbnailCollection.Add(SaveData: TSaveData);
begin
  ThreadedQueue.Add(SaveData);
end;

procedure TThumbnailCollection.Delete(Index: Integer);
begin
  Lock;
  try
    FlockedList.Delete(Index);
    InvokeOnCollectionUpdated;
  finally
    Unlock;
  end;
end;

function TThumbnailCollection.GetCount: Integer;
begin
  Lock;
  try
    Result := FLockedList.Count;
  finally
    Unlock;
  end;

end;

function TThumbnailCollection.GetOnMakeFileName: TMakeFileNameProc;
begin
  if Assigned(ThreadedQueue) then
    Result := ThreadedQueue.OnMakeFileName
  else
    Result:=nil;
end;

function TThumbnailCollection.GetThumbnails(Index: Integer): TThumbnail;
begin
  Lock;
  try
    if (Index<0) or (Index>=FLockedList.Count) then
      Result:=nil
    else begin
        Result := FLockedList[Index];
    end;
  finally
    Unlock;
  end;

end;

procedure TThumbnailCollection.InvokeOnCollectionUpdated;
begin
  if Assigned(OnCollectionUpdated) then
    OnCollectionUpdated(self);
end;

procedure TThumbnailCollection.Lock;
begin
  //FListCritical.Enter;
  //  if InterlockedIncrement(fLocked)=1 then begin
      FLockedList:=List.LockList;
 //   end;
  //FListCritical.Leave;
end;

procedure TThumbnailCollection.SetOnMakeFileName(const Value:
    TMakeFileNameProc);
begin
  if Assigned(ThreadedQueue) then
    ThreadedQueue.OnMakeFileName:=Value;
end;

procedure TThumbnailCollection.Traverse(aTraverseProc: TThumbTraverseProc);
var i:integer;
    Thumbnail:TThumbnail;
    doDelete:boolean;
    changed:boolean;
begin
  if not Assigned(aTraverseProc) then
    exit;
  changed:=false;
  Lock;
  try
    for i:=FLockedList.Count-1 downto 0 do
    begin
      doDelete:=false;
      Thumbnail:=FLockedList[i];
      aTraverseProc(i,Thumbnail,doDelete);
      if doDelete then begin
        FLockedList.Delete(i);
        changed:=true;
      end;
    end;
  finally
    Unlock;
  end;
  if changed then
    InvokeOnCollectionUpdated;
end;

procedure TThumbnailCollection.Unlock;
begin
 // FListCritical.Enter;
  //  if InterlockedDecrement(fLocked)=0 then begin
      List.UnlockList;
      FLockedList:=nil;
  //  end;
  //FListCritical.Leave;
end;

{ TLoadQueue }

constructor TLoadQueue.Create(aParent: TThumbnailCollection);
begin
  Inherited Create('LoadQueueEvent','LoadQueueSemaphore');
  Parent:=aParent;
end;

procedure TLoadQueue.DetectImage(const InputFileName: string; BM: TBitmap);
var
  FS: TFileStream;
  FirstBytes: AnsiString;
  Graphic: TGraphic;
begin
  Graphic := nil;
  FS:=nil;
  try
    FS := TFileStream.Create(InputFileName, fmOpenRead);

    SetLength(FirstBytes, 8);
    FS.Read(FirstBytes[1], 8);
    if Copy(FirstBytes, 1, 2) = 'BM' then
    begin
      Graphic := TBitmap.Create;
    end else
    if FirstBytes = #137'PNG'#13#10#26#10 then
    begin
      Graphic := TPngImage.Create;
    end else
    if Copy(FirstBytes, 1, 3) =  'GIF' then
    begin
      Graphic := TGIFImage.Create;
    end else
    if Copy(FirstBytes, 1, 2) = #$FF#$D8 then
    begin
      Graphic := TJPEGImage.Create;
    end;
    if Assigned(Graphic) then
    begin
      try
        FS.Seek(0, soFromBeginning);
        //Graphic.LoadFromFile(InputFileName);
        Graphic.LoadFromStream(FS);
        BM.Assign(Graphic);
      except
        beep;
      end;

      FreeAndNil(Graphic);
    end;
  finally
    if Assigned(FS) then
      FreeAndNil(FS);
  end;
end;

procedure TLoadQueue.InvokeOnMakeFileName(const SaveData: TSaveData; var
    FileName: string;var Hint: string);
begin
  if Assigned(OnMakeFileName) then
    OnMakeFileName(SaveData,FileName,Hint)
end;

procedure TLoadQueue.Process(const Item: TSaveData);
var
    Thumbnail:TThumbnail;
    W,H,M:integer;
    wScale, hScale,scale:double;
    realW,realH:integer;
    FileName,Hint:string;
    step:integer;
begin
  Thumbnail:=nil;
  step:=1;
  try
    if Assigned(Parent) then begin
      step:=2;
      FileName:=Save(Item,Hint);
      if FileName<>'' then begin
        try
           step:=3;
          Thumbnail:=TThumbnail.Create;
           step:=4;
          Thumbnail.FileName:=FileName;
          Thumbnail.Hint:=Hint;
           step:=5;
          //DetectImage(Item,Thumbnail.Bitmap);
           step:=6;
          W:=Item.Bitmap.Width;
           step:=7;
          H:=Item.Bitmap.Height;
           step:=8;
          if (W=0) or (H=0) then
            raise Exception.Create('Bad File format');
          realW:=Parent.Width;
          realH:=Parent.Height;
          wScale := realW / W;
          hScale := realH / H;
          scale:=Math.Min(wScale,hScale);
          W:=trunc(W*scale);
          H:=trunc(H*scale);
            step:=9;
          Thumbnail.Rect:=Rect(
            (realW-W) div 2,(realH-H) div 2,
            (realW+W) div 2, (realH+H) div 2);
            step:=10;
          Thumbnail.Shrink(Item.Bitmap);
        step:=11;

        except
          on E:Exception do begin
          //MessageBox(0,PChar(E.Message),'Error',0);
          if Assigned(Thumbnail) then
            FreeAndNil(Thumbnail);
          end;
        end;
      end;
    end;
  finally
    Item.Free;
  end;
  if Assigned(Thumbnail) then begin
    self.Queue(procedure begin
                    //if (not Thumbnail.Shrinked) then
                    //  Thumbnail.Shrink;

                    Parent.Add(Thumbnail)
                  end);
  end;
end;

function TLoadQueue.SafePath(str: string): string;
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

function TLoadQueue.Save(const Item: TSaveData;out Hint:string): string;
var
i:integer;

begin
  //MessageBox(0,PChar(DesktopPath),PChar('324'),0);

    //DesktopPath:='C:\img';
    result:='';
    Hint:='';
    InvokeOnMakeFileName(Item,result,Hint);
   
    if result='' then
      exit;
    //FileName:='Screenshot - ' + FileName;
    try
      Item.Bitmap.SaveToFile(result);
    except
      on E:Exception do begin
        MessageBox(0,PChar(E.Message),'Error',0);
      end;
    end;
end;

constructor TSaveData.Create;
begin
  Bitmap:=nil;
  ForegroundWindowCaption:='';
end;

destructor TSaveData.Destroy;
begin
  if Assigned(Bitmap) then
    FreeAndNil(Bitmap);
  Date:=0;
  ForegroundWindowCaption:='';
end;

end.
