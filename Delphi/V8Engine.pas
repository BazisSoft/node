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

    procedure SetDebug(const Value: boolean);
  public
    constructor Create;
    destructor Destroy; override;
    procedure IgnoreException(E: TClass);
    function AddClass(cType: TClass): TJSClass;
    function AddGlobal(global: TObject): TJSClass;
    procedure AddEnumToGlobal(Enum: TRttiType; global: IObjectTemplate);
    procedure RegisterHelper(CType: TClass; HelperType: TJSExtClass);
    function ClassIsRegistered(CType: TClass): boolean;
    class procedure callMethod(args:IMethodArgs); static; stdcall;
    class procedure callPropGetter(args: IGetterArgs); static; stdcall;
    class procedure callPropSetter(args: ISetterArgs); static; stdcall;
    class procedure callFieldGetter(args: IGetterArgs); static; stdcall;
    class procedure callFieldSetter(args: ISetterArgs); static; stdcall;
    class procedure callIndexedPropGetter(args: IGetterArgs); static; stdcall;
    class procedure callIndexedPropSetter(args: ISetterArgs); static; stdcall;
    class procedure callIntfGetter(args: IGetterArgs); static; stdcall;
    class procedure callIntfSetter(args: IIntfSetterArgs); static; stdcall;
    class procedure callIntfMethod(args: IMethodArgs); static; stdcall;
    class procedure SendErrToLog(errMsg: PAnsiChar; eng: TObject); static; stdcall;
    class function GetMethodInfo(List: TRttiMethodList; args: IMethodArgs): TRttiMethodInfo;
    function CallFunction(name: string; Args: IValuesArray): IValue; overload;
    function CallFunction(name: string; Args: array of TValue): IValue; overload;
    function CallFunction(name: string; Args: array of Variant): Variant; overload;

    property ScriptLog: TStrings read FLog;
    procedure SetLog(const Value: TStrings);

    property Debug: boolean read FDebug write SetDebug;
    function RunScript(code, appPath: string): string;
//    function RunIncludeCode
    function RunFile(fileName, appPath: string): string;
    function RunIncludeFile(FileName: string): string;
    procedure AddIncludeCode(code: UTF8String);
    procedure SetClassIntoContext(cl: TJSClass);
    procedure SetRecordIntoContext(ValRecord: TValue; RecDescr: TRttiType; JSRecord: IRecord);
  end;


implementation

uses PSApi, Math, DateUtils, RegularExpressions;

const
  NilMethod: TMethod = (Code: nil; data: nil);

var
  // NumObjsFree: integer = 0;
  // TJSClassProtoCount: integer = 0;
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
  if (Assigned(FEngine.ScriptLog)) then
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
    JsClass := TJSClass.Create(cType);
    if FJSHelpers.TryGetValue(cType, helper) then
      JsClass.AddHelper(helper);
    if FClasses.ContainsKey(ctype) then
      raise EScriptEngineException.Create('Engine already have class being added');
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
  cType := global.ClassType;
  FGlobal := global;
  ClassTemplate := TJSClass.Create(cType);
  FGlobalTemplate := FEngine.AddGlobal(cType, global);
//  FEngine.SetGlobalClasstype(cType);
  for Overloads in ClassTemplate.Methods do
  begin
    Name := PAnsiChar(UTF8String(Overloads.Key));
    Methods := Overloads.Value;
    if Assigned(Methods.MethodInfo.Method) then
    begin
      methodInfo := Methods.MethodInfo;
      method := methodInfo.Method;
//      if (method.Parent.Handle.TypeData.ClassType = TObject) then
//        continue;
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
//        if (method.Parent.Handle.TypeData.ClassType = TObject) then
//          continue;
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

  procedure SetResultAsObject(resul: TValue);
  var
    ResObj: TObject;
    clParent: TClass;
  begin
    ResObj := resul.AsObject;
    if Assigned(ResObj) then
    begin
      clParent := ResObj.ClassType;
      if Assigned(Eng) then
      begin
        while (not Eng.ClassIsRegistered(clParent)) and (clParent <> TObject) do
          clParent := clParent.ClassParent;
      end;
        args.SetGetterResult(ResObj, clParent);
    end;
  end;

var
  ClassDescr: TJSClass;
  Field: TRttiField;
  Result: TValue;
  ReturnType: TypInfo.TTypeKind;
  //debug variables (maybe)
  cl: TClass;
  obj: TObject;
