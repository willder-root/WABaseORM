unit WABaseORM.RttiCache;

interface

uses
  System.Rtti, System.TypInfo, System.SysUtils, System.Generics.Collections,
  System.SyncObjs,
  WABaseORM.Attributes, WABaseORM.Exceptions;

type
  TWABaseORMColumnInfo = record
    Prop: TRttiProperty;
    ColumnName: string;
    IsPK: Boolean;
    IsAutoInc: Boolean;
  end;

  TWABaseORMClassInfo = class
  private
    FTableName: string;
    FColumns: TArray<TWABaseORMColumnInfo>;
    FPrimaryKey: TWABaseORMColumnInfo;
    FHasPrimaryKey: Boolean;
  public
    property TableName: string read FTableName;
    property Columns: TArray<TWABaseORMColumnInfo> read FColumns;
    property PrimaryKey: TWABaseORMColumnInfo read FPrimaryKey;
    property HasPrimaryKey: Boolean read FHasPrimaryKey;
  end;

  // Cache global de metadados de mapeamento, para não reprocessar RTTI a cada chamada.
  // A inicialização/finalização é feita via initialization/finalization da unit
  // (em vez de class constructor/class destructor) para evitar o warning W1025
  // ("Unsupported language feature") em targets que não suportam esse recurso.
  TWABaseORMRttiCache = class
  private
    class var FContext: TRttiContext;
    class var FCache: TObjectDictionary<TClass, TWABaseORMClassInfo>;
    class var FLock: TCriticalSection;
    class function BuildClassInfo(AClass: TClass): TWABaseORMClassInfo;
  public
    class function GetClassInfo(AClass: TClass): TWABaseORMClassInfo;
  end;

implementation

{ TWABaseORMRttiCache }

class function TWABaseORMRttiCache.BuildClassInfo(AClass: TClass): TWABaseORMClassInfo;
var
  RttiType: TRttiType;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
  Columns: TList<TWABaseORMColumnInfo>;
  Col: TWABaseORMColumnInfo;
  TableFound: Boolean;
begin
  Result := TWABaseORMClassInfo.Create;
  RttiType := FContext.GetType(AClass);

  TableFound := False;
  for Attr in RttiType.GetAttributes do
    if Attr is WABaseORMTableAttribute then
    begin
      Result.FTableName := WABaseORMTableAttribute(Attr).Name;
      TableFound := True;
      Break;
    end;

  if not TableFound then
    raise EWABaseORMTableNotMapped.Create(AClass.ClassName);

  Columns := TList<TWABaseORMColumnInfo>.Create;
  try
    for Prop in RttiType.GetProperties do
      for Attr in Prop.GetAttributes do
        if Attr is WABaseORMColumnAttribute then
        begin
          Col.Prop := Prop;
          Col.ColumnName := WABaseORMColumnAttribute(Attr).Name;
          Col.IsPK := WABaseORMColumnAttribute(Attr).IsPK;
          Col.IsAutoInc := WABaseORMColumnAttribute(Attr).IsAutoInc;
          Columns.Add(Col);

          if Col.IsPK then
          begin
            Result.FPrimaryKey := Col;
            Result.FHasPrimaryKey := True;
          end;
        end;

    Result.FColumns := Columns.ToArray;
  finally
    Columns.Free;
  end;
end;

class function TWABaseORMRttiCache.GetClassInfo(AClass: TClass): TWABaseORMClassInfo;
begin
  FLock.Enter;
  try
    if not FCache.TryGetValue(AClass, Result) then
    begin
      Result := BuildClassInfo(AClass);
      FCache.Add(AClass, Result);
    end;
  finally
    FLock.Leave;
  end;
end;

initialization
  TWABaseORMRttiCache.FContext := TRttiContext.Create;
  TWABaseORMRttiCache.FCache := TObjectDictionary<TClass, TWABaseORMClassInfo>.Create([doOwnsValues]);
  TWABaseORMRttiCache.FLock := TCriticalSection.Create;

finalization
  TWABaseORMRttiCache.FLock.Free;
  TWABaseORMRttiCache.FCache.Free;
  TWABaseORMRttiCache.FContext.Free;

end.
