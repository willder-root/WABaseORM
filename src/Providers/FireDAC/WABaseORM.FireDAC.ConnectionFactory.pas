unit WABaseORM.FireDAC.ConnectionFactory;

interface

uses
  System.SysUtils, System.Generics.Collections,
  FireDAC.Comp.Client,
  WABaseORM.DB.Interfaces,
  WABaseORM.FireDAC.Connection;

type
  TWABaseORMConnectionParams = record
    DriverID: string;
    Server: string;
    Database: string;
    User: string;
    Password: string;
    Port: Integer;
    class function New: TWABaseORMConnectionParams; static;
  end;

  TWABaseORMConnectionFactory = class
  public
    class function CreateFirebird(const AServer, ADatabase, AUser, APassword: string): IWABaseORMConnection;
    class function CreateMSSQL(const AServer, ADatabase, AUser, APassword: string): IWABaseORMConnection;
    class function CreatePostgres(const AServer, ADatabase, AUser, APassword: string): IWABaseORMConnection;
    class function CreateSQLite(const ADatabaseFile: string): IWABaseORMConnection;
    class function CreateFromParams(const AParams: TWABaseORMConnectionParams): IWABaseORMConnection;
    class function CreateFromExisting(AConnection: TFDConnection): IWABaseORMConnection;
  end;

implementation

{ TWABaseORMConnectionParams }

class function TWABaseORMConnectionParams.New: TWABaseORMConnectionParams;
begin
  Result.DriverID := '';
  Result.Server := '';
  Result.Database := '';
  Result.User := '';
  Result.Password := '';
  Result.Port := 0;
end;

{ TWABaseORMConnectionFactory }

class function TWABaseORMConnectionFactory.CreateFirebird(const AServer, ADatabase, AUser, APassword: string): IWABaseORMConnection;
begin
  Result := TWABaseORMFireDACConnection.Create('FB', AServer, ADatabase, AUser, APassword);
end;

class function TWABaseORMConnectionFactory.CreateMSSQL(const AServer, ADatabase, AUser, APassword: string): IWABaseORMConnection;
begin
  Result := TWABaseORMFireDACConnection.Create('MSSQL', AServer, ADatabase, AUser, APassword);
end;

class function TWABaseORMConnectionFactory.CreatePostgres(const AServer, ADatabase, AUser, APassword: string): IWABaseORMConnection;
begin
  Result := TWABaseORMFireDACConnection.Create('PG', AServer, ADatabase, AUser, APassword);
end;

class function TWABaseORMConnectionFactory.CreateSQLite(const ADatabaseFile: string): IWABaseORMConnection;
begin
  Result := TWABaseORMFireDACConnection.Create('SQLite', '', ADatabaseFile, '', '');
end;

class function TWABaseORMConnectionFactory.CreateFromParams(const AParams: TWABaseORMConnectionParams): IWABaseORMConnection;
begin
  Result := TWABaseORMFireDACConnection.Create(AParams.DriverID, AParams.Server, AParams.Database, AParams.User, AParams.Password);
end;

class function TWABaseORMConnectionFactory.CreateFromExisting(AConnection: TFDConnection): IWABaseORMConnection;
begin
  Result := TWABaseORMFireDACConnection.Create(AConnection);
end;

end.
