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

var
  Global: TGlobalNamespace;
  code: TStrings;
  log: TStrings;
  Eng: TJSEngine;
  s: string;
begin
  Math.SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow,
    exUnderflow, exPrecision]);
  try
    Eng := TJSEngine.Create;
    log := TStringList.Create;
    Eng.Debug := True;
    Eng.SetLog(log);
    Global := TGlobalNamespace.Create(Eng);
    code := TStringList.Create;
    try
      Eng.AddGlobal(Global);
//      Eng.RunScript('a = 2;// a++; system.log(a)', ParamStr(0));
      code.LoadFromFile('..\scripts\tools\codeassist.js');
      eng.RunScript(code.Text, ExtractFilePath(ParamStr(0)) + '..\scripts\tools\codeassist.js');
      s := eng.CallFunction('computeProposals', ['a = 2;', 0, 1]);
      Eng.ScriptLog.Add(s);
      // <<----send log to user-----
      if Assigned(Eng.ScriptLog) and (Eng.ScriptLog.Count > 0) then
      begin
        Writeln('=========================LOG=========================');
        Writeln(Eng.ScriptLog.Text);
        Writeln('=====================================================');
      end;
      // ------------------------->>
    finally
      Eng.Free;
      Global.Free;
      log.Free;
    end;
  except
    on e: Exception do
      writeln('err');
  end;
  Writeln;
  Writeln('Press Enter for Exit');
  Readln;
end.
