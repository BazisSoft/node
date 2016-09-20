program V8EngineProj;

{.$APPTYPE CONSOLE}

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
  Eng: TJSEngine;
begin
  Math.SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow,
    exUnderflow, exPrecision]);
  try
    Eng := TJSEngine.Create;
    Eng.Debug := True;
    Global := TGlobalNamespace.Create(Eng);
    try
      Eng.AddGlobal(Global);
//      Eng.RunScript('a = 2; a++; system.log(a)', ParamStr(0));
      Eng.RunFile('..\scripts\1.js', ParamStr(0));
      // <<----send log to user-----
      if Eng.ScriptLog.Count > 0 then
      begin
        Writeln('=========================LOG=========================');
        Writeln(Eng.ScriptLog.Text);
        Writeln('=====================================================');
      end;
      // ------------------------->>
    finally
      Eng.Free;
      Global.Free;
    end;
  except
//    writeln('err');
  end;
//  Writeln;
//  Writeln('Press Enter for Exit');
//  Readln;
end.
