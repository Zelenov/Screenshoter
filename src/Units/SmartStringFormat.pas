unit SmartStringFormat;

interface
uses SysUtils,Variants ;
function CSharpFormat(const CSharpFormat: string;Arguments:array of Variant): string;
implementation
function Proceed(const FormatArg: string; Argument: Double; out value: string):
    boolean; overload;
var basicType  : Integer;
    settings:TFormatSettings;
begin
  value:=FloatToStr(Argument);
  result:=true;
end;

function Proceed(const FormatArg: string; Argument: string; out value: string):
    boolean; overload;
var basicType  : Integer;
    settings:TFormatSettings;
begin
  value:=Argument;
  result:=true;
end;

function Proceed(const FormatArg: string; Argument: UInt64; out value: string):
    boolean; overload;
var basicType  : Integer;
    settings:TFormatSettings;
begin
  value:=IntToStr(Argument);
end;
function Proceed(const FormatArg: string; Argument: Boolean; out value:
    string): boolean; overload;
var basicType  : Integer;
    settings:TFormatSettings;
begin
  value:=BoolToStr(Argument);
  result:=true;
end;

function Proceed(const FormatArg: string; Argument: TObject; out value:
    string): boolean; overload;
var basicType  : Integer;
    settings:TFormatSettings;
begin
  if Argument=nil then
    result:=false
  else begin
    value:=Argument.ToString;
    result:=true;
  end;
end;
function Proceed(const FormatArg: string; Argument: TDateTime; out value:
    string): boolean; overload;
var basicType  : Integer;
  settings:TFormatSettings;
begin
  try
    settings:=TFormatSettings.Create;
    settings.DateSeparator:='/';
    settings.TimeSeparator:=':';
    value:=FormatDateTime(Trim(FormatArg),argument,settings);
    result:=true;
  except
    result:=false;
  end;
end;
function Proceed(const FormatArg: string; Argument: Int64; out value: string):
    boolean; overload;
var basicType  : Integer;
    settings:TFormatSettings;
begin
  value:=IntToStr(Argument);
end;
function ProceedArgument(const FormatArg: string;Argument:Variant; out value:string): boolean;
var basicType  : Integer;
begin
  basicType := VarType(Argument) and VarTypeMask;
  result:=true;
  case basicType of
    varInteger:result:=Proceed(FormatArg,Integer(Argument),value);
    varShortInt :result:=Proceed(FormatArg,ShortInt (Argument),value);
    varByte:result:=Proceed(FormatArg,Byte(Argument),value);
    varLongWord:result:=Proceed(FormatArg,LongWord(Argument),value);
    varInt64:result:=Proceed(FormatArg,Int64(Argument),value);
    varWord:result:=Proceed(FormatArg,Word(Argument),value);
    varUInt64:result:=Proceed(FormatArg,UInt64(Argument),value);
    varDate:result:=Proceed(FormatArg,TDateTime(Argument),value);

    varEmpty   :value:='';
    varNull    :value:='';

    varSingle :result:=Proceed(FormatArg,Double(Argument),value);
    varDouble:result:=Proceed(FormatArg,Double(Argument),value);
    varCurrency:result:=Proceed(FormatArg,Double(Argument),value);

    //varOleStr  :result:=Proceed(FormatArg,string(Argument),value);
    //varDispatch:result:=Proceed(FormatArg,Dispatch(Argument),value);
    //varError   :result:=Proceed(FormatArg,Error(Argument),value);
    varBoolean :result:=Proceed(FormatArg,Boolean(Argument),value);
    //varVariant :result:=Proceed(FormatArg,Variant(Argument),value);
    //varUnknown :result:=Proceed(FormatArg,Unknown(Argument),value);
    //varRecord  :result:=Proceed(FormatArg,Record(Argument),value);
    //varStrArg  :result:=Proceed(FormatArg,StrArg(Argument),value);
    //varObject  :result:=Proceed(FormatArg,(Argument as TObject),value);
    //varUStrArg :result:=Proceed(FormatArg,UStrArg(Argument),value);
    varString  :result:=Proceed(FormatArg,String(Argument),value);
    //varAny     :result:=Proceed(FormatArg,Any(Argument),value);
    varUString:result:=Proceed(FormatArg,String(Argument),value);


   else result:=false;
  end;

