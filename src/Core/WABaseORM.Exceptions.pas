unit WABaseORM.Exceptions;

interface

uses
  System.SysUtils;

type
  EWABaseORMException = class(Exception);

  EWABaseORMConnectionError = class(EWABaseORMException);

  EWABaseORMTableNotMapped = class(EWABaseORMException)
  public
    constructor Create(const AClassName: string);
  end;

  EWABaseORMPrimaryKeyNotFound = class(EWABaseORMException)
  public
    constructor Create(const AClassName: string);
  end;

  EWABaseORMRecordNotFound = class(EWABaseORMException)
  public
    constructor Create(const ATableName: string; const AId: Integer);
  end;

  EWABaseORMTransactionError = class(EWABaseORMException);

implementation

{ EWABaseORMTableNotMapped }

constructor EWABaseORMTableNotMapped.Create(const AClassName: string);
begin
  inherited CreateFmt('A classe "%s" não possui o atributo [WABaseORMTableAttribute(...)] definido.', [AClassName]);
end;

{ EWABaseORMPrimaryKeyNotFound }

constructor EWABaseORMPrimaryKeyNotFound.Create(const AClassName: string);
begin
  inherited CreateFmt('A classe "%s" não possui nenhuma propriedade marcada como chave primária (IsPK = True).', [AClassName]);
end;

{ EWABaseORMRecordNotFound }

constructor EWABaseORMRecordNotFound.Create(const ATableName: string; const AId: Integer);
begin
  inherited CreateFmt('Registro não encontrado na tabela "%s" com ID = %d.', [ATableName, AId]);
end;

end.
