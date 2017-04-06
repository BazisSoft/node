unit V8Engine;


interface

uses Classes, TypInfo, V8API, RTTI, types, Generics.Collections, SysUtils,
  Windows, syncObjs, IOUtils, Contnrs, ObjComAuto, ActiveX, Variants,
  V8Interface, ScriptInterface, VCl.Forms, Messages;

const
  systemFieldName = 'system';

type

  TJSEngine = class;

  TObjects = class(TObjectList<TObject>)
  public
    procedure AddObject(obj: TObject);
  end;

  TJSSystemNamespace = class
  private
    FEngine: TJSEngine;
  public
    constructor Create(AEngine: TJSEngine);
    procedure include(const filename: string);
    procedure log(const text: string);

    class function CodeScriptSource(const Source: string;
      const Password: AnsiString): string;
  end;

  TJSExtenderMap = TDictionary<TClass, TJSClassExtender>;

  TRttiMethodInfo = record
    Method: TRttiMethod;
    Helper: TJSClassExtender;
  end;

  TRttiMethodList = TList<TRttiMethodInfo>;

  TMethodOverloadMap = class(TObject)
  public
    MethodInfo: TRttiMethodInfo;
    OverloadsInfo: TRttiMethodList;
    destructor Destroy; override;
  end;
  TMethodMap = TObjectDictionary<string, TMethodOverloadMap>;
  TPropInfo = class(TObject)
  public
    prop: TRttiProperty;
    propObj: TJSClassExtender;
  end;
  TPropMap = TObjectDictionary<string, TPropInfo>;
  TFieldMap = TDictionary<string, TRttiField>;
  TIndexedPropMap = TDictionary<string, TRttiIndexedProperty>;

  TJSIndexedPropWrapper = class
    Obj: TObject;
    PropName: string;
  end;

  TJSClass = class
  private
    FMethods: TMethodMap;
    FProps: TPropMap;
    FFields: TFieldMap;
    FIndexedProps: TIndexedPropMap;
    FDefaultIndexedProp: TRttiIndexedProperty;
    FClasstype: TClass;
    Ftype: TRttiType;
    FInitialized: boolean;
    procedure SetInitialized(const Value: boolean);
  public
    constructor Create(classType: TClass); reintroduce;
    destructor Destroy; override;
    procedure AddHelper(helper: TJSClassExtender);
    property Methods: TMethodMap Read FMethods;
    property Fields: TFieldMap read FFields;
    property Props: TPropMap read FProps;
    property IndexedProps: TIndexedPropMap read FIndexedProps;
    property cType: TClass read FClasstype;
    property Initialized: boolean read FInitialized write SetInitialized;
  end;

  TClassMap = TDictionary<TClass, TJSClass>;

  TJSEngine = class
  private
    FLog: TStrings;
    FClasses: TClassMap;
    FClassList: TObjectList;
    FGlobal: TObject;
    FEngine: IEngine;
    FGarbageCollector: TObjects;
    FDispatchList: IInterfaceList;
    FJSHelpers: TJSExtenderMap;
    FJSHelpersList: TObjectList;
    FScriptName: string;
    //i think, it should using only for running script via PostMessage
    FAppPath: string;
    FDebug: boolean;
    FIgnoredExceptions: TList<TClass>;
    FGlobalTemplate: IObjectTemplate;
    FEnumList: TList<PTypeInfo>;
    FDebugPort: string;
    FNodeEngineCreated, FInactive: boolean;
    FAdParams: string;
    FVars: TDictionary<string, TValue>;
    FInitError: string;

    const NODE_AVAILABLE_VER = 0;

    procedure AddEnumToGlobal(Enum: TRttiType; global: IObjectTemplate);
    class procedure callMethod(args:IMethodArgs); static; stdcall;
    class procedure callPropGetter(args: IGetterArgs); static; stdcall;
    class procedure callPropSetter(args: ISetterArgs); static; stdcall;
    class procedure callFieldGetter(args: IGetterArgs); static; stdcall;
    class procedure callFieldSetter(args: ISetterArgs); static; stdcall;
    // get object by name (e.g 'Objects' in 'Model.Objects[i]')
    class procedure callIndexedObjGetter(args: IGetterArgs); static; stdcall;
    //get object by index (e.g. 'Objects[i]' in 'Model.Objects[i]')
    class procedure callIndexedPropNumberGetter(args: IGetterArgs); static; stdcall;
    class procedure callIndexedPropNumberSetter(args: ISetterArgs); static; stdcall;
    //get object by index name(e.g. 'Objects[ObjectName]' in 'Model.Objects[ObjectName]')
    class procedure callNamedPropNumberGetter(args: IGetterArgs); static; stdcall;
    class procedure callNamedPropNumberSetter(args: ISetterArgs); static; stdcall;
    class procedure callIntfGetter(args: IGetterArgs); static; stdcall;
    class procedure callIntfSetter(args: IIntfSetterArgs); static; stdcall;
    class procedure callIntfMethod(args: IMethodArgs); static; stdcall;
    class procedure SendErrToLog(errMsg: PAnsiChar; eng: TObject); static; stdcall;
    class function GetMethodInfo(List: TRttiMethodList; args: IMethodArgs): TRttiMethodInfo;
    function CallFunction(name: string; Args: IValuesArray): IValue; overload;

    procedure SetClassIntoContext(cl: TJSClass);

    procedure SetDebug(const Value: boolean);
    procedure SetDebugPort(const Value: string);
    procedure SetAdParams(const Value: string);

    function NodeLibAvailable: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure IgnoreException(E: TClass);
    function AddClass(cType: TClass): TJSClass;
    function AddGlobal(global: TObject): TJSClass;
    procedure RegisterHelper(CType: TClass; HelperType: TJSExtClass);
    procedure DeclareVar(const Name: string; Variable: TValue);

    function CallFunction(const Name: string; Args: array of TValue): TValue; overload;
    function CallFunction(const Name: string; Args: array of Variant): Variant; overload;
    function CallFunction(const Name: string): Variant; overload;

    property ScriptLog: TStrings read FLog;
    procedure SetLog(const Value: TStrings);

    property Debug: boolean read FDebug write SetDebug;
    property DebugPort: string read FDebugPort write SetDebugPort;
    property AdParams: string read FAdParams write SetAdParams;
    property InitError: string read FInitError;
    function RunScript(code, scriptName: string): TValue;
    function RunIncludeCode(code: string): string;
    function RunFile(fileName, scriptPath: string): string;
    function RunIncludeFile(FileName: string): string;
    procedure AddIncludeCode(code: UTF8String);
    procedure TryFinishScript;
    class function GetMajor: Integer;
    class function GetFullVersion: string;
  end;


implementation

uses PSApi, Math, DateUtils, RegularExpressions;

const
  NilMethod: TMethod = (Code: nil; data: nil);

var
  RttiContext: TRttiContext;

{ TJSSystemNamespace }

class function TJSSystemNamespace.CodeScriptSource(const Source: string;
  const Password: AnsiString): string;
begin
//var
//  Doc: TXBSDoc;
//  UTFStr: UTF8String;
//begin
//  Doc := TXBSDoc.Create;
//  try
//    Doc.WriteString('Source', Source);
//    Doc.Password := Password;
//    Doc.Compress := True;
//    UTFStr := EncodeBase64(RawByteString(Doc.DataString));
//    Result := 'system.secureExec("' +
//      string(sdAddControlChars(UTFStr, '" + '#13#10'    "', 40) + '");');
//  finally
//    Doc.Free;
//  end;
end;

constructor TJSSystemNamespace.Create(AEngine: TJSEngine);
begin
  FEngine := AEngine;
end;

procedure TJSSystemNamespace.include(const filename: string);
begin
  FEngine.RunIncludeFile(filename);
end;

procedure TJSSystemNamespace.log(const text: string);
begin
  FEngine.ScriptLog.Add(text);
end;

