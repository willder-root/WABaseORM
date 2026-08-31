program WABaseORM.Tests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  WABaseORM.Tests.Mapper in 'WABaseORM.Tests.Mapper.pas',
  WABaseORM.Tests.Repository in 'WABaseORM.Tests.Repository.pas',
  WABaseORM.Tests.FireDACConnection in 'WABaseORM.Tests.FireDACConnection.pas',
  WABaseORM.Tests.Relations in 'WABaseORM.Tests.Relations.pas';

var
  Runner: ITestRunner;
  Results: IRunResults;
  Logger: ITestLogger;
  NUnitLogger: ITestLogger;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    Runner := TDUnitX.CreateRunner;
    Runner.UseRTTI := True;

    Logger := TDUnitXConsoleLogger.Create(True);
    Runner.AddLogger(Logger);

    NUnitLogger := TDUnitXXMLNUnitFileLogger.Create('WABaseORM.Tests.Results.xml');
    Runner.AddLogger(NUnitLogger);

    Results := Runner.Execute;

    if not Results.AllPassed then
      System.ExitCode := EXIT_ERRORS;

    {$IFNDEF CI}
    if TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause then
    begin
      System.Write('Pressione <Enter> para sair...');
      System.Readln;
    end;
    {$ENDIF}
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
