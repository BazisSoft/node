unit V8Interface;

interface

type

  IValue = class;

  IEngineIntf = class
    // do not call!
    // here because implementation needs virtual C++ destructor
    procedure _Destructor; virtual; abstract;
    procedure Delete; virtual; stdcall; abstract;
    function TestFun: Integer; virtual; stdcall; abstract;
  end;

  IObject = class (IEngineIntf)
    function IsDelphiObject: boolean; virtual; stdcall; abstract;
    function GetDelphiObject: TObject; virtual; stdcall; abstract;
    function GetDelphiClasstype: TClass; virtual; stdcall; abstract;
  end;

  IFunction = class (IEngineIntf)
    procedure AddArg(val: integer); overload; virtual; stdcall; abstract;
    procedure AddArg(val: boolean); overload; virtual; stdcall; abstract;
    procedure AddArg(val: PAnsiChar); overload; virtual; stdcall; abstract;
    procedure AddArg(val: double); overload; virtual; stdcall; abstract;
    procedure AddArg(val: TObject); overload; virtual; stdcall; abstract;
    function CallFunction: IValue; virtual; stdcall; abstract;
  end;

  IValuesArray = class (IEngineIntf)
    function GetCount: integer; virtual; stdcall; abstract;
    function GetValue(index: integer): IValue; virtual; stdcall; abstract;
    procedure SetValue(value: IValue; index: integer); virtual; stdcall; abstract;
  end;

  IRecord = class(IEngineIntf)
    procedure SetField(Name: PAnsiChar; val: integer); overload; virtual; stdcall; abstract;
    procedure SetField(Name: PAnsiChar; val: double); overload; virtual; stdcall; abstract;
    procedure SetField(Name: PAnsiChar; val: boolean); overload; virtual; stdcall; abstract;
    procedure SetField(Name: PAnsiChar; val: PAnsiChar); overload; virtual; stdcall; abstract;
    procedure SetField(Name: PAnsiChar; val: TObject); overload; virtual; stdcall; abstract;

    function GetIntField(NAme: PAnsiChar): integer; virtual; stdcall; abstract;
    function GetDoubleField(NAme: PAnsiChar): double; virtual; stdcall; abstract;
    function GetBoolField(NAme: PAnsiChar): boolean; virtual; stdcall; abstract;
    function GetStringField(NAme: PAnsiChar): PAnsiChar; virtual; stdcall; abstract;
    function GetObjectField(NAme: PAnsiChar): TObject; virtual; stdcall; abstract;
  end;

  IValue = class (IEngineIntf)
    function IsNumber: boolean; virtual; stdcall; abstract;
    function IsInt: boolean; virtual; stdcall; abstract;
    function IsBool: boolean; virtual; stdcall; abstract;
    function IsString: boolean; virtual; stdcall; abstract;
    function IsObject: boolean; virtual; stdcall; abstract;
    function IsArray: boolean; virtual; stdcall; abstract;
    function IsV8Function: boolean; virtual; stdcall; abstract;


    function AsNumber: double; virtual; stdcall; abstract;
    function AsInt: integer; virtual; stdcall; abstract;
    function AsBool: Boolean; virtual; stdcall; abstract;
    function AsString: PAnsiChar; virtual; stdcall; abstract;
    function AsObject: IObject; virtual; stdcall; abstract;
    function AsArray: IValuesArray; virtual; stdcall; abstract;
    function AsRecord: IRecord; virtual; stdcall; abstract;
    function AsFunction: IFunction; virtual; stdcall; abstract;
  end;

  IMethodArgs = class (IEngineIntf)
    function GetEngine: TObject; virtual; stdcall; abstract;
    function GetDelphiObject: TObject; virtual; stdcall; abstract;
    function GetDelphiClasstype: Pointer; virtual; stdcall; abstract;
    function GetArgsCount: integer; virtual; stdcall; abstract;

    function GetMethodName: PAnsiChar; virtual; stdcall; abstract;

    procedure SetReturnValue(p: Pointer; dClasstype: Pointer); overload; virtual; stdcall; abstract;
    procedure SetReturnValue(val: integer); overload; virtual; stdcall; abstract;
    procedure SetReturnValue(val: boolean); overload; virtual; stdcall; abstract;
    procedure SetReturnValue(val: PAnsiChar); overload; virtual; stdcall; abstract;
    procedure SetReturnValue(val: Double); overload; virtual; stdcall; abstract;
    procedure SetReturnValueAsRecord; virtual; stdcall; abstract;
    function GetReturnValueAsRecord: IRecord; virtual; stdcall; abstract;

    function GetArg(index: integer): IValue; virtual; stdcall; abstract;
    function GetDelphiMethod: TObject; virtual; stdcall; abstract;
  end;

  IGetterArgs = class (IEngineIntf)
    function GetEngine: TObject; virtual; stdcall; abstract;
    function GetDelphiObject: TObject; virtual; stdcall; abstract;
    function GetDelphiClasstype: Pointer; virtual; stdcall; abstract;
    function GetPropName: PAnsiChar; virtual; stdcall; abstract;
    function GetPropIndex: integer; virtual; stdcall; abstract;

    procedure SetGetterResult(p: Pointer; dClasstype: Pointer); overload; virtual; stdcall; abstract;
    procedure SetGetterResult(val: integer); overload; virtual; stdcall; abstract;
    procedure SetGetterResult(val: boolean); overload; virtual; stdcall; abstract;
    procedure SetGetterResult(val: PAnsiChar); overload; virtual; stdcall; abstract;
    procedure SetGetterResult(val: Double); overload; virtual; stdcall; abstract;
    procedure SetGetterResultAsRecord; virtual; stdcall; abstract;
    function GetGetterResultAsRecord: IRecord; virtual; stdcall; abstract;
  end;

  ISetterArgs = class (IEngineIntf)
    function GetEngine: TObject; virtual; stdcall; abstract;
    function GetDelphiObject: TObject; virtual; stdcall; abstract;
    function GetDelphiClasstype: Pointer; virtual; stdcall; abstract;
    function GetPropName: PAnsiChar; virtual; stdcall; abstract;
    function GetPropIndex: integer; virtual; stdcall; abstract;
    function GetValue: IValue; virtual; stdcall; abstract;

    function GetValueAsObject: TObject; overload; virtual; stdcall; abstract;
    function GetValueAsInt: integer; overload; virtual; stdcall; abstract;
    function GetValueAsBool: boolean; overload; virtual; stdcall; abstract;
    function GetValueAsString: PAnsiChar; overload; virtual; stdcall; abstract;
    function GetValueAsDouble: double; overload; virtual; stdcall; abstract;
  end;

  TMethodCallBack = procedure(args: IMethodArgs); stdcall;
  TGetterCallBack = procedure(args: IGetterArgs); stdcall;
  TSetterCallBack = procedure(args: ISetterArgs); stdcall;
  TErrorMsgCallBack = procedure(errMsg: PAnsiChar; eng: TObject); stdcall;

  IObjectProp = class(IEngineIntf)
    procedure SetRead(read: boolean); virtual; stdcall; abstract;
    procedure SetWrite(write: boolean); virtual; stdcall; abstract;
    procedure SetName(name: PAnsiChar); virtual; stdcall; abstract;
  end;

  IObjectTemplate = class (IEngineIntf)
    procedure SetMethod(methodName: PAnsiChar; MethodCall: Pointer); virtual; stdcall; abstract;
    procedure SetProp(propName: PAnsiChar; read, write: boolean); virtual; stdcall; abstract;
    procedure SetField(fieldNAme: PAnsiChar); virtual; stdcall; abstract;
    procedure SetHasIndexedProps(HAsIndexedProps: boolean); virtual; stdcall; abstract;
    procedure SetClasstype(classtype: PAnsiChar); virtual; stdcall; abstract;
    function GetClasstype: PAnsiChar; virtual; stdcall; abstract;
    procedure SetParent(parent: IObjectTemplate);  virtual; stdcall; abstract;
  end;

  IEngine = class(IEngineIntf)
    function AddGlobal(dClass: Pointer; dObject: TObject): IObjectTemplate; virtual; stdcall; abstract;
    function AddObject(classtype: PAnsiChar; dClass: Pointer): IObjectTemplate; virtual; stdcall; abstract;
    function GetObject(dClass: Pointer): IObjectTemplate; virtual; stdcall; abstract;
    function RunString(code, ExeName: PAnsiChar): PAnsiChar; virtual; stdcall; abstract;
    function RunFile(fileName, ExeName: PAnsiChar): PAnsiChar; virtual; stdcall; abstract;
    function RunIncludeFile(fileName: PAnsiChar): PAnsiChar; virtual; stdcall; abstract;
    function CallFunc(FuncName: PAnsiChar; args: IValuesArray): IValue; virtual; stdcall; abstract;
    procedure SetDebug(debug: boolean); virtual; stdcall; abstract;
    function ErrorCode: integer; virtual; stdcall; abstract;
    procedure SetMethodCallBack(callBack: TMethodCallBack); virtual; stdcall; abstract;
    procedure SetPropGetterCallBack(callBack: TGetterCallBack); virtual; stdcall; abstract;
    procedure SetPropSetterCallBack(callBack: TSetterCallBack); virtual; stdcall; abstract;
    procedure SetFieldGetterCallBack(callBack: TGetterCallBack); virtual; stdcall; abstract;
    procedure SetFieldSetterCallBack(callBack: TSetterCallBack); virtual; stdcall; abstract;
    procedure SetIndexedPropGetterCallBack(callBack: TGetterCallBack); virtual; stdcall; abstract;
    procedure SetIndexedPropSetterCallBack(callBack: TSetterCallBack); virtual; stdcall; abstract;
    procedure SetErrorMessageCallBack(callBack: TErrorMsgCallBack); virtual; stdcall; abstract;

    function NewArray(count: integer): IValuesArray; virtual; stdcall; abstract;
    function NewValue(val: integer): IValue; overload; virtual; stdcall; abstract;
    function NewValue(val: PAnsiChar): IValue; overload; virtual; stdcall; abstract;
    function NewValue(val: boolean): IValue; overload; virtual; stdcall; abstract;

  end;

  function InitEngine(DEngine: TObject): IEngine cdecl; external 'node.dll';

  procedure FinalizeNode(); cdecl; external 'node.dll';

  procedure SetExeName(name: PAnsiChar); cdecl; external 'node.dll';

implementation

initialization

finalization
    FinalizeNode;
end.