{ TJSEngine }

function TJSEngine.AddClass(cType: TClass): TJSClass;
var
  JsClass: TJSClass;
  helper: TJSClassExtender;
begin
  Result := nil;
  if (cType = FGlobal.ClassType) or (cType = TObject) then
    Exit;
  if not FClasses.TryGetValue(cType, JsClass) then
  begin
    if FClasses.ContainsKey(ctype) then
      raise EScriptEngineException.Create('Engine already have class being added');
    JsClass := TJSClass.Create(cType);
    if FJSHelpers.TryGetValue(cType, helper) then
      JsClass.AddHelper(helper);
    FClasses.Add(cType, JsClass);
    SetClassIntoContext(JsClass);
    FClassList.Add(JsClass);
  end;
  Result := JsClass;
end;

procedure TJSEngine.IgnoreException(E: TClass);
begin
  FIgnoredExceptions.Add(E);
end;

function TJSEngine.NodeLibAvailable: Boolean;
begin
  Result := NODE_AVAILABLE_VER = GetMajorVersion;
end;

procedure TJSEngine.AddEnumToGlobal(Enum: TRttiType; global: IObjectTemplate);
var
  i, enumNum: integer;
  typInfo: PTypeInfo;
  EnumName: string;
begin
  typInfo := Enum.Handle;
  if FEnumList.IndexOf(typInfo) < 0 then
  begin
    i := 0;
    EnumName := '';
    // TODO: find better way
    while true do
    begin
      EnumName := GetEnumName(typInfo, i);
      enumNum := GetEnumValue(typInfo, EnumName);
      if enumNum <> i then
        break;
      global.SetEnumField(PAnsiChar(UTF8String(EnumName)), i);
      inc(i);
    end;
    FEnumList.Add(typInfo);
  end;
end;

function TJSEngine.AddGlobal(global: TObject): TJSClass;
var
  Overloads: TPair<string, TMethodOverloadMap>;
  Name: PAnsiChar;
  Methods: TMethodOverloadMap;
  cType: TClass;
  ClassTemplate: TJSClass;
  methodInfo: TRttiMethodInfo;
  method: TRttiMethod;
  propPair: TPair<string, TPropInfo>;
  prop: TRttiProperty;
  ReturnClass: TClass;
  i: Integer;
begin
  Assert(FGlobalTemplate = nil);
  cType := global.ClassType;
  FGlobal := global;
  ClassTemplate := TJSClass.Create(cType);
  FGlobalTemplate := FEngine.AddGlobal(cType, global);
  for Overloads in ClassTemplate.Methods do
  begin
    Name := PAnsiChar(UTF8String(Overloads.Key));
    Methods := Overloads.Value;
    if Assigned(Methods.MethodInfo.Method) then
    begin
      methodInfo := Methods.MethodInfo;
      method := methodInfo.Method;
      if Assigned(method.ReturnType) and (method.ReturnType.TypeKind = tkClass) then
      begin
        ReturnClass := method.ReturnType.Handle.TypeData.ClassType;
        AddClass(ReturnClass);
      end;
    end
    else if Assigned(Methods.OverloadsInfo) then
      for i := 0 to Methods.OverloadsInfo.Count - 1 do
      begin
        methodInfo := methods.OverloadsInfo[i];
        method := methodInfo.Method;
        if Assigned(method.ReturnType) and (method.ReturnType.TypeKind = tkClass) then
        begin
          ReturnClass := method.ReturnType.Handle.TypeData.ClassType;
          AddClass(ReturnClass);
        end;
      end;
    FGlobalTemplate.SetMethod(Name, Methods);
  end;
  for propPair in ClassTemplate.FProps do
  begin
    prop := propPair.Value.prop;
    if Assigned(prop.PropertyType) and (prop.PropertyType.TypeKind = tkClass) then
    begin
      ReturnClass := prop.PropertyType.Handle.TypeData.ClassType;
      AddClass(ReturnClass);
    end;
    FGlobalTemplate.SetProp(PAnsiChar(UTF8String(prop.Name)),
      propPair.Value.propObj, prop.IsReadable, prop.IsWritable);
  end;
  //here setting enumerators to global object;

  Result := ClassTemplate;
  FClasses.Add(cType, ClassTemplate);
  FClassList.Add(ClassTemplate);
end;

procedure TJSEngine.RegisterHelper(CType: TClass; HelperType: TJSExtClass);
var
  HelperObj: TJSClassExtender;
  objind: integer;
begin
  if not FJSHelpers.ContainsKey(CType) then
  begin
    objind := FJSHelpersList.FindInstanceOf(HelperType);
    if objind < 0 then
    begin
      HelperObj := HelperType.Create;
      FJSHelpersList.Add(HelperObj);
    end
    else
      HelperObj := TJSClassExtender(FJSHelpersList[objind]);
    FJSHelpers.Add(CType, HelperObj);
  end;
end;

class procedure TJSEngine.callFieldGetter(args: IGetterArgs);
var
  Eng: TJSEngine;
  ClassDescr: TJSClass;
  Field: TRttiField;
  Result: TValue;
  cl: TClass;
  obj: TObject;
begin
  //invoke right method of right object;
  cl := TClass(args.GetDelphiClasstype);
  if not Assigned(cl) then
    Exit;
  Eng := TJSEngine(args.GetEngine);
  if Assigned(Eng) then
    try
      ClassDescr := Eng.FClasses.Items[cl];
      Field := ClassDescr.FFields.Items[PUtf8CharToString(args.GetPropName)];
      if cl = Eng.FGlobal.ClassType then
        obj := Eng.FGlobal
      else
        obj := args.GetDelphiObject;
      Result := Field.GetValue(obj);
      args.SetGetterResult(TValueToJSValue(Result, Eng.FEngine, Eng.FDispatchList));
    except
      on E: EVariantTypeCastError do
      begin
        args.SetGetterResultUndefined;
        Exit;
      end;
      on E:Exception do
      begin
        if Assigned(eng.FLog) then
        begin
          if Eng.FIgnoredExceptions.IndexOf(e.ClassType) < 0 then
          begin
            eng.FLog.Add('Uncaught exception: ' + E.Message);
            args.SetError(PAnsiChar(UTF8String('Uncaught exception: ' + E.Message)));
          end
          {$ifdef DEBUG}
          else
            eng.FLog.Add('--' + E.Message);
          {$endif}
        end;
      end;
    end;
end;

class procedure TJSEngine.callFieldSetter(args: ISetterArgs);
var
  ClassDescr: TJSClass;
  Field: TRttiField;
  ResultValue: TValue;
  cl: TClass;
  obj: TObject;
  Eng: TJSEngine;
begin
  cl := TClass(args.GetDelphiClasstype);
  if not Assigned(cl) then
    Exit;
  Eng := TJSEngine(args.GetEngine);
  if Assigned(Eng) then
    try
      ClassDescr := Eng.FClasses.Items[cl];
      Field := ClassDescr.FFields.Items[PUtf8CharToString(args.GetPropName)];
      if cl = Eng.FGlobal.ClassType then
        obj := Eng.FGlobal
      else
        obj := args.GetDelphiObject;
      ResultValue := JsValToTValue(args.GetValue, Field.FieldType);
      Field.SetValue(obj, ResultValue);
      args.SetResult(TValueToJSValue(ResultValue, Eng.FEngine, Eng.FDispatchList));
    except
      on E: EVariantTypeCastError do
        Exit;
      on E:Exception do
      begin
        if Assigned(eng.FLog) then
        begin
          if Eng.FIgnoredExceptions.IndexOf(e.ClassType) < 0 then
          begin
            eng.FLog.Add('Uncaught exception: ' + E.Message);
            args.SetError(PAnsiChar(UTF8String('Uncaught exception: ' + E.Message)));
          end
          {$ifdef DEBUG}
          else
            eng.FLog.Add('--' + E.Message);
          {$endif}
        end;
      end;
    end;
