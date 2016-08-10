unit ScriptInterface;

interface

uses SysUtils;

type
  TScriptOption = class
  end;//stub

  //attribute for garbage collector
  TGCAttr = class(TCustomAttribute);
  //attribute for allowed object methods, props and fields
  TAllowedAttr = class(TCustomAttribute);
  //attribute for forbidden methods and fields of object
  TMethodForbiddenAttr = class(TCustomAttribute);
  //attribute for forbidden objects
  TObjectForbiddenAttr = class(TCustomAttribute);

  ICallableMethod = interface
    procedure Call(Sender: TObject);
  end;

  TOptionEvent = procedure(Sender: TScriptOption) of object;

  TOptionCallback = record
    Event: TOptionEvent;
    Callable: ICallableMethod;
    procedure Call(Sender: TScriptOption);
    constructor Create(AEvent: TOptionEvent);
    class operator Implicit(AEvent: TOptionEvent): TOptionCallback;
    function Assigned: boolean;
  end;

  TJSClassExtender = class(TObject)
  private
    FSource: TObject;
  public
    property Source: TObject Read FSource Write FSource;
  end;

  EScriptEngineException = class(Exception)
  end;

implementation

{ TOptionCallback }

function TOptionCallback.Assigned: boolean;
begin
  Result := System.Assigned(Event) or System.Assigned(Callable);
end;

procedure TOptionCallback.Call(Sender: TScriptOption);
begin
  if System.Assigned(Event) then
    Event(Sender)
  else if System.Assigned(Callable) then
    Callable.Call(Sender);
end;

constructor TOptionCallback.Create(AEvent: TOptionEvent);
begin
  Event := AEvent;
  Callable := nil;
end;

class operator TOptionCallback.Implicit(AEvent: TOptionEvent): TOptionCallback;
begin
  Result.Event := AEvent;
end;

end.
