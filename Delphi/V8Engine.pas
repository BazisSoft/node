unit V8Engine;


interface

uses Classes, TypInfo, V8API, RTTI, types, Generics.Collections, SysUtils,
  Windows, syncObjs, IOUtils, Contnrs, ObjComAuto, ActiveX, Variants,
  V8Interface, ScriptInterface;

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
    FPath: string;
  public
    constructor Create(AEngine: TJSEngine; const APath: string);
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
  TMethodMap = TDictionary<string, TMethodOverloadMap>;
  TPropMap = TDictionary<string, TRttiProperty>;
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
    FGlobal: TObject;
    FSystem: TJSSystemNamespace;
    FEngine: IEngine;
    FGarbageCollector: TObjects;
    FJSExtenders: TJSExtenderMap;
    FFilename: string;
    FCode: string;
    FDebug: boolean;

    procedure SetGarbageCollector(const Value: TObjects);
    procedure SetClasses(const Value: TClassMap);
    procedure SetCode(const Value: string);
    procedure SetDebug(const Value: boolean);
    procedure SetFilename(const Value: string);

  public
    constructor Create;
    destructor Destroy; override;
    function AddClass(cType: TClass): TJSClass;
    function AddGlobal(global: TObject): TJSClass;
    procedure RegisterHelper(CType: TClass; HelperObject: TJSClassExtender);
    class procedure callMethod(args:IMethodArgs); static; stdcall;
    class procedure callPropGetter(args: IGetterArgs); static; stdcall;
    class procedure callPropSetter(args: ISetterArgs); static; stdcall;
    class procedure callFieldGetter(args: IGetterArgs); static; stdcall;
    class procedure callFieldSetter(args: ISetterArgs); static; stdcall;
    class procedure callIndexedPropGetter(args: IGetterArgs); static; stdcall;
    class procedure callIndexedPropSetter(args: ISetterArgs); static; stdcall;
    class function GetMethodInfo(List: TRttiMethodList; args: IMethodArgs): TRttiMethodInfo;

    property GarbageCollector: TObjects read FGarbageCollector write SetGarbageCollector;
    property Log: TStrings read FLog;
    property Classes: TClassMap read FClasses write SetClasses;
    property Debug: boolean read FDebug write SetDebug;
    property Code: string read FCode write SetCode;
    property Filename: string read FFilename write SetFilename;
    function RunScript(code, appPath: string): string;
    function RunFile(code, appPath: string): string;
    procedure SetClassIntoContext(cl: TJSClass);
    procedure SetRecordIntoContext(ValRecord: TValue; RecDescr: TRttiType; JSRecord: IRecord);
    function GetSystem: TJSSystemNamespace;
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

constructor TJSSystemNamespace.Create(AEngine: TJSEngine; const APath: string);
begin
  FPath := APath;
  FEngine := AEngine;
end;

procedure TJSSystemNamespace.include(const filename: string);
//var
////  rval: jsval_layout;
//  LFileStream: TResourceStream;
//  ResData: TBytes;
//  Encoding: TEncoding;
//  BOMLength: Integer;
//  FileText: string;
begin
//  if FResLib <> 0 then
//  begin
//    LFileStream := TResourceStream.Create(FResLib,
//      TPath.GetFileNameWithoutExtension(filename), RT_RCDATA);
//    try
//      SetLength(ResData, LFileStream.Size);
//      LFileStream.ReadBuffer(ResData, Length(ResData));
//      Encoding := nil;
//      BOMLength := TEncoding.GetBufferEncoding(ResData, Encoding);
//      FileText := Encoding.GetString(ResData, BOMLength, Length(ResData) - BOMLength);
//    finally
//      LFileStream.Free;
//    end;
//  end
//  else
//    FileText := TFile.ReadAllText(FPath + filename);
////  if not FEngine.EvaluateFile(filename, FileText, nil, rval) then
////    raise Exception.Create('Code tools init failed');
end;

procedure TJSSystemNamespace.log(const text: string);
begin
  FEngine.Log.Add(text);
end;

{ TJSEngine }

function TJSEngine.AddClass(cType: TClass): TJSClass;
var
  JsClass: TJSClass;
  helper: TJSClassExtender;