end;

function TJSEngine.CallFunction(const Name: string; Args: array of Variant): Variant;
var
  JsArgs: IValuesArray;
  count, i: integer;
begin
  Result := '';
  if not FInactive then
  begin
    count := Length(Args);
    JsArgs := FEngine.NewArray(count);
    if not Assigned(JsArgs) then
      raise EScriptEngineException.Create('Can not create an array to call a function');
    for i := 0 to count - 1 do
    begin
      JsArgs.SetValue(
        TValueToJSValue(Tvalue.FromVariant(Args[i]), FEngine, FDispatchList), i);
    end;
    Result := JsValToTValue(CallFunction(name, JsArgs)).AsVariant;
  end;
end;

function TJSEngine.CallFunction(const Name: string; Args: array of TValue): TValue;
var
  JsArgs: IValuesArray;
  count, i: integer;
  resValue: IValue;
begin
  Result := Tvalue.Empty;
  if not FInactive then
  begin
    count := Length(Args);
    JsArgs := FEngine.NewArray(count);
    if not Assigned(JsArgs) then
      raise EScriptEngineException.Create('Can not create an array to call a function');
    for i := 0 to count - 1 do
    begin
      JsArgs.SetValue(TValueToJSValue(Args[i], FEngine, FDispatchList), i);
    end;
    resValue := CallFunction(name, JsArgs);
    Result := JsValToTValue(resValue);
  end;
end;

function TJSEngine.CallFunction(name: string; Args: IValuesArray): IValue;
var
  Utf8Name: UTF8String;
begin
  Result := nil;
  if not FInactive then
  begin
    Utf8Name := UTF8String(name);
    try
      Result := FEngine.CallFunc(PAnsiChar(Utf8Name), Args);
    except
      on E:Exception do
      begin
        if Assigned(FLog) then
        begin
          if FIgnoredExceptions.IndexOf(e.ClassType) < 0 then
            FLog.Add('Uncaught exception: ' + E.Message)
          {$ifdef DEBUG}
          else
            FLog.Add('--' + E.Message);
          {$endif}
        end;
        Result := nil;
      end;
    end;
  end;
end;

class procedure TJSEngine.callIndexedObjGetter(args: IGetterArgs);
var
  ClassDescr: TJSClass;
  Prop: TRttiIndexedProperty;
  PropName: string;
  cl: TClass;
  obj: TObject;
  Eng: TJSEngine;
begin
  cl := TClass(args.GetDelphiClasstype);
  if not Assigned(cl) then
    Exit;
  Eng := TJSEngine(args.GetEngine);
  if Assigned(Eng) then
    try
      ClassDescr := Eng.FClasses.Items[cl];
      PropName := PUtf8CharToString(args.GetPropName);
      if cl = Eng.FGlobal.ClassType then
        obj := Eng.FGlobal
      else
        obj := args.GetDelphiObject;
      Prop := ClassDescr.IndexedProps.Items[PropName];
      //prop pointer will be writed in classtype slot;
      args.SetGetterResultAsIndexObject(obj, Prop);
    except
      on E:Exception do
      begin
        if Assigned(eng.FLog) then
        begin
          if Eng.FIgnoredExceptions.IndexOf(e.ClassType) < 0 then
          begin
            eng.FLog.Add('Uncaught exception: ' + E.Message);
            args.SetError(PAnsiChar(UTF8String('Uncaught exception: ' + E.Message)));
          end
          {$ifdef DEBUG}
          else
            eng.FLog.Add('--' + E.Message);
          {$endif}
        end;
      end;
    end;
end;

class procedure TJSEngine.callIndexedPropNumberGetter(args: IGetterArgs);
var
  Eng: TJSEngine;
  ClassDescr: TJSClass;
  ClassTypeSlotItem: TObject;
  Prop: TRttiIndexedProperty;
  Result: TValue;
  cl: TClass;
  obj: TObject;
begin
  Eng := TJSEngine(args.GetEngine);
  obj := nil;
  Prop := nil;
  cl := nil;
  if Assigned(Eng) then
    try
      ClassTypeSlotItem := TObject(args.GetDelphiClasstype);
      if ClassTypeSlotItem is TClass then
        cl := TClass(ClassTypeSlotItem);
      if not Assigned(ClassTypeSlotItem) then
        raise EScriptEngineException.Create('There is no object in classtype slot');
      if ClassTypeSlotItem.ClassType = TRttiIndexedProperty then
      begin
        //prop pointer was writed in classtype slot;
        Prop := TRttiIndexedProperty(ClassTypeSlotItem);
        obj := args.GetDelphiObject;
      end
      else if Assigned(cl) then
      begin
        ClassDescr := Eng.FClasses.Items[cl];
        Prop := ClassDescr.FDefaultIndexedProp;
        if cl = Eng.FGlobal.ClassType then
          obj := Eng.FGlobal
        else
          obj := args.GetDelphiObject;
      end;
      if Assigned(Prop) and Assigned(obj) then
        Result := Prop.GetValue(obj, [args.GetPropIndex]);
      args.SetGetterResult(
        TValueToJSValue(Result, Eng.FEngine, Eng.FDispatchList));
    except
      on E: EVariantTypeCastError do
      begin
        args.SetGetterResultUndefined;
        Exit;
      end;
      on E: EArgumentOutOfRangeException do
        args.SetError('Argumrent out of range');
      on E:Exception do
      begin
        if Assigned(eng.FLog) then
        begin
          if Eng.FIgnoredExceptions.IndexOf(e.ClassType) < 0 then
          begin
            eng.FLog.Add('Uncaught exception: ' + E.Message);
            args.SetError(PAnsiChar(UTF8String('Uncaught exception: ' + E.Message)));
          end
          {$ifdef DEBUG}
          else
            eng.FLog.Add('--' + E.Message);
          {$endif}
        end;
      end;
    end;
end;

class procedure TJSEngine.callIndexedPropNumberSetter(args: ISetterArgs);
var
  Prop: TRttiIndexedProperty;
  obj: TObject;
  Eng: TJSEngine;
begin
  Eng := TJSEngine(args.GetEngine);
  if Assigned(Eng) then
    try
      //prop pointer will be writed in classtype slot;
      Prop := TRttiIndexedProperty(args.GetDelphiClasstype);
      if not Prop.IsWritable then
        Exit;
      obj := args.GetDelphiObject;
      Prop.SetValue(obj, [args.GetPropIndex], JsValToTValue(args.GetValue, Prop.PropertyType));
    except
      on E: EVariantTypeCastError do
      begin
        Exit;
      end;
      on E: EArgumentOutOfRangeException do
        args.SetError('Argumrent out of range');
      on E:Exception do
      begin
        if Assigned(eng.FLog) then
        begin
          if Eng.FIgnoredExceptions.IndexOf(e.ClassType) < 0 then
          begin
            eng.FLog.Add('Uncaught exception: ' + E.Message);
            args.SetError(PAnsiChar(UTF8String('Uncaught exception: ' + E.Message)));
          end
          {$ifdef DEBUG}
          else
            eng.FLog.Add('--' + E.Message);
          {$endif}
        end;
      end;
    end;
end;

class procedure TJSEngine.callIntfGetter(args: IGetterArgs);
var
  Eng: TJSEngine;
  Intf: IDispatch;
  Result: TValue;
  PropName: string;
  isProperty: boolean;
