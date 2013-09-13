unit Prog_hook_dll;

interface

function SetKeyboardHook: Boolean; stdcall;
function RemoveKeyboardHook: Boolean; stdcall;

implementation

function SetKeyboardHook: Boolean; external 'Screenshoter_hook.dll';
function RemoveKeyboardHook: Boolean; external 'Screenshoter_hook.dll';

end.
