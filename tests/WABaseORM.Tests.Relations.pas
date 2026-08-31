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
  // de relacionamentos HasMany/BelongsTo via JOIN (uma única consulta) de ponta a ponta
  // (RTTI + SQL + FireDAC).
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
  public
    destructor Destroy; override;
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
  public
    destructor Destroy; override;
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
    procedure FindByIDWithHasMany_DeveCarregarClienteEFilhosEmUmaUnicaQuery;
    [Test]
    procedure FindByIDWithHasMany_SemFilhos_DeveRetornarClienteComListaVazia;
    [Test]
    procedure FindByIDWithHasMany_IdInexistente_DeveRetornarNil;
    [Test]
    procedure FindByIDWithBelongsTo_DeveCarregarPedidoEClienteEmUmaUnicaQuery;
    [Test]
    procedure FindByIDWithBelongsTo_SemRegistroPai_DevePopularApenasOPrincipal;
  end;

implementation

{ TClienteFixture }

destructor TClienteFixture.Destroy;
begin
  FPedidos.Free;
  inherited;
end;

{ TPedidoFixture }

destructor TPedidoFixture.Destroy;
begin
  FCliente.Free;
  inherited;
end;

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

procedure TWABaseORMRelationsTests.FindByIDWithHasMany_DeveCarregarClienteEFilhosEmUmaUnicaQuery;
var
  Cliente: TClienteFixture;
  Pedido: TPedidoFixture;
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

  // Uma única chamada = uma única query (LEFT JOIN CLIENTES x PEDIDOS), sem round-trip
  // separado para buscar o cliente e depois os pedidos.
  Cliente := FClienteRepo.FindByIDWithHasMany<TPedidoFixture>(1, 'Pedidos');
  try
    Assert.IsTrue(Assigned(Cliente));
    Assert.AreEqual('Joao', Cliente.Nome);
    Assert.IsTrue(Assigned(Cliente.Pedidos));
    Assert.AreEqual(2, Cliente.Pedidos.Count);
  finally
    Cliente.Free;
  end;
end;

procedure TWABaseORMRelationsTests.FindByIDWithHasMany_SemFilhos_DeveRetornarClienteComListaVazia;
var
  Cliente: TClienteFixture;
begin
  Cliente := TClienteFixture.Create;
  try
    Cliente.Id := 2;
    Cliente.Nome := 'Maria';
    FClienteRepo.Insert(Cliente);
  finally
    Cliente.Free;
  end;

  // LEFT JOIN: mesmo sem nenhum pedido, o cliente precisa ser retornado (um INNER JOIN
  // teria eliminado a linha do cliente por falta de correspondência).
  Cliente := FClienteRepo.FindByIDWithHasMany<TPedidoFixture>(2, 'Pedidos');
  try
    Assert.IsTrue(Assigned(Cliente));
    Assert.IsTrue(Assigned(Cliente.Pedidos));
    Assert.AreEqual(0, Cliente.Pedidos.Count);
  finally
    Cliente.Free;
  end;
end;

procedure TWABaseORMRelationsTests.FindByIDWithHasMany_IdInexistente_DeveRetornarNil;
var
  Cliente: TClienteFixture;
begin
  Cliente := FClienteRepo.FindByIDWithHasMany<TPedidoFixture>(999, 'Pedidos');
  Assert.IsFalse(Assigned(Cliente));
end;

procedure TWABaseORMRelationsTests.FindByIDWithBelongsTo_DeveCarregarPedidoEClienteEmUmaUnicaQuery;
var
  Cliente: TClienteFixture;
  Pedido: TPedidoFixture;
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

  Pedido := FPedidoRepo.FindByIDWithBelongsTo<TClienteFixture>(100, 'Cliente');
  try
    Assert.IsTrue(Assigned(Pedido));
    Assert.AreEqual('Pedido A', Pedido.Descricao);
    Assert.IsTrue(Assigned(Pedido.Cliente), 'A propriedade Cliente deveria ter sido populada automaticamente');
    Assert.AreEqual(1, Pedido.Cliente.Id);
    Assert.AreEqual('Joao', Pedido.Cliente.Nome);
  finally
    Pedido.Free;
  end;
end;

procedure TWABaseORMRelationsTests.FindByIDWithBelongsTo_SemRegistroPai_DevePopularApenasOPrincipal;
var
  Pedido: TPedidoFixture;
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

  // LEFT JOIN: mesmo sem cliente correspondente, o pedido precisa ser retornado.
  Pedido := FPedidoRepo.FindByIDWithBelongsTo<TClienteFixture>(200, 'Cliente');
  try
    Assert.IsTrue(Assigned(Pedido));
    Assert.IsFalse(Assigned(Pedido.Cliente));
  finally
    Pedido.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TWABaseORMRelationsTests);

end.