begin
  //invoke right method of right object;
  cl := TClass(args.GetDelphiClasstype);
  if not Assigned(cl) then
    raise EScriptEngineException.Create('Can''t get classtype of holder object: calling field getter');
  Eng := TJSEngine(args.GetEngine);
  if not Assigned(Eng) then
    raise EScriptEngineException.Create('Engine is not initialized: internal dll error');
  try
    ClassDescr := Eng.FClasses.Items[cl];
    Field := ClassDescr.FFields.Items[string(args.GetPropName)];
    if cl = Eng.FGlobal.ClassType then
      obj := Eng.FGlobal
    else
      obj := args.GetDelphiObject;
    try
      Result := Field.GetValue(obj);
    except
      on E: EVariantTypeCastError do
      begin
        args.SetGetterResultUndefined;
        Exit;
      end;
      on E: Exception do
      begin
        args.SetError(PAnsiChar(UTF8String(e.ClassName + ': ' + E.Message)));
        Exit;
      end;
    end;
    if Assigned(Field.FieldType) then
    begin
      ReturnType :=  Field.FieldType.TypeKind;
      case ReturnType of
        tkUnknown: ;
        tkInteger: args.SetGetterResult(Result.AsInteger);
        tkChar: args.SetGetterResult(PAnsiChar(UTF8String(Result.AsString)));
        tkEnumeration: ;
        tkFloat: args.SetGetterResult(Result.AsExtended);
        tkString: args.SetGetterResult(PAnsiChar(UTF8String(Result.AsString)));
        tkSet: ;
        tkClass: SetResultAsObject(Result);
        tkMethod: ;
        tkWChar: args.SetGetterResult(PAnsiChar(UTF8String(Result.AsString)));
        tkLString: args.SetGetterResult(PAnsiChar(UTF8String(Result.AsString)));
        tkWString: args.SetGetterResult(PAnsiChar(UTF8String(Result.AsString)));
        tkVariant: ;
        tkArray: ;
        tkRecord:
        begin
          Eng.SetRecordIntoContext(Result, Field.FieldType, args.GetGetterResultAsRecord);
          args.SetGetterResultAsRecord;
        end;
        tkInterface: ;
        tkInt64: args.SetGetterResult(Result.AsInteger);
        tkDynArray: ;
        tkUString: args.SetGetterResult(PAnsiChar(UTF8String(Result.AsString)));
        tkClassRef: ;
        tkPointer: ;//args.SetGetterResult(Result.AsObject, Result.AsObject.ClassType);
        tkProcedure: ;
      end;
    end;
  except
    on E:Exception do
    begin
      if Assigned(eng.FLog) then
      begin
        if Eng.FIgnoredExceptions.IndexOf(e.ClassType) >= 0 then
          eng.FLog.Add('--' + E.Message)
        else
          eng.FLog.Add('Uncaught exception: ' + E.Message);
      end;
    end;
  end;
end;

class procedure TJSEngine.callFieldSetter(args: ISetterArgs);
var
  ClassDescr: TJSClass;
  Field: TRttiField;
  //debug variables (maybe)
  cl: TClass;
  obj: TObject;
  Eng: TJSEngine;
begin
  cl := TClass(args.GetDelphiClasstype);
  if not Assigned(cl) then
    raise EScriptEngineException.Create('Can''t get classtype of holder object: calling field setter');
  Eng := TJSEngine(args.GetEngine);
  if not Assigned(Eng) then
    raise EScriptEngineException.Create('Engine is not initialized: internal dll error');
  try
    ClassDescr := Eng.FClasses.Items[cl];
    Field := ClassDescr.FFields.Items[string(args.GetPropName)];
    if cl = Eng.FGlobal.ClassType then
      obj := Eng.FGlobal
    else
      obj := args.GetDelphiObject;
    try
      Field.SetValue(obj, JsValToTValue(args.GetValue, Field.FieldType));
    except
      on E: EVariantTypeCastError do
        Exit;
      on E: Exception do
      begin
        args.SetError(PAnsiChar(UTF8String(e.ClassName + ': ' + E.Message)));
        Exit;
      end;
    end;
  except
    on E:Exception do
    begin
      if Assigned(eng.FLog) then
      begin
        if Eng.FIgnoredExceptions.IndexOf(e.ClassType) >= 0 then
          eng.FLog.Add('--' + E.Message)
        else
          eng.FLog.Add('Uncaught exception: ' + E.Message);
      end;
    end;
  end;
end;

function TJSEngine.CallFunction(name: string; Args: array of Variant): Variant;
var
  JsArgs: IValuesArray;
  count, i: integer;
begin
  count := Length(Args);
  JsArgs := FEngine.NewArray(count);
  if not Assigned(JsArgs) then
    raise EScriptEngineException.Create('Can not create an array to make a function');
  for i := 0 to count - 1 do
  begin
    JsArgs.SetValue(TValueToJSValue(TValue.FromVariant(Args[i]), FEngine), i);
  end;
  Result := JsValToTValue(CallFunction(name, JsArgs)).AsVariant;
end;

function TJSEngine.CallFunction(name: string; Args: array of TValue): IValue;
var
  JsArgs: IValuesArray;
  count, i: integer;
begin
  count := Length(Args);
  JsArgs := FEngine.NewArray(count);
  for i := 0 to count - 1 do
  begin
    JsArgs.SetValue(TValueToJSValue(Args[i], FEngine), i);
  end;
  Result := CallFunction(name, JsArgs);
end;

function TJSEngine.CallFunction(name: string; Args: IValuesArray): IValue;
var
  Utf8Name: UTF8String;
begin
  Utf8Name := UTF8String(name);
  try
    Result := FEngine.CallFunc(PAnsiChar(Utf8Name), Args);
  except
    on E:Exception do
    begin
      if Assigned(FLog) then
      begin
        if FIgnoredExceptions.IndexOf(e.ClassType) >= 0 then
          FLog.Add('--' + E.Message)
        else
          FLog.Add('Uncaught exception: ' + E.Message);
      end;
      Result := nil;
    end;
  end;
