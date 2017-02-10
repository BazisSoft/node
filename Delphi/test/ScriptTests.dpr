program ScriptTests;
{

  Delphi DUnit Test Project
  -------------------------
  This project contains the DUnit test framework and the GUI/Console test runners.
  Add "CONSOLE_TESTRUNNER" to the conditional defines entry in the project options
  to use the console test runner.  Otherwise the GUI test runner will be used by
  default.

}

{$IFDEF CONSOLE_TESTRUNNER}
{$APPTYPE CONSOLE}
{$ENDIF}

uses
  DUnitTestRunner,
  TestV8Engine in 'TestV8Engine.pas',
  V8Engine in '..\V8Engine.pas',
  SampleClasses in '..\SampleClasses.pas',
  ScriptInterface in '..\ScriptInterface.pas',
  V8API in '..\V8API.pas',
  V8Interface in '..\V8Interface.pas';

{$R *.RES}

begin
  DUnitTestRunner.RunRegisteredTests;
end.

