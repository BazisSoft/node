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


  procedure ParseParamsAndRun(Engine: TJSEngine);
  var
    i: integer;
    Param: string;
    DebugStr: string;
    FileNameOrCode: string;
    AdditionalParams: string;
  begin
    i := 1;
    DebugStr := '';
    FileNameOrCode := '';
    while i < ParamCount do
    begin
      Param := ParamStr(i);
      if Param = '' then
      begin
        Inc(i);
        Continue;
      end;
      if (Param[1] = '-') and (Param[2] = '-') then
      begin
        Delete(Param, 1, 2);
        Param := LowerCase(Param);
        //it can be either '--debug' or '--debug-brk' param for debugging
        //also it can be '--eval' param to evaluate file;
        if (Pos('debug', Param) > 0) or (Param = 'eval') then
        begin
          DebugStr := ParamStr(i);
          Inc(i);
          if ParamCount >= i then
          begin
            FileNameOrCode := ParamStr(i);
            Inc(i);
            AdditionalParams := '';
            while i < ParamCount do
            begin
              AdditionalParams := AdditionalParams + ParamStr(i) + #10#13;
              Inc(i);
            end;
          end;
        end;
      end;
      Inc(i)
    end;
    if FileNameOrCode <> '' then
    begin
      if DebugStr = '--eval' then
      begin
        //TODO: check if filename or code
        Engine.RunFile(FileNameOrCode, ParamStr(0))
      end
      else
      begin
        Engine.Debug := True;
        Engine.DebugPort := DebugStr;
        Engine.RunFile(FileNameOrCode, ParamStr(0));
      end;
    end;
  end;

var
  Global: TGlobalNamespace;
  log: TStrings;
  Eng: TJSEngine;
begin
  Math.SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow,
    exUnderflow, exPrecision]);
  try
    Eng := TJSEngine.Create;
    log := TStringList.Create;
    Eng.SetLog(log);
    Global := TGlobalNamespace.Create(Eng);
    try
      Eng.AddGlobal(Global);
      ParseParamsAndRun(Eng);
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
      writeln('error: ' + e.Message);
  end;
  Writeln;
  Writeln('Press Enter for Exit');
  Readln;
end.