end;

class procedure TJSEngine.callIndexedPropGetter(args: IGetterArgs);
var
  ClassDescr: TJSClass;
  Prop: TRttiIndexedProperty;
  Result: TValue;
  ReturnType: TypInfo.TTypeKind;
  //debug variables (maybe)
  cl: TClass;
  obj: TObject;
  Eng: TJSEngine;
begin
  //invoke right method of right object;
  cl := TClass(args.GetDelphiClasstype);
  if not Assigned(cl) then
    raise EScriptEngineException.Create('Can''t get classtype of holder object: calling indexed prop getter');
  Eng := TJSEngine(args.GetEngine);
  if not Assigned(Eng) then
    raise EScriptEngineException.Create('Engine is not initialized: internal dll error');
  try
    ClassDescr := Eng.FClasses.Items[cl];
    Prop := ClassDescr.FDefaultIndexedProp;
    if cl = Eng.FGlobal.ClassType then
      obj := Eng.FGlobal
    else
      obj := args.GetDelphiObject;
    try
      Result := Prop.GetValue(obj, [args.GetPropIndex]);
    except
      on E: EVariantTypeCastError do
      begin
        args.SetGetterResultUndefined;
        Exit;
      end;
      on E: Exception do
      begin
        args.SetError(PAnsiChar(UTF8String(e.ClassName + ': ' + E.Message)));
        Exit;
      end;
    end;
    if Assigned(Prop.PropertyType) then
    begin
      ReturnType :=  Prop.PropertyType.TypeKind;
      case ReturnType of
        tkUnknown: ;
        tkInteger: args.SetGetterResult(Result.AsInteger);
        tkChar: args.SetGetterResult(PAnsiChar(UTF8String(Result.AsString)));
        tkEnumeration: ;
        tkFloat: args.SetGetterResult(Result.AsExtended);
        tkString: args.SetGetterResult(PAnsiChar(UTF8String(Result.AsString)));
        tkSet: ;
        tkClass: args.SetGetterResult(Result.AsObject, Result.AsObject.ClassType);
        tkMethod: ;
        tkWChar: args.SetGetterResult(PAnsiChar(UTF8String(Result.AsString)));
        tkLString: args.SetGetterResult(PAnsiChar(UTF8String(Result.AsString)));
        tkWString: args.SetGetterResult(PAnsiChar(UTF8String(Result.AsString)));
        tkVariant: ;
        tkArray: ;
        tkRecord:
        begin
          Eng.SetRecordIntoContext(Result, Prop.PropertyType, args.GetGetterResultAsRecord);
          args.SetGetterResultAsRecord;
        end;
        tkInterface: ;
        tkInt64: args.SetGetterResult(Result.AsInteger);
        tkDynArray: ;
        tkUString: args.SetGetterResult(PAnsiChar(UTF8String(Result.AsString)));
        tkClassRef: ;
        tkPointer: ;//args.SetGetterResult(Result.AsObject, Result.AsObject.ClassType);
        tkProcedure: ;
      end;
    end;
  except
    on E:Exception do
    begin
      if Assigned(eng.FLog) then
      begin
        if Eng.FIgnoredExceptions.IndexOf(e.ClassType) >= 0 then
          eng.FLog.Add('--' + E.Message)
        else
          eng.FLog.Add('Uncaught exception: ' + E.Message);
      end;
    end;
  end;
end;

class procedure TJSEngine.callIndexedPropSetter(args: ISetterArgs);
var
  ClassDescr: TJSClass;
  Prop: TRttiIndexedProperty;
  //debug variables (maybe)
  cl: TClass;
  obj: TObject;
  Eng: TJSEngine;
begin
  //invoke right method of right object;
  cl := TClass(args.GetDelphiClasstype);
  if not Assigned(cl) then
    raise EScriptEngineException.Create('Can''t get classtype of holder object: calling indexed prop setter');
  Eng := TJSEngine(args.GetEngine);
  if not Assigned(Eng) then
    raise EScriptEngineException.Create('Engine is not initialized: internal dll error');
  try
    ClassDescr := Eng.FClasses.Items[cl];
    Prop := ClassDescr.FDefaultIndexedProp;
    if not Prop.IsWritable then
      Exit;
    if cl = Eng.FGlobal.ClassType then
      obj := Eng.FGlobal
    else
      obj := args.GetDelphiObject;
    try
      Prop.SetValue(obj, [args.GetPropIndex], JsValToTValue(args.GetValue, Prop.PropertyType));
    except
      on E: EArgumentOutOfRangeException do
        Eng.FLog.Add('Argumrent out of range');
      on E: Exception do
      begin
        args.SetError(PAnsiChar(UTF8String(e.ClassName + ': ' + E.Message)));
        Exit;
      end;
    end;
  except
    on E:Exception do
    begin
      if Assigned(eng.FLog) then
      begin
        if Eng.FIgnoredExceptions.IndexOf(e.ClassType) >= 0 then
          eng.FLog.Add('--' + E.Message)
        else
          eng.FLog.Add('Uncaught exception: ' + E.Message);
      end;
    end;
  end;
