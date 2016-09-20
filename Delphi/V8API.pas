unit V8Api;

{$O-}
{$W+}
{$align 1}

interface

uses SysUtils, Windows, V8Interface, Variants, RTTI, TypInfo, ScriptInterface,
WinApi.ActiveX;

type

  jsval = IValue;

  TJSValueRef = class(TInterfacedObject, ICallableMethod)
  private
    FValue: IValue;
  public
    constructor Create(val: IValue); overload;
    destructor Destroy; override;
    function Value: IValue;
    procedure Make(val: IValue);
    function Call(const Params: array of TValue): TValue; overload;
    procedure Clear;
  end;

  [TCallBackAttr]
  TJSCallback = record
  strict private
    FVal: ICallableMethod;
    FCallResult: TValue;
  public
    [TCallBackFuncAttr]
    procedure SetFunction(value: ICallableMethod);
    function Call: boolean; overload;
    function Call(const Params: array of TValue): boolean; overload;
    property CallResult: TValue Read FCallResult;
  end;

  function JSValToDouble(val: jsval): Double;
  function JSValToObject(val: jsval): IObject;
  function JSValToInt(val: jsval): Integer;
//  function JSValToJSString(val: jsval): PJSString;
  function JSValToBoolean(val: jsval): Boolean;
  function JSValToString(val: jsval): UnicodeString;
  function JsValToTValue(val: jsval): TValue; overload;
  function JsValToTValue(val: jsval; typ: TRttiType): TValue; overload;
  function JSvalToRecordTValue(val: jsval; typ: TRttiType): TValue;
  function JSvalToCallBackRecord(val: jsval; typ: TRttiType): TValue;
  function DefaultTValue(typ: TRttiType): TValue;
  function JSArrayToTValue(val: IValuesArray): TValue;

  function JSValIsObject(v: jsval): Boolean;
//  function JSValIsObjectClass(v: jsval; cl: TClass): Boolean;
//  function JSValIsNumber(v: jsval): Boolean;
  function JSValIsInt(v: jsval): Boolean;
  function JSValIsDouble(v: jsval): Boolean;
  function JSValIsString(v: jsval): Boolean;
  function JSValIsBoolean(v: jsval): Boolean;
//  function JSValIsNull(v: jsval): Boolean;
//  function JSValIsVoid(v: jsval): Boolean;

  function TValueToJSValue(val: TValue; typ: TRttiType; JSVal: IValue): boolean; overload;
  function TValueToJSValue(val: TValue; Eng: IEngine): IValue; overload;
  function TValueToDispatch(val: TValue): IDispatch;
  function TValueArrayToJSArray(initArray: array of TValue;
    resArray: IValuesArray; Eng: IEngine): boolean;

  function PUtf8CharToString(s: PAnsiChar): string;

  function TypeHasAttribute(typ: TRttiType; attrClass: TAttrClass): boolean;
  function MethodHasAttribute(method: TRttiMethod; attrClass: TAttrClass): boolean;

  function ExecuteOnDispatchMultiParamProp(TargetObj: IDispatch;
    PropName: string; writeValue: TValue; var IsProperty: boolean): TValue;
  function ExecuteOnDispatchMultiParamFunc(TargetObj: IDispatch;
    FuncName: string; ParamValues: Array of TValue): TValue;

implementation

{ TJSValueRef }

function TJSValueRef.Call(const Params: array of TValue): TValue;
var
  k: integer;
  Func: IFunction;
  Obj: TObject;
begin
  Func := Value.AsFunction;
  Result := False;
  for k := 0 to High(Params) do
    case Params[k].Kind of
      tkInteger: Func.AddArg(Params[k].AsInteger);
      tkFloat: Func.AddArg(Params[k].AsExtended);
      tkClass:
      begin
        Obj := Params[k].AsObject;
        Func.AddArg(Obj, obj.ClassType);
      end;
      tkString: Func.AddArg(PAnsiChar(UTF8String(Params[k].AsString)));
    end;
  Func.CallFunction;
end;

procedure TJSValueRef.Clear;
begin
  FValue := nil;
end;

constructor TJSValueRef.Create(val: IValue);
begin
  inherited Create;
  if not val.IsV8Function then
    raise EScriptEngineException.Create('Value assigned to callback is not function');
  Make(val);
end;

destructor TJSValueRef.Destroy;
begin
  Clear;
  inherited;
end;

procedure TJSValueRef.Make(val: IValue);
begin
  Clear;
  FValue := Val;
end;

function TJSValueRef.Value: IValue;
begin
  Result := FValue;
end;

{ TJSCallback }

function TJSCallback.Call: boolean;
begin
  Result := False;
  FCallResult := nil;
  if Assigned(FVal) then
    FCallResult := FVal.Call([]);