//  ParentClass: TJSClass;
begin
  Result := nil;
  if (cType = FGlobal.ClassType) or (cType = TObject) then
    Exit;
  if not FClasses.TryGetValue(cType, JsClass) then
  begin
    JsClass := TJSClass.Create(cType);
    if FJSExtenders.TryGetValue(cType, helper) then
      JsClass.AddHelper(helper);
    FClasses.Add(cType, JsClass);
//    if not FClasses.TryGetValue(cType.ClassParent, ParentClass) then
//    begin
//      ParentClass := AddClass(cType.ClassParent);
//    end;
    SetClassIntoContext(JsClass);
  end;
  Result := JsClass;
end;

function TJSEngine.AddGlobal(global: TObject): TJSClass;
var
  Overloads: TPair<string, TMethodOverloadMap>;
  Name: PAnsiChar;
  Methods: TMethodOverloadMap;
  cType: TClass;
  ClassTemplate: TJSClass;
  GlobalTemplate: IObjectTemplate;
  methodInfo: TRttiMethodInfo;
  method: TRttiMethod;
  propPair: TPair<string, TRttiProperty>;
  prop: TRttiProperty;
  ReturnClass: TClass;
  i: Integer;
begin
  cType := global.ClassType;
  FGlobal := global;
  ClassTemplate := TJSClass.Create(cType);
  GlobalTemplate := FEngine.AddGlobal(cType, global);
//  FEngine.SetGlobalClasstype(cType);
  for Overloads in ClassTemplate.Methods do
  begin
    Name := PAnsiChar(AnsiString(Overloads.Key));
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
    GlobalTemplate.SetMethod(Name, Methods);
  end;
  for propPair in ClassTemplate.FProps do
  begin
    prop := propPair.Value;
    if Assigned(prop.PropertyType) and (prop.PropertyType.TypeKind = tkClass) then
    begin
      ReturnClass := prop.PropertyType.Handle.TypeData.ClassType;
      AddClass(ReturnClass);
    end;
    GlobalTemplate.SetProp(PAnsiChar(AnsiString(prop.Name)),
      prop.IsReadable, prop.IsWritable);
  end;
  Result := ClassTemplate;
  FClasses.Add(cType, ClassTemplate);
end;

procedure TJSEngine.RegisterHelper(CType: TClass; HelperObject: TJSClassExtender);
begin
  if not FJSExtenders.ContainsKey(CType) then
    FJSExtenders.Add(CType, HelperObject);
end;

class procedure TJSEngine.callFieldGetter(args: IGetterArgs);
var
  ClassDescr: TJSClass;
  Field: TRttiField;
  Result: TValue;
  ReturnType: TypInfo.TTypeKind;
  //debug variables (maybe)
  cl: TClass;
  obj: TObject;
  Eng: TJSEngine;
