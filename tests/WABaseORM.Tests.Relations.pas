unit WABaseORM.Tests.Relations;

interface

uses
  System.SysUtils, System.Generics.Collections,
  DUnitX.TestFramework,
  FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteDef,
  WABaseORM.Attributes, WABaseORM.DB.Interfaces, WABaseORM.Exceptions,
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
    procedure FindByID_HasMany_DeveCarregarClienteEFilhosEmUmaUnicaQuery;
    [Test]
    procedure FindByID_HasMany_SemFilhos_DeveRetornarClienteComListaVazia;
    [Test]
    procedure FindByID_HasMany_IdInexistente_DeveRetornarNil;
    [Test]
    procedure FindByID_BelongsTo_DeveCarregarPedidoEClienteEmUmaUnicaQuery;
    [Test]
    procedure FindByID_BelongsTo_SemRegistroPai_DevePopularApenasOPrincipal;
    [Test]
    procedure FindAll_HasMany_DeveCarregarVariosClientesComSeusFilhos;
    [Test]
    procedure FindAll_BelongsTo_DeveCarregarVariosPedidosComSeusClientes;
    [Test]
    procedure FindByID_PropriedadeSemRelacaoMapeada_DeveLevantarExcecao;
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

procedure TWABaseORMRelationsTests.FindByID_HasMany_DeveCarregarClienteEFilhosEmUmaUnicaQuery;
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
  // separado para buscar o cliente e depois os pedidos. O Kind (HasMany) é detectado
  // automaticamente a partir do atributo da propriedade "Pedidos".
  Cliente := FClienteRepo.FindByID<TPedidoFixture>(1, 'Pedidos');
  try
    Assert.IsTrue(Assigned(Cliente));
    Assert.AreEqual('Joao', Cliente.Nome);
    Assert.IsTrue(Assigned(Cliente.Pedidos));
    Assert.AreEqual(2, Cliente.Pedidos.Count);
  finally
    Cliente.Free;
  end;
end;

procedure TWABaseORMRelationsTests.FindByID_HasMany_SemFilhos_DeveRetornarClienteComListaVazia;
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
  Cliente := FClienteRepo.FindByID<TPedidoFixture>(2, 'Pedidos');
  try
    Assert.IsTrue(Assigned(Cliente));
    Assert.IsTrue(Assigned(Cliente.Pedidos));
    Assert.AreEqual(0, Cliente.Pedidos.Count);
  finally
    Cliente.Free;
  end;
end;

procedure TWABaseORMRelationsTests.FindByID_HasMany_IdInexistente_DeveRetornarNil;
var
  Cliente: TClienteFixture;
begin
  Cliente := FClienteRepo.FindByID<TPedidoFixture>(999, 'Pedidos');
  Assert.IsFalse(Assigned(Cliente));
end;

procedure TWABaseORMRelationsTests.FindByID_BelongsTo_DeveCarregarPedidoEClienteEmUmaUnicaQuery;
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

  Pedido := FPedidoRepo.FindByID<TClienteFixture>(100, 'Cliente');
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

procedure TWABaseORMRelationsTests.FindByID_BelongsTo_SemRegistroPai_DevePopularApenasOPrincipal;
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
  Pedido := FPedidoRepo.FindByID<TClienteFixture>(200, 'Cliente');
  try
    Assert.IsTrue(Assigned(Pedido));
    Assert.IsFalse(Assigned(Pedido.Cliente));
  finally
    Pedido.Free;
  end;
end;

procedure TWABaseORMRelationsTests.FindAll_HasMany_DeveCarregarVariosClientesComSeusFilhos;
var
  Cliente: TClienteFixture;
  Pedido: TPedidoFixture;
  Clientes: TObjectList<TClienteFixture>;
begin
  Cliente := TClienteFixture.Create;
  try
    Cliente.Id := 1;
    Cliente.Nome := 'Joao';
    FClienteRepo.Insert(Cliente);
  finally
    Cliente.Free;
  end;

  Cliente := TClienteFixture.Create;
  try
    Cliente.Id := 2;
    Cliente.Nome := 'Maria';
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

  // Uma única query traz os dois clientes (WHERE ID IN (1, 2)) já com seus pedidos —
  // Joao com 2 pedidos, Maria com lista vazia (LEFT JOIN não elimina quem não tem filho).
  Clientes := FClienteRepo.FindAll<TPedidoFixture>('M.ID IN (1, 2)', 'Pedidos');
  try
    Assert.AreEqual(2, Clientes.Count);

    for Cliente in Clientes do
      if Cliente.Id = 1 then
      begin
        Assert.AreEqual('Joao', Cliente.Nome);
        Assert.IsTrue(Assigned(Cliente.Pedidos));
        Assert.AreEqual(2, Cliente.Pedidos.Count);
      end
      else
      begin
        Assert.AreEqual('Maria', Cliente.Nome);
        Assert.IsTrue(Assigned(Cliente.Pedidos));
        Assert.AreEqual(0, Cliente.Pedidos.Count);
      end;
  finally
    Clientes.Free;
  end;
end;

procedure TWABaseORMRelationsTests.FindAll_BelongsTo_DeveCarregarVariosPedidosComSeusClientes;
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
    Pedido.Id := 200;
    Pedido.ClienteId := 999; // cliente inexistente
    Pedido.Descricao := 'Pedido orfao';
    FPedidoRepo.Insert(Pedido);
  finally
    Pedido.Free;
  end;

  // Uma única query traz os dois pedidos já com o Cliente populado (ou nil, quando a FK
  // não corresponde a nenhum cliente).
  Pedidos := FPedidoRepo.FindAll<TClienteFixture>('M.ID IN (100, 200)', 'Cliente');
  try
    Assert.AreEqual(2, Pedidos.Count);

    for Pedido in Pedidos do
      if Pedido.Id = 100 then
      begin
        Assert.IsTrue(Assigned(Pedido.Cliente));
        Assert.AreEqual('Joao', Pedido.Cliente.Nome);
      end
      else
        Assert.IsFalse(Assigned(Pedido.Cliente));
  finally
    Pedidos.Free;
  end;
end;

procedure TWABaseORMRelationsTests.FindByID_PropriedadeSemRelacaoMapeada_DeveLevantarExcecao;
begin
  Assert.WillRaise(
    procedure
    begin
      FClienteRepo.FindByID<TPedidoFixture>(1, 'Nome'); // "Nome" existe como coluna, não como relação
    end,
    EWABaseORMRelationNotFound);
end;

initialization
  TDUnitX.RegisterTestFixture(TWABaseORMRelationsTests);

end.
