unit WABaseORM.Tests.FireDACConnection;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  WABaseORM.DB.Interfaces,
  WABaseORM.FireDAC.ConnectionFactory;

type
  // Testes de INTEGRAÇÃO — exigem um banco SQLite de teste (arquivo local, em memória).
  // Rodam contra um provider real para validar o adapter FireDAC de ponta a ponta.
  [TestFixture]
  TWABaseORMFireDACConnectionTests = class
  private
    FConnection: IWABaseORMConnection;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Connect_DeveFicarConectado;
    [Test]
    procedure CreateQuery_DeveExecutarDDLSimples;
    [Test]
    procedure Transaction_RollbackDeveDesfazerInsert;
  end;

implementation

procedure TWABaseORMFireDACConnectionTests.Setup;
begin
  // Banco SQLite em memória: rápido, isolado, não deixa arquivo no disco.
  FConnection := TWABaseORMConnectionFactory.CreateSQLite(':memory:');
  FConnection.Connect;
end;

procedure TWABaseORMFireDACConnectionTests.TearDown;
begin
  if Assigned(FConnection) and FConnection.Connected then
    FConnection.Disconnect;
  FConnection := nil;
end;

procedure TWABaseORMFireDACConnectionTests.Connect_DeveFicarConectado;
begin
  Assert.IsTrue(FConnection.Connected);
end;

procedure TWABaseORMFireDACConnectionTests.CreateQuery_DeveExecutarDDLSimples;
var
  Qry: IWABaseORMQuery;
begin
  Qry := FConnection.CreateQuery;
  Qry.SetSQL('CREATE TABLE CLIENTES (ID INTEGER PRIMARY KEY, NOME VARCHAR(100))');
  Qry.ExecSQL;

  Qry := FConnection.CreateQuery;
  Qry.SetSQL('INSERT INTO CLIENTES (ID, NOME) VALUES (:ID, :NOME)');
  Qry.SetParam('ID', 1);
  Qry.SetParam('NOME', 'Teste');
  Assert.AreEqual(1, Qry.ExecSQL);
end;

procedure TWABaseORMFireDACConnectionTests.Transaction_RollbackDeveDesfazerInsert;
var
  Qry: IWABaseORMQuery;
  Transaction: IWABaseORMTransaction;
  Count: Integer;
begin
  Qry := FConnection.CreateQuery;
  Qry.SetSQL('CREATE TABLE PRODUTOS (ID INTEGER PRIMARY KEY, NOME VARCHAR(100))');
  Qry.ExecSQL;

  Transaction := FConnection.StartTransaction;
  Qry := FConnection.CreateQuery;
  Qry.SetSQL('INSERT INTO PRODUTOS (ID, NOME) VALUES (1, ''Teste'')');
  Qry.ExecSQL;
  Transaction.Rollback;

  Qry := FConnection.CreateQuery;
  Qry.SetSQL('SELECT COUNT(*) AS QTD FROM PRODUTOS');
  Count := Qry.Open.FieldByName('QTD').AsInteger;

  Assert.AreEqual(0, Count);
end;

initialization
  TDUnitX.RegisterTestFixture(TWABaseORMFireDACConnectionTests);

end.