begin
  //invoke right method of right object;
  cl := TClass(args.GetDelphiClasstype);
  Eng := TJSEngine(args.GetEngine);
  if not Assigned(Eng) then
    raise Exception.Create('Engine is not initialized, or dll error');
  begin
    ClassDescr := Eng.FClasses.Items[cl];
    Field := ClassDescr.FFields.Items[string(args.GetPropName)];
    if cl = Eng.FGlobal.ClassType then
    begin
      obj := Eng.FGlobal;
      if Field.Name = systemFieldName then
      begin
        args.SetGetterResult(Eng.FSystem, TJSSystemNamespace);
        Exit;
      end;
    end
    else
      obj := args.GetDelphiObject;
    Result := Field.GetValue(obj);
    if Assigned(Field.FieldType) then
    begin
      ReturnType :=  Field.FieldType.TypeKind;
      case ReturnType of
        tkUnknown: ;
        tkInteger: args.SetGetterResult(Result.AsInteger);
        tkChar: args.SetGetterResult(PAnsiChar(AnsiString(Result.AsString)));
        tkEnumeration: ;
        tkFloat: args.SetGetterResult(Result.AsExtended);
        tkString: args.SetGetterResult(PAnsiChar(AnsiString(Result.AsString)));
        tkSet: ;
        tkClass: args.SetGetterResult(Result.AsObject, Result.AsObject.ClassType);
        tkMethod: ;
        tkWChar: args.SetGetterResult(PAnsiChar(AnsiString(Result.AsString)));
        tkLString: args.SetGetterResult(PAnsiChar(AnsiString(Result.AsString)));
        tkWString: args.SetGetterResult(PAnsiChar(AnsiString(Result.AsString)));
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
        tkUString: args.SetGetterResult(PAnsiChar(AnsiString(Result.AsString)));
        tkClassRef: ;
        tkPointer: ;//args.SetGetterResult(Result.AsObject, Result.AsObject.ClassType);
        tkProcedure: ;
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
  Eng := TJSEngine(args.GetEngine);
  if not Assigned(Eng) then
    raise Exception.Create('Engine is not initialized, or dll error');
  begin
    ClassDescr := Eng.FClasses.Items[cl];
    Field := ClassDescr.FFields.Items[string(args.GetPropName)];
    if cl = Eng.FGlobal.ClassType then
      obj := Eng.FGlobal
    else
      obj := args.GetDelphiObject;
    Field.SetValue(obj, JsValToTValue(args.GetValue, Field.FieldType));
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
  Eng := TJSEngine(args.GetEngine);
  if not Assigned(Eng) then
    raise Exception.Create('Engine is not initialized, or dll error');
  begin
    ClassDescr := Eng.FClasses.Items[cl];
    Prop := ClassDescr.FDefaultIndexedProp;
    if cl = Eng.FGlobal.ClassType then
      obj := Eng.FGlobal
    else
      obj := args.GetDelphiObject;
    Result := Prop.GetValue(obj, [args.GetPropIndex]);
    if Assigned(Prop.PropertyType) then
    begin
      ReturnType :=  Prop.PropertyType.TypeKind;
      case ReturnType of
        tkUnknown: ;
        tkInteger: args.SetGetterResult(Result.AsInteger);
        tkChar: args.SetGetterResult(PAnsiChar(AnsiString(Result.AsString)));
        tkEnumeration: ;
        tkFloat: args.SetGetterResult(Result.AsExtended);
        tkString: args.SetGetterResult(PAnsiChar(AnsiString(Result.AsString)));
        tkSet: ;
        tkClass: args.SetGetterResult(Result.AsObject, Result.AsObject.ClassType);
        tkMethod: ;
        tkWChar: args.SetGetterResult(PAnsiChar(AnsiString(Result.AsString)));
        tkLString: args.SetGetterResult(PAnsiChar(AnsiString(Result.AsString)));
        tkWString: args.SetGetterResult(PAnsiChar(AnsiString(Result.AsString)));
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
        tkUString: args.SetGetterResult(PAnsiChar(AnsiString(Result.AsString)));
        tkClassRef: ;
        tkPointer: ;//args.SetGetterResult(Result.AsObject, Result.AsObject.ClassType);
        tkProcedure: ;
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
  Eng := TJSEngine(args.GetEngine);
  if not Assigned(Eng) then
    raise Exception.Create('Engine is not initialized, or dll error');
  begin
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
    end;
  end;
end;

class procedure TJSEngine.callPropGetter(args: IGetterArgs);
var
  ClassDescr: TJSClass;
  Prop: TRttiProperty;
  Result: TValue;
  ReturnType: TypInfo.TTypeKind;
  //debug variables (maybe)
  cl: TClass;
  obj: TObject;
  Eng: TJSEngine;
begin
  //invoke right method of right object;
  cl := TClass(args.GetDelphiClasstype);
  Eng := TJSEngine(args.GetEngine);
  if not Assigned(Eng) then
    raise Exception.Create('Engine is not initialized, or dll error');
  begin
    ClassDescr := Eng.FClasses.Items[cl];
    Prop := ClassDescr.FProps.Items[string(args.GetPropName)];
    if cl = Eng.FGlobal.ClassType then
      obj := Eng.FGlobal
    else
      obj := args.GetDelphiObject;
    Result := Prop.GetValue(obj);
    if Assigned(Prop.PropertyType) then
    begin
      ReturnType := Prop.PropertyType.TypeKind;
      case ReturnType of
        tkUnknown: ;
        tkInteger: args.SetGetterResult(Result.AsInteger);
        tkChar: args.SetGetterResult(PAnsiChar(AnsiString(Result.AsString)));
        tkEnumeration: ;
        tkFloat: args.SetGetterResult(Result.AsExtended);
        tkString: args.SetGetterResult(PAnsiChar(AnsiString(Result.AsString)));
        tkSet: ;
        tkClass: args.SetGetterResult(Result.AsObject, Result.AsObject.ClassType);
        tkMethod: ;
        tkWChar: args.SetGetterResult(PAnsiChar(AnsiString(Result.AsString)));
        tkLString: args.SetGetterResult(PAnsiChar(AnsiString(Result.AsString)));
        tkWString: args.SetGetterResult(PAnsiChar(AnsiString(Result.AsString)));
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
        tkUString: args.SetGetterResult(PAnsiChar(AnsiString(Result.AsString)));
        tkClassRef: ;
        tkPointer: ;//args.SetGetterResult(Result.AsObject, Result.AsObject.ClassType);
        tkProcedure: ;
      end;
    end;
  end;