begin
  Intf := IDispatch(args.GetDelphiObject);
  Eng := TJSEngine(args.GetEngine);
  if Assigned(Eng) then
    try
      PropName := PUtf8CharToString(args.GetPropName);
      Result := ExecuteOnDispatchMultiParamProp(Intf, PropName, Tvalue.Empty, isProperty);
      if isProperty then
      begin
        args.SetGetterResult(TValueToJSValue(Result, Eng.FEngine, Eng.FDispatchList));
      end
      else
      begin
        args.SetGetterResultAsIntfFunction(Pointer(Intf), PAnsiChar(UTF8String(PropName)));
      end;
    except
      on E: EVariantTypeCastError do
      begin
        args.SetGetterResultUndefined;
        Exit;
      end;
      on E:Exception do
      begin
        if Assigned(eng.FLog) then
        begin
          if Eng.FIgnoredExceptions.IndexOf(e.ClassType) < 0 then
          begin
            eng.FLog.Add('Uncaught exception: ' + E.Message);
            args.SetError(PAnsiChar(UTF8String('Uncaught exception: ' + E.Message)));
          end
          {$ifdef DEBUG}
          else
            eng.FLog.Add('--' + E.Message);
          {$endif}
        end;
      end;
    end;
end;

class procedure TJSEngine.callIntfMethod(args: IMethodArgs);
var
  Eng: TJSEngine;

  procedure SetArgs(var Valueargs: array of TValue);
  var
    i:integer;
    argsCount: integer;
  begin
    argsCount := Length(Valueargs);
    for i := 0 to argsCount - 1 do
    begin
      Valueargs[i] := JsValToTValue(args.GetArg(i));
    end;
  end;

var
  Intf: IDispatch;
  Result: TValue;
  MethodName: string;
  ValueArgs: Array of TValue;
begin
  Intf := IDispatch(args.GetDelphiObject);
  Eng := TJSEngine(args.GetEngine);
  Result := TValue.Empty;
  if Assigned(Eng) then
    try
      MethodName := PUtf8CharToString(args.GetMethodName);
      SetLength(ValueArgs, args.GetArgsCount);
      SetArgs(ValueArgs);
      Result := ExecuteOnDispatchMultiParamFunc(Intf, MethodName, ValueArgs);
      args.SetReturnValue(TValueToJSValue(Result, Eng.FEngine, Eng.FDispatchList));
    except
      on E:Exception do
      begin
        if Assigned(eng.FLog) then
        begin
          if Eng.FIgnoredExceptions.IndexOf(e.ClassType) < 0 then
          begin
            eng.FLog.Add('Uncaught exception: ' + E.Message);
            args.SetError(PAnsiChar(UTF8String('Uncaught exception: ' + E.Message)));
          end
          {$ifdef DEBUG}
          else
            eng.FLog.Add('--' + E.Message);
          {$endif}
        end;
      end;
    end;
end;

class procedure TJSEngine.callIntfSetter(args: IIntfSetterArgs);
var
  Prop: string;
  Intf: IDispatch;
  Eng: TJSEngine;
  isProperty: boolean;
  Value: TValue;
begin
  Intf := IDispatch(args.GetDelphiObject);
  prop := PUtf8CharToString(args.GetPropName);
  Value := JsValToTValue(args.GetValue);
  Eng := TJSEngine(args.GetEngine);
  if Assigned(Eng) then
    try
      ExecuteOnDispatchMultiParamProp(Intf, prop, Value, isProperty);
    except
      on E:Exception do
      begin
        if Assigned(eng.FLog) then
        begin
          if Eng.FIgnoredExceptions.IndexOf(e.ClassType) < 0 then
          begin
            eng.FLog.Add('Uncaught exception: ' + E.Message);
            args.SetError(PAnsiChar(UTF8String('Uncaught exception: ' + E.Message)));
          end
          {$ifdef DEBUG}
          else
            eng.FLog.Add('--' + E.Message);
          {$endif}
        end;
      end;
    end;
end;

class procedure TJSEngine.callPropGetter(args: IGetterArgs);
var
  Eng: TJSEngine;
  ClassDescr: TJSClass;
  Result: TValue;
  cl: TClass;
  obj: TObject;
  Helper: TJSClassExtender;
  PropInfo: TPropInfo;
  FoundVar: boolean;
begin
  //invoke right method of right object;
  cl := TClass(args.GetDelphiClasstype);
  if not Assigned(cl) then
    Exit;
  Eng := TJSEngine(args.GetEngine);
  if Assigned(Eng) then
    try
      ClassDescr := Eng.FClasses.Items[cl];
      FoundVar := False;
      if cl = Eng.FGlobal.ClassType then
      begin
        if Eng.FVars.TryGetValue(PUtf8CharToString(args.GetPropName), Result) then
          FoundVar := True;
        obj := Eng.FGlobal
      end
      else
      begin
        obj := args.GetDelphiObject;
      end;
      if not FoundVar then
      begin
        PropInfo := ClassDescr.FProps.Items[PUtf8CharToString(args.GetPropName)];
        helper := PropInfo.propObj;
        if Assigned(Helper) then
        begin
          helper.Source := obj;
          Result := PropInfo.prop.GetValue(helper);
          Helper.Source := nil;
        end
        else
          Result := PropInfo.prop.GetValue(obj);
      end;
      args.SetGetterResult(TValueToJSValue(Result, Eng.FEngine, Eng.FDispatchList));
    except
      on E: EVariantTypeCastError do
      begin
        args.SetGetterResultUndefined;
        Exit;
      end;
      on E:Exception do
      begin
        if Assigned(eng.FLog) then
        begin
          if Eng.FIgnoredExceptions.IndexOf(e.ClassType) < 0 then
          begin
            eng.FLog.Add('Uncaught exception: ' + E.Message);
            args.SetError(PAnsiChar(UTF8String('Uncaught exception: ' + E.Message)));
          end
          {$ifdef DEBUG}
          else
            eng.FLog.Add('--' + E.Message);
          {$endif}
        end;
      end;
    end;
end;

class procedure TJSEngine.callMethod(args: IMethodArgs);
var
  Eng: TJSEngine;

  procedure SetArgs(var Valueargs: array of TValue; argsCount: integer;
    params: TArray<TRttiParameter>);
  var
    i:integer;
  begin
    for i := 0 to argsCount - 1 do
    begin
      Valueargs[i] := JsValToTValue(args.GetArg(i), params[I].ParamType);
    end;
    for i := argsCount to Length(params) - 1 do
    begin
      Valueargs[i] := DefaultTValue(params[i].ParamType);
    end;
  end;

var
  Valueargs: array of TValue;
  Overloads: TMethodOverloadMap;
  MethodInfo: TRttiMethodInfo;
  Method: TRttiMethod;
  count: integer;
  Result: TValue;
  Parameters: TArray<TRttiParameter>;
  Attr: TCustomAttribute;
  cl: TClass;
  obj: TObject;
  Helper: TJSClassExtender;
begin
  //invoke right method of right object;
  cl := TClass(args.GetDelphiClasstype);
  if not Assigned(cl) then
    Exit;
  Eng := TJSEngine(args.GetEngine);
  if Assigned(Eng) then
    try
      Overloads := (args.GetDelphiMethod as TMethodOverloadMap);
      count := args.GetArgsCount;
      if Assigned(Overloads.MethodInfo.Method) then
        MethodInfo := Overloads.MethodInfo
      else if Assigned(Overloads.OverloadsInfo) then
        MethodInfo := GetMethodInfo(Overloads.OverloadsInfo, args);
      method := MethodInfo.Method;
      //TODO: Send Info about parameters count mismatch;
      if not Assigned(Method) {or (Length(Method.GetParameters) <> count)} then
        raise EScriptEngineException.Create(
          Format('there is no overloads for "%s" method, which takes %d param(s)',
          [PUtf8CharToString(args.GetMethodName), count]));
      Parameters := Method.GetParameters;
      SetLength(Valueargs, Length(Parameters));
      SetArgs(Valueargs, count, Parameters);
      //choose object for method invoke
      if cl = Eng.FGlobal.ClassType then
        obj := Eng.FGlobal
      else
        obj := args.GetDelphiObject;
      if not Assigned(obj) then
        raise EScriptEngineException.Create('obj not assigned: CallMethod()');
      Helper := MethodInfo.Helper;
      if Assigned(Helper) then
      begin
        Helper.Source := obj;
        Result := Method.Invoke(Helper, Valueargs);
      end
      else
        Result := Method.Invoke(obj, Valueargs);

      if Result.IsObject then
        for Attr in Method.GetAttributes do
          if Attr is TGCAttr then
            Eng.FGarbageCollector.AddObject(Result.AsObject);
      if Assigned(Method.ReturnType) then
      begin
        args.SetReturnValue(TValueToJSValue(Result, Eng.FEngine, Eng.FDispatchList));
      end;
    except
      on E:Exception do
      begin
        if Assigned(eng.FLog) then
        begin
          if Eng.FIgnoredExceptions.IndexOf(e.ClassType) < 0 then
          begin
            eng.FLog.Add('Uncaught exception: ' + E.Message);
            args.SetError(PAnsiChar(UTF8String('Uncaught exception: ' + E.Message)));
          end
          {$ifdef DEBUG}
          else
            eng.FLog.Add('--' + E.Message);
          {$endif}
        end;
      end;
    end;
