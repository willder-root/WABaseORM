# WABaseORM

Pacote Delphi para mapeamento objeto-relacional (ORM) simples, com abstração de conexão e consultas ao banco via interfaces — o FireDAC fica isolado em uma camada de provider, permitindo trocar de implementação sem afetar o restante da aplicação.

## Estrutura de pastas

```
WABaseORM/
│
├── src/
│   ├── Core/                    Interfaces e contratos (sem dependência de FireDAC)
│   │   ├── WABaseORM.DB.Interfaces.pas
│   │   ├── WABaseORM.Attributes.pas
│   │   ├── WABaseORM.Interfaces.pas
│   │   └── WABaseORM.Exceptions.pas
│   │
│   ├── Providers/
│   │   └── FireDAC/              Implementação concreta usando FireDAC
│   │       ├── WABaseORM.FireDAC.Connection.pas
│   │       ├── WABaseORM.FireDAC.Query.pas
│   │       ├── WABaseORM.FireDAC.Transaction.pas
│   │       └── WABaseORM.FireDAC.ConnectionFactory.pas
│   │
│   ├── ORM/                      Mapeamento, repositório e Unit of Work
│   │   ├── WABaseORM.Repository.pas
│   │   ├── WABaseORM.Mapper.pas
│   │   ├── WABaseORM.RttiCache.pas
│   │   ├── WABaseORM.UnitOfWork.pas
│   │   └── WABaseORM.QueryBuilder.pas
│   │
│   └── Common/
│       ├── WABaseORM.Types.pas
│       └── WABaseORM.Utils.pas
│
├── tests/                        Testes DUnitX
├── examples/Demo/                Projeto de demonstração de uso
├── WABaseORM.dpk                 Pacote único (design-time) com todas as units acima
└── docs/README.md
```

## Instalação (design-time)

1. Abra `WABaseORM.dpk` (na raiz do repositório) e compile/instale. Ele já contém todas as units de `src/Core`, `src/ORM`, `src/Common` e `src/Providers/FireDAC`, além dos `requires` de `FireDAC`/`FireDACCommonDriver`/`FireDACCommon`/`FireDACIBDriver` — não é necessário compilar nenhum outro pacote separadamente.
2. Adicione o caminho de `src/Core`, `src/ORM`, `src/Common` e `src/Providers/FireDAC` em **Library Path** (ou referencie o `.dpk` diretamente no seu projeto).

## Instalação via Boss

