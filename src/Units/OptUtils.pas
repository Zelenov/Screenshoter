unit OptUtils;

interface
uses SysUtils,IniFiles;
type TInlineProc=reference to procedure;


TOptions = class
private
  /// <summary>Ini file associated with this class
  /// </summary>
  /// type:TIniFile
  class var OptionsFile: TIniFile;
  /// <summary>Returns directory with .ini file in it. Now it's application's exe path
  /// </summary>
  /// <returns> directory with Options.ini in it
  /// </returns>
  class function GetOptionsDirectory: string;
  /// <summary>Returns full path to Options.ini
  /// </summary>
  /// <returns> full path to Options.ini
  /// </returns>
  class function GetOptionsFileName: string;
  /// <summary>Opens file and returns true, if procedure succeeded
  /// </summary>
  /// <returns> Existence of ini file
  /// </returns>
  class function OpenFile: Boolean;
  /// <summary>Closes Ini file
  /// </summary>
  /// Close
  class procedure CloseFile;
  /// <summary>Returns true if ini file, assotiated with class is opened
  /// </summary>
  /// <returns> Current file state
  /// </returns>
  class function IsOpen: boolean;
  /// <summary>Opens or creates file, do the work, defined by InlineProc, and closes
  /// the file
  /// </summary>
  /// <param name="InlineProc"> Procedure, that needs to be applied to ini file
  /// </param>
  class procedure Process(InlineProc:TInlineProc);
public
  /// <summary>Creates new ini file and fills it with default values
  /// </summary>
  class procedure CreateOptionsFile;
  /// <summary>Reads boolean value from ini file by string key
  /// </summary>
  /// <param name="Key"> Key to search for</param>
  /// <param name="bValue">output value </param>
  class procedure ReadOption(const Key: string; out bValue: boolean); overload;
  /// <summary>Reads string value from ini file by string key
  /// </summary>
  /// <param name="Key"> Key to search for</param>
  /// <param name="sValue">output value </param>
  class procedure ReadOption(const Key: string; out sValue: string); overload;
  /// <summary>Reads integer value from ini file by string key
  /// </summary>
  /// <param name="Key"> Key to search for</param>
  /// <param name="iValue">output value </param>
  class procedure ReadOption(const Key: string; out iValue: Integer); overload;
  /// <summary>Writes  string value to ini file with string key. Returns actual value,
  /// stored in file.
  /// </summary>
  /// <returns> Actual value, stored in file
  /// </returns>
  /// <param name="Key"> Key for new value </param>
  /// <param name="sValue"> value to write </param>
  class function WriteOption(const Key, sValue: string): string; overload;
  /// <summary>Writes  boolean value to ini file with string key. Returns actual
  /// value, stored in file.
  /// </summary>
  /// <returns> Actual value, stored in file
  /// </returns>
  /// <param name="Key"> Key for new value </param>
  /// <param name="bValue"> value to write </param>
  class function WriteOption(const Key: string; const bValue: boolean): Boolean;
      overload;
  /// <summary>Writes  integer value to ini file with string key. Returns actual
  /// value, stored in file.
  /// </summary>
  /// <returns> Actual value, stored in file
  /// </returns>
  /// <param name="Key"> Key for new value </param>
  /// <param name="iValue"> value to write </param>
  class function WriteOption(const Key: string; const iValue: Integer): Integer;
      overload;
end;

implementation
const OptionsFileName='Options.ini';
const SectionName='Options';

{ TOptions }

class procedure TOptions.CloseFile;
begin
  if IsOpen then
    FreeAndNil(OptionsFile);
end;

class procedure TOptions.CreateOptionsFile;
begin
  OpenFile;
  try
    WriteOption('Language','En');
    WriteOption('Sound',true);
  finally
    CloseFile;
  end;
end;

class function TOptions.GetOptionsDirectory: string;
begin
  result:=ExtractFilePath(Paramstr(0));
end;

class function TOptions.GetOptionsFileName: string;
begin
  result:=IncludeTrailingPathDelimiter(GetOptionsDirectory)+OptionsFileName;
end;

class function TOptions.IsOpen: boolean;
begin
  result:=Assigned(OptionsFile);
end;

class function TOptions.OpenFile: Boolean;
var open:boolean;
    fileName:string;
begin
  fileName:=GetOptionsFileName;
  Result:=FileExists(fileName);
  OptionsFile:=TiniFile.Create(GetOptionsFileName);
end;

class procedure TOptions.Process(InlineProc:TInlineProc);
var open:boolean;
begin
  open:=IsOpen;
  if not open then begin
    if not OpenFile then begin
      CreateOptionsFile;
      open:=OpenFile;
      if open=false then
        exit;
    end;
  end;
  try
    InlineProc;
  finally
    if not open then
      CloseFile;

  end;
end;

class procedure TOptions.ReadOption(const Key: string; out bValue: boolean);
var res:boolean;
begin
  Process(procedure
  begin
    res:=OptionsFile.ReadBool(SectionName,Key,false);
  end);
  bValue:=res;
end;

class procedure TOptions.ReadOption(const Key: string; out sValue: string);
var res:string;
begin
  Process(procedure
  begin
    res:=OptionsFile.ReadString(SectionName,Key,'');
  end);
  sValue:=res;
end;

class procedure TOptions.ReadOption(const Key: string; out iValue: Integer);
var res:integer;
begin
  Process(procedure
  begin
    res:=OptionsFile.ReadInteger(SectionName,Key,0);
  end);
  iValue:=res;
end;

class function TOptions.WriteOption(const Key, sValue: string): string;
begin
  Process(procedure
  begin
    OptionsFile.WriteString(SectionName,Key,sValue);
  end);
  ReadOption(Key,Result);
end;


class function TOptions.WriteOption(const Key: string; const bValue: boolean):
    Boolean;
begin
  Process(procedure
  begin
    OptionsFile.WriteBool(SectionName,Key,bValue);
  end);
  ReadOption(Key,Result);
end;

class function TOptions.WriteOption(const Key: string; const iValue: Integer):
    Integer;
begin
  Process(procedure
  begin
    OptionsFile.WriteInteger(SectionName,Key,iValue);
  end);
  ReadOption(Key,Result);
end;

end.
