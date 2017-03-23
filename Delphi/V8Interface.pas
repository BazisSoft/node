unit V8Interface;

interface

type

  IObject = class;
  IValuesArray = class;
  IRecord = class;
  IValue = class;

  IEngineIntf = class
    // do not call!
    // here because implementation needs virtual C++ destructor
    procedure _Destructor; virtual; abstract;
    procedure Delete; virtual; stdcall; abstract;
    function TestFun: Integer; virtual; stdcall; abstract;
  end;

  IBaseValue = class(IEngineIntf)
    function IsJSObject: boolean; virtual; stdcall; abstract;
    function IsJSArray: boolean; virtual; stdcall; abstract;
    function IsJSRecord: boolean; virtual; stdcall; abstract;
    function IsJSValue: boolean; virtual; stdcall; abstract;

    function AsJSObject: IObject; virtual; stdcall; abstract;
    function AsJSArray: IValuesArray; virtual; stdcall; abstract;
    function AsJSRecord: IRecord; virtual; stdcall; abstract;
    function AsJSValue: IValue; virtual; stdcall; abstract;
  end;

  IObject = class (IBaseValue)
    function IsDelphiObject: boolean; virtual; stdcall; abstract;
    function GetDelphiObject: TObject; virtual; stdcall; abstract;
    function GetDelphiClasstype: TClass; virtual; stdcall; abstract;
  end;

  IFunction = class (IEngineIntf)
    procedure AddArg(val: integer); overload; virtual; stdcall; abstract;
    procedure AddArg(val: boolean); overload; virtual; stdcall; abstract;
    procedure AddArg(val: PAnsiChar); overload; virtual; stdcall; abstract;
    procedure AddArg(val: double); overload; virtual; stdcall; abstract;
    procedure AddArg(val: Pointer; cType: Pointer); overload; virtual; stdcall; abstract;
    function CallFunction: IValue; virtual; stdcall; abstract;
  end;

  IValuesArray = class (IBaseValue)
    function GetCount: integer; virtual; stdcall; abstract;
    function GetValue(index: integer): IValue; virtual; stdcall; abstract;
    procedure SetValue(value: IBaseValue; index: integer); virtual; stdcall; abstract;
  end;

  IRecord = class(IBaseValue)
    procedure SetField(Name: PAnsiChar; val: integer); overload; virtual; stdcall; abstract;
    procedure SetField(Name: PAnsiChar; val: double); overload; virtual; stdcall; abstract;
    procedure SetField(Name: PAnsiChar; val: boolean); overload; virtual; stdcall; abstract;
    procedure SetField(Name: PAnsiChar; val: PAnsiChar); overload; virtual; stdcall; abstract;
    procedure SetField(Name: PAnsiChar; val: TObject); overload; virtual; stdcall; abstract;
    procedure SetField(Name: PAnsiChar; val: IBaseValue); overload; virtual; stdcall; abstract;

    function GetIntField(NAme: PAnsiChar): integer; virtual; stdcall; abstract;
    function GetDoubleField(NAme: PAnsiChar): double; virtual; stdcall; abstract;
    function GetBoolField(NAme: PAnsiChar): boolean; virtual; stdcall; abstract;
    function GetStringField(NAme: PAnsiChar): PAnsiChar; virtual; stdcall; abstract;
    function GetObjectField(NAme: PAnsiChar): TObject; virtual; stdcall; abstract;
  end;

  IValue = class (IBaseValue)
    function IsNumber: boolean; virtual; stdcall; abstract;
    function IsInt: boolean; virtual; stdcall; abstract;
    function IsBool: boolean; virtual; stdcall; abstract;
    function IsString: boolean; virtual; stdcall; abstract;
    function IsObject: boolean; virtual; stdcall; abstract;
    function IsArray: boolean; virtual; stdcall; abstract;
    function IsV8Function: boolean; virtual; stdcall; abstract;
    function IsUndefined: boolean; virtual; stdcall; abstract;


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
    function GetDelphiObject: Pointer; virtual; stdcall; abstract;
    function GetDelphiClasstype: Pointer; virtual; stdcall; abstract;
    function GetArgsCount: integer; virtual; stdcall; abstract;

    function GetMethodName: PAnsiChar; virtual; stdcall; abstract;

    procedure SetReturnValueUndefined; virtual; stdcall; abstract;
    procedure SetReturnValueIntf(p: Pointer); virtual; stdcall; abstract;
    procedure SetReturnValue(obj: Pointer; dClasstype: Pointer); overload; virtual; stdcall; abstract;
    procedure SetReturnValue(val: integer); overload; virtual; stdcall; abstract;
    procedure SetReturnValue(val: boolean); overload; virtual; stdcall; abstract;
    procedure SetReturnValue(val: PAnsiChar); overload; virtual; stdcall; abstract;
    procedure SetReturnValue(val: Double); overload; virtual; stdcall; abstract;
    procedure SetReturnValue(val: IBaseValue); overload; virtual; stdcall; abstract;

    function GetArg(index: integer): IValue; virtual; stdcall; abstract;
    function GetDelphiMethod: TObject; virtual; stdcall; abstract;

    procedure SetError(errorType: PAnsiChar); virtual; stdcall; abstract;
  end;

  IGetterArgs = class (IEngineIntf)
    function GetEngine: TObject; virtual; stdcall; abstract;
    function GetDelphiObject: Pointer; virtual; stdcall; abstract;
    function GetDelphiClasstype: Pointer; virtual; stdcall; abstract;
    function GetPropName: PAnsiChar; virtual; stdcall; abstract;
    function GetPropIndex: integer; virtual; stdcall; abstract;
    function GetPropIndexIValue: IValue; virtual; stdcall; abstract;

    procedure SetGetterResultUndefined; virtual; stdcall; abstract;
    procedure SetGetterResultIntf(p: Pointer); virtual; stdcall; abstract;
    procedure SetGetterResultAsIntfFunction(intf: Pointer; funcName: PAnsiChar); virtual; stdcall; abstract;
    procedure SetGetterResult(obj: Pointer; dClasstype: Pointer); overload; virtual; stdcall; abstract;
    procedure SetGetterResult(val: integer); overload; virtual; stdcall; abstract;
    procedure SetGetterResult(val: boolean); overload; virtual; stdcall; abstract;
    procedure SetGetterResult(val: PAnsiChar); overload; virtual; stdcall; abstract;
    procedure SetGetterResult(val: Double); overload; virtual; stdcall; abstract;
    procedure SetGetterResultAsIndexObject(ParentObj: TObject; RttiProp: TObject); virtual; stdcall; abstract;
    procedure SetGetterResult(val: IBaseValue); overload; virtual; stdcall; abstract;

    procedure SetError(errorType: PAnsiChar); virtual; stdcall; abstract;
  end;

  ISetterArgs = class (IEngineIntf)
    function GetEngine: TObject; virtual; stdcall; abstract;
    function GetDelphiObject: TObject; virtual; stdcall; abstract;
    function GetDelphiClasstype: Pointer; virtual; stdcall; abstract;
    function GetPropName: PAnsiChar; virtual; stdcall; abstract;
    function GetPropIndex: integer; virtual; stdcall; abstract;
    function GetPropIndexIValue: IValue; virtual; stdcall; abstract;
    function GetValue: IValue; virtual; stdcall; abstract;

    function GetValueAsObject: TObject; overload; virtual; stdcall; abstract;
    function GetValueAsInt: integer; overload; virtual; stdcall; abstract;
    function GetValueAsBool: boolean; overload; virtual; stdcall; abstract;
    function GetValueAsString: PAnsiChar; overload; virtual; stdcall; abstract;
    function GetValueAsDouble: double; overload; virtual; stdcall; abstract;

    procedure SetResultUndefined; virtual; stdcall; abstract;
    procedure SetResultIntf(p: Pointer); virtual; stdcall; abstract;
    procedure SetResultAsIntfFunction(intf: Pointer; funcName: PAnsiChar); virtual; stdcall; abstract;
    procedure SetResult(obj: Pointer; dClasstype: Pointer); overload; virtual; stdcall; abstract;
    procedure SetResult(val: integer); overload; virtual; stdcall; abstract;
    procedure SetResult(val: boolean); overload; virtual; stdcall; abstract;
    procedure SetResult(val: PAnsiChar); overload; virtual; stdcall; abstract;
    procedure SetResult(val: Double); overload; virtual; stdcall; abstract;
    procedure SetResultAsIndexObject(ParentObj: TObject; RttiProp: TObject); virtual; stdcall; abstract;
    procedure SetResult(val: IBaseValue); overload; virtual; stdcall; abstract;

    procedure SetError(errorType: PAnsiChar); virtual; stdcall; abstract;
  end;

  IIntfSetterArgs = class (IEngineIntf)
    function GetEngine: TObject; virtual; stdcall; abstract;
    function GetDelphiObject: Pointer; virtual; stdcall; abstract;
    function GetPropName: PAnsiChar; virtual; stdcall; abstract;
    function GetValue: IValue; virtual; stdcall; abstract;

    function GetValueAsObject: TObject; overload; virtual; stdcall; abstract;
    function GetValueAsInt: integer; overload; virtual; stdcall; abstract;
    function GetValueAsBool: boolean; overload; virtual; stdcall; abstract;
    function GetValueAsString: PAnsiChar; overload; virtual; stdcall; abstract;
    function GetValueAsDouble: double; overload; virtual; stdcall; abstract;

    procedure SetError(errorType: PAnsiChar); virtual; stdcall; abstract;
  end;

  TMethodCallBack = procedure(args: IMethodArgs); stdcall;
  TGetterCallBack = procedure(args: IGetterArgs); stdcall;
  TSetterCallBack = procedure(args: ISetterArgs); stdcall;
  TIntfSetterCallBack = procedure(args: IIntfSetterArgs); stdcall;
  TErrorMsgCallBack = procedure(errMsg: PAnsiChar; eng: TObject); stdcall;

  IObjectProp = class(IEngineIntf)
    procedure SetRead(read: boolean); virtual; stdcall; abstract;
    procedure SetWrite(write: boolean); virtual; stdcall; abstract;
    procedure SetName(name: PAnsiChar); virtual; stdcall; abstract;
  end;

  IObjectTemplate = class (IEngineIntf)
    procedure SetMethod(methodName: PAnsiChar; MethodCall: Pointer); virtual; stdcall; abstract;
    procedure SetProp(propName: PAnsiChar; propObj: Pointer; read, write: boolean); virtual; stdcall; abstract;
    procedure SetIndexedProp(propName: PAnsiChar; propObj: Pointer; read, write: boolean); virtual; stdcall; abstract;
    procedure SetField(fieldNAme: PAnsiChar); virtual; stdcall; abstract;
    procedure SetEnumField(fieldName: PAnsiChar; fieldValue: Integer); virtual; stdcall; abstract;
    procedure SetHasIndexedProps(HAsIndexedProps: boolean); virtual; stdcall; abstract;
    procedure SetParent(parent: IObjectTemplate);  virtual; stdcall; abstract;
  end;

  IEngine = class(IEngineIntf)
    function AddGlobal(dClass: Pointer; dObject: TObject): IObjectTemplate; virtual; stdcall; abstract;
    function AddObject(classtype: PAnsiChar; dObject: Pointer): IObjectTemplate; virtual; stdcall; abstract;
    function GetObject(dClass: Pointer): IObjectTemplate; virtual; stdcall; abstract;
    function ClassIsRegistered(dClass: Pointer): boolean; virtual; stdcall; abstract;

    function RunString(code, ScriptName, ScriptPath, AdditionalParams: PAnsiChar): IValue; virtual; stdcall; abstract;
    function RunFile(fileName, ExeName, AdditionalParams: PAnsiChar): PAnsiChar; virtual; stdcall; abstract;
    function RunIncludeFile(fileName: PAnsiChar): PAnsiChar; virtual; stdcall; abstract;
    function RunIncludeCode(code: PAnsiChar): PAnsiChar; virtual; stdcall; abstract;
    procedure AddIncludeCode(code: PAnsiChar); virtual; stdcall; abstract;
    function CallFunc(FuncName: PAnsiChar; args: IValuesArray): IValue; virtual; stdcall; abstract;
    procedure SetInactive; virtual; stdcall; abstract;

    procedure SetDebug(debug: boolean; arg: PAnsiChar); virtual; stdcall; abstract;
    function ErrorCode: integer; virtual; stdcall; abstract;

    procedure SetMethodCallBack(callBack: TMethodCallBack); virtual; stdcall; abstract;
    procedure SetPropGetterCallBack(callBack: TGetterCallBack); virtual; stdcall; abstract;
    procedure SetPropSetterCallBack(callBack: TSetterCallBack); virtual; stdcall; abstract;
    procedure SetFieldGetterCallBack(callBack: TGetterCallBack); virtual; stdcall; abstract;
    procedure SetFieldSetterCallBack(callBack: TSetterCallBack); virtual; stdcall; abstract;
    procedure SetIndexedPropGetterObjCallBack(callBack: TGetterCallBack); virtual; stdcall; abstract;
    procedure SetIndexedPropGetterCallBack(callBack: TGetterCallBack); virtual; stdcall; abstract;
    procedure SetIndexedPropSetterCallBack(callBack: TSetterCallBack); virtual; stdcall; abstract;
    procedure SetNamedPropGetterCallBack(callBack: TGetterCallBack); virtual; stdcall; abstract;
    procedure SetNamedPropSetterCallBack(callBack: TSetterCallBack); virtual; stdcall; abstract;
    procedure SetInterfaceGetterCallBack(callBack: TGetterCallBack); virtual; stdcall; abstract;
    procedure SetInterfaceSetterCallBack(callBack: TIntfSetterCallBack); virtual; stdcall; abstract;
    procedure SetInterfaceMethodCallBack(callBack: TMethodCallBack); virtual; stdcall; abstract;
    procedure SetErrorMessageCallBack(callBack: TErrorMsgCallBack); virtual; stdcall; abstract;

    function NewArray(count: integer): IValuesArray; virtual; stdcall; abstract;
    function NewValue(val: integer): IValue; overload; virtual; stdcall; abstract;
    function NewValue(val: double): IValue; overload; virtual; stdcall; abstract;
    function NewValue(val: PAnsiChar): IValue; overload; virtual; stdcall; abstract;
    function NewValue(val: boolean): IValue; overload; virtual; stdcall; abstract;
    function NewRecord: IRecord; virtual; stdcall; abstract;
    function NewObject(obj: Pointer; dClasstype: Pointer): IObject; virtual; stdcall; abstract;
    function NewInterfaceObject(p: Pointer): IValue; virtual; stdcall; abstract;

  end;

  function GetMajorVersion: Integer cdecl; external 'node.dll' delayed;
  function GetMinorVersion: Integer cdecl; external 'node.dll' delayed;

  function InitEngine(DEngine: TObject): IEngine cdecl; external 'node.dll' delayed;

  function InitGlobalEngine(DEngine: TObject): IEngine cdecl; external 'node.dll' delayed;

  procedure InitializeNode(); cdecl; external 'node.dll' delayed;
  procedure FinalizeNode(); cdecl; external 'node.dll' delayed;

implementation
end.