end;

class procedure TJSEngine.callIntfGetter(args: IGetterArgs);
var
  Eng: TJSEngine;

  procedure SetResultAsIface(val: TValue);
  var
    ResDispatch: IDispatch;
  begin
    ResDispatch := TValueToDispatch(val);
    Eng.FDispatchList.Add(ResDispatch);
    args.SetGetterResultIntf(Pointer(ResDispatch));
  end;

var
  Intf: IDispatch;
  Result: TValue;
  ReturnType: TypInfo.TTypeKind;
  PropName: string;
  isProperty: boolean;
begin
  Intf := IDispatch(args.GetDelphiObject);
  Eng := TJSEngine(args.GetEngine);
  if not Assigned(Eng) then
    raise EScriptEngineException.Create('Engine is not initialized: internal dll error');
  try
    PropName := PUtf8CharToString(args.GetPropName);
    try
      Result := ExecuteOnDispatchMultiParamProp(Intf, PropName, Tvalue.Empty, isProperty);
    except
      on E: EVariantTypeCastError do
      begin
        args.SetGetterResultUndefined;
        Exit;
      end;
      on E: Exception do
      begin
        args.SetError(PAnsiChar(UTF8String(e.ClassName + ': ' + E.Message)));
        Exit;
      end;
    end;
    if isProperty then
    begin
      if Assigned(Result.TypeInfo) then
      begin
        ReturnType := Result.TypeInfo.Kind;;
        case ReturnType of
          tkUnknown: args.SetGetterResultUndefined;
          tkInteger: args.SetGetterResult(Result.AsInteger);
          tkChar: args.SetGetterResult(PAnsiChar(UTF8String(Result.AsString)));
          tkEnumeration: ;
          tkFloat: args.SetGetterResult(Result.AsExtended);
          tkString: args.SetGetterResult(PAnsiChar(UTF8String(Result.AsString)));
          tkSet: ;
  //        tkClass: SetResultAsObject(Result);
          tkMethod: ;
          tkWChar: args.SetGetterResult(PAnsiChar(UTF8String(Result.AsString)));
          tkLString: args.SetGetterResult(PAnsiChar(UTF8String(Result.AsString)));
          tkWString: args.SetGetterResult(PAnsiChar(UTF8String(Result.AsString)));
          tkVariant: ;
          tkArray: ;
          tkRecord:
          begin
            Eng.SetRecordIntoContext(Result,
              TRttiContext.Create.GetType(Result.TypeInfo),
              args.GetGetterResultAsRecord);
            args.SetGetterResultAsRecord;
          end;
          tkInterface: SetResultAsIface(Result);
          tkInt64: args.SetGetterResult(Result.AsInteger);
          tkDynArray: ;
          tkUString: args.SetGetterResult(PAnsiChar(UTF8String(Result.AsString)));
          tkClassRef: ;
          tkPointer: ;//args.SetGetterResult(Result.AsObject, Result.AsObject.ClassType);
          tkProcedure: ;
        end;
      end;
    end
    else
    begin
      args.SetGetterResultAsIntfFunction(Pointer(Intf), PAnsiChar(UTF8String(PropName)));
    end;
  except
    on E:Exception do
    begin
      if Assigned(eng.FLog) then
      begin
        if Eng.FIgnoredExceptions.IndexOf(e.ClassType) >= 0 then
          eng.FLog.Add('--' + E.Message)
        else
          eng.FLog.Add('Uncaught exception: ' + E.Message);
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

  procedure SetResultAsIface(val: TValue);
  var
    ResDispatch: IDispatch;
  begin
    ResDispatch := TValueToDispatch(val);
    Eng.FDispatchList.Add(ResDispatch);
    args.SetReturnValueIntf(Pointer(ResDispatch));
  end;

//TODO:: make it work.
var
  Intf: IDispatch;
  Result: TValue;
  ReturnType: TypInfo.TTypeKind;
  MethodName: string;
  ValueArgs: Array of TValue;
begin
  Intf := IDispatch(args.GetDelphiObject);
  Eng := TJSEngine(args.GetEngine);
  Result := TValue.Empty;
  if not Assigned(Eng) then
    raise EScriptEngineException.Create('Engine is not initialized: internal dll error');
  try
    MethodName := PUtf8CharToString(args.GetMethodName);
    SetLength(ValueArgs, args.GetArgsCount);
    SetArgs(ValueArgs);
    Result := ExecuteOnDispatchMultiParamFunc(Intf, MethodName, ValueArgs);
    if Assigned(Result.TypeInfo) then
    begin
      ReturnType := Result.TypeInfo.Kind;;
      case ReturnType of
        tkUnknown: args.SetReturnValueUndefined;
        tkInteger: args.SetReturnValue(Result.AsInteger);
        tkChar: args.SetReturnValue(PAnsiChar(UTF8String(Result.AsString)));
        tkEnumeration: ;
        tkFloat: args.SetReturnValue(Result.AsExtended);
        tkString: args.SetReturnValue(PAnsiChar(UTF8String(Result.AsString)));
        tkSet: ;
