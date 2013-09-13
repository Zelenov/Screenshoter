unit ZThreads;

interface
uses
  Classes, Vcl.Graphics,System.SyncObjs,mmsystem,System.Generics.Collections,
    Vcl.clipbrd, ActiveX, SysUtils;
type
TQueueThread<T> = class (TThread)
private
protected
  Destroing: boolean;
  FinishedEvent: TEvent;
  ThreadedQueue: TThreadedQueue<T>;
  QueueSemaphore: TSemaphore;
  procedure Process(const Item: T); virtual; abstract;
public

  constructor Create(const EventName,SemaphreName:string);
  destructor Destroy; override;
  procedure Add(const Item: T);
  procedure Execute; override;
end;
implementation

constructor TQueueThread<T>.Create(const EventName,SemaphreName:string);
begin
  Inherited Create(true);
  FreeOnTerminate:=false;
  Destroing:=false;
  //AddedEvent:=TEvent.Create(nil,true,false,'ScreenSaveThreadEvent');
  FinishedEvent:=TEvent.Create(nil,true,false,EventName);
  //QueueSemaphore:=TSemaphore.Create(false);
  QueueSemaphore:=TSemaphore.Create(nil,0,100,SemaphreName,false);
  ThreadedQueue:=TThreadedQueue<T>.Create;
end;

destructor TQueueThread<T>.Destroy;
begin
  Destroing:=true;
  if Assigned(QueueSemaphore) then begin
    QueueSemaphore.Release;
  end;


  if Assigned(FinishedEvent) then begin
    FinishedEvent.WaitFor(5000);
    FreeAndNil(FinishedEvent);
  end;
  if Assigned(ThreadedQueue) then
    FreeAndNil(ThreadedQueue);
  if Assigned(QueueSemaphore) then begin
    FreeAndNil(QueueSemaphore);
  end;
  inherited;
end;

{ TQueueThread<T> }

procedure TQueueThread<T>.Add(const Item: T);
begin
  if Destroing then
    exit;
  ThreadedQueue.PushItem(Item);
  QueueSemaphore.Release;
end;

procedure TQueueThread<T>.Execute;
var Item:T;
begin
  try
    while not Destroing do begin
      QueueSemaphore.Acquire;
      if ThreadedQueue.QueueSize>0 then begin
        Item:=ThreadedQueue.PopItem;
        try
          Process(Item);
        except
          on E:Exception do begin
            beep;
          end;
        end;
      end;
    end;
    if Assigned(FinishedEvent) then
      FinishedEvent.SetEvent;
  except
    on E:Exception do begin
      beep;
    end;
  end;
end;

end.