O projeto tem um `boss.json` na raiz, então também pode ser adicionado como dependência via [Boss](https://github.com/HashLoad/boss):

```
boss install github.com/willder-root/WABaseORM
```

O Boss usa `mainsrc`/`browsingpath` do `boss.json` para adicionar `src/Core`, `src/ORM`, `src/Common` e `src/Providers/FireDAC` ao Library Path do seu projeto automaticamente.

## Uso básico

```pascal
uses
  WABaseORM.DB.Interfaces,
  WABaseORM.FireDAC.ConnectionFactory,
  WABaseORM.Repository,
  Model.Cliente;

var
  Conn: IWABaseORMConnection;
  Repo: TWABaseORMRepository<TCliente>;
  Cliente: TCliente;
begin
  Conn := TWABaseORMConnectionFactory.CreateMSSQL('localhost', 'MeuBanco', 'sa', 'senha');
  Conn.Connect;

  Repo := TWABaseORMRepository<TCliente>.Create(Conn);
  try
    Cliente := TCliente.Create;
    try
      Cliente.Nome := 'João';
      Cliente.Email := 'joao@teste.com';
      Repo.Insert(Cliente);
    finally
      Cliente.Free;
    end;
  finally
    Repo.Free;
  end;
end;
```

Veja `examples/Demo/WABaseORM.Demo.dpr` para um exemplo completo, incluindo uso do `TWABaseORMUnitOfWork` para agrupar múltiplas operações numa única transação.

## Mapeando uma entidade

```pascal
[WABaseORMTableAttribute('CLIENTES')]
TCliente = class
private
  FId: Integer;
  FNome: string;
published
  [WABaseORMColumnAttribute('ID', True)] // True = chave primária
  property Id: Integer read FId write FId;
  [WABaseORMColumnAttribute('NOME')]
  property Nome: string read FNome write FNome;
end;
```

> As propriedades precisam estar na seção `published` para que a RTTI as enumere em tempo de execução.

## Relacionamentos (HasMany / BelongsTo)

```pascal
[WABaseORMTableAttribute('CLIENTES')]
TCliente = class
private
  FId: Integer;
  FNome: string;
  FPedidos: TObjectList<TPedido>;
published
  [WABaseORMColumnAttribute('ID', True)]
  property Id: Integer read FId write FId;
  [WABaseORMColumnAttribute('NOME')]
  property Nome: string read FNome write FNome;
  // "Pedidos" é o lado N: cada TPedido referencia este Cliente via CLIENTE_ID.
  [WABaseORMHasManyAttribute('CLIENTE_ID')]
  property Pedidos: TObjectList<TPedido> read FPedidos write FPedidos;
end;

[WABaseORMTableAttribute('PEDIDOS')]
TPedido = class
private
  FId: Integer;
  FClienteId: Integer;
  FCliente: TCliente;
published
  [WABaseORMColumnAttribute('ID', True)]
  property Id: Integer read FId write FId;
  [WABaseORMColumnAttribute('CLIENTE_ID')]
  property ClienteId: Integer read FClienteId write FClienteId;
  // "Cliente" é o lado 1: aponta para o Cliente dono deste Pedido.
  [WABaseORMBelongsToAttribute('CLIENTE_ID')]
  property Cliente: TCliente read FCliente write FCliente;
end;
```

Carregando o registro principal já com o relacionamento em **uma única consulta** (`LEFT JOIN`, sem round-trip separado para buscar a entidade e depois o relacionamento):

```pascal
// SELECT ... FROM CLIENTES M LEFT JOIN PEDIDOS C ON C.CLIENTE_ID = M.ID WHERE M.ID = :ID
Cliente := ClienteRepo.FindByIDWithHasMany<TPedido>(1, 'Pedidos'); // já vem com Cliente.Pedidos populado

// SELECT ... FROM PEDIDOS M LEFT JOIN CLIENTES P ON P.ID = M.CLIENTE_ID WHERE M.ID = :ID
Pedido := PedidoRepo.FindByIDWithBelongsTo<TCliente>(100, 'Cliente'); // já vem com Pedido.Cliente populado
```

O `LEFT JOIN` garante que o registro principal continua sendo retornado mesmo sem nenhum relacionado (`Cliente.Pedidos` fica com `Count = 0`) ou com a FK vazia/sem correspondência (`Pedido.Cliente` fica `nil`). Os dois métodos retornam `nil` apenas se o próprio registro principal (`AId`) não existir. Quem chama é responsável por liberar o objeto retornado — a propriedade de navegação populada (`TObjectList`/objeto relacionado) é liberada junto se o destructor da entidade cuidar disso (como em qualquer grafo de objetos comum).

## Convenção de nomes

| Camada | Padrão | Exemplo |
|---|---|---|
| Interfaces/contratos | `WABaseORM.<Área>.pas` | `WABaseORM.DB.Interfaces.pas` |
| Provider FireDAC | `WABaseORM.FireDAC.<Componente>.pas` | `WABaseORM.FireDAC.Connection.pas` |
| ORM/mapeamento | `WABaseORM.<Funcionalidade>.pas` | `WABaseORM.Repository.pas` |
| Testes | `WABaseORM.Tests.<Alvo>.pas` | `WABaseORM.Tests.Mapper.pas` |
| Pacote .dpk | `WABaseORM.dpk` (único, na raiz) | `WABaseORM.dpk` |

## Rodando os testes

O projeto `tests/WABaseORM.Tests.dpr` usa [DUnitX](https://github.com/VSoftTechnologies/DUnitX). Os testes de `WABaseORM.Tests.FireDACConnection.pas` usam SQLite em memória (`:memory:`) para não depender de um banco externo.

## Limitações conhecidas / próximos passos

- Relacionamentos (`HasMany`/`BelongsTo`) são carregados via `FindByIDWithHasMany<T>`/`FindByIDWithBelongsTo<T>`, que usam `LEFT JOIN` numa única consulta — mas só a partir de uma busca por ID; não há inclusão declarativa de relacionamentos em `FindAll`/`FindWhere` nem suporte a múltiplos relacionamentos na mesma consulta ainda.
- `TWABaseORMUnitOfWork` depende de registro manual de "persisters" por classe (`RegisterPersister`); não há descoberta automática ainda.
- RTTI exige que as propriedades estejam em `published` (ou a classe tenha `{$M+}`).