//        tkClass: SetResultAsObject(Result);
        tkMethod: ;
        tkWChar: args.SetReturnValue(PAnsiChar(UTF8String(Result.AsString)));
        tkLString: args.SetReturnValue(PAnsiChar(UTF8String(Result.AsString)));
        tkWString: args.SetReturnValue(PAnsiChar(UTF8String(Result.AsString)));
        tkVariant: ;
        tkArray: ;
        tkRecord:
        begin
          Eng.SetRecordIntoContext(Result,
            TRttiContext.Create.GetType(Result.TypeInfo),
            args.GetReturnValueAsRecord);
          args.SetReturnValueAsRecord;
        end;
        tkInterface: SetResultAsIface(Result);
        tkInt64: args.SetReturnValue(Result.AsInteger);
        tkDynArray: ;
        tkUString: args.SetReturnValue(PAnsiChar(UTF8String(Result.AsString)));
        tkClassRef: ;
        tkPointer: ;//args.SetReturnValue(Result.AsObject, Result.AsObject.ClassType);
        tkProcedure: ;
      end;
    end;
  except
    on E:Exception do
    begin
      if Assigned(eng.FLog) then
      begin
        if Eng.FIgnoredExceptions.IndexOf(e.ClassType) >= 0 then
          eng.FLog.Add('--' + E.Message)
        else
          eng.FLog.Add('Uncaught exception: ' + E.Message);
      end;
    end;
  end;
end;

class procedure TJSEngine.callIntfSetter(args: IIntfSetterArgs);
var
  ClassDescr: TJSClass;
  Prop: string;
  Intf: IDispatch;
  obj: TObject;
  Eng: TJSEngine;
  isProperty: boolean;
  Value: TValue;
begin
  Intf := IDispatch(args.GetDelphiObject);
  prop := PUtf8CharToString(args.GetPropName);
  Value := JsValToTValue(args.GetValue);
  Eng := TJSEngine(args.GetEngine);
  try
    ExecuteOnDispatchMultiParamProp(Intf, prop, Value, isProperty);
  except
    on E:Exception do
    begin
      if Assigned(eng.FLog) then
      begin
        if Eng.FIgnoredExceptions.IndexOf(e.ClassType) >= 0 then
          eng.FLog.Add('--' + E.Message)
        else
          eng.FLog.Add('Uncaught exception: ' + E.Message);
      end;
    end;
  end;
end;

class procedure TJSEngine.callPropGetter(args: IGetterArgs);
var
  Eng: TJSEngine;

  procedure SetResultAsObject(resul: TValue);
  var
    ResObj: TObject;
    clParent: TClass;
  begin
    ResObj := resul.AsObject;
    if Assigned(ResObj) then
    begin
      clParent := ResObj.ClassType;
      if Assigned(Eng) then
      begin
        while (not Eng.ClassIsRegistered(clParent)) and (clParent <> TObject) do
          clParent := clParent.ClassParent;
      end;
        args.SetGetterResult(ResObj, clParent);
    end;
  end;

  procedure SetResultAsIface(resul: TValue);
  var
    ResDispatch: IDispatch;
  begin
    ResDispatch := TValueToDispatch(resul);
    Eng.FDispatchList.Add(ResDispatch);
    args.SetGetterResultIntf(Pointer(ResDispatch));
  end;

var
  ClassDescr: TJSClass;
  Prop: TRttiProperty;
  Result: TValue;
  ReturnType: TypInfo.TTypeKind;
  //debug variables (maybe)
  cl: TClass;
  obj: TObject;
  Helper: TJSClassExtender;
