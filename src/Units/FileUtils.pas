unit FileUtils;

interface
uses SysUtils,classes,ImageUtils,System.SyncObjs;
type
  {Thread that traverse list of files and cheks their existence}
  TFileWatchTread = class (TThread)
    private
      FThumbnailCollection: TThumbnailCollection;
    protected
      /// <summary>Event is set when tread finishes it's work</summary>
      /// type:TEvent
      FinishedEvent: TEvent;
      /// <summary>Event for setting delay between thread cycles
      /// </summary>
      /// type:TEvent
      WaitingEvent: TEvent;
      /// <summary>Flag sets when Destroy method was called
      /// </summary>
      /// type:boolean
      Destroing: boolean;
      procedure Execute; override;
    public
      constructor Create(aThumbnailCollection: TThumbnailCollection);
      destructor Destroy; override;
      property ThumbnailCollection: TThumbnailCollection read FThumbnailCollection;

  end;
implementation

constructor TFileWatchTread.Create(aThumbnailCollection: TThumbnailCollection);
begin
  inherited Create(true);
  Destroing:=false;
  FThumbnailCollection:=aThumbnailCollection;
  WaitingEvent:=TEvent.Create(nil,true,false,'WaitingEvent');
  FinishedEvent:=TEvent.Create(nil,true,false,'FileWatchTread');
end;

destructor TFileWatchTread.Destroy;
begin
  Destroing:=true;
  WaitingEvent.SetEvent;
  //Honestly waiting for thread to finish
  FinishedEvent.WaitFor(5000);
  if Assigned(WaitingEvent) then
    FreeAndNil(WaitingEvent);
  if Assigned(FinishedEvent) then
    FreeAndNil(FinishedEvent);
  inherited;
end;

procedure TFileWatchTread.Execute;
begin

  while (not self.Terminated)and (not Destroing) do begin
    //for all files
    FThumbnailCollection.Traverse(procedure (Index:integer; Thumbnail:TThumbnail; var doDelete:boolean)
    begin
      //set delete flag, if file no longer exists
      doDelete:=not FileExists(Thumbnail.FileName)
    end);
    //wait for next cycle 2 seconds
    WaitingEvent.WaitFor(2000);
  end;
  FinishedEvent.SetEvent;
end;

end.
