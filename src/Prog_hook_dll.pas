unit Prog_hook_dll;

interface

function SetKeyboardHook: Boolean; stdcall;
function RemoveKeyboardHook: Boolean; stdcall;

implementation

function SetKeyboardHook: Boolean; external 'Prog_hook_dll.dll';
function RemoveKeyboardHook: Boolean; external 'Prog_hook_dll.dll';

end.