begin
  //invoke right method of right object;
  cl := TClass(args.GetDelphiClasstype);
  if not Assigned(cl) then
    raise EScriptEngineException.Create('Can''t get classtype of holder object: calling prop getter');
  Eng := TJSEngine(args.GetEngine);
  if not Assigned(Eng) then
    raise EScriptEngineException.Create('Engine is not initialized: internal dll error');
  try
    ClassDescr := Eng.FClasses.Items[cl];
    Prop := ClassDescr.FProps.Items[string(args.GetPropName)].prop;
    if cl = Eng.FGlobal.ClassType then
      obj := Eng.FGlobal
    else
      obj := args.GetDelphiObject;
    helper := ClassDescr.FProps.Items[string(args.GetPropName)].propObj;
    try
      if Assigned(Helper) then
      begin
        helper.Source := obj;
        Result := Prop.GetValue(helper);
        Helper.Source := nil;
      end
      else
        Result := Prop.GetValue(obj);
    except
      on E: EVariantTypeCastError do
      begin
        args.SetGetterResultUndefined;
        Exit;
      end;
      on E: Exception do
      begin
        args.SetError(PAnsiChar(UTF8String(e.ClassName + ': ' + E.Message)));
        Exit;
      end;
    end;
    if Assigned(Prop.PropertyType) then
    begin
      ReturnType := Prop.PropertyType.TypeKind;
      case ReturnType of
        tkUnknown: ;
        tkInteger: args.SetGetterResult(Result.AsInteger);
        tkChar: args.SetGetterResult(PAnsiChar(UTF8String(Result.AsString)));
        tkEnumeration: ;
        tkFloat: args.SetGetterResult(Result.AsExtended);
        tkString: args.SetGetterResult(PAnsiChar(UTF8String(Result.AsString)));
        tkSet: ;
        tkClass: SetResultAsObject(Result);
        tkMethod: ;
        tkWChar: args.SetGetterResult(PAnsiChar(UTF8String(Result.AsString)));
        tkLString: args.SetGetterResult(PAnsiChar(UTF8String(Result.AsString)));
        tkWString: args.SetGetterResult(PAnsiChar(UTF8String(Result.AsString)));
        tkVariant: ;
        tkArray: ;
        tkRecord:
        begin
          Eng.SetRecordIntoContext(Result, Prop.PropertyType, args.GetGetterResultAsRecord);
          args.SetGetterResultAsRecord;
        end;
        tkInterface: SetResultAsIface(Result);
        tkInt64: args.SetGetterResult(Result.AsInteger);
        tkDynArray: ;
        tkUString: args.SetGetterResult(PAnsiChar(UTF8String(Result.AsString)));
        tkClassRef: ;
        tkPointer: ;//args.SetGetterResult(Result.AsObject, Result.AsObject.ClassType);
        tkProcedure: ;
      end;
    end;
  except
    on E:Exception do
    begin
      if Assigned(eng.FLog) then
      begin
        if Eng.FIgnoredExceptions.IndexOf(e.ClassType) >= 0 then
          eng.FLog.Add('--' + E.Message)
        else
          eng.FLog.Add('Uncaught exception: ' + E.Message);
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

  procedure SetResultAsIface(val: TValue);
  var
    ResDispatch: IDispatch;
  begin
    ResDispatch := TValueToDispatch(val);
    Eng.FDispatchList.Add(ResDispatch);
    args.SetReturnValueIntf(Pointer(ResDispatch));
  end;

  procedure SetObjectAsResult(Obj: TObject);
  var
    clParent: TClass;
  begin
    if Assigned(Obj) then
    begin
      clParent := Obj.ClassType;
      if Assigned(Eng) then
      begin
        while (not Eng.ClassIsRegistered(clParent)) and (clParent <> TObject) do
          clParent := clParent.ClassParent;
      end;
      args.SetReturnValue(Obj, clParent);
    end;
  end;

var
  Valueargs: array of TValue;
  Overloads: TMethodOverloadMap;
  MethodInfo: TRttiMethodInfo;
  Method: TRttiMethod;
  count: integer;
  Result: TValue;
  ReturnType: TypInfo.TTypeKind;
  Parameters: TArray<TRttiParameter>;
  Attr: TCustomAttribute;
  //debug variables (maybe)
  cl: TClass;
  obj: TObject;
  Helper: TJSClassExtender;
begin
  //invoke right method of right object;
  Eng := TJSEngine(args.GetEngine);
  cl := TClass(args.GetDelphiClasstype);
  if not Assigned(cl) then
    raise EScriptEngineException.Create('Can''t get classtype of holder object: calling method');
  if not Assigned(Eng) then
    raise EScriptEngineException.Create('Engine is not initialized: internal dll error');
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
        Format('there is no overloads for "%s" method, which takes %d param(s)', [string(args.GetMethodName), count]));
    Parameters := Method.GetParameters;
    SetLength(Valueargs, Length(Parameters));
    SetArgs(Valueargs, count, Parameters);
    //choose object for method invoke
    if cl = Eng.FGlobal.ClassType then
      obj := Eng.FGlobal
    else
      obj := args.GetDelphiObject;
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
      ReturnType :=  Method.ReturnType.TypeKind;
      case ReturnType of
        tkUnknown: ;
        tkInteger: args.SetReturnValue(Result.AsInteger);
        tkChar: args.SetReturnValue(PAnsiChar(UTF8String(Result.AsString)));
        tkEnumeration: ;
        tkFloat: args.SetReturnValue(Result.AsExtended);
        tkString: args.SetReturnValue(PAnsiChar(UTF8String(Result.AsString)));
        tkSet: ;
        tkClass: SetObjectAsResult(Result.AsObject);
        tkMethod: ;
        tkWChar: args.SetReturnValue(PAnsiChar(UTF8String(Result.AsString)));
        tkLString: args.SetReturnValue(PAnsiChar(UTF8String(Result.AsString)));
        tkWString: args.SetReturnValue(PAnsiChar(UTF8String(Result.AsString)));
        tkVariant: ;
        tkArray: ;
        tkRecord:
        begin
          Eng.SetRecordIntoContext(Result, Method.ReturnType, args.GetReturnValueAsRecord);
          args.SetReturnValueAsRecord;
        end;
        tkInterface: SetResultAsIface(Result);
        tkInt64: args.SetReturnValue(Result.AsInteger);
        tkDynArray: ;
        tkUString: args.SetReturnValue(PAnsiChar(UTF8String(Result.AsString)));
        tkClassRef: ;
        tkPointer: ;//args.SetReturnValue(Result.AsObject, Result.AsObject.ClassType);
        tkProcedure: ;
      end;
    end;
  except
    on E:Exception do
    begin
      if Assigned(eng.FLog) then
      begin
        if Eng.FIgnoredExceptions.IndexOf(e.ClassType) >= 0 then
          eng.FLog.Add('--' + E.Message)
        else
          eng.FLog.Add('Uncaught exception: ' + E.Message);
      end;
    end;
  end;
