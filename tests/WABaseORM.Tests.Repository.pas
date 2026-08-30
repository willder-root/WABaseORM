unit WABaseORM.Tests.Repository;

interface

uses
  System.SysUtils, Data.DB,
  DUnitX.TestFramework,
  WABaseORM.DB.Interfaces, WABaseORM.Attributes, WABaseORM.Repository;

type
  [WABaseORMTableAttribute('CLIENTES')]
  TClienteRepoFixture = class
  private
    FId: Integer;
    FNome: string;
  published
    [WABaseORMColumnAttribute('ID', True)]
    property Id: Integer read FId write FId;
    [WABaseORMColumnAttribute('NOME')]
    property Nome: string read FNome write FNome;
  end;

  // Fakes mínimos de IWABaseORMConnection/IWABaseORMQuery para testar
  // a montagem de SQL do repository sem precisar de um banco real.
  // Em um projeto real, prefira um mock framework (ex: Spring4D Mocking, Delphi-Mocks).
  TFakeWABaseORMQuery = class(TInterfacedObject, IWABaseORMQuery)
  public
    LastSQL: string;
    LastParams: TArray<string>;
    procedure SetSQL(const ASQL: string);
    procedure SetParam(const AName: string; const AValue: Variant); overload;
    procedure SetParam(const AName: string; const AValue: Integer); overload;
    procedure SetParam(const AName: string; const AValue: Int64); overload;
    procedure SetParam(const AName: string; const AValue: string); overload;
    procedure SetParam(const AName: string; const AValue: Double); overload;
    procedure SetParam(const AName: string; const AValue: Currency); overload;
    procedure SetParam(const AName: string; const AValue: TDateTime); overload;
    procedure SetParam(const AName: string; const AValue: Boolean); overload;
    procedure SetParam(const AName: string); overload;
    function Open: TDataSet;
    function ExecSQL: Integer;
    function AsDataSet: TDataSet;
  end;

  TFakeWABaseORMConnection = class(TInterfacedObject, IWABaseORMConnection)
  public
    LastQuery: TFakeWABaseORMQuery;
    procedure Connect;
    procedure Disconnect;
    function Connected: Boolean;
    function CreateQuery: IWABaseORMQuery;
    function StartTransaction: IWABaseORMTransaction;
    function InTransaction: Boolean;
  end;

  [TestFixture]
  TWABaseORMRepositoryTests = class
  public
    [Test]
    procedure Delete_DeveMontarSQLComWhereNaColunaPK;
  end;

implementation

{ TFakeWABaseORMQuery }

procedure TFakeWABaseORMQuery.SetSQL(const ASQL: string);
begin
  LastSQL := ASQL;
end;

procedure TFakeWABaseORMQuery.SetParam(const AName: string; const AValue: Variant);
begin
  LastParams := LastParams + [AName];
end;

procedure TFakeWABaseORMQuery.SetParam(const AName: string; const AValue: Integer);
begin
  LastParams := LastParams + [AName];
end;

procedure TFakeWABaseORMQuery.SetParam(const AName: string; const AValue: Int64);
begin
  LastParams := LastParams + [AName];
end;

procedure TFakeWABaseORMQuery.SetParam(const AName: string; const AValue: string);
begin
  LastParams := LastParams + [AName];
end;

procedure TFakeWABaseORMQuery.SetParam(const AName: string; const AValue: Double);
begin
  LastParams := LastParams + [AName];
end;

procedure TFakeWABaseORMQuery.SetParam(const AName: string; const AValue: Currency);
begin
  LastParams := LastParams + [AName];
end;

procedure TFakeWABaseORMQuery.SetParam(const AName: string; const AValue: TDateTime);
begin
  LastParams := LastParams + [AName];
end;

procedure TFakeWABaseORMQuery.SetParam(const AName: string; const AValue: Boolean);
begin
  LastParams := LastParams + [AName];
end;

procedure TFakeWABaseORMQuery.SetParam(const AName: string);
begin
  LastParams := LastParams + [AName];
end;

function TFakeWABaseORMQuery.Open: TDataSet;
begin
  Result := nil; // não exercitado neste teste
end;

function TFakeWABaseORMQuery.ExecSQL: Integer;
begin
  Result := 1;
end;

function TFakeWABaseORMQuery.AsDataSet: TDataSet;
begin
  Result := nil;
end;

{ TFakeWABaseORMConnection }

procedure TFakeWABaseORMConnection.Connect;
begin
  // no-op
end;

procedure TFakeWABaseORMConnection.Disconnect;
begin
  // no-op
end;

function TFakeWABaseORMConnection.Connected: Boolean;
begin
  Result := True;
end;

function TFakeWABaseORMConnection.CreateQuery: IWABaseORMQuery;
begin
  LastQuery := TFakeWABaseORMQuery.Create;
  Result := LastQuery;
end;

function TFakeWABaseORMConnection.StartTransaction: IWABaseORMTransaction;
begin
  Result := nil; // não exercitado neste teste
end;

function TFakeWABaseORMConnection.InTransaction: Boolean;
begin
  Result := False;
end;

{ TWABaseORMRepositoryTests }

procedure TWABaseORMRepositoryTests.Delete_DeveMontarSQLComWhereNaColunaPK;
var
  Conn: TFakeWABaseORMConnection;
  Repo: TWABaseORMRepository<TClienteRepoFixture>;
begin
  Conn := TFakeWABaseORMConnection.Create;
  Repo := TWABaseORMRepository<TClienteRepoFixture>.Create(Conn);
  try
    Repo.Delete(10);
    Assert.Contains(Conn.LastQuery.LastSQL, 'DELETE FROM CLIENTES');
    Assert.Contains(Conn.LastQuery.LastSQL, 'WHERE ID = :ID');
  finally
    Repo.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TWABaseORMRepositoryTests);

end.