end;

class procedure TJSEngine.callMethod(args: IMethodArgs);

  procedure SetArgs(var Valueargs: array of TValue; argsCount: integer;
    params: TArray<TRttiParameter>);
  var
    i:integer;
//    MethodArgsCount: integer;
  begin
    for i := 0 to argsCount - 1 do
    begin
      Valueargs[i] := JsValToTValue(args.GetArg(i), params[I].ParamType);
    end;
  end;

  procedure SetObjectAsResult(Obj: TObject);
  begin
    args.SetReturnValue(Obj, Obj.ClassType);
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
  Eng: TJSEngine;
begin
  //invoke right method of right object;
  cl := TClass(args.GetDelphiClasstype);
  Eng := TJSEngine(args.GetEngine);
  if not Assigned(Eng) then
    raise Exception.Create('Engine is not initialized, or dll error');
  begin
    Overloads := (args.GetDelphiMethod as TMethodOverloadMap);
    count := args.GetArgsCount;
    if Assigned(Overloads.MethodInfo.Method) then
      MethodInfo := Overloads.MethodInfo
    else if Assigned(Overloads.OverloadsInfo) then
      MethodInfo := GetMethodInfo(Overloads.OverloadsInfo, args);
    method := MethodInfo.Method;
    //TODO: Send Info about parameters count mismatch;
    if not Assigned(Method) or (Length(Method.GetParameters) <> count) then
      raise Exception.Create(Format('there is no overloads for "%s" method, which takes %d param(s)', [string(args.GetMethodName), count]));
    Parameters := Method.GetParameters;
    SetLength(Valueargs, count);
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
          Eng.GarbageCollector.AddObject(Result.AsObject);
    if Assigned(Method.ReturnType) then
    begin
      ReturnType :=  Method.ReturnType.TypeKind;
      case ReturnType of
        tkUnknown: ;
        tkInteger: args.SetReturnValue(Result.AsInteger);
        tkChar: args.SetReturnValue(PAnsiChar(AnsiString(Result.AsString)));
        tkEnumeration: ;
        tkFloat: args.SetReturnValue(Result.AsExtended);
        tkString: args.SetReturnValue(PAnsiChar(AnsiString(Result.AsString)));
        tkSet: ;
        tkClass: SetObjectAsResult(Result.AsObject);
        tkMethod: ;
        tkWChar: args.SetReturnValue(PAnsiChar(AnsiString(Result.AsString)));
        tkLString: args.SetReturnValue(PAnsiChar(AnsiString(Result.AsString)));
        tkWString: args.SetReturnValue(PAnsiChar(AnsiString(Result.AsString)));
        tkVariant: ;
        tkArray: ;
        tkRecord:
        begin
          Eng.SetRecordIntoContext(Result, Method.ReturnType, args.GetReturnValueAsRecord);
          args.SetReturnValueAsRecord;
        end;
        tkInterface: ;
        tkInt64: args.SetReturnValue(Result.AsInteger);
        tkDynArray: ;
        tkUString: args.SetReturnValue(PAnsiChar(AnsiString(Result.AsString)));
        tkClassRef: ;
        tkPointer: ;//args.SetReturnValue(Result.AsObject, Result.AsObject.ClassType);
        tkProcedure: ;
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
  Eng: TJSEngine;