end;

class procedure TJSEngine.callPropSetter(args: ISetterArgs);
var
  ClassDescr: TJSClass;
  Prop: TRttiProperty;
  //debug variables (maybe)
  cl: TClass;
  obj: TObject;
  helper: TJSClassExtender;
  Eng: TJSEngine;
begin
  //invoke right method of right object;
  cl := TClass(args.GetDelphiClasstype);
  if not Assigned(cl) then
    raise EScriptEngineException.Create('Can''t get classtype of holder object: calling prop setter');
  Eng := TJSEngine(args.GetEngine);
  if not Assigned(Eng) then
    raise EScriptEngineException.Create('Engine is not initialized: internal dll error');
  try
    ClassDescr := Eng.FClasses.Items[cl];
    Prop := ClassDescr.FProps.Items[string(args.GetPropName)].prop;
    if cl = Eng.FGlobal.ClassType then
      obj := Eng.FGlobal
    else
      obj := args.GetDelphiObject;
    helper := ClassDescr.FProps.Items[string(args.GetPropName)].propObj;
    try
      if Assigned(Helper) then
      begin
        helper.Source := obj;
        Prop.SetValue(helper, JsValToTValue(args.GetValue, Prop.PropertyType));
        Helper.Source := nil;
      end
      else
        Prop.SetValue(obj, JsValToTValue(args.GetValue, Prop.PropertyType));
    except
      on E: EVariantTypeCastError do
        Exit;
      on E: Exception do
      begin
        args.SetError(PAnsiChar(UTF8String(e.ClassName + ': ' + E.Message)));
        Exit;
      end;
    end;
  except
    on E:Exception do
    begin
      if Assigned(eng.FLog) then
      begin
        if Eng.FIgnoredExceptions.IndexOf(e.ClassType) >= 0 then
          eng.FLog.Add('--' + E.Message)
        else
          eng.FLog.Add('Uncaught exception: ' + E.Message);
      end;
    end;
  end;
end;

function TJSEngine.ClassIsRegistered(CType: TClass): boolean;
begin
  Result := FEngine.ClassIsRegistered(CType);
end;

constructor TJSEngine.Create;
begin
  FClasses := TClassMap.Create;
  FClassList := TObjectList.Create;
  FEngine := InitEngine(Self);
  FDebug := False;
  if not Assigned(FEngine) then
    raise EScriptEngineException.Create('Engine is not initialized: internal dll error');
  FGarbageCollector := TObjects.Create;
  FJSHelpers := TJSExtenderMap.Create;
  FJSHelpersList := TObjectList.Create(True);
  FIgnoredExceptions := TList<TClass>.Create;
  FIgnoredExceptions.Add(EScriptEngineException);
  FDispatchList := TInterfaceList.Create;
  FEnumList := TList<PTypeInfo>.Create;
  //set callbacks for methods, props, fields;
  FEngine.SetMethodCallBack(callMethod);
  FEngine.SetPropGetterCallBack(callPropGetter);
  FEngine.SetPropSetterCallBack(callPropSetter);
  FEngine.SetFieldGetterCallBack(callFieldGetter);
  FEngine.SetFieldSetterCallBack(callFieldSetter);
  FEngine.SetIndexedPropGetterCallBack(callIndexedPropGetter);
  FEngine.SetIndexedPropSetterCallBack(callIndexedPropSetter);
  FEngine.SetInterfaceGetterCallBack(callIntfGetter);
  FEngine.SetInterfaceSetterCallBack(callIntfSetter);
  FEngine.SetInterfaceMethodCallBack(callIntfMethod);
  FEngine.SetErrorMessageCallBack(SendErrToLog);
end;

destructor TJSEngine.Destroy;
begin
  FEnumList.Free;
  FClasses.Clear;
  FClasses.Free;
  FEngine.Delete;
  FJSHelpers.Free;
  FJSHelpersList.Free;
  FGarbageCollector.Clear;
  FGarbageCollector.Free;
  FClassList.Free;
  FIgnoredExceptions.Free;
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

function TJSEngine.RunFile(fileName, appPath: string): string;
var
  RawByteStr: RawByteString;
  CharPtr: PAnsiChar;
  AppDir: string;
begin
  AppDir := ExtractFilePath(appPath);
  try
    FScriptName := TPath.Combine(AppDir, fileName);
  except
    on E: EArgumentException do
    begin
      FLog.Add('Run script: ' + E.Message);
      Exit('Run script: ' + E.Message);
    end;
  end;
  Result := '';
  RawByteStr := UTF8Encode(FScriptName);
  FEngine.SetDebug(Debug);
  FAppPath := appPath;
  CharPtr := FEngine.RunFile(PansiChar(RawByteStr), PansiChar(UTF8String(appPath)));
  if Assigned(CharPtr) then
    Result := string(CharPtr);
  Result := '';
end;

procedure TJSEngine.AddIncludeCode(code: UTF8String);
begin
  FEngine.AddIncludeCode(PAnsiChar(code));
end;

function TJSEngine.RunIncludeFile(FileName: string): string;
var
  Utf8Str: UTF8String;
  CharPtr: PAnsiChar;
  ScriptFullPath: string;
