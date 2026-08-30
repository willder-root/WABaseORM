unit WABaseORM.UnitOfWork;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Rtti,
  WABaseORM.DB.Interfaces, WABaseORM.Interfaces, WABaseORM.RttiCache;

type
  TWABaseORMEntityAction = (eaInsert, eaUpdate, eaDelete);

  TWABaseORMPendingEntity = record
    Obj: TObject;
    Action: TWABaseORMEntityAction;
  end;

  // Agrupa Insert/Update/Delete de várias entidades numa única transação.
  // Usa RTTI para descobrir a classe em tempo de execução e delega
  // a persistência para um TWABaseORMRepository<T> criado dinamicamente
  // via um callback registrado por tipo (veja RegisterPersister).
  TWABaseORMPersisterProc = reference to procedure(AConnection: IWABaseORMConnection; AObj: TObject; AAction: TWABaseORMEntityAction);

  TWABaseORMUnitOfWork = class(TInterfacedObject, IWABaseORMUnitOfWork)
  private
    FConnection: IWABaseORMConnection;
    FPending: TList<TWABaseORMPendingEntity>;
    FPersisters: TDictionary<TClass, TWABaseORMPersisterProc>;
  public
    constructor Create(AConnection: IWABaseORMConnection);
    destructor Destroy; override;

    procedure RegisterPersister(AClass: TClass; AProc: TWABaseORMPersisterProc);

    procedure RegisterNew(AObj: TObject);
    procedure RegisterDirty(AObj: TObject);
    procedure RegisterRemoved(AObj: TObject);

    procedure Commit;
    procedure Rollback;
  end;

implementation

{ TWABaseORMUnitOfWork }

constructor TWABaseORMUnitOfWork.Create(AConnection: IWABaseORMConnection);
begin
  inherited Create;
  FConnection := AConnection;
  FPending := TList<TWABaseORMPendingEntity>.Create;
  FPersisters := TDictionary<TClass, TWABaseORMPersisterProc>.Create;
end;

destructor TWABaseORMUnitOfWork.Destroy;
begin
  FPending.Free;
  FPersisters.Free;
  inherited;
end;

procedure TWABaseORMUnitOfWork.RegisterPersister(AClass: TClass; AProc: TWABaseORMPersisterProc);
begin
  FPersisters.AddOrSetValue(AClass, AProc);
end;

procedure TWABaseORMUnitOfWork.RegisterNew(AObj: TObject);
var
  Item: TWABaseORMPendingEntity;
begin
  Item.Obj := AObj;
  Item.Action := eaInsert;
  FPending.Add(Item);
end;

procedure TWABaseORMUnitOfWork.RegisterDirty(AObj: TObject);
var
  Item: TWABaseORMPendingEntity;
begin
  Item.Obj := AObj;
  Item.Action := eaUpdate;
  FPending.Add(Item);
end;

procedure TWABaseORMUnitOfWork.RegisterRemoved(AObj: TObject);
var
  Item: TWABaseORMPendingEntity;
begin
  Item.Obj := AObj;
  Item.Action := eaDelete;
  FPending.Add(Item);
end;

procedure TWABaseORMUnitOfWork.Commit;
var
  Transaction: IWABaseORMTransaction;
  Item: TWABaseORMPendingEntity;
  Persister: TWABaseORMPersisterProc;
begin
  Transaction := FConnection.StartTransaction;
  try
    for Item in FPending do
    begin
      if not FPersisters.TryGetValue(Item.Obj.ClassType, Persister) then
        raise Exception.CreateFmt(
          'Nenhum "persister" registrado para a classe "%s". Use RegisterPersister antes de Commit.',
          [Item.Obj.ClassType.ClassName]);

      Persister(FConnection, Item.Obj, Item.Action);
    end;

    Transaction.Commit;
    FPending.Clear;
  except
    Transaction.Rollback;
    raise;
  end;
end;

procedure TWABaseORMUnitOfWork.Rollback;
begin
  FPending.Clear;
end;

end.
