unit WABaseORM.Interfaces;

interface

uses
  Data.DB, System.Generics.Collections;

type
  IWABaseORMEntityMapper<T: class, constructor> = interface
    ['{6A2E9A0B-6C39-4F1A-9E2B-6B1B6D6A8C10}']
    function GetTableName: string;
    function GetPrimaryKeyColumn: string;
    procedure MapRowToObject(ADataSet: TDataSet; AObj: T);
    function MapObjectToParams(AObj: T; AIncludePK: Boolean): TArray<string>;
  end;

  IWABaseORMRepository<T: class, constructor> = interface
    ['{D3C7C8F4-9E62-4C2F-8E0F-2F2D6B8E4A21}']
    function FindAll: TObjectList<T>;
    function FindByID(const AId: Integer): T;
    function FindWhere(const ACondition: string): TObjectList<T>;
    procedure Insert(AObj: T);
    procedure Update(AObj: T);
    procedure Delete(const AId: Integer);
  end;

  IWABaseORMUnitOfWork = interface
    ['{4B8F5A2E-1D3C-4A7B-9E5D-8A2F6C1B9D33}']
    procedure RegisterNew(AObj: TObject);
    procedure RegisterDirty(AObj: TObject);
    procedure RegisterRemoved(AObj: TObject);
    procedure Commit;
    procedure Rollback;
  end;

implementation

end.