begin
  Result := '';
  try
    ScriptFullPath := TPath.Combine(ExtractFilePath(FScriptName), FileName);
  except
    on E: EArgumentException do
    begin
      FLog.Add('Include file: ' + E.Message);
      Exit('Include file: ' + E.Message);
    end;
  end;
  Utf8Str := UTF8String(ScriptFullPath);
  try
    CharPtr := FEngine.RunIncludeFile(PansiChar(Utf8Str));
    if Assigned(CharPtr) then
        Result := string(CharPtr);
  except
    on e: Exception do
      Result := 'File couldn''t be included: internal node error';
  end;
end;

function TJSEngine.RunScript(code, appPath: string): string;
var
  codeStr: UTF8String;
  CharPtr: PAnsiChar;
begin
  Result := '';
  codeStr := UTF8String(code);
  FScriptName := appPath;
  FEngine.SetDebug(Debug);
  CharPtr := FEngine.RunString(PansiChar(codeStr), PansiChar(UTF8String(appPath)));
  if Assigned(CharPtr) then
    Result := PUtf8CharToString(CharPtr);
end;

class procedure TJSEngine.SendErrToLog(errMsg: PAnsiChar; eng: TObject);
var
  engine: TJSEngine;
begin
  if eng is TJSEngine then
  begin
    engine := eng as TJSEngine;
    if Assigned(engine.FLog) then
      engine.FLog.Add(UTF8ToUnicodeString(RawByteString(errMsg)));
  end;
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
    objTempl.SetHasIndexedProps(cl.FIndexedProps.Count > 0);
    cl.Initialized := True;
  end;
end;

procedure TJSEngine.SetDebug(const Value: boolean);
begin
  FDebug := Value;
  if Assigned(FEngine) then  
    FEngine.SetDebug(Value);
end;

procedure TJSEngine.SetLog(const Value: TStrings);
begin
  FLog := Value;
end;

procedure TJSEngine.SetRecordIntoContext(ValRecord: TValue; RecDescr: TRttiType;
  JSRecord: IRecord);
var
  FieldArr: TArray<TRttiField>;
  Field: TRttiField;
  PropArr: TArray<TRttiProperty>;
  Prop: TRttiProperty;
  ValueType: TRttiType;
begin
  FieldArr := RecDescr.GetFields;
  for Field in FieldArr do
  begin
    ValueType := Field.FieldType;
    if (Field.Visibility = mvPublic) and (Assigned(ValueType)) and (ValueType.TypeKind in tkProperties) then
    begin
      case Field.FieldType.TypeKind of
        tkUnknown: ;
        tkInteger: JSRecord.SetField(PAnsiChar(UTF8String(Field.Name)),
          Field.GetValue(ValRecord.GetReferenceToRawData).AsInteger);
        tkChar: ;
        tkEnumeration: ;
        tkFloat: JSRecord.SetField(PAnsiChar(UTF8String(Field.Name)),
          Field.GetValue(ValRecord.GetReferenceToRawData).AsExtended);
        tkString: JSRecord.SetField(PAnsiChar(UTF8String(Field.Name)),
          PAnsiChar(UTF8String(Field.GetValue(ValRecord.GetReferenceToRawData).AsString)));
        tkSet: ;
        tkClass: ;
        tkMethod: ;
        tkWChar: ;
        tkLString: ;
        tkWString: ;
        tkVariant: ;
        tkArray: ;
        tkRecord: ;
        tkInterface: ;
        tkInt64: ;
        tkDynArray: ;
        tkUString: ;
        tkClassRef: ;
        tkPointer: ;
        tkProcedure: ;
      end;
    end;
  end;

  PropArr := RecDescr.GetProperties;
  for Prop in PropArr do
  begin
    ValueType := Prop.PropertyType;
    if (Prop.Visibility = mvPublic) and (Assigned(ValueType)) and (ValueType.TypeKind in tkProperties) then
    begin
      case Prop.PropertyType.TypeKind of
        tkUnknown: ;
        tkInteger: JSRecord.SetField(PAnsiChar(UTF8String(Prop.Name)),
          Prop.GetValue(ValRecord.GetReferenceToRawData).AsInteger);
        tkChar: ;
        tkEnumeration: ;
        tkFloat: JSRecord.SetField(PAnsiChar(UTF8String(Prop.Name)),
          Prop.GetValue(ValRecord.GetReferenceToRawData).AsExtended);
        tkString: JSRecord.SetField(PAnsiChar(UTF8String(Prop.Name)),
          PAnsiChar(UTF8String(Prop.GetValue(ValRecord.GetReferenceToRawData).AsString)));
        tkSet: ;
        tkClass: ;
        tkMethod: ;
        tkWChar: ;
        tkLString: ;
        tkWString: ;
        tkVariant: ;
        tkArray: ;
        tkRecord: ;
        tkInterface: ;
        tkInt64: ;
        tkDynArray: ;
        tkUString: ;
        tkClassRef: ;
        tkPointer: ;
        tkProcedure: ;
      end;
    end;
  end;
end;

{ TJSClass }

procedure TJSClass.AddHelper(helper: TJSClassExtender);
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