end;

class procedure TJSEngine.callNamedPropNumberGetter(args: IGetterArgs);
var
  Eng: TJSEngine;
  ClassDescr: TJSClass;
  ClassTypeSlotItem: TObject;
  Prop: TRttiIndexedProperty;
  Result: TValue;
  cl: TClass;
  obj: TObject;
begin
  Eng := TJSEngine(args.GetEngine);
  obj := nil;
  Prop := nil;
  cl := nil;
  if Assigned(Eng) then
    try
      ClassTypeSlotItem := TObject(args.GetDelphiClasstype);
      if ClassTypeSlotItem is TClass then
        cl := TClass(ClassTypeSlotItem);
      if not Assigned(ClassTypeSlotItem) then
        raise EScriptEngineException.Create('There is no object in classtype slot');
      if ClassTypeSlotItem.ClassType = TRttiIndexedProperty then
      begin
        //prop pointer was writed in classtype slot;
        Prop := TRttiIndexedProperty(ClassTypeSlotItem);
        obj := args.GetDelphiObject;
      end
      else if Assigned(cl) then
      begin
        ClassDescr := Eng.FClasses.Items[cl];
        Prop := ClassDescr.FDefaultIndexedProp;
        if cl = Eng.FGlobal.ClassType then
          obj := Eng.FGlobal
        else
          obj := args.GetDelphiObject;
      end;
      if Assigned(Prop) and Assigned(obj) then
        Result := Prop.GetValue(obj, [JsValToTValue(args.GetPropIndexIValue)]);
      args.SetGetterResult(
        TValueToJSValue(Result, Eng.FEngine, Eng.FDispatchList));
    except
      on E: EVariantTypeCastError do
      begin
        args.SetGetterResultUndefined;
        Exit;
      end;
      on E:Exception do
      begin
        if Assigned(eng.FLog) then
        begin
          if Eng.FIgnoredExceptions.IndexOf(e.ClassType) < 0 then
          begin
            eng.FLog.Add('Uncaught exception: ' + E.Message);
            args.SetError(PAnsiChar(UTF8String('Uncaught exception: ' + E.Message)));
          end
          {$ifdef DEBUG}
          else
            eng.FLog.Add('--' + E.Message);
          {$endif}
        end;
      end;
    end;
end;

class procedure TJSEngine.callNamedPropNumberSetter(args: ISetterArgs);
var
  Prop: TRttiIndexedProperty;
  obj: TObject;
  Eng: TJSEngine;
begin
  Eng := TJSEngine(args.GetEngine);
  if Assigned(Eng) then
    try
      //prop pointer will be writed in classtype slot;
      Prop := TRttiIndexedProperty(args.GetDelphiClasstype);
      if not Prop.IsWritable then
        Exit;
      obj := args.GetDelphiObject;
      Prop.SetValue(obj, [JsValToTValue(args.GetPropIndexIValue)], JsValToTValue(args.GetValue, Prop.PropertyType));
    except
      on E: EVariantTypeCastError do
      begin
        Exit;
      end;
      on E:Exception do
      begin
        if Assigned(eng.FLog) then
        begin
          if Eng.FIgnoredExceptions.IndexOf(e.ClassType) < 0 then
          begin
            eng.FLog.Add('Uncaught exception: ' + E.Message);
            args.SetError(PAnsiChar(UTF8String('Uncaught exception: ' + E.Message)));
          end
          {$ifdef DEBUG}
          else
            eng.FLog.Add('--' + E.Message);
          {$endif}
        end;
      end;
    end;
end;

class procedure TJSEngine.callPropSetter(args: ISetterArgs);

  procedure SetValueToObject(obj: TObject; value: IValue; Prop: TRttiProperty);
  var
    PrevValue: TValue;
    StringsValue: TStrings;
    arrayValue: IValuesArray;
    i: integer;
  begin
    if Prop.IsReadable then
    begin
      PrevValue := Prop.GetValue(obj);
      if PrevValue.IsObject and (PrevValue.AsObject is TStrings) then
      begin
        StringsValue := (PrevValue.AsObject as TStrings);
        if value.IsArray then
        begin
          arrayValue := value.AsArray;
          StringsValue.Clear;
          for i := 0 to arrayValue.GetCount - 1 do
          begin
            StringsValue.Add(PUtf8CharToString(arrayValue.GetValue(i).AsString));
          end;
          Exit;
        end;
      end;
    end;
    Prop.SetValue(obj, JsValToTValue(value, Prop.PropertyType));
  end;

var
  ClassDescr: TJSClass;
  Prop: TRttiProperty;
  cl: TClass;
  obj: TObject;
  helper: TJSClassExtender;
  Eng: TJSEngine;
begin
  //invoke right method of right object;
  cl := TClass(args.GetDelphiClasstype);
  if not Assigned(cl) then
    Exit;
  Eng := TJSEngine(args.GetEngine);
  if Assigned(Eng) then
    try
      ClassDescr := Eng.FClasses.Items[cl];
      Prop := ClassDescr.FProps.Items[PUtf8CharToString(args.GetPropName)].prop;
      if cl = Eng.FGlobal.ClassType then
        obj := Eng.FGlobal
      else
        obj := args.GetDelphiObject;
      helper := ClassDescr.FProps.Items[PUtf8CharToString(args.GetPropName)].propObj;
      if Assigned(Helper) then
      begin
        helper.Source := obj;
        SetValueToObject(helper, args.GetValue, Prop);
        Helper.Source := nil;
      end
      else
        SetValueToObject(obj, args.GetValue, Prop);
    except
      on E: EVariantTypeCastError do
      begin
        args.SetResultUndefined;
        Exit;
      end;
      on E:Exception do
      begin
        if Assigned(eng.FLog) then
        begin
          if Eng.FIgnoredExceptions.IndexOf(e.ClassType) < 0 then
          begin
            eng.FLog.Add('Uncaught exception: ' + E.Message);
            args.SetError(PAnsiChar(UTF8String('Uncaught exception: ' + E.Message)));
          end
          {$ifdef DEBUG}
          else
            eng.FLog.Add('--' + E.Message);
          {$endif}
        end;
      end;
    end;
end;

