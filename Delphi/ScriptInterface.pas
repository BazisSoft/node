unit ScriptInterface;

interface

uses SysUtils, RTTI;

type
{ATTRIBUTES/}
  //attribute for garbage collector
  TGCAttr = class(TCustomAttribute);
  //attribute for allowed object methods, props and fields
  TAllowedAttr = class(TCustomAttribute);
  //attribute for forbidden methods and fields of object
  TMethodForbiddenAttr = class(TCustomAttribute);
  //attribute for forbidden objects
  TObjectForbiddenAttr = class(TCustomAttribute);
  //attribute for callback records
  TCallBackAttr = class(TCustomAttribute);
  //attribute for callback 'SetFunction' method
  TCallBackFuncAttr = class(TCustomAttribute);

  TAttrClass = class of TCustomAttribute;
{\ATTRIBUTES}

  ICallableMethod = interface
    function Call(const Params: array of TValue): TValue;
  end;

  TJSClassExtender = class(TObject)
  private
    FSource: TObject;
  public
    property Source: TObject Read FSource Write FSource;
  end;

  TJSExtClass = class of TJSCLassExtender;

  EScriptEngineException = class(Exception)
  end;

implementation

end.