begin
  //invoke right method of right object;
  cl := TClass(args.GetDelphiClasstype);
  Eng := TJSEngine(args.GetEngine);
  if not Assigned(Eng) then
    raise Exception.Create('Engine is not initialized, or dll error');
  begin
    ClassDescr := Eng.FClasses.Items[cl];
    Prop := ClassDescr.FProps.Items[string(args.GetPropName)];
    if cl = Eng.FGlobal.ClassType then
      obj := Eng.FGlobal
    else
      obj := args.GetDelphiObject;
    Prop.SetValue(obj, JsValToTValue(args.GetValue, Prop.PropertyType));
  end;
end;

constructor TJSEngine.Create;
begin
  FLog := TStringList.Create;
  FClasses := TClassMap.Create;
  FEngine := InitEngine(Self);
  FDebug := False;
  if not Assigned(FEngine) then
    raise Exception.Create('Engine is not initialized, I don''t know why exception didn''t created before');
  FGarbageCollector := TObjects.Create;
  FSystem := TJSSystemNamespace.Create(Self, '');
  FJSExtenders := TJSExtenderMap.Create;
  //set callbacks for methods, props, fields;
  FEngine.SetMethodCallBack(callMethod);
  FEngine.SetPropGetterCallBack(callPropGetter);
  FEngine.SetPropSetterCallBack(callPropSetter);
  FEngine.SetFieldGetterCallBack(callFieldGetter);
  FEngine.SetFieldSetterCallBack(callFieldSetter);
  FEngine.SetIndexedPropGetterCallBack(callIndexedPropGetter);
  FEngine.SetIndexedPropSetterCallBack(callIndexedPropSetter);
end;

destructor TJSEngine.Destroy;
begin
  FLog.Free;
  FClasses.Clear;
  FClasses.Free;
  FEngine.Delete;
  FJSExtenders.Free;
  FGarbageCollector.Clear;
  FGarbageCollector.Free;
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
        case PArams[i].ParamType.TypeKind of
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

function TJSEngine.GetSystem: TJSSystemNamespace;
begin
  Result := FSystem;
end;

function TJSEngine.RunFile(code, appPath: string): string;
var
  AnsiStr: AnsiString;
  CharPtr: PAnsiChar;
begin
  Self.Code := code;
  Result := '';
  AnsiStr := AnsiString(code);
  FEngine.InitializeContext;
  FEngine.SetDebug(Debug);
  CharPtr := FEngine.RunFile(PansiChar(AnsiStr), PansiChar(AnsiString(appPath)));
  if Assigned(CharPtr) then  
    Result := string(CharPtr);
end;

function TJSEngine.RunScript(code, appPath: string): string;
var
  AnsiStr: AnsiString;
begin
  Self.Code := code;
  Result := '';
  AnsiStr := AnsiString(code);
  FEngine.InitializeContext;
  FEngine.SetDebug(Debug);
  Result := string(FEngine.RunString(PansiChar(AnsiStr), PansiChar(AnsiString(appPath))));;
end;

procedure TJSEngine.SetClasses(const Value: TClassMap);
begin
  FClasses := Value;
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
  PropPair: TPair<string, TRttiProperty>;
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
      if FJSExtenders.TryGetValue(clParent, helper) then
        cl.AddHelper(helper);
      clParent := clParent.ClassParent;
    end;
    objTempl := FEngine.AddObject(PAnsiChar(AnsiString(cl.Ftype.ToString)), cl.FClasstype);
    objTempl.SetParent(GetParent(cl.cType.ClassParent));
    for Overloads in cl.FMethods do
    begin
      Methods := Overloads.Value;
      if Assigned(Methods.MethodInfo.Method) then
      begin
        method := Methods.MethodInfo.Method;
//        if (method.Parent.Handle.TypeData.ClassType = TObject) then
//          continue;
        if Assigned(method.ReturnType) and (method.ReturnType.TypeKind = tkClass) then
        begin
          ReturnClass := method.ReturnType.Handle.TypeData.ClassType;
          AddClass(ReturnClass);
        end;
      end
      else if Assigned(Methods.OverloadsInfo) then
        for i := 0 to Methods.OverloadsInfo.Count - 1 do
        begin
          method := Methods.OverloadsInfo[i].Method;