constructor TJSEngine.Create;
begin
  FNodeEngineCreated := False;
  FInactive := True;
  FInitError := '';
  FClasses := TClassMap.Create;
  FClassList := TObjectList.Create;
  FDebug := False;
  FGarbageCollector := TObjects.Create;
  FJSHelpers := TJSExtenderMap.Create;
  FJSHelpersList := TObjectList.Create(True);
  FIgnoredExceptions := TList<TClass>.Create;
  FIgnoredExceptions.Add(EScriptEngineException);
  FDispatchList := TInterfaceList.Create;
  FEnumList := TList<PTypeInfo>.Create;
  FVars := TDictionary<string, TValue>.Create();
  try
    if NodeLibAvailable then
      FEngine := InitEngine(Self)
    else
      FInitError := Format('Failed to intialize node.dll. ' +
        'Incorrect version. Required %d version', [NODE_AVAILABLE_VER]);
  except
    on E: EExternalException do
    begin
      FInitError := 'Failed to initialize node.dll';
    end;
  end;
  if Assigned(FEngine) then
  begin
    FNodeEngineCreated := True;
    FInactive := False;
    //set callbacks for methods, props, fields;
    FEngine.SetMethodCallBack(callMethod);
    FEngine.SetPropGetterCallBack(callPropGetter);
    FEngine.SetPropSetterCallBack(callPropSetter);
    FEngine.SetFieldGetterCallBack(callFieldGetter);
    FEngine.SetFieldSetterCallBack(callFieldSetter);
    FEngine.SetIndexedPropGetterCallBack(callIndexedPropNumberGetter);
    FEngine.SetIndexedPropSetterCallBack(callIndexedPropNumberSetter);
    FEngine.SetNamedPropGetterCallBack(callNamedPropNumberGetter);
    FEngine.SetNamedPropSetterCallBack(callNamedPropNumberSetter);
    FEngine.SetInterfaceGetterCallBack(callIntfGetter);
    FEngine.SetInterfaceSetterCallBack(callIntfSetter);
    FEngine.SetInterfaceMethodCallBack(callIntfMethod);
    FEngine.SetErrorMessageCallBack(SendErrToLog);
    FEngine.SetIndexedPropGetterObjCallBack(callIndexedObjGetter);
  end;
end;

procedure TJSEngine.DeclareVar(const Name: string; Variable: TValue);
begin
  FVars.Add(Name, Variable);
  if Variable.IsObject then
  begin
    AddClass(Variable.AsObject.ClassType);
  end;
  Assert(Assigned(FGlobalTemplate));
  FGlobalTemplate.SetProp(PAnsiChar(UTF8String(Name)),
      TObject(FVars.Count - 1), True, True);
end;

destructor TJSEngine.Destroy;
begin
  FEnumList.Free;
  FClasses.Clear;
  FClasses.Free;
  if FNodeEngineCreated then
    FEngine.Delete;
  FJSHelpers.Free;
  FJSHelpersList.Free;
  FGarbageCollector.Clear;
  FGarbageCollector.Free;
  FClassList.Free;
  FIgnoredExceptions.Free;
  FVars.Free;
end;

class function TJSEngine.GetFullVersion: string;
begin
  Result := IntToStr(GetMajorVersion) + '.' + IntToStr(GetMinorVersion);
end;

class function TJSEngine.GetMajor: Integer;
begin
  Result := GetMajorVersion;
end;

class function TJSEngine.GetMethodInfo(List: TRttiMethodList;
  args: IMethodArgs): TRttiMethodInfo;
var
  i: Integer;
  count: integer;
  PArams: TArray<TRttiParameter>;
  method: TRttiMethodInfo;
  k: Integer;
  Correct: boolean;
begin
  Result.Helper := nil;
  Result.Method := nil;
  count := args.GetArgsCount;
  for i := 0 to List.Count - 1 do
  begin
    method := List[i];
    PArams := method.Method.GetParameters;
    if count = Length(PArams) then
    begin
      Correct := True;
      for k := 0 to count - 1 do
      begin
        case PArams[k].ParamType.TypeKind of
          tkUnknown: ;
          tkInteger: Correct := args.GetArg(k).IsInt;
          tkChar: ;
          tkEnumeration: ;
          tkFloat: Correct := args.GetArg(k).IsNumber;
          tkString: Correct := args.GetArg(k).IsString;
          tkSet: ;
          tkClass: Correct := args.GetArg(k).IsObject;
          tkMethod: ;
          tkWChar: ;
          tkLString: Correct := args.GetArg(k).IsString;
          tkWString: Correct := args.GetArg(k).IsString;
          tkVariant: ;
          tkArray: ;
          tkRecord: ;
          tkInterface: ;
          tkInt64: Correct := args.GetArg(k).IsInt;
          tkDynArray: ;
          tkUString: Correct := args.GetArg(k).IsString;
          tkClassRef: ;
          tkPointer: ;
          tkProcedure: ;
        end;
        if not Correct then
          break;
      end;
      if Correct then
        Exit(method)
    end;
  end;
end;

function TJSEngine.RunFile(fileName, scriptPath: string): string;
var
  RawByteStr: RawByteString;
  CharPtr: PAnsiChar;
  ScriptDir: string;
begin
  Result := '';
  if not FInactive then
  begin
    ScriptDir := ExtractFilePath(scriptPath);
    try
      FScriptName := TPath.Combine(ScriptDir, fileName);
    except
      on E: EArgumentException do
      begin
        FLog.Add('Run script: ' + E.Message);
        Exit('Run script: ' + E.Message);
      end;
    end;
    RawByteStr := UTF8Encode(FScriptName);
    FEngine.SetDebug(Debug, PAnsiChar(UTF8String(FDebugPort)));
    FAppPath := scriptPath;
    CharPtr := FEngine.RunFile(PansiChar(RawByteStr),
      PansiChar(UTF8String(scriptPath)), PAnsiChar(UTF8String(FAdParams)));
    FEngine.SetDebug(False, '');
    if Assigned(CharPtr) then
      Result := PUtf8CharToString(CharPtr);
    Result := '';
  end;
end;

procedure TJSEngine.AddIncludeCode(code: UTF8String);
begin
  FEngine.AddIncludeCode(PAnsiChar(code));
end;

function TJSEngine.RunIncludeCode(code: string): string;
begin
  Result := '';
  if not FInactive then
    Result := PUtf8CharToString(FEngine.RunIncludeCode(PAnsiChar(UTF8String(code))));
end;

function TJSEngine.RunIncludeFile(FileName: string): string;
var
  Utf8StrCode: UTF8String;
  CharPtr: PAnsiChar;
  ScriptFullName, Code: string;
begin
  Result := '';
  if not FInactive then
  begin
    try
      ScriptFullName := TPath.Combine(ExtractFilePath(FScriptName), FileName);
    except
      on E: EArgumentException do
      begin
        FLog.Add('Include file: ' + E.Message);
        Exit('Include file: ' + E.Message);
      end;
    end;
    Code := TFile.ReadAllText(ScriptFullName);
    Utf8StrCode := UTF8String(Code);
    try
      CharPtr := FEngine.RunIncludeCode(PAnsiChar(Utf8StrCode));
      if Assigned(CharPtr) then
          Result := PUtf8CharToString(CharPtr);
    except
      on e: Exception do
        Result := 'File couldn''t be included: internal node error';
    end;
  end;
end;

function TJSEngine.RunScript(code, scriptName: string): TValue;
var
  codeStr: UTF8String;
  resValue: IValue;
  scriptPath: string;
begin
  Result := TValue.Empty;
  if not FInactive then
  begin
    codeStr := UTF8String(code);
    FScriptName := scriptName;
    scriptPath := ExtractFilePath(scriptName);
    scriptName := ExtractFileName(scriptName);
  //  FEngine.SetDebug(Debug);
    resValue := FEngine.RunString(PansiChar(codeStr),
      PansiChar(UTF8String(scriptName)), PAnsiChar(UTF8String(scriptPath)),
      PAnsiChar(UTF8String(FAdParams)));
    if Assigned(resValue) then
      Result := JsValToTValue(resValue);
  end;
end;

class procedure TJSEngine.SendErrToLog(errMsg: PAnsiChar; eng: TObject);

  function TrimErrorStack(msg: string): string;
  const
    nodeErrorStack1 = 'at ContextifyScript.Script.runInThisContext';
    nodeErrorStack2 = 'at Object.exports.runInThisContext';
    nodeErrorStack3 = 'at Module._compile';
  var
    StrPos: integer;
  begin
    Result := msg;
    StrPos := Pos(nodeErrorStack1, Result);
    if StrPos < 1 then
    begin
      StrPos := Pos(nodeErrorStack2, Result);
      if StrPos < 1 then
        StrPos := Pos(nodeErrorStack3, Result);
    end;
    if StrPos > 0 then
      Result := Copy(Result, 1, StrPos - 1);
  end;

