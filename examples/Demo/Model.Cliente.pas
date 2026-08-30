unit Model.Cliente;

interface

uses
  WABaseORM.Attributes;

type
  [WABaseORMTableAttribute('CLIENTES')]
  TCliente = class
  private
    FId: Integer;
    FNome: string;
    FEmail: string;
  published
    [WABaseORMColumnAttribute('ID', True)]
    property Id: Integer read FId write FId;
    [WABaseORMColumnAttribute('NOME')]
    property Nome: string read FNome write FNome;
    [WABaseORMColumnAttribute('EMAIL')]
    property Email: string read FEmail write FEmail;
  end;

implementation

end.
