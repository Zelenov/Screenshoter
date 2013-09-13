

unit AutoRun;

interface
uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Registry, Dialogs;

type
  TAutoRun = class
  public
    {
    <summary>Writes or deletes application from "Run" section of registry
    </summary>
    <returns> True, if application is in registry, false otherwise.
    </returns>
    <param name="aName"> path to an application </param>
    <param name="isActive">true to write app, false - to delete app from "Run"
    section</param>
    }
    class function SetAutorun(aName:string; isActive:boolean): Boolean;
    /// <summary>Returns true, if current applications is written in "Run" section of
    /// registry
    /// </summary>
    /// <returns> Existence of application in registry "Run" section
    /// </returns>
    /// <param name="aName"> path to an application</param>
    class function isAutorun(aName:string): Boolean;

  end;



implementation
class function TAutoRun.isAutorun(aName:string): Boolean;
var reg: TRegistry;
    str:string;
begin
  try
    reg := TRegistry.Create(KEY_READ);
    reg.RootKey := HKEY_LOCAL_MACHINE;
    reg.LazyWrite := false;
    //RUN
    reg.OpenKey('Software\Microsoft\Windows\CurrentVersion\Run', false);
    result:=false;
    if reg.ValueExists(aName) then begin
      str:=reg.ReadString(aName);
      if str=Paramstr(0) then
        result:=true;
    end;
    reg.CloseKey;
  finally
     FreeAndNil(reg);
  end;

end;

{---------------SetActive------------------------------}
class function TAutoRun.SetAutorun(aName:string; isActive:boolean): Boolean;
var reg: TRegistry;
begin
  Result:=false;
  try
    reg := TRegistry.Create(KEY_WRITE);
    reg.RootKey := HKEY_LOCAL_MACHINE;
    reg.LazyWrite := false;
    reg.OpenKey('Software\Microsoft\Windows\CurrentVersion\Run', false);
    case isActive of
      true:reg.WriteString(aName, Paramstr(0));
      false:reg.DeleteValue(aName);
    end;
    reg.CloseKey;
  finally
    FreeAndNil(reg);
  end;
  result:=isActive;
end;



end.
 