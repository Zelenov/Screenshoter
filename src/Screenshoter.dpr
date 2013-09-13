program Screenshoter;



{$R 'Localization.res' 'Res\Localization.rc'}
{$R 'uac_xp.res' 'Res\uac_xp.rc'}
{$R *.dres}

uses
  Forms,
  Windows,
  OptUtils in 'Units\OptUtils.pas',
  AutoRun in 'Units\AutoRun.pas',
  CommonUtils in 'Units\CommonUtils.pas',
  FileUtils in 'Units\FileUtils.pas',
  ImageUtils in 'Units\ImageUtils.pas',
  ScreenshotUtils in 'Units\ScreenshotUtils.pas',
  ShellUtils in 'Units\ShellUtils.pas',
  SmartStringFormat in 'Units\SmartStringFormat.pas',
  TrayUtils in 'Units\TrayUtils.pas',
  ZControls in 'Units\ZControls.pas',
  ZThreads in 'Units\ZThreads.pas',
  About in 'Forms\About.pas',
  main in 'Forms\main.pas';

{$R *.res}

begin
  if IsAlreadyRunning then begin
    exit;
  end;

  Application.Initialize;
  Application.Title := 'Screenshoter';
  Application.CreateForm(TiScreenshoterForm, iScreenshoterForm);
  Application.ShowMainForm:=False;
  Application.Run;


end.

