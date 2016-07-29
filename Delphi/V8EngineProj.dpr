program V8EngineProj;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Windows,
  Math,
  Classes,
  Generics.Collections,
  V8Interface in 'V8Interface.pas',
  SampleClasses in 'SampleClasses.pas',
  V8API in 'V8API.pas',
  V8Engine in 'V8Engine.pas',
  ScriptInterface in 'ScriptInterface.pas';

type

  TGlobalNamespace = class
  private
    FEng: TJSEngine;
    FSys: TJSSystemNamespace;
    FSomeHelper: TSomeObjectHelper;
    FChildHelper: TSomeChildHelper;
    function GetSystem: TJSSystemNamespace;
  public
    constructor Create(Eng: TJSEngine);
    destructor Destroy;
    procedure log(str: string);
    property system: TJSSystemNamespace read GetSystem;
    [TGCAttr]
    function NewVectorList: TVectorList;
    [TGCAttr]
    function NewVector(x: double = 0; y: double = 0; z: double = 0): TVector3; overload;
    [TGCAttr]
    function NewVector(): TVector3; overload;
    [TGCAttr]
    function NewCallBack: TCallBackClass;
    [TGCAttr]
    function NewSomeObject: TSomeObject;
    [TGCAttr]
    function NewSomeChild: TSomeChild;
    function Length(vec: TVector3): double;
    function Multiplicate(arg1, arg2: double; arg3: double = 1.0): double;
  end;
{ TGlobalNamespace }

constructor TGlobalNamespace.Create(Eng: TJSEngine);
begin
  FEng := Eng;
  FSys := Eng.GetSystem;
  FSomeHelper := TSomeObjectHelper.Create;
  FChildHelper := TSomeChildHelper.Create;
  FEng.RegisterHelper(TSomeObject, FSomeHelper);
  FEng.RegisterHelper(TSomeChild, FChildHelper);
end;

destructor TGlobalNamespace.Destroy;
begin
  FreeAndNil(FSomeHelper);
  FreeAndNil(FChildHelper);
end;

function TGlobalNamespace.GetSystem: TJSSystemNamespace;
begin
  Result := FSys;
end;

procedure TGlobalNamespace.log(str: string);
begin
  FEng.Log.Add(str);
end;

function TGlobalNamespace.Multiplicate(arg1, arg2, arg3: double): double;
begin
  Result := arg1 * arg2 * arg3;
end;

function TGlobalNamespace.NewCallBack: TCallBackClass;
begin
  Result := TCallBackClass.Create;
end;

function TGlobalNamespace.NewSomeChild: TSomeChild;
begin
  Result := TSomeChild.Create;
end;

function TGlobalNamespace.NewSomeObject: TSomeObject;
begin
  Result := TSomeObject.Create;
end;

function TGlobalNamespace.NewVector: TVector3;
begin
  Result := TVector3.Create(0, 0, 0);
end;

function TGlobalNamespace.NewVectorList: TVectorList;
begin
  Result := TVectorList.Create(False);
end;

function TGlobalNamespace.Length(vec: TVector3): double;
begin
  Result := vec.Length;
end;

function TGlobalNamespace.NewVector(x, y, z: double): TVector3;
begin
  Result := TVector3.Create(x, y, z);
end;


var
  Global: TGlobalNamespace;
  Eng: TJSEngine;
begin
  Writeln('===========TEST==========');
  try
    Math.SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow,
      exUnderflow, exPrecision]);
    Eng := TJSEngine.Create;
    Eng.Init(ParamStr(0));
    Eng.Debug := True;
    Global := TGlobalNamespace.Create(Eng);
    try
      Eng.AddGlobal(Global);
      ///
//      Eng.RunScript('a = 2; a++; system.log(a)', ParamStr(0));
      Eng.RunFile('1.js', ParamStr(0));
      Eng.RunFile('1.js', ParamStr(0));
      // <<----send log to user-----
      if Eng.Log.Count > 0 then
      begin
        Writeln('=========================LOG=========================');
        Writeln(Eng.Log.Text);
        Writeln('=====================================================');
      end;
      // ------------------------->>
    finally
      Eng.Free;
      Global.Free;
    end;
  except
    writeln('err');
  end;
  Writeln;
  Writeln('Press Enter for Exit');
  Readln;
end.
