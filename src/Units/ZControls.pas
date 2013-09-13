unit ZControls;

interface
uses Vcl.ComCtrls,Winapi.Messages,Vcl.Controls;
type
TZListView = class(TListView)
  private
    procedure CNMeasureItem(var Message: TWMMeasureItem); message CN_MEASUREITEM;
  end;

implementation

{ TZListView }

procedure TZListView.CNMeasureItem(var Message: TWMMeasureItem);
begin
  Message.MeasureItemStruct.itemHeight:=50;
  Message.MeasureItemStruct.itemWidth:=50;
end;

end.
