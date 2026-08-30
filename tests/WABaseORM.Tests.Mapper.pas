unit WABaseORM.Tests.Mapper;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  WABaseORM.Attributes, WABaseORM.Mapper, WABaseORM.Exceptions;

function ArrayContainsStr(const AArray: TArray<string>; const AValue: string): Boolean;

type
  [WABaseORMTableAttribute('CLIENTES')]
  TClienteFixture = class
  private
    FId: Integer;
    FNome: string;
  published
    [WABaseORMColumnAttribute('ID', True)]
    property Id: Integer read FId write FId;
    [WABaseORMColumnAttribute('NOME')]
    property Nome: string read FNome write FNome;
  end;

  TClienteSemTabelaFixture = class
  private
    FId: Integer;
  published
    property Id: Integer read FId write FId;
  end;

  [TestFixture]
  TWABaseORMMapperTests = class
  public
    [Test]
    procedure GetTableName_DeveRetornarNomeDoAtributo;
    [Test]
    procedure GetPrimaryKeyColumn_DeveRetornarColunaMarcadaComoPK;
    [Test]
    procedure MapObjectToParams_SemPK_NaoDeveIncluirColunaPK;
    [Test]
    procedure ClasseSemAtributoTable_DeveLevantarExcecao;
  end;

implementation

function ArrayContainsStr(const AArray: TArray<string>; const AValue: string): Boolean;
var
  Item: string;
begin
  Result := False;
  for Item in AArray do
    if SameText(Item, AValue) then
      Exit(True);
end;

procedure TWABaseORMMapperTests.GetTableName_DeveRetornarNomeDoAtributo;
var
  Mapper: TWABaseORMMapper<TClienteFixture>;
begin
  Mapper := TWABaseORMMapper<TClienteFixture>.Create;
  try
    Assert.AreEqual('CLIENTES', Mapper.GetTableName);
  finally
    Mapper.Free;
  end;
end;

procedure TWABaseORMMapperTests.GetPrimaryKeyColumn_DeveRetornarColunaMarcadaComoPK;
var
  Mapper: TWABaseORMMapper<TClienteFixture>;
begin
  Mapper := TWABaseORMMapper<TClienteFixture>.Create;
  try
    Assert.AreEqual('ID', Mapper.GetPrimaryKeyColumn);
  finally
    Mapper.Free;
  end;
end;

procedure TWABaseORMMapperTests.MapObjectToParams_SemPK_NaoDeveIncluirColunaPK;
var
  Mapper: TWABaseORMMapper<TClienteFixture>;
  Cols: TArray<string>;
begin
  Mapper := TWABaseORMMapper<TClienteFixture>.Create;
  try
    Cols := Mapper.MapObjectToParams(nil, False);
    Assert.IsFalse(ArrayContainsStr(Cols, 'ID'));
    Assert.IsTrue(ArrayContainsStr(Cols, 'NOME'));
  finally
    Mapper.Free;
  end;
end;

procedure TWABaseORMMapperTests.ClasseSemAtributoTable_DeveLevantarExcecao;
begin
  Assert.WillRaise(
    procedure
    var
      Mapper: TWABaseORMMapper<TClienteSemTabelaFixture>;
    begin
      Mapper := TWABaseORMMapper<TClienteSemTabelaFixture>.Create;
      Mapper.Free;
    end,
    EWABaseORMTableNotMapped);
end;

initialization
  TDUnitX.RegisterTestFixture(TWABaseORMMapperTests);

end.