end;

function TJSCallback.Call(const Params: array of TValue): boolean;
var
  k: Integer;
  Func: IFunction;
begin
  Result := False;
  if Assigned(FVal) then
  begin
    FCallResult := FVal.Call(Params);
    Result := True;
  end;
end;

procedure TJSCallback.SetFunction(value: ICallableMethod);
begin
  FVal := value;
end;

  function JSValToDouble(val: jsval): Double;
  begin
    if val.IsNumber then
      result := val.AsNumber
    else
      try
        raise Exception.Create('val is not number');
      finally
        Result := 0.0;
      end;
  end;

  function JSValToObject(val: jsval): IObject;
  begin
    if val.IsObject then
      result := val.AsObject
    else
      try
        raise Exception.Create('val is not object');
      finally
        Result := nil;
      end;
  end;

  function JSValToInt(val: jsval): Integer;
  begin
    if val.IsInt then
      result := val.AsInt
    else
      try
        raise Exception.Create('val is not int');
      finally
        Result := 0;
      end;
  end;

  function JSValToBoolean(val: jsval): Boolean;
  begin
    if val.IsBool then
      result := val.AsBool
    else
      try
        raise Exception.Create('val is not boolean');
      finally
        Result := false;
      end;
  end;

  function JSValToString(val: jsval): UnicodeString;
  begin
    if val.IsString then
      result := UTF8ToUnicodeString(RawByteString(val.AsString))
    else
      try
        raise Exception.Create('val is not string');
      finally
        Result := '';
      end;
  end;

  function JSArrayToTValue(val: IValuesArray): TValue;
  var
    TValueArr: array of TValue;
    i, count: integer;
  begin
    count := val.GetCount;
    SetLength(TValueArr, count);
    for i := 0 to count - 1 do
    begin
      TValueArr[i] := JsValToTValue(val.GetValue(i));
    end;
                             //fix that
    Result := TValue.FromArray(Result.TypeInfo, TValueArr);
  end;

  function JsValToTValue(val: jsval): TValue;
  begin
    //checking for type
    if val.IsBool then
      Result := TValue.FromVariant(val.AsBool)
    else if val.IsInt then
      Result := TValue.FromVariant(val.AsInt)
    else if Val.IsNumber then
      Result := TValue.FromVariant(val.AsNumber)
    else if val.IsString then
      Result := TValue.FromVariant(PUtf8CharToString(val.AsString))
    else if (val.IsObject) and (val.AsObject.IsDelphiObject) then
      Result := TValue.From<TObject>(val.AsObject.GetDelphiObject)
    else if val.IsArray then
      Result := JSArrayToTValue(val.AsArray);
  end;

  function JSvalToRecordTValue(val: jsval; typ: TRttiType): TValue;
  var
    FieldsArr: TArray<TRttiField>;
    Field: TRttiField;
    Rec: IRecord;
    ref: Pointer;
  begin
    if typ.TypeKind <> tkRecord then
      Exit;
    Rec := val.AsRecord;
    TValue.Make(nil, typ.Handle, Result);
    FieldsArr := typ.GetFields;
    ref := Result.GetReferenceToRawData;
    for Field in FieldsArr do
    begin
      if not Assigned(Field.FieldType) then
        Continue;
      case Field.FieldType.TypeKind of
        tkUnknown: ;
        tkInteger: Field.SetValue(ref, rec.GetIntField(PAnsiChar(UTF8String(Field.Name))));
        tkChar: ;
        tkEnumeration: ;
        tkFloat: Field.SetValue(ref, rec.GetDoubleField(PAnsiChar(UTF8String(Field.Name))));
        tkString: ;
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

  function JSvalToCallBackRecord(val: jsval; typ: TRttiType): TValue;
  var
    ref: Pointer;
    MethodArr: TArray<TRttiMethod>;
    method, rightMethod: TRttiMethod;
    callBack: ICallableMethod;
  begin
    TValue.Make(nil, typ.Handle, Result);
    MethodArr := typ.GetMethods;
    rightMethod := nil;
    for method in MethodArr do
      if MethodHasAttribute(method, TCallBackFuncAttr) then
      begin
        rightMethod := method;
        break;
      end;
    if Assigned(rightMethod) and (Length(rightMethod.GetParameters) = 1) then
    begin
      if (val.IsUndefined) then
        callBack := nil
      else
        callBack := TJSValueRef.Create(val);
      rightMethod.Invoke(Result, [TValue.From(callBack)]);
    end;
  end;

  function JsValToTValue(val: jsval; typ: TRttiType): TValue; overload;
  var
    TypeKind: TypInfo.TTypeKind;
  begin
    Result := '';
    if not Assigned(typ) then
      Exit;
    TypeKind := typ.TypeKind;
    case TypeKind of
      tkUnknown: ;
      tkInteger: Result := val.AsInt;
      tkChar: Result := string(val.AsString);
      tkEnumeration: Result := TValue.FromOrdinal(typ.Handle, val.AsInt);
      tkFloat: Result := val.AsNumber;
      tkString: Result := UTF8ToUnicodeString(RawByteString(val.AsString));
      tkSet: ;
      tkClass:
      begin
        if val.AsObject.IsDelphiObject then
          Result := TValue.From<TObject>(val.AsObject.GetDelphiObject)
      end;
      tkMethod: ;
      tkWChar: Result := UTF8ToUnicodeString(RawByteString(val.AsString));
      tkLString: Result := (UTF8ToUnicodeString(RawByteString(val.AsString)));
      tkWString: Result := UTF8ToUnicodeString(RawByteString(val.AsString));
      tkVariant: Result := JsValToTValue(val);
      tkArray: ;
      tkRecord:
      begin
        if TypeHasAttribute(typ, TCallBackAttr) then
          Result := JSvalToCallBackRecord(val, typ)
        else
          Result := JSvalToRecordTValue(val, typ);
      end;
      tkInterface: ;
      tkInt64: Result := JSValToInt(val);
      tkDynArray: ;

      tkUString: Result := UTF8ToUnicodeString(RawByteString(val.AsString));
      tkClassRef: ;
      tkPointer: ;
      tkProcedure: ;
    end;
  end;

  function DefaultTValue(typ: TRttiType): TValue;
  begin
    Result := TValue.Empty;
    if not Assigned(typ) then
      Exit;
    case typ.TypeKind of
      tkUnknown: ;
      tkInteger: Result := 0;
      tkChar: Result := '';
      tkEnumeration: Result := 0;
      tkFloat: Result := 0.0;
      tkString: Result := '';
      tkSet: ;
      tkClass: Result := nil;
      tkMethod: Result := nil;
      tkWChar: Result := '';
      tkLString: Result := '';
      tkWString: Result := '';
      tkVariant: Result := '';
      tkArray: ;
      tkRecord: ;
      tkInterface: Result := nil;
      tkInt64: Result := 0;
      tkDynArray: ;
      tkUString: Result := '';
      tkClassRef: ;
      tkPointer: Result := nil;
      tkProcedure: Result := nil;
    end;
  end;

  function JSValIsObject(v: jsval): Boolean;
  begin
    result := v.IsObject;
  end;

  function JSValIsDouble(v: jsval): Boolean;
  begin
    result := v.IsNumber;
  end;

  function JSValIsInt(v: jsval): Boolean;
  begin
    result := v.IsInt;
  end;

  function JSValIsBoolean(v: jsval): Boolean;
  begin
    result := v.IsBool;
  end;

  function JSValIsString(v: jsval): Boolean;
  begin
    result := v.IsString;
  end;

  function TValueToJSValue(val: TValue; typ: TRttiType; JSVal: IValue): boolean;
  begin
    Result := False;
     //todo
  end;

  function TValueToJSValue(val: TValue; Eng: IEngine): IValue; overload;
  var
    valType: Typinfo.TTypeKind;
  begin
    Result := nil;
    valType := val.Kind;
    case valType of
      tkUnknown: ;
      tkInteger: Result := Eng.NewValue(val.AsInteger);
      tkChar: ;
      tkEnumeration: ;
