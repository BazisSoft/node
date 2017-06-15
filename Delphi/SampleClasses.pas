unit SampleClasses;

interface

uses ScriptInterface, Generics.Collections, RTTI, V8Engine;

type

[TCallBackAttr]
  TSampleCallback = record
    Callable: ICallableMethod;
    [TCallBackFuncAttr]
    procedure SetCallable(calla: ICallableMethod);
    procedure Call(Sender: TObject);
    function Assigned: boolean;
  end;

  //just vectors
  TVector2 = record
    x, y: double;
  end;

  TVector3 = record
  public
    x: double;
    y: double;
    z: double;
    constructor Create(ax, ay, az: double);
    function Length: double;
    [TGCAttr]
    function Copy: TVector3;
    function ToV2: TVector2;
  end;

  //class with callback
  TCallBackClass = class
  private
    FOnValueChange: TSampleCallback;
    FValue: double;
    procedure SetOnValueChange(const Value: TSampleCallback);
    procedure SetValue(const Value: double);
  public
    property Value: double read FValue write SetValue;
    property OnValueChange: TSampleCallback read FOnValueChange write SetOnValueChange;
  end;

  //some classes
  TSomeObject = class
  private
    FSomeValue: Double;
  public
    property Value: Double read FSomeValue write FSomeValue;
  end;

  TSomeList = class(TList<TSomeObject>)
  end;

  TSomeChild = class(TSomeObject)
  end;

  //some helpers
  TSomeObjectHelper = class(TJSClassExtender)
  private
  public
    function ValueSqr: double;
  end;

  TSomeChildHelper = class(TJSClassExtender)
  public
    function ValueX2:Double;
  end;

  //class with custom attributes
  TSomeAttrObject = class
  public
    [TMethodForbiddenAttr]
    function GetForbiddenNumber: integer;
    function GetNumber: integer;
  end;

  //this class and all methods, create him, sholdn't exist in scripts
  [TObjectForbiddenAttr]
  TSomeForbiddenObject = class
  public
    function Get5: integer;
  end;

  ISomeIntf = interface
    function GetClassName: string;
  end;

  TSomeIntfObj = class(TInterfacedObject, ISomeIntf)
    function GetClassName: string;
  end;

  TGlobalNamespace = class
  private
    FEng: TJSEngine;
    FSys: TJSSystemNamespace;
    FSomeHelper: TSomeObjectHelper;
    FChildHelper: TSomeChildHelper;
    function GetSystem: TJSSystemNamespace;
  public
    constructor Create(Eng: TJSEngine);
    destructor Destroy; override;
    procedure log(str: string);
    procedure alert(str: string);
    property system: TJSSystemNamespace read GetSystem;
    [TGCAttr]
    function NewVector(x: double = 0; y: double = 0; z: double = 0): TVector3;
    [TGCAttr]
    function NewCallBackClass: TCallBackClass;
    [TGCAttr]
    function NewSomeObject: TSomeObject;
    [TGCAttr]
    function NewSomeList: TSomeList;
    [TGCAttr]
    function NewSomeChild: TSomeChild;
    [TGCAttr]
    function NewAttrObject: TSomeAttrObject;
    [TGCAttr]
    function NewForbiddenObject: TSomeForbiddenObject;
    function Length(vec: TVector3): double;
  end;

implementation

{ TVector3 }

function TVector3.Copy: TVector3;
begin
  Result := TVector3.Create(x, y, z);
end;

constructor TVector3.Create(ax, ay, az: double);
begin
  x := ax;
  y := ay;
  z := az;
end;

function TVector3.Length: double;
begin
  Result := Sqrt(x*x + y*y + z*z);
end;

function TVector3.ToV2: TVector2;
begin
  Result.x := x;
  Result.y := y;
end;

{ TCallBackClass }

procedure TCallBackClass.SetOnValueChange(const Value: TSampleCallback);
begin
  FOnValueChange := Value;
end;

procedure TCallBackClass.SetValue(const Value: double);
begin
  if FOnValueChange.Assigned then
    FOnValueChange.Call(nil);
  FValue := Value;
end;

{ TSomeObjectHelper }

function TSomeObjectHelper.ValueSqr: double;
begin
  Result := -1;
  if Source is TSomeObject then
    Result := Sqr((Source as TSomeObject).Value);
end;

{ TSomeChildHelper }

function TSomeChildHelper.ValueX2: Double;
begin
  Result := -1;
  if Source is TSomeObject then
    Result := (Source as TSomeObject).Value * 2;
end;

{ TSomeAttrObject }

function TSomeAttrObject.GetForbiddenNumber: integer;
begin
  Result := -1;
end;

function TSomeAttrObject.GetNumber: integer;
begin
  Result := 1;
end;

{ TSomeForbiddenObject }

function TSomeForbiddenObject.Get5: integer;
begin
  Result := 5;
end;

{ ISomeIntfObj }

function TSomeIntfObj.GetClassName: string;
begin
  Result := 'TsomeIntfObj';
end;

{ TGlobalNamespace }

procedure TGlobalNamespace.alert(str: string);
begin
  FEng.ScriptLog.Add('alert: ' + str);
end;

constructor TGlobalNamespace.Create(Eng: TJSEngine);
begin
  FEng := Eng;
  FSys := TJSSystemNamespace.Create(Eng);
  FEng.RegisterHelper(TSomeObject, TSomeObjectHelper);
  FEng.RegisterHelper(TSomeChild, TSomeChildHelper);
end;

destructor TGlobalNamespace.Destroy;
begin
  FSys.Free;
  FSomeHelper.Free;
  FChildHelper.Free;
end;

function TGlobalNamespace.GetSystem: TJSSystemNamespace;
begin
  Result := FSys;
end;

procedure TGlobalNamespace.log(str: string);
begin
  FEng.ScriptLog.Add(str);
end;

function TGlobalNamespace.NewAttrObject: TSomeAttrObject;
begin
  Result := TSomeAttrObject.Create;
end;

function TGlobalNamespace.NewCallBackClass: TCallBackClass;
begin
  Result := TCallBackClass.Create;
end;

function TGlobalNamespace.NewForbiddenObject: TSomeForbiddenObject;
begin
  Result := TSomeForbiddenObject.Create;
end;

function TGlobalNamespace.NewSomeChild: TSomeChild;
begin
  Result := TSomeChild.Create;
end;

function TGlobalNamespace.NewSomeList: TSomeList;
begin
  Result := TSomeList.Create;
end;

function TGlobalNamespace.NewSomeObject: TSomeObject;
begin
  Result := TSomeObject.Create;
end;

function TGlobalNamespace.Length(vec: TVector3): double;
begin
  Result := vec.Length;
end;

function TGlobalNamespace.NewVector(x, y, z: double): TVector3;
begin
  Result := TVector3.Create(x, y, z);
end;

{ TOptionCallback }

function TSampleCallback.Assigned: boolean;
begin
  Result := System.Assigned(Callable);
end;

procedure TSampleCallback.Call(Sender: TObject);
begin
  Callable.Call([Sender]);
end;

procedure TSampleCallback.SetCallable(calla: ICallableMethod);
begin
  Callable := calla;
end;

end.
