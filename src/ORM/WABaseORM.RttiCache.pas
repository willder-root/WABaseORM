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

  TWABaseORMRelationKind = (rkHasMany, rkBelongsTo);

  // Metadados de uma propriedade de navegação (HasMany/BelongsTo). O tipo apontado
  // (classe "filha" ou "pai") não é resolvido aqui: quem carrega o relacionamento
  // (TWABaseORMRepository<T>.LoadHasMany<TChild>/LoadBelongsTo<TParent>) recebe esse
  // tipo como parâmetro de generics, então só precisamos da coluna de FK e da propriedade.
  TWABaseORMRelationInfo = record
    Kind: TWABaseORMRelationKind;
    PropertyName: string;
    Prop: TRttiProperty;
    ForeignKeyColumn: string;
  end;

  TWABaseORMClassInfo = class
  private
    FTableName: string;
    FColumns: TArray<TWABaseORMColumnInfo>;
    FPrimaryKey: TWABaseORMColumnInfo;
    FHasPrimaryKey: Boolean;
    FRelations: TArray<TWABaseORMRelationInfo>;
  public
    property TableName: string read FTableName;
    property Columns: TArray<TWABaseORMColumnInfo> read FColumns;
    property PrimaryKey: TWABaseORMColumnInfo read FPrimaryKey;
    property HasPrimaryKey: Boolean read FHasPrimaryKey;
    property Relations: TArray<TWABaseORMRelationInfo> read FRelations;
    function FindColumn(const AColumnName: string; out AColumn: TWABaseORMColumnInfo): Boolean;
    function FindRelation(const APropertyName: string; AKind: TWABaseORMRelationKind;
      out ARelation: TWABaseORMRelationInfo): Boolean;
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

{ TWABaseORMClassInfo }

function TWABaseORMClassInfo.FindColumn(const AColumnName: string; out AColumn: TWABaseORMColumnInfo): Boolean;
var
  Col: TWABaseORMColumnInfo;
begin
  for Col in FColumns do
    if SameText(Col.ColumnName, AColumnName) then
    begin
      AColumn := Col;
      Exit(True);
    end;
  Result := False;
end;

function TWABaseORMClassInfo.FindRelation(const APropertyName: string; AKind: TWABaseORMRelationKind;
  out ARelation: TWABaseORMRelationInfo): Boolean;
var
  Rel: TWABaseORMRelationInfo;
begin
  for Rel in FRelations do
    if (Rel.Kind = AKind) and SameText(Rel.PropertyName, APropertyName) then
    begin
      ARelation := Rel;
      Exit(True);
    end;
  Result := False;
end;

{ TWABaseORMRttiCache }

class function TWABaseORMRttiCache.BuildClassInfo(AClass: TClass): TWABaseORMClassInfo;
var
  RttiType: TRttiType;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
  Columns: TList<TWABaseORMColumnInfo>;
  Col: TWABaseORMColumnInfo;
  Relations: TList<TWABaseORMRelationInfo>;
  Rel: TWABaseORMRelationInfo;
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
  Relations := TList<TWABaseORMRelationInfo>.Create;
  try
    for Prop in RttiType.GetProperties do
      for Attr in Prop.GetAttributes do
      begin
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
        end
        else if Attr is WABaseORMHasManyAttribute then
        begin
          Rel.Kind := rkHasMany;
          Rel.PropertyName := Prop.Name;
          Rel.Prop := Prop;
          Rel.ForeignKeyColumn := WABaseORMHasManyAttribute(Attr).ForeignKeyColumn;
          Relations.Add(Rel);
        end
        else if Attr is WABaseORMBelongsToAttribute then
        begin
          Rel.Kind := rkBelongsTo;
          Rel.PropertyName := Prop.Name;
          Rel.Prop := Prop;
          Rel.ForeignKeyColumn := WABaseORMBelongsToAttribute(Attr).ForeignKeyColumn;
          Relations.Add(Rel);
        end;
      end;

    Result.FColumns := Columns.ToArray;
    Result.FRelations := Relations.ToArray;
  finally
    Columns.Free;
    Relations.Free;
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