end;
function CSharpFormat(const CSharpFormat: string;Arguments:array of Variant): string;
  type TMode = (WaitingForBracket,Bracket);

  var mode:TMode;
      index:integer;
      stringBuilder,argBuilder:TStringBuilder;
      lastPos:integer;
  procedure Push(const value:string);overload;
  var builder:tStringBuilder;
      s:string;
  begin
    case mode of
      Bracket:builder:=argBuilder;
      WaitingForBracket:builder:=stringBuilder;
    end;
    builder.Append(value);
  end;
  procedure Push();overload;
  var builder:tStringBuilder;
      value:string;
  begin
    value:=Copy(CSharpFormat,lastPos+1,index-lastPos-1);
    Push(value);
  end;
  function ConvertArgToString(const Param:string):string;
  var c:Char;

      i,len:integer;
      ArgumentIndex:integer;
      ArgumentStr,ArgumentParams:string;
  begin
    if param='' then begin
      raise EArgumentException.Create('Empty argument number');
    end;
    len:=Length(param);
    i:=1;
    while (i<=len) do begin
      c:=Param[i];
      if not (c in ['0'..'9']) then
        break;
      inc(i);
    end;
    dec(i);
    ArgumentStr:=Copy(Param,1,i);
    if ArgumentStr='' then begin
      raise EArgumentException.Create('Empty argument number');
    end;
    ArgumentIndex:=StrToInt(ArgumentStr);
    if (ArgumentIndex>=Length(Arguments)) then begin
      raise EArgumentException.Create('Wrong argument number');
    end else begin
      if (i<len) and (Param[i+1]<>':') then
      begin
        raise EArgumentException.Create('Argument parameters should be started with ":"');
      end else begin
        ArgumentParams:=Copy(Param,i+2,len-i-1);
        if not ProceedArgument(ArgumentParams,Arguments[ArgumentIndex],Result) then
          Result:='';
      end;
    end;
  end;
   var
      c:Char;
      len:integer;

      res:string;

      FormatArg,FormatRes:string;
      Argument:TVarRec;
      ArgumnetIndex:integer;
begin
  len:=Length(CSharpFormat);
  if len=0 then begin
    result:='';
    exit;
  end;
  ArgumnetIndex:=0;
  stringBuilder:=TStringBuilder.Create(len);
  argBuilder:=TStringBuilder.Create();
  try
  mode:=WaitingForBracket;

  lastPos:=0;
  index:=0;
  while (index<=len) do begin
    inc(index);
    c:=CSharpFormat[index];
    case c of
      '{':begin
            if (index<len)and(CSharpFormat[index+1]='{') then begin
              Push;
              Push('{');
              inc(index);
            end else
              case mode of
                Bracket:begin

                        end;
                WaitingForBracket:
                        begin
                          Push;
                          mode:=Bracket;
                          lastPos:=Index;


                        end;
              end;
          end;
      '}':begin
            if (index<len)and(CSharpFormat[index+1]='}') then begin
              Push;
              Push('}');
              inc(index);
            end else
              case mode of
                Bracket:begin
                          Push;
                          mode:=WaitingForBracket;
                          lastPos:=Index;


                          FormatArg:=argBuilder.ToString;
                          FormatRes:=ConvertArgToString(FormatArg);

                          Push(FormatRes);

                          argBuilder.Clear;
                        end;
                WaitingForBracket:
                        begin
                        end;
              end;
            end;
          end;
  end;
  if mode=Bracket then begin
    raise EArgumentException.Create('Bracket is not closed');
  end;
  Push;
  Result:=stringBuilder.ToString;
  finally
  FreeAndNil(argBuilder);
    FreeAndNil(stringBuilder);

  end;
end;






end.
