unit WABaseORM.FireDAC.Transaction;

interface

uses
  System.SysUtils,
  FireDAC.Comp.Client,
  WABaseORM.DB.Interfaces, WABaseORM.Exceptions;

type
  TWABaseORMFireDACTransaction = class(TInterfacedObject, IWABaseORMTransaction)
  private
    FConnection: TFDConnection;
    FFinished: Boolean;
  public
    constructor Create(AConnection: TFDConnection);
    destructor Destroy; override;
    procedure Commit;
    procedure Rollback;
  end;

implementation

{ TWABaseORMFireDACTransaction }

constructor TWABaseORMFireDACTransaction.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
  FFinished := False;
  if not FConnection.InTransaction then
    FConnection.StartTransaction;
end;

destructor TWABaseORMFireDACTransaction.Destroy;
begin
  // Segurança: se ninguém chamou Commit/Rollback explicitamente, desfaz.
  if not FFinished and FConnection.InTransaction then
    FConnection.Rollback;
  inherited;
end;

procedure TWABaseORMFireDACTransaction.Commit;
begin
  if FFinished then
    raise EWABaseORMTransactionError.Create('Transação já foi finalizada (Commit/Rollback).');
  FConnection.Commit;
  FFinished := True;
end;

procedure TWABaseORMFireDACTransaction.Rollback;
begin
  if FFinished then
    raise EWABaseORMTransactionError.Create('Transação já foi finalizada (Commit/Rollback).');
  FConnection.Rollback;
  FFinished := True;
end;

end.