//          if (method.Parent.Handle.TypeData.ClassType = TObject) then
//            continue;
          if Assigned(method.ReturnType) and (method.ReturnType.TypeKind = tkClass) then
          begin
            ReturnClass := method.ReturnType.Handle.TypeData.ClassType;
            AddClass(ReturnClass);
          end;
        end;
      objTempl.SetMethod(PAnsiChar(AnsiString(Overloads.Key)), Methods);
    end;
    for PropPair in cl.FProps do
    begin
      Prop := PropPair.Value;
      objTempl.SetProp(PAnsiChar(AnsiString(Prop.Name)), Prop.IsReadable, Prop.IsWritable);
    end;
    for FieldPair in cl.FFields do
    begin
      field := FieldPair.Value;
      objTempl.SetField(PAnsiChar(AnsiString(field.Name)));
    end;
    objTempl.SetHasIndexedProps(cl.FIndexedProps.Count > 0);
    cl.Initialized := True;
  end;
end;

procedure TJSEngine.SetCode(const Value: string);
begin
  FCode := Value;
  FFilename := '';
end;

procedure TJSEngine.SetDebug(const Value: boolean);
begin
  FDebug := Value;
  if Assigned(FEngine) then  
    FEngine.SetDebug(Value);
end;

procedure TJSEngine.SetFilename(const Value: string);
begin
  FFilename := Value;
  FCode := '';
end;

procedure TJSEngine.SetGarbageCollector(const Value: TObjects);
begin
  FGarbageCollector := Value;
end;

procedure TJSEngine.SetRecordIntoContext(ValRecord: TValue; RecDescr: TRttiType;
  JSRecord: IRecord);
var
  FieldArr: TArray<TRttiField>;
  Field: TRttiField;
begin
  FieldArr := RecDescr.GetFields;
  for Field in FieldArr do
  begin
    if (Field.Visibility = mvPublic) and (Field.FieldType.TypeKind in tkProperties) then
    begin
      case Field.FieldType.TypeKind of
        tkUnknown: ;
        tkInteger: JSRecord.SetField(PAnsiChar(AnsiString(Field.Name)),
          Field.GetValue(ValRecord.GetReferenceToRawData).AsInteger);
        tkChar: ;
        tkEnumeration: ;
        tkFloat: JSRecord.SetField(PAnsiChar(AnsiString(Field.Name)),
          Field.GetValue(ValRecord.GetReferenceToRawData).AsExtended);
        tkString: JSRecord.SetField(PAnsiChar(AnsiString(Field.Name)),
          PAnsiChar(AnsiString(Field.GetValue(ValRecord.GetReferenceToRawData).AsString)));
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
        overloads.OverloadsInfo.Add(methodInfo);
      end;
    end;
  end;
end;

constructor TJSClass.Create(classType: TClass);
var
  MethodArr: TArray<TRttiMethod>;
  overloads: TMethodOverloadMap;
  methodInfo: TRttiMethodInfo;
  method: TRttiMethod;

  PropArr: TArray<TRttiProperty>;
  prop: TRttiProperty;

  FieldArr: TArray<TRttiField>;
  field: TRttiField;

  IndPropArr: TArray<TRttiIndexedProperty>;
  indProp: TRttiIndexedProperty;

begin
  inherited Create();
  FMethods := TMethodMap.Create;
  FProps := TPropMap.Create;
  FFields := TFieldMap.Create;
  FIndexedProps := TIndexedPropMap.Create;
  FClasstype := classType;
  Ftype := RttiContext.GetType(FClasstype);
  MethodArr := Ftype.GetMethods;
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
    if FProps.ContainsKey(prop.Name) then
      continue;
    if (prop.PropertyType.TypeKind in tkProperties) and (prop.Visibility = mvPublic) then
      FProps.Add(prop.Name, prop);
  end;
  FieldArr := Ftype.GetFields;
  for field in FieldArr do
  begin
    if Fields.ContainsKey(field.Name) then
      continue;
    if (field.FieldType.TypeKind in tkProperties) and (field.Visibility = mvPublic) then
      FFields.Add(field.Name, field);
  end;
  IndPropArr := Ftype.GetIndexedProperties;
  for indProp in IndPropArr do
  begin
    if FIndexedProps.ContainsKey(indProp.Name) then
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

