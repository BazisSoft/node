unit V8Api;

{$O-}
{$W+}
{$align 1}

interface

uses SysUtils, Windows, V8Interface, Variants, RTTI, TypInfo, ScriptInterface;

type

  jsval = IValue;

  IJSValueRef = interface
    function Value: IValue;
    procedure Make(val: IValue);
    procedure Clear;
  end;

  TJSValueRef = class(TInterfacedObject, IJSValueRef, ICallableMethod)
  private
    FValue: IValue;
  public
    constructor Create(val: IValue); overload;
    destructor Destroy; override;
    function Value: IValue;
    procedure Make(val: IValue);
    function CallValue(const Params: array of TValue): boolean; overload;
    procedure Call(Sender: TObject);
    procedure Clear;
  end;

  TJSCallback = record
  strict private
    FVal: IJSValueRef;
    FCallResult: jsval;
  public
    procedure Make(val: IValue);
    procedure Clear;
    function Func: IValue;
    function Call: boolean; overload;
    function Call(const Params: array of TValue): boolean; overload;
    property CallResult: jsval Read FCallResult;
  end;

  function JSValToDouble(val: jsval): Double;
  function JSValToObject(val: jsval): IObject;
  function JSValToInt(val: jsval): Integer;
//  function JSValToJSString(val: jsval): PJSString;
  function JSValToBoolean(val: jsval): Boolean;
  function JSValToString(val: jsval): UnicodeString;
  function JsValToTValue(val: jsval): TValue; overload;
  function JSvalToRecordTValue(val: jsval; typ: TRttiType): TValue;
  function JsValToTValue(val: jsval; typ: TRttiType): TValue; overload;
  function JSArrayToTValue(val: IValuesArray): TValue;

  function TValueToJSValue(val: TValue; typ: TRttiType; JSVal: IValue): boolean;

  function JSValIsObject(v: jsval): Boolean;
//  function JSValIsObjectClass(v: jsval; cl: TClass): Boolean;
//  function JSValIsNumber(v: jsval): Boolean;
  function JSValIsInt(v: jsval): Boolean;
  function JSValIsDouble(v: jsval): Boolean;
  function JSValIsString(v: jsval): Boolean;
  function JSValIsBoolean(v: jsval): Boolean;
//  function JSValIsNull(v: jsval): Boolean;
//  function JSValIsVoid(v: jsval): Boolean;

implementation

{ TJSValueRef }

procedure TJSValueRef.Call(Sender: TObject);
begin
  CallValue([TValue.From(Sender)]);
end;

function TJSValueRef.CallValue(const Params: array of TValue): boolean;
var
  k: integer;
  Func: IFunction;
begin
  Func := Value.AsFunction;
  Result := False;
  for k := 0 to High(Params) do
    case Params[k].Kind of
      tkInteger: Func.AddArg(Params[k].AsInteger);
      tkFloat: Func.AddArg(Params[k].AsExtended);
      tkClass: Func.AddArg(Params[k].AsObject);
      tkString: Func.AddArg(PAnsiChar(AnsiString(Params[k].AsString)));
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
    FCallResult := FVal.Value.AsFunction.CallFunction;
end;

function TJSCallback.Call(const Params: array of TValue): boolean;
var
  k: Integer;
  Func: IFunction;
begin
  Result := False;
  FCallResult := nil;
  if Assigned(FVal) then
  begin
    //set params to func
    Func := FVal.Value.AsFunction;
    for k := 0 to High(Params) do
    begin
      case Params[k].TypeInfo.Kind of
        tkInteger: Func.AddArg(Params[k].AsInteger);
        tkFloat: Func.AddArg(Params[k].AsExtended);
        tkString: Func.AddArg(PAnsiChar(AnsiString(Params[k].AsString)));
        tkClass: Func.AddArg(Params[k].AsObject);
        tkEnumeration: Func.AddArg(Params[k].AsBoolean);
      end;
    end;
    //call func
    FCallResult :=  Func.CallFunction;
  end;
end;

procedure TJSCallback.Clear;
begin
  FVal := nil;
end;

procedure TJSCallback.Make(val: IValue);
begin
  FVal := nil;
  FVal := TJSValueRef.Create;
  FVal.Make(val);
end;

function TJSCallback.Func: IValue;
begin
  if Assigned(FVal) then
    Result := FVal.Value
  else
    Result := nil;
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
    if Val.IsNumber then
      Result := TValue.FromVariant(val.AsNumber)
    else if val.IsInt then
      Result := TValue.FromVariant(val.AsInt)
    else if val.IsBool then
      Result := TValue.FromVariant(val.AsBool)
    else if val.IsString then
      Result := TValue.FromVariant(string(val.AsString))
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
      case Field.FieldType.TypeKind of
        tkUnknown: ;
        tkInteger: Field.SetValue(ref, rec.GetIntField(PAnsiChar(AnsiString(Field.Name))));
        tkChar: ;
        tkEnumeration: ;
        tkFloat: Field.SetValue(ref, rec.GetDoubleField(PAnsiChar(AnsiString(Field.Name))));
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

  function JsValToTValue(val: jsval; typ: TRttiType): TValue; overload;
  var
    TypeKind: TTypeKind;
    OptionCallBack: TOptionCallBack;
  begin
    TypeKind := typ.TypeKind;
    Result := '';
    case TypeKind of
      tkUnknown: ;
      tkInteger: Result := val.AsInt;
      tkChar: Result := string(val.AsString);
      tkEnumeration: ;
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
      tkLString: Result := AnsiString(UTF8ToUnicodeString(RawByteString(val.AsString)));
      tkWString: Result := UTF8ToUnicodeString(RawByteString(val.AsString));
      tkVariant: ;
      tkArray: ;
      tkRecord:
      begin
        if typ.Handle = TypeInfo(TOptionCallBack) then
        begin
          OptionCallBack.Event := nil;
          if val.IsV8Function then
            OptionCallback.Callable := TJSValueRef.Create(val)
          else
            OptionCallback.Callable := nil;;
          Result := TValue.From(OptionCallback);
        end
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

end.