var
  engine: TJSEngine;
  msg, scriptName, lineNumString, tempString: string;
  StrPos, i, lineNum: integer;
  Added: boolean;
begin
  if (Assigned(eng)) and (eng is TJSEngine) then
  begin
    Added := False;
    engine := eng as TJSEngine;
    if Assigned(engine.FLog) then
    begin
      msg := PUtf8CharToString(errMsg);
      msg := TrimErrorStack(msg);
      scriptName := ExtractFileName(engine.FScriptName);
      StrPos := Pos(scriptName, msg);
      if StrPos > 0 then
      begin
        tempString := Copy(msg, StrPos + Length(scriptName) + 1, Length(msg) - (StrPos + Length(scriptName) + 1));
        lineNumString := '';
        i := 1;
        while i < Length(tempString) do
        begin
          if CharInSet(tempString[i], ['0'..'9']) then
            lineNumString := lineNumString + tempString[i]
          else
            break;
          Inc(i);
        end;
        if TryStrToInt(lineNumString, lineNum) then
        begin
          StrPos := Pos('^', tempString);
          if StrPos > 0 then
            msg := Copy(tempString, StrPos + 1, Length(tempString) - StrPos - 1);
          engine.FLog.AddObject(msg + engine.FLog.NameValueSeparator + engine.FScriptName, TObject(lineNum));
          Added := True
        end;
      end;
      if not Added then
        engine.FLog.Add(msg);
    end;
  end;
end;

procedure TJSEngine.SetAdParams(const Value: string);
begin
  FAdParams := Value;
end;

procedure TJSEngine.SetClassIntoContext(cl: TJSClass);

  function GetParent(ParentClass: TClass): IObjectTemplate;
  begin
    Result := nil;
    if ParentClass = TObject then
      Exit;
    Result := FEngine.GetObject(ParentClass);
    if not Assigned(Result) then
    begin
      AddClass(ParentClass);
      Result := FEngine.GetObject(ParentClass);
    end;
  end;

var
  objTempl: IObjectTemplate;
  Methods: TMethodOverloadMap;
  method: TRttiMethod;
  ReturnClass: TClass;
  Overloads: TPair<string, TMethodOverloadMap>;
  Prop: TRttiProperty;
  PropPair: TPair<string, TPropInfo>;
  field: TRttiField;
  FieldPair: TPair<string, TRttiField>;
  IndProp: TRttiIndexedProperty;
  IndPropPair: TPair<string, TRttiIndexedProperty>;
  i: integer;
  helper: TJSClassExtender;
  clParent: TClass;
begin
  if cl.Initialized then
    Exit;
  if Assigned(FEngine) then
  begin
    clParent := cl.cType.ClassParent;
    while clParent <> TObject do
    begin
      if FJSHelpers.TryGetValue(clParent, helper) then
        cl.AddHelper(helper);
      clParent := clParent.ClassParent;
    end;
    objTempl := FEngine.AddObject(PAnsiChar(UTF8String(cl.Ftype.ToString)), cl.FClasstype);
    objTempl.SetParent(GetParent(cl.cType.ClassParent));
    for Overloads in cl.FMethods do
    begin
      Methods := Overloads.Value;
      if Assigned(Methods.MethodInfo.Method) then
      begin
        method := Methods.MethodInfo.Method;
        if Assigned(method.ReturnType) then
        begin
          if (method.ReturnType.TypeKind = tkClass) then
          begin
            ReturnClass := method.ReturnType.Handle.TypeData.ClassType;
            AddClass(ReturnClass);
          end;
          if (method.ReturnType.TypeKind = tkEnumeration) then
            AddEnumToGlobal(method.ReturnType, FGlobalTemplate);
        end;
      end
      else if Assigned(Methods.OverloadsInfo) then
        for i := 0 to Methods.OverloadsInfo.Count - 1 do
        begin
          method := Methods.OverloadsInfo[i].Method;
          if Assigned(method.ReturnType) then
          begin
            if (method.ReturnType.TypeKind = tkClass) then
            begin
              ReturnClass := method.ReturnType.Handle.TypeData.ClassType;
              AddClass(ReturnClass);
            end;
            if (method.ReturnType.TypeKind = tkEnumeration) then
              AddEnumToGlobal(method.ReturnType, FGlobalTemplate);
          end;
        end;
      objTempl.SetMethod(PAnsiChar(UTF8String(Overloads.Key)), Methods);
    end;
    for PropPair in cl.FProps do
    begin
      Prop := PropPair.Value.prop;
      objTempl.SetProp(PAnsiChar(UTF8String(Prop.Name)), PropPair.Value.propObj, Prop.IsReadable, Prop.IsWritable);
      if Assigned(Prop.PropertyType) then
      begin
        if (Prop.PropertyType.TypeKind = tkClass) then
        begin
          ReturnClass := Prop.PropertyType.Handle.TypeData.ClassType;
          AddClass(ReturnClass);
        end;
        if (Prop.PropertyType.TypeKind = tkEnumeration) then
          AddEnumToGlobal(Prop.PropertyType, FGlobalTemplate);
      end;
    end;
    for FieldPair in cl.FFields do
    begin
      field := FieldPair.Value;
      objTempl.SetField(PAnsiChar(UTF8String(field.Name)));
      if Assigned(field.FieldType) then
      begin
        if (field.FieldType.TypeKind = tkClass) then
        begin
          ReturnClass := field.FieldType.Handle.TypeData.ClassType;
          AddClass(ReturnClass);
        end;
        if (field.FieldType.TypeKind = tkEnumeration) then
          AddEnumToGlobal(field.FieldType, FGlobalTemplate);
      end;
    end;
    for IndPropPair in cl.IndexedProps do
    begin
      IndProp := IndPropPair.Value;
      objTempl.SetIndexedProp(PAnsiChar(UTF8String(IndProp.Name)), nil,
        IndProp.IsReadable, IndProp.IsWritable);
    end;
    objTempl.SetHasIndexedProps(cl.FIndexedProps.Count > 0);
    cl.Initialized := True;
  end;
end;

procedure TJSEngine.SetDebug(const Value: boolean);
begin
  FDebug := Value;
end;

procedure TJSEngine.SetDebugPort(const Value: string);
begin
  FDebugPort := Value;
end;

procedure TJSEngine.SetLog(const Value: TStrings);
begin
  FLog := Value;
end;

procedure TJSEngine.TryFinishScript;
begin
  FInactive := True;
  FEngine.SetInactive;
end;

function TJSEngine.CallFunction(const Name: string): Variant;
var
  JsArgs: IValuesArray;
begin
  Result := '';
  if not FInactive then
  begin
    JsArgs := FEngine.NewArray(0);
    if not Assigned(JsArgs) then
      raise EScriptEngineException.Create('Can not create an array to call a function');
    Result := JsValToTValue(CallFunction(name, JsArgs)).AsVariant;
  end;
end;

{ TJSClass }

