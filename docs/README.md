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
├── packages/                     Pacotes .dpk (Core e FireDAC separados)
├── examples/Demo/                Projeto de demonstração de uso
└── docs/README.md
```

## Instalação (design-time)

1. Abra `packages/WABaseORM.Core.dpk` e compile.
2. Abra `packages/WABaseORM.FireDAC.dpk` e compile (depende do Core e dos pacotes `FireDAC*` da própria instalação do Delphi — ajuste os nomes em `requires` conforme a versão da sua IDE, caso o compilador acuse pacote não encontrado).
3. Adicione o caminho de `src/Core`, `src/ORM`, `src/Common` e `src/Providers/FireDAC` em **Library Path** (ou referencie os `.dpk` diretamente no seu projeto).

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

## Convenção de nomes

| Camada | Padrão | Exemplo |
|---|---|---|
| Interfaces/contratos | `WABaseORM.<Área>.pas` | `WABaseORM.DB.Interfaces.pas` |
| Provider FireDAC | `WABaseORM.FireDAC.<Componente>.pas` | `WABaseORM.FireDAC.Connection.pas` |
| ORM/mapeamento | `WABaseORM.<Funcionalidade>.pas` | `WABaseORM.Repository.pas` |
| Testes | `WABaseORM.Tests.<Alvo>.pas` | `WABaseORM.Tests.Mapper.pas` |
| Pacotes .dpk | `WABaseORM.<Módulo>.dpk` | `WABaseORM.Core.dpk` |

## Rodando os testes

O projeto `tests/WABaseORM.Tests.dpr` usa [DUnitX](https://github.com/VSoftTechnologies/DUnitX). Os testes de `WABaseORM.Tests.FireDACConnection.pas` usam SQLite em memória (`:memory:`) para não depender de um banco externo.

## Limitações conhecidas / próximos passos

- Sem suporte a relacionamentos (1:N, N:1) ainda — cada entidade é mapeada isoladamente.
- `TWABaseORMUnitOfWork` depende de registro manual de "persisters" por classe (`RegisterPersister`); não há descoberta automática ainda.
- RTTI exige que as propriedades estejam em `published` (ou a classe tenha `{$M+}`).
