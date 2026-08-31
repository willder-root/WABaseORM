unit WABaseORM.Tests.Relations;

interface

uses
  System.SysUtils, System.Generics.Collections,
  DUnitX.TestFramework,
  FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteDef,
  WABaseORM.Attributes, WABaseORM.DB.Interfaces,
  WABaseORM.FireDAC.ConnectionFactory, WABaseORM.Repository;

type
  TPedidoFixture = class;

  // Testes de INTEGRAÇÃO — usam um banco SQLite em memória para validar o carregamento
  // de relacionamentos HasMany/BelongsTo de ponta a ponta (RTTI + SQL + FireDAC).
  [WABaseORMTableAttribute('CLIENTES')]
  TClienteFixture = class
  private
    FId: Integer;
    FNome: string;
    FPedidos: TObjectList<TPedidoFixture>;
  published
    [WABaseORMColumnAttribute('ID', True)]
    property Id: Integer read FId write FId;
    [WABaseORMColumnAttribute('NOME')]
    property Nome: string read FNome write FNome;
    [WABaseORMHasManyAttribute('CLIENTE_ID')]
    property Pedidos: TObjectList<TPedidoFixture> read FPedidos write FPedidos;
  end;

  [WABaseORMTableAttribute('PEDIDOS')]
  TPedidoFixture = class
  private
    FId: Integer;
    FClienteId: Integer;
    FDescricao: string;
    FCliente: TClienteFixture;
  published
    [WABaseORMColumnAttribute('ID', True)]
    property Id: Integer read FId write FId;
    [WABaseORMColumnAttribute('CLIENTE_ID')]
    property ClienteId: Integer read FClienteId write FClienteId;
    [WABaseORMColumnAttribute('DESCRICAO')]
    property Descricao: string read FDescricao write FDescricao;
    [WABaseORMBelongsToAttribute('CLIENTE_ID')]
    property Cliente: TClienteFixture read FCliente write FCliente;
  end;

  [TestFixture]
  TWABaseORMRelationsTests = class
  private
    FConnection: IWABaseORMConnection;
    FClienteRepo: TWABaseORMRepository<TClienteFixture>;
    FPedidoRepo: TWABaseORMRepository<TPedidoFixture>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure LoadHasMany_DeveCarregarFilhosPelaFK;
    [Test]
    procedure LoadBelongsTo_DeveCarregarPaiPelaFK;
    [Test]
    procedure LoadBelongsTo_SemRegistroPai_DeveRetornarNil;
  end;

implementation

{ TWABaseORMRelationsTests }

procedure TWABaseORMRelationsTests.Setup;
var
  Qry: IWABaseORMQuery;
begin
  FConnection := TWABaseORMConnectionFactory.CreateSQLite(':memory:');
  FConnection.Connect;

  Qry := FConnection.CreateQuery;
  Qry.SetSQL('CREATE TABLE CLIENTES (ID INTEGER PRIMARY KEY, NOME VARCHAR(100))');
  Qry.ExecSQL;

  Qry := FConnection.CreateQuery;
  Qry.SetSQL('CREATE TABLE PEDIDOS (ID INTEGER PRIMARY KEY, CLIENTE_ID INTEGER, DESCRICAO VARCHAR(100))');
  Qry.ExecSQL;

  FClienteRepo := TWABaseORMRepository<TClienteFixture>.Create(FConnection);
  FPedidoRepo := TWABaseORMRepository<TPedidoFixture>.Create(FConnection);
end;

procedure TWABaseORMRelationsTests.TearDown;
begin
  FClienteRepo.Free;
  FPedidoRepo.Free;
  if Assigned(FConnection) and FConnection.Connected then
    FConnection.Disconnect;
  FConnection := nil;
end;

procedure TWABaseORMRelationsTests.LoadHasMany_DeveCarregarFilhosPelaFK;
var
  Cliente: TClienteFixture;
  Pedido: TPedidoFixture;
  Pedidos: TObjectList<TPedidoFixture>;
begin
  Cliente := TClienteFixture.Create;
  try
    Cliente.Id := 1;
    Cliente.Nome := 'Joao';
    FClienteRepo.Insert(Cliente);
  finally
    Cliente.Free;
  end;

  Pedido := TPedidoFixture.Create;
  try
    Pedido.Id := 100;
    Pedido.ClienteId := 1;
    Pedido.Descricao := 'Pedido A';
    FPedidoRepo.Insert(Pedido);
  finally
    Pedido.Free;
  end;

  Pedido := TPedidoFixture.Create;
  try
    Pedido.Id := 101;
    Pedido.ClienteId := 1;
    Pedido.Descricao := 'Pedido B';
    FPedidoRepo.Insert(Pedido);
  finally
    Pedido.Free;
  end;

  Cliente := FClienteRepo.FindByID(1);
  try
    Pedidos := FClienteRepo.LoadHasMany<TPedidoFixture>(Cliente, 'Pedidos');
    try
      Assert.AreEqual(2, Pedidos.Count);
      Assert.IsTrue(Assigned(Cliente.Pedidos), 'A propriedade Pedidos deveria ter sido populada automaticamente');
      Assert.AreEqual(2, Cliente.Pedidos.Count);
    finally
      Pedidos.Free;
    end;
  finally
    Cliente.Free;
  end;
end;

procedure TWABaseORMRelationsTests.LoadBelongsTo_DeveCarregarPaiPelaFK;
var
  Cliente: TClienteFixture;
  Pedido: TPedidoFixture;
  ClientePai: TClienteFixture;
begin
  Cliente := TClienteFixture.Create;
  try
    Cliente.Id := 1;
    Cliente.Nome := 'Joao';
    FClienteRepo.Insert(Cliente);
  finally
    Cliente.Free;
  end;

  Pedido := TPedidoFixture.Create;
  try
    Pedido.Id := 100;
    Pedido.ClienteId := 1;
    Pedido.Descricao := 'Pedido A';
    FPedidoRepo.Insert(Pedido);
  finally
    Pedido.Free;
  end;

  Pedido := FPedidoRepo.FindByID(100);
  try
    ClientePai := FPedidoRepo.LoadBelongsTo<TClienteFixture>(Pedido, 'Cliente');
    try
      Assert.IsTrue(Assigned(ClientePai));
      Assert.AreEqual(1, ClientePai.Id);
      Assert.AreEqual('Joao', ClientePai.Nome);
      Assert.IsTrue(Pedido.Cliente = ClientePai, 'A propriedade Cliente deveria ter sido populada automaticamente');
    finally
      ClientePai.Free;
    end;
  finally
    Pedido.Free;
  end;
end;

procedure TWABaseORMRelationsTests.LoadBelongsTo_SemRegistroPai_DeveRetornarNil;
var
  Pedido: TPedidoFixture;
  ClientePai: TClienteFixture;
begin
  Pedido := TPedidoFixture.Create;
  try
    Pedido.Id := 200;
    Pedido.ClienteId := 999; // cliente inexistente
    Pedido.Descricao := 'Pedido orfao';
    FPedidoRepo.Insert(Pedido);
  finally
    Pedido.Free;
  end;

  Pedido := FPedidoRepo.FindByID(200);
  try
    ClientePai := FPedidoRepo.LoadBelongsTo<TClienteFixture>(Pedido, 'Cliente');
    Assert.IsFalse(Assigned(ClientePai));
  finally
    Pedido.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TWABaseORMRelationsTests);

end.