procedure TJSClass.AddHelper(helper: TJSClassExtender);

  function SimilarParams(Param1, Param2: TArray<TRttiParameter>): boolean;
  var
    i: integer;
  begin
    Result := Length(Param1) = Length(Param2);
    if (Result) then
    begin
      for i := 0 to Length(Param1) - 1 do
        if Param1[i].ParamType.TypeKind <> Param2[i].ParamType.TypeKind then
        begin
          Result := False;
          break;
        end;
    end;
  end;

  function AssignHelperToSimilarMethod(overloads: TMethodOverloadMap;
    Method: TRttiMethod): boolean;
  var
    MethodInfo: TRttiMethodInfo;
    i: integer;
  begin
    Result := False;
    if Assigned(overloads.OverloadsInfo) then
    begin
      for i := 0 to overloads.OverloadsInfo.Count - 1 do
      begin
        MethodInfo := overloads.OverloadsInfo[i];
        if (MethodInfo.Method.Name = Method.Name) and
          (SimilarParams(MethodInfo.Method.GetParameters, Method.GetParameters)) then
        begin
          MethodInfo.Method := Method;
          MethodInfo.Helper := helper;
          overloads.OverloadsInfo[i] := MethodInfo;
          Result := True;
          break;
        end;
      end;
    end
    else
    begin
      MethodInfo := overloads.MethodInfo;
      if Assigned(MethodInfo.Method) and
        SimilarParams(MethodInfo.Method.GetParameters, Method.GetParameters) then
      begin
        MethodInfo.Method := Method;
        MethodInfo.Helper := helper;
        overloads.MethodInfo := MethodInfo;
        Result := True;
      end;
    end;
  end;

var
  MethodArr: TArray<TRttiMethod>;
  overloads: TMethodOverloadMap;
  methodInfo: TRttiMethodInfo;
  method: TRttiMethod;
  PropArr: TArray<TRttiProperty>;
  propInfo: TPropInfo;
  prop: TRttiProperty;
  helperCType: TClass;
  helpType: TRttiType;
begin
  helperCType := helper.ClassType;
  helpType := RttiContext.GetType(helperCType);
  MethodArr := helpType.GetMethods;
  for method in MethodArr do
  begin
    if (method.MethodKind in [mkProcedure, mkFunction]) and
      (method.Visibility = mvPublic) and (method.Parent.Handle.TypeData.ClassType <> TObject) then
    begin
      if not FMethods.TryGetValue(method.Name, overloads) then
      begin
          overloads := TMethodOverloadMap.Create;
          FMethods.Add(method.Name, overloads);
          overloads.MethodInfo.Method := method;
          overloads.MethodInfo.Helper := helper;
      end
      else
      begin
        if not AssignHelperToSimilarMethod(overloads, method) then
        begin
          if Assigned(overloads.MethodInfo.Method) then
          begin
            overloads.OverloadsInfo := TRttiMethodList.Create;
            overloads.OverloadsInfo.Add(overloads.MethodInfo);
            overloads.MethodInfo.Method := nil;
            overloads.MethodInfo.Helper := helper;
          end;
          methodInfo.Method := method;
          methodInfo.Helper := helper;
          overloads.OverloadsInfo.Add(methodInfo);
        end;
      end;
    end;
  end;
  PropArr := helpType.GetProperties;
  for prop in PropArr do
  begin
    if FProps.ContainsKey(prop.Name) or (not Assigned(prop.PropertyType)) then
      continue;
    if (prop.PropertyType.TypeKind in tkProperties) and (prop.Visibility = mvPublic) then
    begin
      propInfo := TPropInfo.Create;
      propInfo.prop := prop;
      propInfo.propObj := helper;
      FProps.Add(prop.Name, propInfo);
    end;
  end;
end;

constructor TJSClass.Create(classType: TClass);

  function ClassIsForbidden(clDescr: TRttiType): boolean;
  var
    Attrs: TArray<TCustomAttribute>;
    attr: TCustomAttribute;
  begin
    Result := False;
    if not Assigned(clDescr) then
      Exit;
    if clDescr.TypeKind = tkClass then
    begin
      Attrs := clDescr.GetAttributes;
      for attr in Attrs do
      begin
        if attr is TObjectForbiddenAttr then
          Exit(True);
      end;
    end;
  end;

  function ReturnsForbiddenClass(method : TRttiMethod): boolean;
  begin
    Result := ClassIsForbidden(method.ReturnType);
  end;

  function HasForbiddenAttribute(Attrs: TArray<TCustomAttribute>): boolean;
  var
    attr: TCustomAttribute;
  begin
    Result := False;
    for attr in Attrs do
    begin
      if attr is TMethodForbiddenAttr then
        Exit(True);
    end;
  end;

var
  MethodArr: TArray<TRttiMethod>;
  overloads: TMethodOverloadMap;
  methodInfo: TRttiMethodInfo;
  method: TRttiMethod;

  PropArr: TArray<TRttiProperty>;
  propInfo: TPropInfo;
  prop: TRttiProperty;

  FieldArr: TArray<TRttiField>;
  field: TRttiField;

  IndPropArr: TArray<TRttiIndexedProperty>;
  indProp: TRttiIndexedProperty;

begin
  inherited Create();
  FMethods := TMethodMap.Create([doOwnsValues]);
  FProps := TPropMap.Create([doOwnsValues]);
  FFields := TFieldMap.Create;
  FIndexedProps := TIndexedPropMap.Create;
  FClasstype := classType;
  Ftype := RttiContext.GetType(FClasstype);
  if ClassIsForbidden(Ftype) then
    raise EScriptEngineException.Create('Trying to create forbidden class');
  MethodArr := Ftype.GetMethods;
  for method in MethodArr do
  begin
    if ReturnsForbiddenClass(method) then
      continue;
    if HasForbiddenAttribute(method.GetAttributes) then
      continue;
    if (method.MethodKind in [mkProcedure, mkFunction]) and
      (method.Visibility = mvPublic) and (method.Parent.Handle.TypeData.ClassType <> TObject) then
    begin
      if not FMethods.TryGetValue(method.Name, overloads) then
      begin
        overloads := TMethodOverloadMap.Create;
        FMethods.Add(method.Name, overloads);
        overloads.MethodInfo.Method := method;
      end
      else
      begin
        if Assigned(overloads.MethodInfo.Method) then
        begin
          overloads.OverloadsInfo := TRttiMethodList.Create;
          overloads.OverloadsInfo.Add(overloads.MethodInfo);
          overloads.MethodInfo.Method := nil;
        end;
        methodInfo.Method := method;
        overloads.OverloadsInfo.Add(methodInfo);
      end;
    end;
  end;
  PropArr := Ftype.GetProperties;
  for prop in PropArr do
  begin
    if FProps.ContainsKey(prop.Name) or (not Assigned(prop.PropertyType)) then
      continue;
    if (prop.PropertyType.TypeKind in tkProperties) and (prop.Visibility = mvPublic) then
    begin
      propInfo := TPropInfo.Create;
      propInfo.prop := prop;
      propInfo.propObj := nil;
      FProps.Add(prop.Name, propInfo);
    end;
  end;
  FieldArr := Ftype.GetFields;
  for field in FieldArr do
  begin
    if Fields.ContainsKey(field.Name) or (not Assigned(field.FieldType)) then
      continue;
    if (field.FieldType.TypeKind in tkProperties) and (field.Visibility = mvPublic) then
      FFields.Add(field.Name, field);
  end;
  IndPropArr := Ftype.GetIndexedProperties;
  for indProp in IndPropArr do
  begin
    if FIndexedProps.ContainsKey(indProp.Name) or (not Assigned(indProp.PropertyType)) then
      continue;
    if (indProp.PropertyType.TypeKind in tkProperties) and (indProp.Visibility = mvPublic) then
    begin
      FIndexedProps.Add(indProp.Name, indProp);
      if indProp.IsDefault then
        FDefaultIndexedProp := indProp;
    end;
  end;
end;

destructor TJSClass.Destroy;
begin
  FMethods.Free;
  FProps.Free;
  FFields.Free;
  FIndexedProps.Free;
  inherited;
end;

procedure TJSClass.SetInitialized(const Value: boolean);
begin
  FInitialized := Value;
end;

{ TObjects }

procedure TObjects.AddObject(obj: TObject);
begin
  if not Contains(obj) then
    Add(obj);
end;

{ TMethodOverloadMap }

destructor TMethodOverloadMap.Destroy;
begin
  if Assigned(OverloadsInfo) then
    OverloadsInfo.Free;
  inherited;
end;

initialization
  RttiContext := TRttiContext.Create;

finalization
  RttiContext.Free;

end.