//      tkFloat: Result := Eng.NewValue(val.AsExtended);
      tkString: Result := Eng.NewValue(PAnsiChar(Utf8String(val.AsString)));
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

  function TValueToDispatch(val: TValue): IDispatch;
  var
    DispIntf: IDispatch;
  begin
    Result := nil;
    if val.AsInterface.QueryInterface(IDispatch, DispIntf) = S_OK then
    begin
      Result := DispIntf;
    end
  end;

  function TValueArrayToJSArray(initArray: array of TValue;
    resArray: IValuesArray; Eng: IEngine): boolean;
  var
    count: integer;
    i: Integer;
    initValue: TValue;
    resValue: IValue;
  begin
    count := Length(initArray);
    if count > resArray.GetCount then
      raise EScriptEngineException.Create('Result array count is less than init array count');
    for i := 0 to count - 1 do
    begin
      resValue := TValueToJSValue(initValue, Eng);
      resArray.SetValue(resValue, i);
    end;
  end;

  function PUtf8CharToString(s: PAnsiChar): string;
  begin
    Result := UTF8ToUnicodeString(RawByteString(s));
  end;

  function TypeHasAttribute(typ: TRttiType; attrClass: TAttrClass): boolean;
  var
    Attributes: TArray<TCustomAttribute>;
    attr: TCustomAttribute;
  begin
    Result := False;
    Attributes := typ.GetAttributes;
    for attr in Attributes do
      if Assigned(attr) and (attr is attrClass) then
        Exit(True)
  end;

  function MethodHasAttribute(method: TRttiMethod; attrClass: TAttrClass): boolean;
  var
    Attributes: TArray<TCustomAttribute>;
    attr: TCustomAttribute;
  begin
    Result := False;
    Attributes := method.GetAttributes;
    for attr in Attributes do
      if Assigned(attr) and (attr is attrClass) then
        Exit(True)
  end;

  function ExecuteOnDispatchMultiParamProp(
    TargetObj: IDispatch;
    PropName: string;
    writeValue: TValue;
    var IsProperty: boolean): TValue;
  var
    wide: widestring;
    disps: TDispIDList;
    panswer: ^Variant;
    answer: Variant;
    dispParams: TDispParams;
    aexception: TExcepInfo;
    res: HResult;
    ParamCount: Integer;
    DispIDNamed: Longint;
    CallFlags: Word;
    pVarArg: PVariantArgList;
    WriteProp: boolean;
    VariantVal: OleVariant;
  begin
    Result := TValue.Empty;
    WriteProp := not writeValue.IsEmpty;
    IsProperty := True;
    wide := PropName;
    ParamCount := 0;
    pVarArg := nil;
    // get dispid of requested method
    if not succeeded(TargetObj.GetIDsOfNames(GUID_NULL, @wide, 1, 0, @disps)) then
      raise Exception.Create('This object does not support this method');
    pAnswer := @answer;
    // prepare dispatch parameters
    dispparams.rgvarg := nil;
    dispparams.rgdispidNamedArgs := nil;
    dispparams.cArgs := ParamCount;
    dispparams.cNamedArgs := 0;

    if WriteProp then
    begin
      VariantVal := writeValue.AsVariant;
      dispParams.rgvarg := @VariantVal;
      dispParams.cArgs := 1;
      CallFlags := DISPATCH_PROPERTYPUT;
      dispParams.cNamedArgs := 1;
      DispIDNamed := DISPID_PROPERTYPUT;
      dispParams.rgdispidNamedArgs := @DispIDNamed;
    end
    else
      CallFlags := DISPATCH_PROPERTYGET;

    res := TargetObj.Invoke(disps[0],
      GUID_NULL, 0, CallFlags,
      dispParams, pAnswer, @aexception, nil);
    // check the result
    if res <> 0 then
    begin
      ////if write prop, then we cant use method anyway
      if WriteProp then
        raise EScriptEngineException.CreateFmt(
          'Method call unsuccessfull. %s (%s).',
          [string(aexception.bstrDescription), string(aexception.bstrSource)])
      else
      begin
        IsProperty := False;
        Exit;
      end;
    end;
    // return the result
    Result := TValue.FromVariant(answer);
  end;

  function ExecuteOnDispatchMultiParamFunc(
    TargetObj: IDispatch;
    FuncName: string;
    ParamValues: Array of TValue): TValue;
  var
    wide: widestring;
    disps: TDispIDList;
    panswer: ^Variant;
    answer: Variant;
    dispParams: TDispParams;
    aexception: TExcepInfo;
    res: HResult;
    CallFlags: Word;
    DispIDNamed: Longint;
    pVarArg: PVariantArgList;
    ParamCount: Integer;
    i: integer;
    params: array of OleVariant;
  begin
    Result := TValue.Empty;
    ParamCount := High(ParamValues) + 1;
    SetLength(params, ParamCount);
    for i := 0 to ParamCount - 1 do
    begin
      Params[i] := paramValues[i].AsVariant;
    end;
    wide := FuncName;
    pVarArg := nil;
    // get dispid of requested method
    if not succeeded(TargetObj.GetIDsOfNames(GUID_NULL, @wide, 1, 0, @disps)) then
      raise Exception.Create('This object does not support this method');
    pAnswer := @answer;
    // prepare dispatch parameters
    if Length(ParamValues) > 0 then
      dispparams.rgvarg := @Params[0]
    else
      dispparams.rgvarg := nil;
    //dispparams.rgvarg := pVarArg;
    dispparams.rgdispidNamedArgs := nil;
    dispparams.cArgs := ParamCount;
    dispparams.cNamedArgs := 0;

    res := TargetObj.Invoke(disps[0],
    GUID_NULL, 0, DISPATCH_METHOD,
    dispParams, pAnswer, @aexception, nil);
    if res <> 0 then
      raise Exception.CreateFmt(
        'Method call unsuccessfull. %s (%s).',
        [string(aexception.bstrDescription), string(aexception.bstrSource)]);

    // return the result
    Result := TValue.FromVariant(answer);
  end;

end.


